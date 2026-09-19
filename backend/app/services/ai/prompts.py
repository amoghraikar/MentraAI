"""
Centralized, versioned prompt templates for Mentra AI Coach.
All prompts enforce concise, structured responses and safe, non-judgmental guidance.
"""

MENTRA_SYSTEM_PROMPT = """You are Mentra, a personal AI study coach.

Help students understand subjects clearly and practically.

Explain difficult concepts step by step.
Adapt explanations to the student's level.
Use examples when useful.
Correct misunderstandings.
Be technically accurate.

Speak naturally and directly.
Avoid repetitive filler phrases.
Do not ask unnecessary questions.
Do not pretend to know something you do not know."""

COACH_SYSTEM_PROMPT = MENTRA_SYSTEM_PROMPT

TOPIC_EXPLANATION_PROMPT = """Explain the concept '{concept_name}' tailored for a learner at the '{difficulty_level}' level.
Subject Context: {subject_name}
Topic Context: {topic_name}
{notes_context}

Provide an intuitive breakdown, a memorable analogy, 3 core takeaway bullet points, and 1 active-recall practice question.
"""

INTERVENTION_PROMPT = """The student is in an active study session on '{subject_title}: {topic_title}'.
Session elapsed: {elapsed_minutes} minutes.
Distractions noted: {distractions_count}.
Trigger reason: {trigger_reason}.

Generate a calm, gentle, 1-2 sentence focus intervention tip and a recommended micro-action (e.g. 30-second breath, posture adjustment, hydration, or quick topic shift).
"""

POST_SESSION_PROMPT = """Analyze the completed study session:
Subject: {subject_title}
Topic: {topic_title}
Target Duration: {target_duration_minutes} mins | Actual Duration: {actual_duration_minutes} mins
Focus Score: {focus_score}/100 | Distractions: {distractions_count}
Student Self-Reflection: {reflection}

Provide:
1. Overall encouraging performance summary.
2. 2 specific things that went well.
3. 1 high-impact focus improvement for next time.
4. Recommended immediate next action.
"""

STUDY_PLAN_PROMPT = """Create an actionable, day-by-day study roadmap for:
Goal: {goal_title}
Subject: {subject_title}
Available daily study time: {available_daily_minutes} minutes
Target completion: {target_completion_days} days
Existing Topics: {topics_list}

Break down the goal into clear daily focus tasks with realistic time allocations and specific study modes.
"""


def build_coaching_system_prompt(
    context_str: str = "",
    intent: str = "GENERAL",
    mode: str = "ANSWER",
    intent_rule: str = "",
) -> str:
    """
    Constructs a layered, structured system prompt for Mentra AI Coach:
    1. Core Coach Identity & Tone
    2. Real Student & Session Context
    3. Active Interaction Intent & Mode Directives
    4. Guardrails & Output Framing
    """
    from app.services.ai.coach_identity import MENTRA_COACH_IDENTITY

    prompt_parts = [MENTRA_COACH_IDENTITY]

    if context_str:
        prompt_parts.append(
            f"\n### REAL-TIME STUDENT & SESSION CONTEXT:\n"
            f"{context_str}\n"
            f"(Use this context naturally to ground your advice. Never invent fictional stats or claim monitoring when absent.)"
        )

    prompt_parts.append(
        f"\n### ACTIVE INTERACTION DIRECTIVES:\n"
        f"- Detected Intent: {intent}\n"
        f"- Target Coaching Mode: {mode}\n"
    )

    if intent_rule:
        prompt_parts.append(f"- Strategy Rule: {intent_rule}")

    prompt_parts.append(
        "\n### BEHAVIORAL CONSTRAINTS:\n"
        "- Respond concisely and naturally.\n"
        "- If the student is tired, frustrated, or informal, mirror their brevity and give practical support.\n"
        "- Do not dump encyclopedic text unless explicitly asked for a full breakdown.\n"
        "- Maintain multi-turn continuity with previous messages in the conversation."
    )

    return "\n".join(prompt_parts)


# Alias for backward and internal compatibility
MEXTRA_SYSTEM_PROMPT_LAYER = build_coaching_system_prompt

