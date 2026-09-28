"""
Deterministic Chunker for Mentra RAG.

Splits parsed documents into semantic, sentence-boundary-preserving chunks with rich metadata.
Guarantees deterministic chunk IDs and structural awareness (headings, pages).
"""

import re
from dataclasses import asdict, dataclass
from typing import Any, Dict, List, Optional

from app.services.rag.document_parser import ParsedDocument, DocumentSection


@dataclass
class DocumentChunk:
    chunk_id: str
    doc_id: str
    doc_title: str
    filename: str
    chunk_index: int
    text: str
    page_number: Optional[int] = None
    section_heading: Optional[str] = None
    char_count: int = 0
    token_estimate: int = 0
    metadata: Dict[str, Any] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        if not d.get("metadata"):
            d["metadata"] = {}
        return d


class DeterministicChunker:
    """
    Splits text into deterministic, sentence-boundary-preserving chunks.
    Configured for pedagogical texts (concise, high-information chunks with context preservation).
    """

    DEFAULT_CHUNK_SIZE = 500  # Target characters (~100-120 words)
    DEFAULT_CHUNK_OVERLAP = 80  # Character overlap for continuity
    MIN_CHUNK_SIZE = 40  # Minimum size to prevent stray fragments

    def __init__(
        self,
        chunk_size: int = DEFAULT_CHUNK_SIZE,
        chunk_overlap: int = DEFAULT_CHUNK_OVERLAP,
        min_chunk_size: int = MIN_CHUNK_SIZE,
    ):
        if chunk_size <= chunk_overlap:
            raise ValueError(f"chunk_size ({chunk_size}) must be greater than chunk_overlap ({chunk_overlap})")
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.min_chunk_size = min_chunk_size

    def chunk_document(self, doc: ParsedDocument) -> List[DocumentChunk]:
        """Chunks a ParsedDocument preserving section headings and page numbers."""
        all_chunks: List[DocumentChunk] = []
        global_chunk_idx = 0

        # If sections are available, chunk by section
        if doc.sections:
            for section in doc.sections:
                section_chunks = self._chunk_section(
                    text=section.content,
                    doc_id=doc.doc_id,
                    doc_title=doc.title,
                    filename=doc.filename,
                    start_idx=global_chunk_idx,
                    page_number=section.page_number,
                    section_heading=section.heading,
                )
                all_chunks.extend(section_chunks)
                global_chunk_idx += len(section_chunks)
        else:
            # Fallback to chunking raw_text
            all_chunks = self._chunk_section(
                text=doc.raw_text,
                doc_id=doc.doc_id,
                doc_title=doc.title,
                filename=doc.filename,
                start_idx=0,
                page_number=None,
                section_heading="General",
            )

        # Fallback: if text was non-empty but somehow yielded no chunks due to min_chunk_size
        if not all_chunks and doc.raw_text.strip():
            fallback_text = doc.raw_text.strip()
            all_chunks.append(
                DocumentChunk(
                    chunk_id=f"{doc.doc_id}_c0",
                    doc_id=doc.doc_id,
                    doc_title=doc.title,
                    filename=doc.filename,
                    chunk_index=0,
                    text=fallback_text,
                    page_number=1 if doc.file_type == "pdf" else None,
                    section_heading="General",
                    char_count=len(fallback_text),
                    token_estimate=max(1, len(fallback_text) // 4),
                    metadata={"source": doc.filename},
                )
            )

        return all_chunks

    def _chunk_section(
        self,
        text: str,
        doc_id: str,
        doc_title: str,
        filename: str,
        start_idx: int,
        page_number: Optional[int],
        section_heading: Optional[str],
    ) -> List[DocumentChunk]:
        """Splits section text into sentence-aware overlapping chunks."""
        clean_text = text.strip()
        if not clean_text:
            return []

        # If section is small enough, keep as single chunk
        if len(clean_text) <= self.chunk_size:
            return [
                DocumentChunk(
                    chunk_id=f"{doc_id}_c{start_idx}",
                    doc_id=doc_id,
                    doc_title=doc_title,
                    filename=filename,
                    chunk_index=start_idx,
                    text=clean_text,
                    page_number=page_number,
                    section_heading=section_heading,
                    char_count=len(clean_text),
                    token_estimate=max(1, len(clean_text) // 4),
                    metadata={
                        "source": filename,
                        "heading": section_heading,
                        "page": page_number,
                    },
                )
            ]

        # Break text into paragraphs, then sentences
        paragraphs = clean_text.split("\n\n")
        sentences: List[str] = []
        for p in paragraphs:
            p_clean = p.strip()
            if not p_clean:
                continue
            # Split by sentence boundaries (.?! followed by space or newline)
            p_sentences = re.split(r"(?<=[.!?])\s+", p_clean)
            for s in p_sentences:
                s_strip = s.strip()
                if s_strip:
                    sentences.append(s_strip)

        chunks: List[DocumentChunk] = []
        current_sentences: List[str] = []
        current_len = 0
        chunk_idx = start_idx

        for sentence in sentences:
            sentence_len = len(sentence)
            # If a single sentence exceeds chunk size, split it by words
            if sentence_len > self.chunk_size:
                if current_sentences:
                    chunk_text = " ".join(current_sentences).strip()
                    if len(chunk_text) >= self.min_chunk_size:
                        chunks.append(
                            self._create_chunk(
                                chunk_text, doc_id, doc_title, filename, chunk_idx, page_number, section_heading
                            )
                        )
                        chunk_idx += 1
                    current_sentences = []
                    current_len = 0

                # Split oversized sentence
                sub_chunks = self._split_oversized_sentence(sentence)
                for sc in sub_chunks:
                    chunks.append(
                        self._create_chunk(
                            sc, doc_id, doc_title, filename, chunk_idx, page_number, section_heading
                        )
                    )
                    chunk_idx += 1
                continue

            if current_len + sentence_len + (1 if current_sentences else 0) <= self.chunk_size:
                current_sentences.append(sentence)
                current_len += sentence_len + (1 if current_sentences else 0)
            else:
                if current_sentences:
                    chunk_text = " ".join(current_sentences).strip()
                    if len(chunk_text) >= self.min_chunk_size:
                        chunks.append(
                            self._create_chunk(
                                chunk_text, doc_id, doc_title, filename, chunk_idx, page_number, section_heading
                            )
                        )
                        chunk_idx += 1

                # Calculate overlap: retain trailing sentences that fit within overlap budget
                overlap_sentences: List[str] = []
                overlap_len = 0
                for s in reversed(current_sentences):
                    if overlap_len + len(s) + 1 <= self.chunk_overlap:
                        overlap_sentences.insert(0, s)
                        overlap_len += len(s) + 1
                    else:
                        break

                current_sentences = overlap_sentences + [sentence]
                current_len = sum(len(s) for s in current_sentences) + max(0, len(current_sentences) - 1)

        if current_sentences:
            chunk_text = " ".join(current_sentences).strip()
            if len(chunk_text) >= self.min_chunk_size or not chunks:
                chunks.append(
                    self._create_chunk(
                        chunk_text, doc_id, doc_title, filename, chunk_idx, page_number, section_heading
                    )
                )

        return chunks

    def _split_oversized_sentence(self, sentence: str) -> List[str]:
        """Breaks a long sentence into sub-chunks at word boundaries."""
        words = sentence.split()
        sub_chunks: List[str] = []
        current_words: List[str] = []
        current_len = 0

        for w in words:
            if current_len + len(w) + 1 <= self.chunk_size:
                current_words.append(w)
                current_len += len(w) + 1
            else:
                if current_words:
                    sub_chunks.append(" ".join(current_words))
                current_words = [w]
                current_len = len(w)

        if current_words:
            sub_chunks.append(" ".join(current_words))

        return sub_chunks

    def _create_chunk(
        self,
        text: str,
        doc_id: str,
        doc_title: str,
        filename: str,
        chunk_idx: int,
        page_number: Optional[int],
        section_heading: Optional[str],
    ) -> DocumentChunk:
        return DocumentChunk(
            chunk_id=f"{doc_id}_c{chunk_idx}",
            doc_id=doc_id,
            doc_title=doc_title,
            filename=filename,
            chunk_index=chunk_idx,
            text=text,
            page_number=page_number,
            section_heading=section_heading,
            char_count=len(text),
            token_estimate=max(1, len(text) // 4),
            metadata={
                "source": filename,
                "heading": section_heading,
                "page": page_number,
            },
        )
