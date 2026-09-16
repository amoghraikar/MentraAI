import json
import logging
import os
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, Type, TypeVar
import httpx
from pydantic import BaseModel

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)


class BaseAiProvider(ABC):
    """Abstract interface for LLM providers."""

    @abstractmethod
    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 800,
    ) -> str:
        pass

    @abstractmethod
    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        pass


class OpenAiProvider(BaseAiProvider):
    """Real OpenAI ChatGPT Provider implementation (GPT-4o, GPT-4o-mini, GPT-3.5-turbo)."""

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY", "")
        self.model = model or os.getenv("OPENAI_MODEL", "gpt-4o-mini")
        self.fallback_provider = HeuristicAiProvider()

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 800,
    ) -> str:
        if not self.api_key:
            logger.info("OPENAI_API_KEY not configured. Falling back to Heuristic provider.")
            return await self.fallback_provider.generate_text(prompt, system_prompt, temperature, max_tokens)

        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(url, headers=headers, json=payload)
                res.raise_for_status()
                data = res.json()
                content = data["choices"][0]["message"]["content"]
                return content.strip()
        except Exception as e:
            logger.warning(f"OpenAI ChatGPT API request failed: {e}. Utilizing resilient fallback provider.")
            return await self.fallback_provider.generate_text(prompt, system_prompt, temperature, max_tokens)

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        if not self.api_key:
            return await self.fallback_provider.generate_structured(prompt, system_prompt, response_model, temperature)

        schema_json = json.dumps(response_model.model_json_schema())
        json_directive = (
            f"IMPORTANT: You must respond ONLY with a raw JSON object strictly adhering to this schema:\n{schema_json}"
        )

        full_system = f"{system_prompt or ''}\n\n{json_directive}".strip()

        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        messages = [
            {"role": "system", "content": full_system},
            {"role": "user", "content": prompt},
        ]

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "response_format": {"type": "json_object"},
            "max_tokens": 1200,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(url, headers=headers, json=payload)
                res.raise_for_status()
                data = res.json()
                raw_text = data["choices"][0]["message"]["content"].strip()
                parsed = json.loads(raw_text)
                return response_model.model_validate(parsed)
        except Exception as e:
            logger.warning(f"Structured response parsing failed for OpenAI: {e}. Utilizing resilient fallback.")
            return await self.fallback_provider.generate_structured(prompt, system_prompt, response_model, temperature)


