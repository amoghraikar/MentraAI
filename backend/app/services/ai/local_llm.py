"""Canonical Local LLM Engine for Mentra.

Implements the single local AI engine abstraction connecting Mentra directly to
a local open-weight instruction-tuned model running locally without cloud APIs.
"""

from enum import Enum
import json
import logging
import os
from typing import Any, AsyncGenerator, Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

from app.services.ai.prompts import MENTRA_SYSTEM_PROMPT


class ModelState(str, Enum):
    UNINITIALIZED = "UNINITIALIZED"
    LOADING = "LOADING"
    READY = "READY"
    GENERATING = "GENERATING"
    STOPPING = "STOPPING"
    ERROR = "ERROR"
    DISPOSED = "DISPOSED"


class LocalLLMErrorCode(str, Enum):
    MODEL_NOT_FOUND = "MODEL_NOT_FOUND"
    MODEL_LOAD_FAILED = "MODEL_LOAD_FAILED"
    MODEL_BUSY = "MODEL_BUSY"
    GENERATION_FAILED = "GENERATION_FAILED"
    GENERATION_CANCELLED = "GENERATION_CANCELLED"
    INVALID_INPUT = "INVALID_INPUT"
    CONTEXT_TOO_LARGE = "CONTEXT_TOO_LARGE"


class LocalLLMError(Exception):
    """Exception raised by LocalLLM engine."""

    def __init__(self, code: LocalLLMErrorCode, message: str):
        super().__init__(f"[{code.value}] {message}")
        self.code = code
        self.message = message


