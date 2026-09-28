"""
Mentra Local RAG Engine Package.

Provides modular, independent on-device Retrieval-Augmented Generation capabilities.
"""

from app.services.rag.chunker import DeterministicChunker, DocumentChunk
from app.services.rag.context_formatter import NO_RELEVANT_CONTEXT, RAGContextFormatter
from app.services.rag.document_parser import DocumentParser, ParsedDocument, DocumentSection
from app.services.rag.embeddings import LocalEmbeddingModel, embedding_model
from app.services.rag.exceptions import (
    DocumentNotFoundError,
    EmbeddingError,
    EmptyDocumentError,
    MalformedDocumentError,
    QueryError,
    RAGError,
    UnsupportedDocumentTypeError,
    VectorStoreError,
)
from app.services.rag.rag_engine import IngestionResult, LocalRAGEngine, RAGContextResponse, rag_engine
from app.services.rag.retriever import SemanticRetriever
from app.services.rag.vector_store import LocalVectorStore, VectorSearchResult

__all__ = [
    "LocalRAGEngine",
    "rag_engine",
    "DocumentParser",
    "ParsedDocument",
    "DocumentSection",
    "DeterministicChunker",
    "DocumentChunk",
    "LocalEmbeddingModel",
    "embedding_model",
    "LocalVectorStore",
    "VectorSearchResult",
    "SemanticRetriever",
    "RAGContextFormatter",
    "NO_RELEVANT_CONTEXT",
    "IngestionResult",
    "RAGContextResponse",
    "RAGError",
    "DocumentNotFoundError",
    "EmptyDocumentError",
    "UnsupportedDocumentTypeError",
    "MalformedDocumentError",
    "EmbeddingError",
    "VectorStoreError",
    "QueryError",
]
