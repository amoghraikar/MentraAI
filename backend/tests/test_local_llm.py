"""Tests for LocalLLM engine, lifecycle states, streaming, and cancellation."""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from app.services.ai.local_llm import (
    LocalLLM,
    ModelState,
    LocalLLMError,
    LocalLLMErrorCode,
    MENTRA_SYSTEM_PROMPT,
)


@pytest.mark.anyio
async def test_localllm_states_and_initialization():
    llm = LocalLLM(base_url="http://127.0.0.1:11434", model="qwen2.5:0.5b")
    assert llm.get_state() == ModelState.UNINITIALIZED
    assert not llm.is_ready()

    # Mock successful tags response
    mock_res = MagicMock()
    mock_res.status_code = 200
    mock_res.json.return_value = {"models": [{"name": "qwen2.5:0.5b"}]}

    with patch("httpx.AsyncClient.get", AsyncMock(return_value=mock_res)):
        await llm.initialize()
        assert llm.get_state() == ModelState.READY
        assert llm.is_ready()


@pytest.mark.anyio
async def test_localllm_model_not_found():
    llm = LocalLLM(base_url="http://127.0.0.1:11434", model="nonexistent_model")
    mock_res = MagicMock()
    mock_res.status_code = 200
    mock_res.json.return_value = {"models": []}

    with patch("httpx.AsyncClient.get", AsyncMock(return_value=mock_res)):
        with pytest.raises(LocalLLMError) as exc:
            await llm.initialize()
        assert exc.value.code == LocalLLMErrorCode.MODEL_NOT_FOUND
        assert llm.get_state() == ModelState.ERROR


@pytest.mark.anyio
async def test_localllm_generate():
    llm = LocalLLM(base_url="http://127.0.0.1:11434", model="qwen2.5:0.5b")
    llm._state = ModelState.READY

    mock_res = MagicMock()
    mock_res.status_code = 200
    mock_res.json.return_value = {
        "message": {"role": "assistant", "content": "Arrays are contiguous memory blocks."}
    }

    with patch("httpx.AsyncClient.post", AsyncMock(return_value=mock_res)):
        response = await llm.generate(
            messages=[{"role": "user", "content": "Explain arrays"}],
            system_prompt=MENTRA_SYSTEM_PROMPT,
        )
        assert response == "Arrays are contiguous memory blocks."
        assert llm.get_state() == ModelState.READY


@pytest.mark.anyio
async def test_localllm_cancellation():
    llm = LocalLLM(base_url="http://127.0.0.1:11434", model="qwen2.5:0.5b")
    llm._state = ModelState.GENERATING
    await llm.cancel()
    assert llm.get_state() == ModelState.READY
    assert llm._cancel_requested is True


from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_status_endpoint():
    res = client.get("/api/v1/ai-coach/status")
    assert res.status_code == 200
    data = res.json()
    assert "state" in data
    assert "model" in data
    assert "is_ready" in data


def test_cancel_endpoint():
    res = client.post("/api/v1/ai-coach/cancel")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "STOPPING"

