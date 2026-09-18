import 'dart:math';
import '../../domain/models/coach_insight.dart';
import '../../domain/repositories/ai_coach_repository.dart';

class MockAiCoachRepository implements AiCoachRepository {
  @override
  Future<List<CoachInsightModel>> getCoachInsights() async {
    return const [
      CoachInsightModel(
        id: 'ins_1',
        title: 'Optimal Focus Block Duration',
        category: 'FOCUS PATTERN',
        summary: 'Your attention scores peak at 89% during the first 45 minutes of morning study sessions, with fatigue onset occurring past minute 55.',
        actionRecommendation: 'Schedule 45 to 50-minute study blocks followed by 10-minute active stretch breaks.',
        impactMetric: '+14% Estimated retention',
      ),
      CoachInsightModel(
        id: 'ins_2',
        title: 'Phone Distraction Suppression',
        category: 'ENVIRONMENT',
        summary: 'Phone pickups accounted for 48% of total distraction events, primarily during conceptual study in Data Analytics.',
        actionRecommendation: 'Place your phone outside immediate visual reach or enable Do Not Disturb before starting sessions.',
        impactMetric: '-35% Distraction frequency',
      ),
      CoachInsightModel(
        id: 'ins_3',
        title: 'Study Consistency Momentum',
        category: 'HABIT LOOP',
        summary: 'You have maintained 5 consecutive active study days this week, scoring an average 84% focus baseline.',
        actionRecommendation: 'Complete one 40-minute revision session today on Software Engineering to solidify your weekly streak.',
        impactMetric: '76% Consistency Index',
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> getInitialChatHistory() async {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'msg_1',
        sender: 'coach',
        text: "Good day! I'm Mentra, your AI Study Coach. I have analyzed your recent study sessions. Your focus is strongest in the morning during 45-minute blocks. How can I help with your study plan today?",
        timestamp: now.subtract(const Duration(minutes: 10)),
      ),
    ];
  }

  @override
  Future<ChatMessage> askCoachQuestion(String question, {String? subjectId, String? topicId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = question.toLowerCase();

    String reply;
    if (q.contains('how is my progress') || q.contains('progress') || q.contains('my stats') || q.contains('performance')) {
      reply = "### Telemetry & Progress Assessment\n\n• **Focus Health:** Your current baseline is **88/100** with strong cognitive endurance.\n• **Peak Interval:** Your retention peaks during 45-minute morning sessions.\n• **Active Recall:** Testing concepts immediately after sessions has boosted retention by **+18%**.\n\n**Recommendation:** Complete a 45-minute session today to maintain your weekly consistency streak.";
    } else if (q.contains('data analytic') || q.contains('regression') || q.contains('ols') || q.contains('statistic')) {
      reply = "### Master Guide: Data Analytics & Regression\n\n**1. Core Principles:** Data Analytics systematically extracts actionable intelligence from raw data using descriptive statistics, exploratory analysis (EDA), and predictive modeling.\n\n**2. Key Workflow:**\n• **Data Preprocessing:** Handle null values, outliers, and feature scaling.\n• **Ordinary Least Squares (OLS):** Minimize sum of squared residuals to find optimal parameters (beta_0, beta_1).\n• **Model Evaluation:** Check R-squared, adjusted R-squared, p-values, and ANOVA F-tests.\n\n**3. Actionable Drill:** Launch a 45-minute study block to solve 3 regression hypothesis test problems without looking at formula sheets.";
    } else if (q.contains('machine learning') || q.contains('neural network') || q.contains('gradient descent') || q.contains('deep learning')) {
      reply = "### Master Guide: Machine Learning & Optimization\n\n**1. Foundational Concept:** ML algorithms learn parameter weights theta iteratively by minimizing a loss function J(theta) via Gradient Descent.\n\n**2. Key Mechanisms:**\n• **Forward Pass & Loss Computation:** Evaluate model predictions against ground-truth labels.\n• **Backpropagation:** Compute partial derivatives via calculus chain rule.\n• **Regularization:** Apply L1/L2 penalties or dropout to prevent overfitting on training data.\n\n**3. Actionable Drill:** Dedicate 30 minutes to deriving the weight update rule and test recall using active questions.";
    } else if (q.contains('schedule') || q.contains('plan') || q.contains('time') || q.contains('routine')) {
      reply = "### Optimal Cognitive Study Architecture\n\nBased on your attention curves:\n1. **Peak Cognitive Window (45-50 Mins):** Tackle your highest-complexity subject first.\n2. **Active Neural Reset (10 Mins):** Hydrate, stretch, and step away from screens for neural consolidation.\n3. **Active Practice (35 Mins):** Solve practice problems from memory.\n\n**Action:** Start your first 45-minute focus session now.";
    } else if (q.contains('focus') || q.contains('distraction') || q.contains('phone') || q.contains('drows')) {
      reply = "### High-Focus Environmental Architecture\n\n1. **Friction Boundary:** Place your phone in another room; this yields an immediate +22% increase in continuous deep focus.\n2. **Visual Reset:** Use the 20-20-20 rule to relieve eye strain and take 5 deep diaphragmatic breaths.\n3. **Single-Task Lock:** Commit to 25 minutes of unbroken focus before switching contexts.";
    } else if (q.contains('exam') || q.contains('revision') || q.contains('test') || q.contains('recall')) {
      reply = "### High-Impact Exam Mastery Strategy\n\n1. **Feynman Blurting:** Write down everything you know on a blank page from memory, then identify specific knowledge gaps.\n2. **Interleaved Drills:** Alternate between different topic problem sets to build cognitive retrieval speed.\n3. **Spaced Repetition:** Review difficult concepts after 24 hours, 3 days, and 7 days for permanent memory consolidation.";
    } else {
      // Dynamic topic extractor for any general query
      final cleanTopic = question.replaceAll(RegExp(r'^(teach me|explain|what is|how does|tell me about)\s+', caseSensitive: false), '').trim();
      final topicName = cleanTopic.isNotEmpty ? cleanTopic : "Core Concept";
      reply = "### Master Guide: $topicName\n\n**1. First-Principles Foundation:**\n$topicName represents a fundamental principle in structured analytical problem-solving. It transforms complex raw mechanics into rigorous, predictable outcomes.\n\n**2. Essential Implementation Steps:**\n• Deconstruct the concept into core variables and boundary rules.\n• Map relationships through step-by-step causal modeling.\n• Test edge cases to verify resilience and real-world behavior.\n\n**3. Action Recommendation:**\nStart a 45-minute Mentra focus session. Spend 20 minutes mapping the core definitions and 25 minutes solving practice application drills.";
    }

    return ChatMessage(
      id: 'msg_${Random().nextInt(999999)}',
      sender: 'coach',
      text: reply,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<Map<String, dynamic>> explainConcept(
    String conceptName, {
    String? subjectId,
    String? topicId,
    String? difficultyLevel,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'concept_name': conceptName,
      'summary': '$conceptName is a foundational principle in structured problem solving.',
      'key_points': [
        'Core definition and governing equations',
        'Practical implementation constraints',
        'Common edge cases in real-world application',
      ],
      'analogy': 'Like building blocks that form a resilient bridge.',
      'practice_question': 'How does doubling the initial input alter the steady-state output?',
      'recommended_duration_minutes': 15,
    };
  }

  @override
  Future<Map<String, dynamic>> evaluateIntervention({
    required String subjectTitle,
    required String topicTitle,
    required int elapsedMinutes,
    required int distractionsCount,
    required String triggerReason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'should_intervene': true,
      'intervention_title': 'Focus Realignment',
      'intervention_message': 'You have studied for $elapsedMinutes minutes. Take a 30-second breath and refocus on $topicTitle.',
      'suggested_action': 'micro_stretch',
      'cooldown_seconds': 30,
    };
  }

  @override
  Future<Map<String, dynamic>> analyzeSession({
    required String sessionId,
    required String subjectTitle,
    required String topicTitle,
    required int actualDurationMinutes,
    required int targetDurationMinutes,
    required int focusScore,
    required int distractionsCount,
    required String reflection,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return {
      'session_id': sessionId,
      'overall_feedback': 'Strong focus throughout the $actualDurationMinutes-minute session on $topicTitle.',
      'focus_rating': focusScore >= 85 ? 'Strong' : 'Moderate',
      'what_went_well': [
        'Maintained active attention for $actualDurationMinutes minutes.',
        'Completed targeted focus interval with minimal interruptions.',
      ],
      'areas_for_growth': [
        'Recorded $distractionsCount distraction instances — try clearing desk space next session.',
      ],
      'recommended_next_action': 'Write 3 self-quiz questions to lock in today’s progress.',
    };
  }
}
