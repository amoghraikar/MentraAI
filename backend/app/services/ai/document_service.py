import logging
import re
import uuid
from typing import Dict, List, Optional
from pydantic import BaseModel

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
    Ingests and indexes study materials (lecture notes, syllabus, textbook excerpts).
    Performs chunking and relevance matching to ground the Study Coach GPT.
    """

    def __init__(self):
        # In-memory document index store (keyed by doc_id)
        self._documents: Dict[str, StudyMaterialDocument] = {}
        self._chunks: List[DocumentChunk] = []

    def ingest_material(self, title: str, content: str, filename: Optional[str] = None) -> StudyMaterialDocument:
        """Parses and indexes a study document."""
        doc_id = f"doc_{uuid.uuid4().hex[:8]}"
        filename = filename or f"{title.lower().replace(' ', '_')}.txt"
        clean_text = content.strip()

        # Split into semantic chunks (~500-800 characters per chunk with overlap)
        chunks = self._chunk_text(clean_text, doc_id, title)
        self._chunks.extend(chunks)

        preview = clean_text[:200] + ("..." if len(clean_text) > 200 else "")
        doc = StudyMaterialDocument(
            doc_id=doc_id,
            title=title,
            filename=filename,
            char_count=len(clean_text),
            chunks_count=len(chunks),
            summary_preview=preview,
        )
        self._documents[doc_id] = doc
        logger.info(f"Ingested study document '{title}' ({len(chunks)} chunks)")
        return doc

    def get_document(self, doc_id: str) -> Optional[StudyMaterialDocument]:
        return self._documents.get(doc_id)

    def list_documents(self) -> List[StudyMaterialDocument]:
        return list(self._documents.values())

    def retrieve_relevant_context(self, query: str, top_k: int = 4) -> str:
        """Retrieves the most relevant study material chunks for a given query."""
        if not self._chunks:
            return ""

        query_terms = set(re.findall(r"\w+", query.lower()))
        if not query_terms:
            return ""

        scored_chunks = []
        for chunk in self._chunks:
            chunk_terms = set(re.findall(r"\w+", chunk.content.lower()))
            overlap = len(query_terms.intersection(chunk_terms))
            if overlap > 0:
                scored_chunks.append((overlap, chunk))

        scored_chunks.sort(key=lambda x: x[0], reverse=True)
        top_chunks = [chunk for _, chunk in scored_chunks[:top_k]]

        if not top_chunks:
            # If no direct keyword overlap, return the first 2 chunks as baseline context
            top_chunks = self._chunks[:2]

        context_blocks = []
        for c in top_chunks:
            context_blocks.append(f"--- Excerpt from '{c.doc_title}' ---\n{c.content}")

        return "\n\n".join(context_blocks)

    def _chunk_text(self, text: str, doc_id: str, doc_title: str, chunk_size: int = 750, overlap: int = 150) -> List[DocumentChunk]:
        """Splits text into overlapping chunks for retrieval."""
        paragraphs = text.split("\n\n")
        chunks: List[DocumentChunk] = []
        current_chunk = ""

        for p in paragraphs:
            p_clean = p.strip()
            if not p_clean:
                continue

            if len(current_chunk) + len(p_clean) < chunk_size:
                current_chunk += ("\n\n" if current_chunk else "") + p_clean
            else:
                if current_chunk:
                    chunks.append(
                        DocumentChunk(
                            chunk_id=f"chk_{uuid.uuid4().hex[:8]}",
                            doc_id=doc_id,
                            doc_title=doc_title,
                            content=current_chunk,
                            token_estimate=len(current_chunk) // 4,
                        )
                    )
                # Apply overlap from end of current chunk
                overlap_text = current_chunk[-overlap:] if len(current_chunk) > overlap else ""
                current_chunk = (overlap_text + "\n\n" + p_clean).strip()

        if current_chunk:
            chunks.append(
                DocumentChunk(
                    chunk_id=f"chk_{uuid.uuid4().hex[:8]}",
                    doc_id=doc_id,
                    doc_title=doc_title,
                    content=current_chunk,
                    token_estimate=len(current_chunk) // 4,
                )
            )

        return chunks


# Global DocumentService instance
document_service = DocumentService()
