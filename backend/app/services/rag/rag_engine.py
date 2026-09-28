"""
Canonical Independent Local RAG Engine for Mentra.

Coordinates DocumentParser, DeterministicChunker, LocalEmbeddingModel,
LocalVectorStore, SemanticRetriever, and RAGContextFormatter.
Everything runs 100% on-device. No external APIs or cloud dependencies.
"""

from dataclasses import asdict, dataclass
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

from app.services.rag.chunker import DeterministicChunker, DocumentChunk
from app.services.rag.context_formatter import NO_RELEVANT_CONTEXT, RAGContextFormatter
from app.services.rag.document_parser import DocumentParser, ParsedDocument
from app.services.rag.embeddings import LocalEmbeddingModel, embedding_model
from app.services.rag.exceptions import RAGError, QueryError
from app.services.rag.retriever import SemanticRetriever
from app.services.rag.vector_store import LocalVectorStore, VectorSearchResult

logger = logging.getLogger("mentra.rag.engine")


@dataclass
class IngestionResult:
    status: str  # "INDEXED", "ALREADY_INDEXED", "UPDATED"
    is_duplicate: bool
    doc_id: str
    title: str
    filename: str
    char_count: int
    chunk_count: int
    file_hash: str
    file_type: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class RAGContextResponse:
    status: str  # "SUCCESS" or "NO_RELEVANT_CONTEXT"
    query: str
    results_count: int
    results: List[Dict[str, Any]]
    formatted_context: str
    sources: List[Dict[str, Any]]

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class LocalRAGEngine:
    """
    Independent Local Retrieval-Augmented Generation Engine for Mentra.
    Provides document parsing, deterministic chunking, on-device vector embedding,
    SQLite persistence, semantic retrieval, and source-grounded prompt assembly.
    """

    def __init__(
        self,
        vector_store: Optional[LocalVectorStore] = None,
        embeddings: Optional[LocalEmbeddingModel] = None,
        chunk_size: int = DeterministicChunker.DEFAULT_CHUNK_SIZE,
        chunk_overlap: int = DeterministicChunker.DEFAULT_CHUNK_OVERLAP,
        default_top_k: int = SemanticRetriever.DEFAULT_TOP_K,
        default_threshold: float = SemanticRetriever.DEFAULT_THRESHOLD,
    ):
        self.embeddings = embeddings or embedding_model
        self.vector_store = vector_store or LocalVectorStore()
        self.parser = DocumentParser()
        self.chunker = DeterministicChunker(chunk_size=chunk_size, chunk_overlap=chunk_overlap)
        self.retriever = SemanticRetriever(
            vector_store=self.vector_store,
            embeddings=self.embeddings,
            default_top_k=default_top_k,
            default_threshold=default_threshold,
        )
        self.formatter = RAGContextFormatter()

    def ingest_document(
        self,
        content: str,
        filename: str = "notes.txt",
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> IngestionResult:
        """
        Parses, chunks, embeds, and indexes text or markdown content into the vector store.
        Prevents duplicate indexing if identical content was already ingested.
        Re-indexes and replaces stale chunks if document content changed.
        """
        parsed_doc = self.parser.parse_text_content(
            content=content,
            filename=filename,
            title=title,
            doc_id=doc_id,
        )
        return self._index_parsed_document(parsed_doc)

    def ingest_file(
        self,
        file_path: Union[str, Path],
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> IngestionResult:
        """
        Loads and indexes a file from disk (.txt, .md, .pdf).
        """
        parsed_doc = self.parser.parse_file(
            file_path=file_path,
            title=title,
            doc_id=doc_id,
        )
        return self._index_parsed_document(parsed_doc)

    def _index_parsed_document(self, parsed_doc: ParsedDocument) -> IngestionResult:
        """Internal helper to execute deduplication, chunking, embedding, and storage."""
        # 1. Check for exact duplicate by file hash
        existing_by_hash = self.vector_store.get_document_by_hash(parsed_doc.file_hash)
        if existing_by_hash and existing_by_hash["filename"] == parsed_doc.filename:
            logger.info("Document '%s' already indexed with identical hash. Skipping duplicate.", parsed_doc.title)
            return IngestionResult(
                status="ALREADY_INDEXED",
                is_duplicate=True,
                doc_id=existing_by_hash["doc_id"],
                title=existing_by_hash["title"],
                filename=existing_by_hash["filename"],
                char_count=existing_by_hash["char_count"],
                chunk_count=existing_by_hash["chunk_count"],
                file_hash=existing_by_hash["file_hash"],
                file_type=existing_by_hash["file_type"],
            )

        # 2. Check if a document with same filename exists with different hash (Update scenario)
        existing_by_name = self.vector_store.get_document_by_filename(parsed_doc.filename)
        is_update = existing_by_name is not None
        if is_update:
            logger.info("Document '%s' changed. Replacing previous version.", parsed_doc.filename)

        # 3. Create deterministic chunks
        chunks = self.chunker.chunk_document(parsed_doc)
        if not chunks:
            raise RAGError("CHUNKING_FAILED", f"No chunks generated for document '{parsed_doc.title}'")

        # 4. Generate local embeddings
        chunk_texts = [c.text for c in chunks]
        embeddings = self.embeddings.embed_batch(chunk_texts)

        # 5. Insert document and chunks atomically
        self.vector_store.insert_document(parsed_doc, chunks, embeddings)

        return IngestionResult(
            status="UPDATED" if is_update else "INDEXED",
            is_duplicate=False,
            doc_id=parsed_doc.doc_id,
            title=parsed_doc.title,
            filename=parsed_doc.filename,
            char_count=parsed_doc.char_count,
            chunk_count=len(chunks),
            file_hash=parsed_doc.file_hash,
            file_type=parsed_doc.file_type,
        )

    def remove_document(self, doc_id: str) -> bool:
        """Removes a document and all its chunks from the vector store."""
        return self.vector_store.delete_document(doc_id)

    def list_documents(self) -> List[Dict[str, Any]]:
        """Lists all indexed documents."""
        return self.vector_store.list_documents()

    def get_document(self, doc_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves a single document metadata record."""
        return self.vector_store.get_document(doc_id)

    def search(
        self,
        query: str,
        top_k: Optional[int] = None,
        threshold: Optional[float] = None,
    ) -> List[Dict[str, Any]]:
        """Searches vector store and returns raw chunk results with similarity scores."""
        results = self.retriever.retrieve(query=query, top_k=top_k, threshold=threshold)
        return [r.to_dict() for r in results]

    def retrieve_context(
        self,
        query: str,
        top_k: Optional[int] = None,
        threshold: Optional[float] = None,
    ) -> RAGContextResponse:
        """
        Executes semantic retrieval and formats source-grounded context.
        Returns status 'NO_RELEVANT_CONTEXT' if no chunks pass the threshold.
        """
        if not query or not query.strip():
            raise QueryError("Query text cannot be empty or whitespace")

        results = self.retriever.retrieve(query=query, top_k=top_k, threshold=threshold)

        if not results:
            return RAGContextResponse(
                status="NO_RELEVANT_CONTEXT",
                query=query.strip(),
                results_count=0,
                results=[],
                formatted_context=NO_RELEVANT_CONTEXT,
                sources=[],
            )

        formatted_context = self.formatter.format_context(results)
        sources = self.formatter.extract_sources(results)

        return RAGContextResponse(
            status="SUCCESS",
            query=query.strip(),
            results_count=len(results),
            results=[r.to_dict() for r in results],
            formatted_context=formatted_context,
            sources=sources,
        )

    def clear_index(self) -> bool:
        """Clears all indexed documents and chunks."""
        return self.vector_store.clear()

    def get_stats(self) -> Dict[str, Any]:
        """Returns storage and model statistics."""
        db_path = self.vector_store.db_path
        storage_size = db_path.stat().st_size if db_path.exists() else 0
        return {
            "document_count": self.vector_store.count_documents(),
            "chunk_count": self.vector_store.count_chunks(),
            "embedding_model": self.embeddings.model,
            "embedding_dimension": self.embeddings.dimension,
            "runtime": "ollama (local)",
            "vector_store_type": "sqlite3_binary_float32",
            "vector_store_path": str(db_path),
            "storage_size_bytes": storage_size,
        }


# Canonical singleton RAG engine instance
rag_engine = LocalRAGEngine()
