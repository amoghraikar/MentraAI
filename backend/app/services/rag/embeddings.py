"""
Local Embedding Engine for Mentra RAG.

Communicates strictly with the on-device Ollama embedding endpoint (all-minilm, 384 dimensions).
No external APIs, no cloud dependencies, zero data egress.
"""

import logging
import math
from typing import Any, Dict, List, Optional
import httpx

from app.services.rag.exceptions import EmbeddingError

logger = logging.getLogger("mentra.rag.embeddings")


class LocalEmbeddingModel:
    """
    On-device embedding model powered by local Ollama runtime.
    Model: all-minilm (MiniLM-L6-v2)
    Dimension: 384
    """

    MODEL_NAME = "all-minilm"
    DIMENSION = 384
    DEFAULT_BASE_URL = "http://127.0.0.1:11434"

    def __init__(
        self,
        model: str = MODEL_NAME,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = 30.0,
    ):
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.dimension = self.DIMENSION

    @staticmethod
    def _normalize_vector(vec: List[float]) -> List[float]:
        """Normalizes vector to unit L2 norm so dot product equals cosine similarity."""
        norm = math.sqrt(sum(x * x for x in vec))
        if norm > 1e-12:
            return [x / norm for x in vec]
        return vec

    def embed_text(self, text: str) -> List[float]:
        """Generates a normalized 384-dimensional embedding for a single text string."""
        if not text or not text.strip():
            raise EmbeddingError("Cannot embed empty text")

        results = self.embed_batch([text])
        if not results:
            raise EmbeddingError("Embedding service returned empty result")
        return results[0]

    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """Generates normalized embeddings for a batch of text strings."""
        if not texts:
            return []

        cleaned_texts = [t.strip() if t and t.strip() else " " for t in texts]
        url = f"{self.base_url}/api/embed"
        payload = {
            "model": self.model,
            "input": cleaned_texts if len(cleaned_texts) > 1 else cleaned_texts[0],
        }

        try:
            with httpx.Client(timeout=self.timeout) as client:
                res = client.post(url, json=payload)
                if res.status_code != 200:
                    raise EmbeddingError(
                        f"Local embedding endpoint error ({res.status_code}): {res.text}"
                    )
                data = res.json()
                raw_embeddings = data.get("embeddings", [])
                if not raw_embeddings:
                    raise EmbeddingError("No embeddings returned by local embedding model")

                # Normalize each vector
                normalized = [self._normalize_vector(v) for v in raw_embeddings]
                return normalized
        except httpx.ConnectError as e:
            raise EmbeddingError(
                f"Failed to connect to local embedding runtime at {self.base_url}. Ensure Ollama is running."
            ) from e
        except EmbeddingError:
            raise
        except Exception as e:
            raise EmbeddingError(f"Embedding generation failed: {e}") from e

    async def aembed_text(self, text: str) -> List[float]:
        """Asynchronous embedding for a single text string."""
        results = await self.aembed_batch([text])
        if not results:
            raise EmbeddingError("Embedding service returned empty result")
        return results[0]

    async def aembed_batch(self, texts: List[str]) -> List[List[float]]:
        """Asynchronous embedding for a batch of text strings."""
        if not texts:
            return []

        cleaned_texts = [t.strip() if t and t.strip() else " " for t in texts]
        url = f"{self.base_url}/api/embed"
        payload = {
            "model": self.model,
            "input": cleaned_texts if len(cleaned_texts) > 1 else cleaned_texts[0],
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                res = await client.post(url, json=payload)
                if res.status_code != 200:
                    raise EmbeddingError(
                        f"Local embedding endpoint error ({res.status_code}): {res.text}"
                    )
                data = res.json()
                raw_embeddings = data.get("embeddings", [])
                if not raw_embeddings:
                    raise EmbeddingError("No embeddings returned by local embedding model")

                return [self._normalize_vector(v) for v in raw_embeddings]
        except httpx.ConnectError as e:
            raise EmbeddingError(
                f"Failed to connect to local embedding runtime at {self.base_url}. Ensure Ollama is running."
            ) from e
        except EmbeddingError:
            raise
        except Exception as e:
            raise EmbeddingError(f"Embedding generation failed: {e}") from e

    def get_info(self) -> Dict[str, Any]:
        """Returns model and runtime metadata."""
        return {
            "model": self.model,
            "dimension": self.dimension,
            "runtime": "ollama",
            "base_url": self.base_url,
            "is_local": True,
        }


# Canonical singleton embedding model
embedding_model = LocalEmbeddingModel()