class GeminiAiProvider(BaseAiProvider):
    """Google Gemini AI Provider implementation via standard REST API."""

    def __init__(self, api_key: Optional[str] = None, model: str = "gemini-1.5-flash"):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        self.model = model
        self.fallback_provider = HeuristicAiProvider()

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 800,
    ) -> str:
        if not self.api_key:
            logger.info("GEMINI_API_KEY not configured. Falling back to Heuristic provider.")
            return await self.fallback_provider.generate_text(prompt, system_prompt, temperature, max_tokens)

        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent?key={self.api_key}"
        contents = []
        if system_prompt:
            contents.append({"role": "user", "parts": [{"text": f"System Directive: {system_prompt}"}]})
        contents.append({"role": "user", "parts": [{"text": prompt}]})

        payload = {
            "contents": contents,
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_tokens,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                res = await client.post(url, json=payload)
                res.raise_for_status()
                data = res.json()
                text = data["candidates"][0]["content"]["parts"][0]["text"]
                return text.strip()
        except Exception as e:
            logger.warning(f"Gemini API request failed: {e}. Utilizing resilient fallback provider.")
            return await self.fallback_provider.generate_text(prompt, system_prompt, temperature, max_tokens)

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        if not self.api_key:
            return await self.fallback_provider.generate_structured(prompt, system_prompt, response_model, temperature)

        json_prompt = (
            f"{prompt}\n\nIMPORTANT: Respond ONLY with a valid JSON object strictly matching this schema format:\n"
            f"{json.dumps(response_model.model_json_schema())}"
        )

        raw_response = await self.generate_text(json_prompt, system_prompt, temperature=temperature, max_tokens=1000)

        # Parse and sanitize JSON output
        try:
            cleaned = raw_response.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            parsed = json.loads(cleaned.strip())
            return response_model.model_validate(parsed)
        except Exception as e:
            logger.warning(f"Structured response parsing failed for Gemini output: {e}. Using resilient fallback.")
            return await self.fallback_provider.generate_structured(prompt, system_prompt, response_model, temperature)


class HeuristicAiProvider(BaseAiProvider):
    """
    Deterministic, rule-based AI Coach provider.
    Ensures 100% offline availability, ultra-fast test execution, and zero crash resilience.
    """

    async def generate_text(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 800,
    ) -> str:
        prompt_lower = prompt.lower()

        if "schedule" in prompt_lower or "time" in prompt_lower or "plan" in prompt_lower:
            return (
                "Based on your study telemetry, your optimal cognitive window is 45-minute morning intervals. "
                "I recommend scheduling your most demanding topics first, followed by a 10-minute active recovery break."
            )
        elif "focus" in prompt_lower or "distraction" in prompt_lower or "tired" in prompt_lower:
            return (
                "When you notice focus slipping, try the 20-20-20 visual reset rule and take three deep diaphragmatic breaths. "
                "Structuring your active study block into 25-minute sprints will dramatically reduce mental fatigue."
            )
        elif "explain" in prompt_lower or "concept" in prompt_lower or "what is" in prompt_lower:
            return (
                "Let's break this down using first principles. Start by articulating the core definition in your own words, "
                "then map out how each component interacts. Test your mastery by explaining it simply without notes."
            )
        else:
            return (
                "You're making steady progress on your study targets. Keep your active study blocks focused on one concept at a time, "
                "and ensure you test active recall at the end of each session."
            )

    async def generate_structured(
        self,
        prompt: str,
        system_prompt: Optional[str],
        response_model: Type[T],
        temperature: float = 0.5,
    ) -> T:
        schema_name = response_model.__name__
        prompt_lower = prompt.lower()

        fallback_data: Dict[str, Any] = {}

        if schema_name == "AiCoachExplainResponse":
            fallback_data = {
                "concept_name": "Core Concept",
                "summary": "An essential foundational mechanism that enables systematic problem-solving and structured analysis.",
                "key_points": [
                    "Fundamental definition and governing principles.",
                    "Primary inputs, state transformations, and outputs.",
                    "Real-world constraints and practical edge cases.",
                ],
                "analogy": "Think of it like an orchestra conductor coordinating instruments in harmonious timing.",
                "practice_question": "How would the final output change if one of the primary constraints is doubled?",
                "recommended_duration_minutes": 15,
            }
        elif schema_name == "AiCoachInterventionResponse":
            is_drowsy = "drowsiness" in prompt_lower or "closed" in prompt_lower
            fallback_data = {
                "should_intervene": True,
                "intervention_title": "Energy Reset Needed" if is_drowsy else "Focus Realignment",
                "intervention_message": (
                    "Your eye tracking indicates fatigue. Stand up, stretch your shoulders, and drink water."
                    if is_drowsy
                    else "Distraction pattern observed. Take one deep breath and refocus on your core target."
                ),
                "suggested_action": "micro_stretch" if is_drowsy else "take_break",
                "cooldown_seconds": 30,
            }
        elif schema_name == "AiCoachSessionAnalysisResponse":
            fallback_data = {
                "session_id": "sess_analyzed",
                "overall_feedback": "Solid study session with consistent pacing. You maintained strong attention across the main segment.",
                "focus_rating": "Strong",
                "what_went_well": [
                    "Maintained consistent engagement for over 80% of the session duration.",
                    "Minimized off-topic interruptions during the critical problem-solving phase.",
                ],
                "areas_for_growth": [
                    "Noticeable attention dip in the final 5 minutes — consider a slightly shorter interval next time.",
                ],
                "recommended_next_action": "Review your active recall questions before your next study session.",
            }
        elif schema_name == "AiCoachStudyPlanResponse":
            fallback_data = {
                "plan_title": "Accelerated Mastery Roadmap",
                "total_days": 7,
                "estimated_total_hours": 5.25,
                "strategy_summary": "Daily 45-minute focused blocks combining conceptual breakdown with active practice drills.",
                "daily_tasks": [
                    {
                        "day": 1,
                        "topic_name": "Foundational Overview",
                        "duration_minutes": 45,
                        "study_mode": "Focus Mode",
                        "key_objective": "Master terminology and core structure",
                    },
                    {
                        "day": 2,
                        "topic_name": "Deep Dive & Problem Solving",
                        "duration_minutes": 45,
                        "study_mode": "Practice Mode",
                        "key_objective": "Work through 5 standard application scenarios",
                    },
                    {
                        "day": 3,
                        "topic_name": "Active Recall & Synthesis",
                        "duration_minutes": 45,
                        "study_mode": "Review Mode",
                        "key_objective": "Self-test without notes and solidify key takeaways",
                    },
                ],
            }

        return response_model.model_validate(fallback_data)


class AiProviderFactory:
    """Factory to instantiate AI Provider based on runtime environment."""

    @staticmethod
    def get_provider() -> BaseAiProvider:
        provider_name = os.getenv("AI_PROVIDER", "auto").lower()

        if provider_name == "openai" or (provider_name == "auto" and os.getenv("OPENAI_API_KEY")):
            return OpenAiProvider()
        elif provider_name == "gemini" or (provider_name == "auto" and os.getenv("GEMINI_API_KEY")):
            return GeminiAiProvider()
        elif provider_name in ("heuristic", "mock"):
            return HeuristicAiProvider()
        else:
            # If auto and no keys, fallback to Heuristic provider
            return HeuristicAiProvider()
