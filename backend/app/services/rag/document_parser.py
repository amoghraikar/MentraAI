"""
Document Parser and Normalization for Mentra RAG.

Extracts text, structural sections, and page numbers from TXT, Markdown, and PDF documents.
Computes deterministic SHA-256 fingerprints for duplicate detection and document versioning.
"""

import hashlib
import io
import os
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

from app.services.rag.exceptions import (
    DocumentNotFoundError,
    EmptyDocumentError,
    MalformedDocumentError,
    UnsupportedDocumentTypeError,
)

SUPPORTED_EXTENSIONS = {".txt", ".md", ".markdown", ".pdf"}


@dataclass
class DocumentSection:
    heading: str
    content: str
    page_number: Optional[int] = None


@dataclass
class ParsedDocument:
    doc_id: str
    title: str
    filename: str
    file_type: str
    file_hash: str
    raw_text: str
    char_count: int
    sections: List[DocumentSection] = field(default_factory=list)
    metadata: Dict[str, Union[str, int, float, bool]] = field(default_factory=dict)


class DocumentParser:
    """Parses and normalizes local study files into structured, page/section-aware documents."""

    @staticmethod
    def normalize_text(text: str) -> str:
        """Sanitizes text, standardizes line endings, cleans control chars, and normalizes Unicode."""
        if not text:
            return ""
        # Unicode normalization (NFC)
        text = unicodedata.normalize("NFC", text)
        # Standardize line endings
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        # Strip null bytes and non-printable control characters (retain tabs and newlines)
        text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)
        # Strip trailing whitespace on each line
        lines = [line.rstrip() for line in text.split("\n")]
        # Collapse excessive blank lines (> 2 newlines to 2 newlines)
        normalized = "\n".join(lines)
        normalized = re.sub(r"\n{3,}", "\n\n", normalized)
        return normalized.strip()

    @staticmethod
    def compute_hash(content: Union[str, bytes]) -> str:
        """Computes SHA-256 fingerprint for document content."""
        hasher = hashlib.sha256()
        if isinstance(content, str):
            hasher.update(content.encode("utf-8"))
        else:
            hasher.update(content)
        return hasher.hexdigest()

    @classmethod
    def parse_text_content(
        cls,
        content: str,
        filename: str,
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> ParsedDocument:
        """Parses in-memory raw text or markdown content."""
        normalized = cls.normalize_text(content)
        if not normalized:
            raise EmptyDocumentError(f"Document '{filename}' contains no readable text")

        ext = Path(filename).suffix.lower() if filename else ".txt"
        if ext not in SUPPORTED_EXTENSIONS:
            # Default to .txt if no extension provided or treat as text
            if not ext:
                ext = ".txt"
            else:
                raise UnsupportedDocumentTypeError(f"Unsupported document format '{ext}'. Supported: {', '.join(SUPPORTED_EXTENSIONS)}")

        doc_hash = cls.compute_hash(normalized)
        inferred_title = title or Path(filename).stem.replace("_", " ").title()
        generated_id = doc_id or f"doc_{doc_hash[:12]}"

        sections = cls._extract_sections_from_text(normalized)

        return ParsedDocument(
            doc_id=generated_id,
            title=inferred_title,
            filename=filename,
            file_type=ext.lstrip("."),
            file_hash=doc_hash,
            raw_text=normalized,
            char_count=len(normalized),
            sections=sections,
            metadata={
                "source_type": "text",
                "char_count": len(normalized),
                "sections_count": len(sections),
            },
        )

    @classmethod
    def parse_file(
        cls,
        file_path: Union[str, Path],
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> ParsedDocument:
        """Parses a file on disk (TXT, MD, PDF)."""
        path = Path(file_path).resolve()
        if not path.exists() or not path.is_file():
            raise DocumentNotFoundError(f"File not found at '{file_path}'")

        ext = path.suffix.lower()
        if ext not in SUPPORTED_EXTENSIONS:
            raise UnsupportedDocumentTypeError(
                f"File format '{ext}' is not supported. Supported: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
            )

        file_size = path.stat().st_size
        if file_size == 0:
            raise EmptyDocumentError(f"File '{path.name}' is empty (0 bytes)")

        if ext == ".pdf":
            return cls._parse_pdf_file(path, title=title, doc_id=doc_id)
        else:
            return cls._parse_text_file(path, title=title, doc_id=doc_id)

    @classmethod
    def _parse_text_file(
        cls,
        path: Path,
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> ParsedDocument:
        """Parses plain text or Markdown file from disk."""
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            try:
                content = path.read_text(encoding="latin-1")
            except Exception as e:
                raise MalformedDocumentError(f"Failed to read file '{path.name}': {e}") from e

        return cls.parse_text_content(
            content=content,
            filename=path.name,
            title=title,
            doc_id=doc_id,
        )

    @classmethod
    def _parse_pdf_file(
        cls,
        path: Path,
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
    ) -> ParsedDocument:
        """Parses PDF file page-by-page, extracting text and page numbers."""
        try:
            import pypdf
        except ImportError as e:
            raise MalformedDocumentError("pypdf library is required for PDF parsing") from e

        try:
            with open(path, "rb") as f:
                raw_bytes = f.read()
                file_hash = cls.compute_hash(raw_bytes)
                reader = pypdf.PdfReader(io.BytesIO(raw_bytes))

                if len(reader.pages) == 0:
                    raise EmptyDocumentError(f"PDF '{path.name}' contains 0 pages")

                sections: List[DocumentSection] = []
                full_text_parts: List[str] = []

                for page_idx, page in enumerate(reader.pages):
                    page_num = page_idx + 1
                    try:
                        extracted = page.extract_text() or ""
                    except Exception:
                        extracted = ""
                    normalized_page = cls.normalize_text(extracted)
                    if normalized_page:
                        full_text_parts.append(normalized_page)
                        # Extract sub-sections on this page
                        page_sections = cls._extract_sections_from_text(normalized_page, page_number=page_num)
                        sections.extend(page_sections)

                full_text = "\n\n".join(full_text_parts).strip()
                if not full_text:
                    raise EmptyDocumentError(f"PDF '{path.name}' contains no readable or extractable text")

                inferred_title = title or path.stem.replace("_", " ").title()
                generated_id = doc_id or f"doc_{file_hash[:12]}"

                return ParsedDocument(
                    doc_id=generated_id,
                    title=inferred_title,
                    filename=path.name,
                    file_type="pdf",
                    file_hash=file_hash,
                    raw_text=full_text,
                    char_count=len(full_text),
                    sections=sections,
                    metadata={
                        "source_type": "pdf",
                        "page_count": len(reader.pages),
                        "char_count": len(full_text),
                        "file_size_bytes": len(raw_bytes),
                    },
                )
        except (DocumentNotFoundError, EmptyDocumentError, UnsupportedDocumentTypeError, MalformedDocumentError):
            raise
        except Exception as e:
            raise MalformedDocumentError(f"Failed to parse PDF '{path.name}': {e}") from e

    @classmethod
    def _extract_sections_from_text(
        cls,
        text: str,
        page_number: Optional[int] = None,
    ) -> List[DocumentSection]:
        """Splits document text by markdown headings (#, ##) or natural paragraphs."""
        lines = text.split("\n")
        sections: List[DocumentSection] = []
        current_heading = "General"
        current_lines: List[str] = []

        header_pattern = re.compile(r"^(#{1,4})\s+(.+)$")

        for line in lines:
            match = header_pattern.match(line.strip())
            if match:
                if current_lines:
                    content = "\n".join(current_lines).strip()
                    if content:
                        sections.append(DocumentSection(heading=current_heading, content=content, page_number=page_number))
                    current_lines = []
                current_heading = match.group(2).strip()
            else:
                current_lines.append(line)

        if current_lines:
            content = "\n".join(current_lines).strip()
            if content:
                sections.append(DocumentSection(heading=current_heading, content=content, page_number=page_number))

        return sections
