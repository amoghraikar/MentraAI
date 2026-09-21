"""Canonical AI Provider layer for Mentra.

Strictly communicates with the local on-device LLM engine (Ollama / GGUF).
All cloud LLM APIs, synthetic canned generators, and fake response templates
have been removed.
"""

import json
import logging
import os
import time
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional, Type, TypeVar
from pydantic import BaseModel

from app.services.ai.local_llm import LocalLLM, local_llm_engine

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)


class BaseAiProvider(ABC):
    """Abstract interface for Mentra LLM provider."""

    @abstractmethod
    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> str:
        pass

    async def generate_chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> str:
        full_prompt = "\n".join(
            f"{m.get('role', 'user').capitalize()}: {m.get('content', '')}" for m in messages
        )
        return await self.generate_text(full_prompt, system_prompt, temperature, max_tokens)

    @abstractmethod
    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        pass

    async def test_connection(self) -> Dict[str, Any]:
        """Verifies local model runtime connectivity."""
        start = time.time()
        try:
            res = await self.generate_text(
                "Reply with 'OK' only.", system_prompt="Test ping", max_tokens=10
            )
            latency_ms = int((time.time() - start) * 1000)
            return {
                "success": True,
                "latency_ms": latency_ms,
                "message": f"Successfully connected to {type(self).__name__}",
                "preview": res[:100],
            }
        except Exception as e:
            return {
                "success": False,
                "latency_ms": int((time.time() - start) * 1000),
                "error": str(e),
            }


class LocalLLMProvider(BaseAiProvider):
    """Canonical Local LLM Provider connecting Mentra to on-device Qwen2.5."""

    def __init__(
        self,
        model: Optional[str] = None,
        base_url: Optional[str] = None,
        engine: Optional[LocalLLM] = None,
    ):
        self.engine = engine or local_llm_engine
        if model:
            self.engine.model = model
        if base_url:
            self.engine.base_url = base_url.rstrip("/")
        self.model = self.engine.model

    async def generate_chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> str:
        return await self.engine.generate(
            messages=messages,
            system_prompt=system_prompt,
            temperature=temperature,
            max_tokens=max_tokens,
        )

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> str:
        return await self.engine.generate(
            messages=[{"role": "user", "content": prompt}],
            system_prompt=system_prompt,
            temperature=temperature,
            max_tokens=max_tokens,
        )

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        schema_json = json.dumps(response_model.model_json_schema())
        json_directive = f"Respond ONLY in valid JSON matching this schema, without markdown fences:\n{schema_json}"
        full_system = f"{system_prompt or ''}\n\n{json_directive}".strip()
        raw = await self.generate_text(prompt, full_system, temperature, 1200)
        cleaned = raw.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        return response_model.model_validate_json(cleaned.strip())


class AiProviderFactory:
    """Factory providing the single local AI provider."""

    @staticmethod
    def get_provider(
        provider_name: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> BaseAiProvider:
        return LocalLLMProvider(model=model, base_url=base_url)


# Backward compatibility aliases pointing exclusively to the real local provider
HeuristicAiProvider = LocalLLMProvider
DynamicCognitiveAiProvider = LocalLLMProvider
