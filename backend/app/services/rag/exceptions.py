"""
Explicit error hierarchy for the Mentra Local RAG Engine.
"""


class RAGError(Exception):
    """Base exception for all RAG engine errors."""

    def __init__(self, code: str, message: str):
        super().__init__(f"[{code}] {message}")
        self.code = code
        self.message = message


class DocumentNotFoundError(RAGError):
    """Raised when a specified document path or ID cannot be found."""

    def __init__(self, message: str = "Document not found"):
        super().__init__("DOCUMENT_NOT_FOUND", message)


class EmptyDocumentError(RAGError):
    """Raised when an ingested document has no readable text."""

    def __init__(self, message: str = "Document contains no readable text"):
        super().__init__("EMPTY_DOCUMENT", message)


class UnsupportedDocumentTypeError(RAGError):
    """Raised when attempting to parse an unsupported file extension."""

    def __init__(self, message: str = "Unsupported document file type"):
        super().__init__("UNSUPPORTED_DOCUMENT_TYPE", message)


class MalformedDocumentError(RAGError):
    """Raised when a document is corrupted or cannot be parsed."""

    def __init__(self, message: str = "Document is malformed or corrupted"):
        super().__init__("MALFORMED_DOCUMENT", message)


class EmbeddingError(RAGError):
    """Raised when local embedding generation fails."""

    def __init__(self, message: str = "Embedding service unavailable or failed"):
        super().__init__("EMBEDDING_FAILED", message)


class VectorStoreError(RAGError):
    """Raised when vector storage operations encounter a database error."""

    def __init__(self, message: str = "Vector store error"):
        super().__init__("VECTOR_STORE_ERROR", message)


class QueryError(RAGError):
    """Raised when a query string is invalid or empty."""

    def __init__(self, message: str = "Query is invalid or empty"):
        super().__init__("INVALID_QUERY", message)
