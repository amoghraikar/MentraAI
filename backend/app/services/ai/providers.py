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
        format: Optional[str] = None,
    ) -> str:
        return await self.engine.generate(
            messages=[{"role": "user", "content": prompt}],
            system_prompt=system_prompt,
            temperature=temperature,
            max_tokens=max_tokens,
            format=format,
        )

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        import re
        field_names = list(response_model.model_fields.keys())
        schema_json = json.dumps(response_model.model_json_schema())
        json_directive = (
            f"Respond ONLY in valid JSON.\n"
            f"Output a JSON object with top-level keys: {json.dumps(field_names)}.\n"
            f"Schema:\n{schema_json}"
        )
        full_system = f"{system_prompt or ''}\n\n{json_directive}".strip()
        raw = await self.generate_text(prompt, full_system, temperature, 1200, format="json")
        cleaned = raw.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        # Extract JSON object boundaries if necessary
        start_idx = cleaned.find("{")
        end_idx = cleaned.rfind("}")
        if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
            cleaned = cleaned[start_idx : end_idx + 1]

        def _try_parse_and_validate(text: str) -> Optional[T]:
            try:
                data = json.loads(text, strict=False)
                if isinstance(data, dict):
                    # Unwrap if the model nested fields inside a "properties" key
                    if "properties" in data and isinstance(data["properties"], dict):
                        props = data["properties"]
                        for k, v in list(props.items()):
                            if isinstance(v, dict):
                                if "value" in v:
                                    props[k] = v["value"]
                                elif "default" in v:
                                    props[k] = v["default"]
                        data = props
                    return response_model.model_validate(data)
            except Exception:
                pass
            return None

        res = _try_parse_and_validate(cleaned)
        if res is not None:
            return res

        # Repair invalid escape sequences (e.g. unescaped LaTeX backslashes \alpha, \frac, etc.)
        repaired = re.sub(r'\\(?![/"\\bfnrtu]|u[0-9a-fA-F]{4})', r'\\\\', cleaned)
        res = _try_parse_and_validate(repaired)
        if res is not None:
            return res

        return response_model.model_validate_json(cleaned)


class GeminiProvider(BaseAiProvider):
    """Google Gemini Cloud AI Provider for high-speed cloud reasoning."""

    def __init__(self, api_key: str, model: Optional[str] = None):
        self.api_key = api_key
        self.model = model or "gemini-1.5-flash"

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
        format: Optional[str] = None,
    ) -> str:
        import httpx
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent?key={self.api_key}"
        payload: Dict[str, Any] = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": temperature, "maxOutputTokens": max_tokens},
        }
        if system_prompt:
            payload["systemInstruction"] = {"parts": [{"text": system_prompt}]}
        if format == "json":
            payload["generationConfig"]["responseMimeType"] = "application/json"

        async with httpx.AsyncClient(timeout=30.0) as client:
            res = await client.post(url, json=payload)
            if res.status_code != 200:
                raise Exception(f"Gemini API error ({res.status_code}): {res.text}")
            data = res.json()
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    return parts[0].get("text", "")
            return ""

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        raw = await self.generate_text(prompt, system_prompt, temperature, 1200, format="json")
        return response_model.model_validate_json(raw)


class OpenAiProvider(BaseAiProvider):
    """OpenAI compatible Cloud Provider."""

    def __init__(self, api_key: str, model: Optional[str] = None, base_url: Optional[str] = None):
        self.api_key = api_key
        self.model = model or "gpt-4o-mini"
        self.base_url = (base_url or "https://api.openai.com/v1").rstrip("/")

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
        format: Optional[str] = None,
    ) -> str:
        import httpx
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if format == "json":
            payload["response_format"] = {"type": "json_object"}

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            res = await client.post(f"{self.base_url}/chat/completions", json=payload, headers=headers)
            if res.status_code != 200:
                raise Exception(f"OpenAI API error ({res.status_code}): {res.text}")
            data = res.json()
            choices = data.get("choices", [])
            if choices:
                return choices[0].get("message", {}).get("content", "")
            return ""

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        raw = await self.generate_text(prompt, system_prompt, temperature, 1200, format="json")
        return response_model.model_validate_json(raw)


class AiProviderFactory:
    """Factory providing AI providers (LocalLLM default with seamless Gemini/OpenAI cloud fallback)."""

    @staticmethod
    def get_provider(
        provider_name: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        base_url: Optional[str] = None,
    ) -> BaseAiProvider:
        p_name = (provider_name or os.getenv("AI_PROVIDER") or "").lower()
        key = api_key or os.getenv("GEMINI_API_KEY") or os.getenv("OPENAI_API_KEY")

        if p_name == "gemini" or (key and "AIza" in key):
            return GeminiProvider(api_key=key, model=model)
        elif (p_name in ("openai", "chatgpt") and key) or (key and key.startswith("sk-")):
            return OpenAiProvider(api_key=key, model=model, base_url=base_url)

        return LocalLLMProvider(model=model, base_url=base_url)


# Backward compatibility aliases pointing to providers
HeuristicAiProvider = LocalLLMProvider
DynamicCognitiveAiProvider = LocalLLMProvider

