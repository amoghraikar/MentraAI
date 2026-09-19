"""
Automated Test Suite for Milestone 4: Natural Conversation + Study Context Engine.

Covers:
A. Basic conversation
B. Multi-turn context
C. Pronoun/context understanding ("Explain arrays." -> "Explain them with an example.")
D. Topic continuity (DSA -> Arrays -> Indexing)
E. Topic switching (DBMS -> Recursion)
F. Beginner adaptation
G. Confusion handling
H. Practice generation
I. Hint behaviour
J. New conversation isolation
K. Long-context handling
L. Missing study context
M. Empty/invalid message
N. Local model failure
"""

import pytest
from app.services.ai.conversation_engine import ConversationEngine
from app.services.ai.mentra_context import MentraContext
from app.services.ai.prompts import MENTRA_SYSTEM_PROMPT


class TestMilestone4ConversationEngine:
    """Automated unit and integration tests for Mentra Conversation & Context Engine."""

    # A. Basic conversation
    def test_a_basic_conversation_prompt(self):
        ctx = MentraContext()
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="hi",
            history=[],
            context=ctx,
        )
        assert "You are Mentra" in prompt
        assert len(messages) == 1
        assert messages[0]["content"] == "hi"
        assert messages[0]["role"] == "user"

    # B. Multi-turn context
    def test_b_multi_turn_context(self):
        ctx = MentraContext()
        history = [
            {"role": "user", "content": "i need to study dsa"},
            {"role": "assistant", "content": "Sure, let's dive into Data Structures and Algorithms."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="what are arrays?",
            history=history,
            context=ctx,
        )
        assert ctx.current_subject == "DSA"
        assert ctx.current_topic == "Arrays"
        assert len(messages) == 3
        assert messages[-1]["content"] == "what are arrays?"

    # C. Pronoun / implicit reference resolution
    def test_c_pronoun_context_understanding(self):
        ctx = MentraContext()
        history = [
            {"role": "user", "content": "explain arrays"},
            {"role": "assistant", "content": "An array is a contiguous memory structure storing items of the same type."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="explain them with an example",
            history=history,
            context=ctx,
        )
        # Context engine resolves pronoun "them" back to Arrays
        assert ctx.current_topic == "Arrays"
        assert "Arrays" in prompt

    # D. Topic continuity (DSA -> Arrays -> Indexing)
    def test_d_topic_continuity(self):
        ctx = MentraContext()
        history = [
            {"role": "user", "content": "i need to study dsa"},
            {"role": "assistant", "content": "Let's begin with fundamentals."},
            {"role": "user", "content": "arrays"},
            {"role": "assistant", "content": "Arrays store sequential data indexed from zero."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="how does indexing work?",
            history=history,
            context=ctx,
        )
        assert ctx.current_subject == "DSA"
        assert ctx.current_topic in ("Indexing", "Arrays")

    # E. Topic switching (DBMS -> Recursion)
    def test_e_topic_switching(self):
        ctx = MentraContext(current_subject="DBMS", current_topic="Normalization")
        history = [
            {"role": "user", "content": "we are studying dbms normalization"},
            {"role": "assistant", "content": "Normalization reduces redundancy in relational schemas."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="what is recursion?",
            history=history,
            context=ctx,
        )
        # New topic must be recognized as Recursion
        assert ctx.current_topic == "Recursion"
        # Prompt includes priority override rule
        assert "[CONTEXT PRIORITY RULE]" in prompt

    # F. Beginner adaptation
    def test_f_beginner_adaptation(self):
        ctx = MentraContext()
        history = [
            {"role": "user", "content": "arrays"},
            {"role": "assistant", "content": "Arrays are linear data structures."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="explain like i'm a complete beginner",
            history=history,
            context=ctx,
        )
        assert ctx.difficulty_level == "BEGINNER"
        assert "Inferred Learner Level: BEGINNER" in prompt

    # G. Confusion handling
    def test_g_confusion_handling(self):
        ctx = MentraContext(current_topic="Arrays")
        history = [
            {"role": "user", "content": "what are arrays?"},
            {"role": "assistant", "content": "Contiguous memory allocations holding homogenous datatypes."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="this makes no sense, i don't get it",
            history=history,
            context=ctx,
        )
        assert ctx.is_confused is True
        assert "STUDENT CONFUSION DETECTED" in prompt

    # H. Practice generation
    def test_h_practice_generation(self):
        ctx = MentraContext(current_topic="Arrays")
        history = [
            {"role": "user", "content": "teach me arrays"},
            {"role": "assistant", "content": "Arrays use zero-based indexing."},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="give me a practice question",
            history=history,
            context=ctx,
        )
        assert ctx.is_practice_mode is True
        assert "PRACTICE MODE ACTIVE" in prompt

    # I. Hint behaviour
    def test_i_hint_behaviour(self):
        ctx = MentraContext(current_topic="Arrays", is_practice_mode=True)
        history = [
            {"role": "assistant", "content": "arr = [10, 20, 30]. What is arr[1]?"},
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="i don't know, hint please",
            history=history,
            context=ctx,
        )
        assert ctx.needs_hint is True
        assert ctx.hint_level >= 1
        assert "HINT REQUEST" in prompt
        assert "Do NOT reveal the full answer immediately" in prompt

    # J. New conversation isolation
    def test_j_new_conversation_isolation(self):
        # Conversation A
        ctx_a = MentraContext()
        prompt_a, _ = ConversationEngine.prepare_llm_payload(
            current_message="my name is Alex and I study DSA",
            history=[],
            context=ctx_a,
        )
        assert ctx_a.current_subject == "DSA"

        # Conversation B (Fresh conversation)
        ctx_b = MentraContext()
        prompt_b, _ = ConversationEngine.prepare_llm_payload(
            current_message="what is my name?",
            history=[],
            context=ctx_b,
        )
        assert ctx_b.current_subject is None
        assert "Alex" not in prompt_b

    # K. Long-context handling & Rolling Summarization
    def test_k_long_context_handling(self):
        ctx = MentraContext()
        long_history = [
            {"role": "user", "content": f"query {i} about arrays and dsa"}
            if i % 2 == 0
            else {"role": "assistant", "content": f"explanation {i}"}
            for i in range(16)
        ]
        prompt, messages = ConversationEngine.prepare_llm_payload(
            current_message="what was the first thing we discussed?",
            history=long_history,
            context=ctx,
        )
        # Verify raw messages are bounded
        assert len(messages) <= ConversationEngine.MAX_RAW_TURNS + 1
        # Verify rolling summary is present
        assert "[CONVERSATION BACKGROUND SUMMARY]" in prompt

    # L. Missing study context
    def test_l_missing_study_context(self):
        ctx = MentraContext.create_from_db_and_session(
            db=None,
            user_id=None,
            subject_id=None,
            topic_id=None,
            active_session_id=None,
            history=[],
            current_message="teach me quicksort",
        )
        assert ctx.current_study_session is None
        assert ctx.current_subject is None
        assert ctx.current_topic == "Quicksort"

    # M. Empty / whitespace message
    def test_m_empty_message_sanitization(self):
        raw_history = [
            {"role": "user", "content": "  "},
            {"role": "assistant", "content": "valid text"},
            {"role": "invalid_role", "content": "hello"},
        ]
        sanitized = ConversationEngine.sanitize_history(raw_history)
        # Empty message filtered out
        assert len(sanitized) == 2
        # Standardized roles
        assert sanitized[0]["role"] == "assistant"
        assert sanitized[1]["role"] == "user"

    # N. Local model failure handling
    def test_n_local_model_failure_handling(self):
        import asyncio
        from app.services.ai.local_llm import LocalLLM, LocalLLMError
        # LocalLLM with non-existent endpoint
        llm = LocalLLM(base_url="http://127.0.0.1:9999")
        with pytest.raises(LocalLLMError):
            asyncio.run(llm.initialize())
        assert llm.is_ready() is False
        assert llm.state.value == "ERROR"
        assert llm.get_last_error() is not None
