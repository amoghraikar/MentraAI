"""
Local Persistent Vector Store for Mentra RAG.

Backed by SQLite with binary-packed float32 vector storage.
Persists across application restarts, handles change detection, deduplication,
and vectorized cosine-similarity retrieval via NumPy matrix multiplication.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import logging
import os
from pathlib import Path
import sqlite3
import struct
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from app.services.rag.chunker import DocumentChunk
from app.services.rag.document_parser import ParsedDocument
from app.services.rag.exceptions import VectorStoreError

logger = logging.getLogger("mentra.rag.vector_store")

DEFAULT_DB_PATH = Path("backend/data/rag_vector_store.db")


@dataclass
class VectorSearchResult:
    chunk_id: str
    doc_id: str
    doc_title: str
    filename: str
    chunk_index: int
    text: str
    page_number: Optional[int]
    section_heading: Optional[str]
    similarity_score: float
    char_count: int
    metadata: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "chunk_id": self.chunk_id,
            "doc_id": self.doc_id,
            "doc_title": self.doc_title,
            "filename": self.filename,
            "chunk_index": self.chunk_index,
            "text": self.text,
            "page_number": self.page_number,
            "section_heading": self.section_heading,
            "similarity_score": round(self.similarity_score, 4),
            "char_count": self.char_count,
            "metadata": self.metadata or {},
        }


class LocalVectorStore:
    """
    On-device SQLite-backed persistent vector store.
    Stores documents, chunks, and exact 384-dimensional float32 vector embeddings.
    """

    def __init__(self, db_path: Optional[Path] = None):
        self.db_path = Path(db_path or DEFAULT_DB_PATH).resolve()
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path), check_same_thread=False, timeout=30.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA foreign_keys=ON;")
        return conn

    def _init_db(self) -> None:
        """Initializes tables for documents and vectorized chunks."""
        with self._get_connection() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS rag_documents (
                    doc_id TEXT PRIMARY KEY,
                    filename TEXT NOT NULL,
                    title TEXT NOT NULL,
                    file_hash TEXT NOT NULL,
                    file_type TEXT NOT NULL,
                    char_count INTEGER NOT NULL,
                    chunk_count INTEGER NOT NULL,
                    metadata_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS rag_chunks (
                    chunk_id TEXT PRIMARY KEY,
                    doc_id TEXT NOT NULL,
                    chunk_index INTEGER NOT NULL,
                    text TEXT NOT NULL,
                    page_number INTEGER,
                    section_heading TEXT,
                    char_count INTEGER NOT NULL,
                    embedding_blob BLOB NOT NULL,
                    metadata_json TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (doc_id) REFERENCES rag_documents(doc_id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_rag_chunks_doc_id ON rag_chunks(doc_id);
                CREATE INDEX IF NOT EXISTS idx_rag_documents_hash ON rag_documents(file_hash);
                CREATE INDEX IF NOT EXISTS idx_rag_documents_filename ON rag_documents(filename);
            """)

    @staticmethod
    def _pack_vector(vector: List[float]) -> bytes:
        """Packs float list into binary float32 buffer."""
        return struct.pack(f"{len(vector)}f", *vector)

    @staticmethod
    def _unpack_vector(blob: bytes) -> np.ndarray:
        """Unpacks binary buffer into NumPy float32 array."""
        return np.frombuffer(blob, dtype=np.float32)

    def insert_document(
        self,
        doc: ParsedDocument,
        chunks: List[DocumentChunk],
        embeddings: List[List[float]],
    ) -> None:
        """
        Inserts document and its vectorized chunks atomically.
        If a document with the same doc_id or same filename exists, replaces previous chunks cleanly.
        """
        if len(chunks) != len(embeddings):
            raise VectorStoreError(
                f"Mismatch: {len(chunks)} chunks provided with {len(embeddings)} embedding vectors"
            )

        now_str = datetime.now(timezone.utc).isoformat()

        with self._get_connection() as conn:
            cursor = conn.cursor()
            try:
                # Remove any existing document with same filename to avoid stale chunks on update
                cursor.execute("SELECT doc_id FROM rag_documents WHERE filename = ?", (doc.filename,))
                existing = cursor.fetchall()
                for row in existing:
                    cursor.execute("DELETE FROM rag_documents WHERE doc_id = ?", (row["doc_id"],))

                # Insert document record
                cursor.execute(
                    """
                    INSERT INTO rag_documents (
                        doc_id, filename, title, file_hash, file_type,
                        char_count, chunk_count, metadata_json, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        doc.doc_id,
                        doc.filename,
                        doc.title,
                        doc.file_hash,
                        doc.file_type,
                        doc.char_count,
                        len(chunks),
                        json.dumps(doc.metadata or {}),
                        now_str,
                        now_str,
                    ),
                )

                # Insert chunks
                chunk_rows = []
                for chunk, vec in zip(chunks, embeddings):
                    blob = self._pack_vector(vec)
                    chunk_rows.append(
                        (
                            chunk.chunk_id,
                            chunk.doc_id,
                            chunk.chunk_index,
                            chunk.text,
                            chunk.page_number,
                            chunk.section_heading,
                            chunk.char_count,
                            blob,
                            json.dumps(chunk.metadata or {}),
                            now_str,
                        )
                    )

                cursor.executemany(
                    """
                    INSERT INTO rag_chunks (
                        chunk_id, doc_id, chunk_index, text, page_number,
                        section_heading, char_count, embedding_blob, metadata_json, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    chunk_rows,
                )
                conn.commit()
                logger.info("Indexed document '%s' with %d chunks into SQLite store", doc.title, len(chunks))
            except Exception as e:
                conn.rollback()
                raise VectorStoreError(f"Failed to insert document into vector store: {e}") from e

    def get_document_by_hash(self, file_hash: str) -> Optional[Dict[str, Any]]:
        """Finds existing document by SHA-256 fingerprint."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM rag_documents WHERE file_hash = ?",
                (file_hash,),
            )
            row = cursor.fetchone()
            if row:
                return dict(row)
        return None

    def get_document(self, doc_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves document record by doc_id."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rag_documents WHERE doc_id = ?", (doc_id,))
            row = cursor.fetchone()
            if row:
                return dict(row)
        return None

    def get_document_by_filename(self, filename: str) -> Optional[Dict[str, Any]]:
        """Retrieves document record by filename."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rag_documents WHERE filename = ?", (filename,))
            row = cursor.fetchone()
            if row:
                return dict(row)
        return None

    def delete_document(self, doc_id: str) -> bool:
        """Deletes a document and all associated chunks."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM rag_documents WHERE doc_id = ?", (doc_id,))
            conn.commit()
            return cursor.rowcount > 0

    def list_documents(self) -> List[Dict[str, Any]]:
        """Lists all ingested documents ordered by update time."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM rag_documents ORDER BY updated_at DESC")
            return [dict(row) for row in cursor.fetchall()]

    def count_documents(self) -> int:
        """Returns total number of distinct ingested documents."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM rag_documents")
            return cursor.fetchone()[0]

    def count_chunks(self) -> int:
        """Returns total number of chunks across all documents."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM rag_chunks")
            return cursor.fetchone()[0]

    def clear(self) -> bool:
        """Clears all documents and chunks from the vector store."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM rag_chunks;")
            cursor.execute("DELETE FROM rag_documents;")
            conn.commit()
            return True

    def search(
        self,
        query_vector: List[float],
        top_k: int = 4,
        threshold: float = 0.35,
    ) -> List[VectorSearchResult]:
        """
        Executes semantic cosine-similarity search against all indexed chunks.
        Applies relevance threshold and ranks results.
        """
        if not query_vector:
            return []

        q_vec = np.array(query_vector, dtype=np.float32)
        q_norm = np.linalg.norm(q_vec)
        if q_norm > 1e-12:
            q_vec = q_vec / q_norm

        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT 
                    c.chunk_id,
                    c.doc_id,
                    c.chunk_index,
                    c.text,
                    c.page_number,
                    c.section_heading,
                    c.char_count,
                    c.embedding_blob,
                    c.metadata_json,
                    d.title AS doc_title,
                    d.filename AS doc_filename
                FROM rag_chunks c
                JOIN rag_documents d ON c.doc_id = d.doc_id
            """)
            rows = cursor.fetchall()

        if not rows:
            return []

        # Build matrix of all stored embeddings
        all_embeddings: List[np.ndarray] = []
        for r in rows:
            vec = self._unpack_vector(r["embedding_blob"])
            all_embeddings.append(vec)

        matrix = np.array(all_embeddings, dtype=np.float32)

        # Dot product against unit-normalized vectors gives cosine similarity
        scores = matrix.dot(q_vec)

        results: List[VectorSearchResult] = []
        for idx, score in enumerate(scores):
            similarity = float(score)
            if similarity >= threshold:
                r = rows[idx]
                meta = {}
                if r["metadata_json"]:
                    try:
                        meta = json.loads(r["metadata_json"])
                    except Exception:
                        pass

                results.append(
                    VectorSearchResult(
                        chunk_id=r["chunk_id"],
                        doc_id=r["doc_id"],
                        doc_title=r["doc_title"],
                        filename=r["doc_filename"],
                        chunk_index=r["chunk_index"],
                        text=r["text"],
                        page_number=r["page_number"],
                        section_heading=r["section_heading"],
                        similarity_score=similarity,
                        char_count=r["char_count"],
                        metadata=meta,
                    )
                )

        # Sort descending by similarity score
        results.sort(key=lambda x: x.similarity_score, reverse=True)
        return results[:top_k]
