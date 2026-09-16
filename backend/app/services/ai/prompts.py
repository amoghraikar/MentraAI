"""
Centralized, versioned prompt templates for Mentra AI Coach.
All prompts enforce concise, structured responses and safe, non-judgmental guidance.
"""

COACH_SYSTEM_PROMPT = """You are Mentra, an expert AI Study Coach and cognitive performance guide.
Your goal is to help learners master complex topics through deliberate practice, optimal focus pacing, and actionable behavioral coaching.
Tone guidelines:
- Calm, encouraging, intellectual, and focused.
- Never judgmental or punitive.
- Provide structured, practical advice rather than generic motivational fluff.
- Emphasize evidence-based study techniques: Feynman technique, active recall, spaced repetition, and Pomodoro focus intervals.
"""

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