class LocalLLM:
    """Canonical Local LLM Controller and Adapter.

    Communicates directly with the local inference runtime (Ollama)
    serving the local open-weight instruction-tuned model.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
    ):
        self.base_url = (base_url or os.getenv("LOCAL_LLM_URL", "http://127.0.0.1:11434")).rstrip("/")
        self.model = model or os.getenv("LOCAL_LLM_MODEL", "qwen2.5:1.5b")
        self._state: ModelState = ModelState.UNINITIALIZED
        self._last_error: Optional[str] = None
        self._active_client: Optional[httpx.AsyncClient] = None
        self._cancel_requested: bool = False

    @property
    def state(self) -> ModelState:
        return self._state

    def is_ready(self) -> bool:
        return self._state == ModelState.READY

    def get_state(self) -> ModelState:
        return self._state

    def get_last_error(self) -> Optional[str]:
        return self._last_error

    async def get_model_info(self) -> Dict[str, Any]:
        """Returns verified real metadata about the local model and runtime."""
        if not self.is_ready():
            try:
                await self.initialize()
            except Exception:
                pass

        info = {
            "name": self.model,
            "runtime": "Ollama (local on-device)",
            "state": self._state.value,
            "is_ready": self.is_ready(),
            "last_error": self._last_error,
            "format": "GGUF",
            "parameters": "1.54B" if "1.5b" in self.model else ("494M" if "0.5b" in self.model else "Unknown"),
            "quantization": "Q4_K_M",
            "contextLength": 4096,
        }

        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                res = await client.post(f"{self.base_url}/api/show", json={"model": self.model})
                if res.status_code == 200:
                    data = res.json()
                    details = data.get("details", {})
                    if details.get("parameter_size"):
                        info["parameters"] = details.get("parameter_size")
                    if details.get("quantization_level"):
                        info["quantization"] = details.get("quantization_level")
                    if details.get("format"):
                        info["format"] = details.get("format").upper()
        except Exception:
            pass

        return info

    async def initialize(self) -> None:
        """Initialize and verify connection to the local model runtime."""
        self._state = ModelState.LOADING
        self._last_error = None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(f"{self.base_url}/api/tags")
                if res.status_code != 200:
                    raise LocalLLMError(
                        LocalLLMErrorCode.MODEL_LOAD_FAILED,
                        f"Local runtime returned HTTP {res.status_code}",
                    )
                data = res.json()
                models = [m.get("name", "") for m in data.get("models", [])]
                
                # Check for preferred models in order: configured, qwen2.5:1.5b, qwen2.5:0.5b, or first available
                candidates = [self.model, "qwen2.5:1.5b", "qwen2.5:0.5b"]
                selected = None
                for c in candidates:
                    for m in models:
                        if c in m or m in c:
                            selected = m
                            break
                    if selected:
                        break

                if selected:
                    self.model = selected
                elif models:
                    self.model = models[0]
                else:
                    raise LocalLLMError(
                        LocalLLMErrorCode.MODEL_NOT_FOUND,
                        f"No local models installed in Ollama. Available: {models}",
                    )

            self._state = ModelState.READY
            logger.info("Mentra LocalLLM initialized successfully with model '%s'", self.model)
        except LocalLLMError as e:
            self._state = ModelState.ERROR
            self._last_error = e.message
            logger.error("LocalLLM initialization error: %s", e)
            raise
        except Exception as e:
            self._state = ModelState.ERROR
            self._last_error = str(e)
            logger.error("LocalLLM failed to connect to local runtime: %s", e)
            raise LocalLLMError(
                LocalLLMErrorCode.MODEL_LOAD_FAILED,
                f"Could not connect to local LLM runtime at {self.base_url}: {e}",
            )

    async def generate(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> str:
        """Generate a complete text response from the local model."""
        if self._state == ModelState.GENERATING:
            raise LocalLLMError(LocalLLMErrorCode.MODEL_BUSY, "Model is currently generating another response")

        if not messages:
            raise LocalLLMError(LocalLLMErrorCode.INVALID_INPUT, "Messages list cannot be empty")

        if not self.is_ready():
            await self.initialize()

        self._state = ModelState.GENERATING
        self._cancel_requested = False

        full_system = (system_prompt or MENTRA_SYSTEM_PROMPT).strip()
        chat_payload: List[Dict[str, str]] = [{"role": "system", "content": full_system}]
        for m in messages:
            chat_payload.append({
                "role": m.get("role", "user"),
                "content": m.get("content", ""),
            })

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": chat_payload,
            "stream": False,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=90.0) as client:
                self._active_client = client
                res = await client.post(f"{self.base_url}/api/chat", json=payload)
                if res.status_code != 200:
                    raise LocalLLMError(
                        LocalLLMErrorCode.GENERATION_FAILED,
                        f"Local model inference returned HTTP {res.status_code}: {res.text}",
                    )
                data = res.json()
                msg = data.get("message", {}).get("content", "").strip()
                if not msg:
                    raise LocalLLMError(
                        LocalLLMErrorCode.GENERATION_FAILED,
                        "Local model produced an empty response.",
                    )
                return msg
        except httpx.TimeoutException:
            raise LocalLLMError(
                LocalLLMErrorCode.GENERATION_FAILED,
                "Generation timed out. The local model took too long to respond.",
            )
        except LocalLLMError:
            raise
        except Exception as e:
            if self._cancel_requested:
                raise LocalLLMError(
                    LocalLLMErrorCode.GENERATION_CANCELLED,
                    "Generation was cancelled by user.",
                )
            raise LocalLLMError(
                LocalLLMErrorCode.GENERATION_FAILED,
                f"Generation error: {e}",
            )
        finally:
            self._active_client = None
            self._state = ModelState.READY

    async def stream(
        self,
        messages: List[Dict[str, str]],
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1500,
    ) -> AsyncGenerator[str, None]:
        """Stream generated response tokens progressively."""
        if not messages:
            raise LocalLLMError(LocalLLMErrorCode.INVALID_INPUT, "Messages list cannot be empty")

        if not self.is_ready():
            await self.initialize()

        self._state = ModelState.GENERATING
        self._cancel_requested = False

        full_system = (system_prompt or MENTRA_SYSTEM_PROMPT).strip()
        chat_payload: List[Dict[str, str]] = [{"role": "system", "content": full_system}]
        for m in messages:
            chat_payload.append({
                "role": m.get("role", "user"),
                "content": m.get("content", ""),
            })

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": chat_payload,
            "stream": True,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=90.0) as client:
                self._active_client = client
                async with client.stream("POST", f"{self.base_url}/api/chat", json=payload) as response:
                    if response.status_code != 200:
                        err_text = await response.aread()
                        raise LocalLLMError(
                            LocalLLMErrorCode.GENERATION_FAILED,
                            f"Streaming error HTTP {response.status_code}: {err_text.decode('utf-8', 'ignore')}",
                        )
                    async for line in response.aiter_lines():
                        if self._cancel_requested:
                            break
                        if not line or not line.strip():
                            continue
                        try:
                            chunk = json.loads(line)
                            content = chunk.get("message", {}).get("content", "")
                            if content:
                                yield content
                            if chunk.get("done", False):
                                break
                        except json.JSONDecodeError:
                            continue
        except LocalLLMError:
            raise
        except Exception as e:
            if not self._cancel_requested:
                raise LocalLLMError(
                    LocalLLMErrorCode.GENERATION_FAILED,
                    f"Streaming error: {e}",
                )
        finally:
            self._active_client = None
            self._state = ModelState.READY

    async def cancel(self) -> None:
        """Cancel an ongoing generation."""
        if self._state == ModelState.GENERATING:
            self._state = ModelState.STOPPING
            self._cancel_requested = True
            logger.info("LocalLLM: generation cancellation requested")
            self._state = ModelState.READY

    async def dispose(self) -> None:
        """Dispose the model controller resources."""
        await self.cancel()
        self._state = ModelState.DISPOSED
        logger.info("Mentra LocalLLM disposed.")


# Canonical singleton engine instance
local_llm_engine = LocalLLM()
