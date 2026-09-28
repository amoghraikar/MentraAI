import logging
from typing import Dict, List, Optional
from pydantic import BaseModel

from app.services.rag import rag_engine, LocalRAGEngine

logger = logging.getLogger(__name__)


class DocumentChunk(BaseModel):
    chunk_id: str
    doc_id: str
    doc_title: str
    content: str
    token_estimate: int


class StudyMaterialDocument(BaseModel):
    doc_id: str
    title: str
    filename: str
    char_count: int
    chunks_count: int
    summary_preview: str


class DocumentService:
    """
    Service adapter exposing the canonical LocalRAGEngine to existing Mentra endpoints.
    Provides persistent SQLite vector storage, on-device embeddings, and semantic search.
    """

    def __init__(self, engine: Optional[LocalRAGEngine] = None):
        self.engine = engine or rag_engine

    def ingest_material(self, title: str, content: str, filename: Optional[str] = None) -> StudyMaterialDocument:
        """Parses, embeds, and indexes a study document using LocalRAGEngine."""
        fname = filename or f"{title.lower().replace(' ', '_')}.txt"
        ingestion = self.engine.ingest_document(
            content=content,
            filename=fname,
            title=title,
        )

        clean_text = content.strip()
        preview = clean_text[:200] + ("..." if len(clean_text) > 200 else "")
        return StudyMaterialDocument(
            doc_id=ingestion.doc_id,
            title=ingestion.title,
            filename=ingestion.filename,
            char_count=ingestion.char_count,
            chunks_count=ingestion.chunk_count,
            summary_preview=preview,
        )

    def get_document(self, doc_id: str) -> Optional[StudyMaterialDocument]:
        doc = self.engine.get_document(doc_id)
        if not doc:
            return None
        return StudyMaterialDocument(
            doc_id=doc["doc_id"],
            title=doc["title"],
            filename=doc["filename"],
            char_count=doc["char_count"],
            chunks_count=doc["chunk_count"],
            summary_preview="",
        )

    def list_documents(self) -> List[StudyMaterialDocument]:
        docs = self.engine.list_documents()
        return [
            StudyMaterialDocument(
                doc_id=d["doc_id"],
                title=d["title"],
                filename=d["filename"],
                char_count=d["char_count"],
                chunks_count=d["chunk_count"],
                summary_preview="",
            )
            for d in docs
        ]

    def retrieve_relevant_context(self, query: str, top_k: int = 4, threshold: float = 0.35) -> str:
        """Retrieves semantic context via LocalRAGEngine. Returns empty string if below threshold."""
        res = self.engine.retrieve_context(query=query, top_k=top_k, threshold=threshold)
        if res.status == "NO_RELEVANT_CONTEXT":
            return ""
        return res.formatted_context

    def clear(self) -> bool:
        return self.engine.clear_index()


# Global DocumentService instance
document_service = DocumentService()
