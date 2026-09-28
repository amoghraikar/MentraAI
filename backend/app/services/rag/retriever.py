"""
Semantic Retriever for Mentra RAG.

Embeds incoming queries using LocalEmbeddingModel and performs threshold-gated
vector retrieval via LocalVectorStore.
"""

import logging
from typing import List, Optional

from app.services.rag.embeddings import LocalEmbeddingModel, embedding_model
from app.services.rag.exceptions import QueryError
from app.services.rag.vector_store import LocalVectorStore, VectorSearchResult

logger = logging.getLogger("mentra.rag.retriever")


class SemanticRetriever:
    """
    Retrieves semantically relevant document chunks using local vector cosine similarity.
    Enforces a strict relevance threshold to prevent hallucinated citations or false positives.
    """

    DEFAULT_TOP_K = 4
    DEFAULT_THRESHOLD = 0.35  # Minimum cosine similarity to be considered relevant

    def __init__(
        self,
        vector_store: LocalVectorStore,
        embeddings: Optional[LocalEmbeddingModel] = None,
        default_top_k: int = DEFAULT_TOP_K,
        default_threshold: float = DEFAULT_THRESHOLD,
    ):
        self.vector_store = vector_store
        self.embeddings = embeddings or embedding_model
        self.default_top_k = default_top_k
        self.default_threshold = default_threshold

    def retrieve(
        self,
        query: str,
        top_k: Optional[int] = None,
        threshold: Optional[float] = None,
    ) -> List[VectorSearchResult]:
        """
        Retrieves top-k relevant chunks exceeding the similarity threshold.
        Returns empty list if no chunks satisfy the threshold.
        """
        if not query or not query.strip():
            raise QueryError("Query text cannot be empty or whitespace")

        clean_query = query.strip()
        effective_top_k = top_k if top_k is not None else self.default_top_k
        effective_threshold = threshold if threshold is not None else self.default_threshold

        # 1. Embed query locally
        query_vector = self.embeddings.embed_text(clean_query)

        # 2. Search local vector store
        results = self.vector_store.search(
            query_vector=query_vector,
            top_k=effective_top_k,
            threshold=effective_threshold,
        )

        logger.debug(
            "Retrieved %d chunks for query '%s' (top_k=%d, threshold=%.2f)",
            len(results),
            clean_query[:40],
            effective_top_k,
            effective_threshold,
        )
        return results

    async def aretrieve(
        self,
        query: str,
        top_k: Optional[int] = None,
        threshold: Optional[float] = None,
    ) -> List[VectorSearchResult]:
        """Asynchronous retrieval variant."""
        if not query or not query.strip():
            raise QueryError("Query text cannot be empty or whitespace")

        clean_query = query.strip()
        effective_top_k = top_k if top_k is not None else self.default_top_k
        effective_threshold = threshold if threshold is not None else self.default_threshold

        query_vector = await self.embeddings.aembed_text(clean_query)
        results = self.vector_store.search(
            query_vector=query_vector,
            top_k=effective_top_k,
            threshold=effective_threshold,
        )
        return results
