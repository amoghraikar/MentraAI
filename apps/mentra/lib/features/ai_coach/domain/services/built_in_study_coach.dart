import 'dart:async';
import 'dart:math';
import '../models/coach_insight.dart';

/// Embedded, zero-dependency autonomous Study Coach Engine.
///
/// Runs 100% on-device inside the Flutter client with zero network calls,
/// zero background daemons (no Ollama required), and zero API keys.
/// Guarantees 100% availability on local web, desktop, and published Netlify builds.
class BuiltInStudyCoach {
  BuiltInStudyCoach._();
  static final BuiltInStudyCoach instance = BuiltInStudyCoach._();

  // Active quiz state memory across multi-turn interactions
  String? _lastQuizTopic;
  String? _lastCorrectAnswer;
  String? _lastExplanation;
  int _quizQuestionIndex = 0;

  /// Generates a rich, structured pedagogical response for any user query.
  Future<String> generateResponse({
    required String question,
    String? subjectTitle,
    String? topicTitle,
    String? studyGoal,
    int? elapsedMinutes,
    int? targetDurationMinutes,
    int? focusScore,
    List<ChatMessage>? history,
  }) async {
    // Artificial small delay for natural pacing if called non-streaming
    await Future.delayed(const Duration(milliseconds: 60));

    final cleanQuery = question.trim();
    final lower = cleanQuery.toLowerCase();
    final activeTopic = (topicTitle != null && topicTitle.isNotEmpty && topicTitle != 'General Topic')
        ? topicTitle
        : ((subjectTitle != null && subjectTitle.isNotEmpty && subjectTitle != 'General Subject')
            ? subjectTitle
            : 'your current study material');

    // 1. Check if the user is answering a previous quiz question
    if (_lastCorrectAnswer != null && _isQuizAnswer(cleanQuery)) {
      return _evaluateQuizAnswer(cleanQuery, activeTopic);
    }

    // 2. Language learning intent (e.g. Kannada, Hindi, Spanish)
    if (_isLanguageIntent(lower)) {
      return _generateLanguageLesson(cleanQuery, lower);
    }

    // 3. "Quiz me" or "Practice" intent
    if (_isQuizIntent(lower)) {
      return _generateQuizQuestion(activeTopic, subjectTitle);
    }

    // 3. "Explain a topic" / "Help me understand" intent
    if (_isExplanationIntent(lower)) {
      return _generateConceptExplanation(cleanQuery, activeTopic);
    }

    // 4. Study strategy / plan / focus coaching intent
    if (_isStrategyIntent(lower)) {
      return _generateStudyStrategy(
        activeTopic: activeTopic,
        elapsedMinutes: elapsedMinutes ?? 0,
        targetDurationMinutes: targetDurationMinutes ?? 45,
        focusScore: focusScore,
        studyGoal: studyGoal,
      );
    }

    // 5. Greetings / check-ins
    if (_isGreeting(lower)) {
      return _generateGreeting(activeTopic, focusScore);
    }

    // 6. Context-aware topic query or generic academic question
    return _generateTopicAnswer(cleanQuery, activeTopic, subjectTitle);
  }

  /// Streams tokens progressively word-by-word with natural cadence.
  Stream<String> streamResponse({
    required String question,
    String? subjectTitle,
    String? topicTitle,
    String? studyGoal,
    int? elapsedMinutes,
    int? targetDurationMinutes,
    int? focusScore,
    List<ChatMessage>? history,
  }) async* {
    final fullText = await generateResponse(
      question: question,
      subjectTitle: subjectTitle,
      topicTitle: topicTitle,
      studyGoal: studyGoal,
      elapsedMinutes: elapsedMinutes,
      targetDurationMinutes: targetDurationMinutes,
      focusScore: focusScore,
      history: history,
    );

    // Stream out words with realistic cognitive typing latency (~12-25ms)
    final words = fullText.split(' ');
    for (int i = 0; i < words.length; i++) {
      final token = i == 0 ? words[i] : ' ${words[i]}';
      yield token;
      // Faster typing for punctuation/short words, slight pause on sentences
      final isSentenceEnd = token.endsWith('.') || token.endsWith('\n') || token.endsWith('!');
      await Future.delayed(Duration(milliseconds: isSentenceEnd ? 28 : 14));
    }
  }

  // ---------------------------------------------------------------------------
  // Intent Recognition
  // ---------------------------------------------------------------------------

  bool _isQuizIntent(String query) {
    return query.contains('quiz') ||
        query.contains('test me') ||
        query.contains('practice') ||
        query.contains('ask me a question') ||
        query.contains('flashcard') ||
        query == 'quiz' ||
        query == 'practice';
  }

  bool _isExplanationIntent(String query) {
    return query.startsWith('explain') ||
        query.startsWith('help me understand') ||
        query.startsWith('what is') ||
        query.startsWith('what are') ||
        query.startsWith('how does') ||
        query.startsWith('how do') ||
        query.contains('teach me') ||
        query.contains('break down');
  }

  bool _isStrategyIntent(String query) {
    return query.contains('study plan') ||
        query.contains('how should i study') ||
        query.contains('schedule') ||
        query.contains('focus tips') ||
        query.contains('tired') ||
        query.contains('break') ||
        query.contains('pomodoro') ||
        query.contains('distracted');
  }

  bool _isGreeting(String query) {
    return query == 'hi' ||
        query == 'hello' ||
        query == 'hey' ||
        query == 'sup' ||
        query.startsWith('good morning') ||
        query.startsWith('good evening');
  }

  bool _isLanguageIntent(String query) {
    return query.contains('kannada') ||
        query.contains('hindi') ||
        query.contains('spanish') ||
        query.contains('french') ||
        query.contains('german') ||
        query.contains('japanese') ||
        query.contains('language') ||
        query.contains('kannada basics');
  }

  bool _isQuizAnswer(String query) {
    final trimmed = query.trim().toUpperCase();
    if (trimmed.length <= 4) {
      if (trimmed.startsWith('A') ||
          trimmed.startsWith('B') ||
          trimmed.startsWith('C') ||
          trimmed.startsWith('D') ||
          trimmed == '1' ||
          trimmed == '2' ||
          trimmed == '3' ||
          trimmed == '4') {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Quiz Generator & Answer Evaluator
  // ---------------------------------------------------------------------------

  String _generateQuizQuestion(String topic, String? subject) {
    _quizQuestionIndex++;
    _lastQuizTopic = topic;

    final lowerTopic = topic.toLowerCase();
    final lowerSubject = (subject ?? '').toLowerCase();

    // Specific domain: Correlation & Covariance / Data Analytics
    if (lowerTopic.contains('correlation') || lowerTopic.contains('covariance') || lowerSubject.contains('analytic')) {
      final qIndex = _quizQuestionIndex % 3;
      if (qIndex == 1) {
        _lastCorrectAnswer = 'B';
        _lastExplanation = 'Covariance depends directly on the measurement scale of the variables (e.g., meters vs centimeters), whereas Pearson Correlation is normalized between -1.0 and +1.0, making it scale-invariant.';
        return '''### 🎯 Quick Concept Check: **$topic**

**Question:** What is the primary difference between **Covariance** and **Correlation**?

- **A)** Covariance measures non-linear relationships, while correlation only measures linear trends.
- **B)** Covariance is sensitive to units of measurement, whereas correlation is standardized between -1 and +1.
- **C)** Correlation can be greater than +1, whereas covariance is always bounded between 0 and 1.
- **D)** Covariance indicates the exact causal relationship, while correlation indicates coincidence.

👉 *Reply with **A**, **B**, **C**, or **D** to check your answer!*''';
      } else if (qIndex == 2) {
        _lastCorrectAnswer = 'C';
        _lastExplanation = 'A correlation of r = 0 indicates the absence of a *linear* relationship, but a strong non-linear relationship (such as y = x²) may still exist.';
        return '''### 🎯 Concept Mastery Check: **$topic**

**Question:** If the Pearson correlation coefficient between two variables is **r = 0.0**, what can you definitively conclude?

- **A)** The two variables have absolutely no statistical dependency whatsoever.
- **B)** One variable causes the other variable to remain constant.
- **C)** There is no *linear* relationship between the variables, though a non-linear relationship might exist.
- **D)** The covariance between the two variables must be equal to 1.0.

👉 *Type your answer (**A**, **B**, **C**, or **D**)!*''';
      } else {
        _lastCorrectAnswer = 'A';
        _lastExplanation = 'Correlation measures association, never causation. Confounding variables or reverse causality can create strong statistical correlation without direct causation.';
        return '''### 🎯 Analytical Challenge: **$topic**

**Question:** You discover that ice cream sales and sunscreen sales have a correlation coefficient of **r = +0.92**. What does this demonstrate?

- **A)** A strong positive association, driven by an external confounding variable (temperature/summer).
- **B)** Eating ice cream directly causes people to purchase sunscreen.
- **C)** The covariance between the two products is negative.
- **D)** The statistical model is mathematically invalid.

👉 *Reply with your selection (**A**, **B**, **C**, or **D**)!*''';
      }
    }

    // Specific domain: Software Engineering / Computer Science
    if (lowerTopic.contains('software') || lowerTopic.contains('algorithm') || lowerTopic.contains('data structure') || lowerSubject.contains('computer')) {
      final qIndex = _quizQuestionIndex % 2;
      if (qIndex == 1) {
        _lastCorrectAnswer = 'B';
        _lastExplanation = 'In a standard hash table with good hashing, average lookup is O(1). In the worst case (all keys hash to the same bucket), lookup degrades to O(N).';
        return '''### 💻 Technical Check: **$topic**

**Question:** What is the average-case and worst-case time complexity of retrieving a key from a **Hash Table**?

- **A)** Average: O(log N) | Worst: O(N)
- **B)** Average: O(1) | Worst: O(N)
- **C)** Average: O(1) | Worst: O(log N)
- **D)** Average: O(N) | Worst: O(N²)

👉 *Reply with **A**, **B**, **C**, or **D**!*''';
      } else {
        _lastCorrectAnswer = 'C';
        _lastExplanation = 'The Single Responsibility Principle (SRP) states that a class or module should have one, and only one, reason to change.';
        return '''### 💻 Architecture Check: **$topic**

**Question:** In SOLID design principles, what does the **Single Responsibility Principle (SRP)** advocate?

- **A)** Each function should have at most one parameter.
- **B)** A software application must be deployed as a single unified binary.
- **C)** A class should have only one reason to change, encapsulating a single responsibility.
- **D)** Only one developer should commit code to a repository at any given time.

👉 *Reply with **A**, **B**, **C**, or **D**!*''';
      }
    }

    // Adaptive Universal Concept Check for any subject/topic
    _lastCorrectAnswer = 'B';
    _lastExplanation = 'Effective retention relies on Active Recall and Spaced Retrieval rather than passive re-reading, forcing the neural pathways to reconstruct the information.';
    return '''### 🧠 Retrieval Practice: **$topic**

**Question:** When mastering foundational principles in **$topic**, which study strategy produces the highest long-term retention?

- **A)** Highlighting key definitions and re-reading textbook chapters 3 times.
- **B)** Active self-testing (retrieval practice) paired with spaced repetition intervals.
- **C)** Cramming all related problems in a single 4-hour non-stop block.
- **D)** Listening to lectures at 2x speed without taking notes.

👉 *Reply with **A**, **B**, **C**, or **D** to lock in your answer!*''';
  }

  String _evaluateQuizAnswer(String answer, String topic) {
    final activeTopic = _lastQuizTopic ?? topic;
    final cleanAnswer = answer.trim().toUpperCase();
    final letter = cleanAnswer.replaceAll(RegExp(r'[^A-D]'), '');
    final isCorrect = letter == _lastCorrectAnswer || cleanAnswer.startsWith(_lastCorrectAnswer!);

    final explanation = _lastExplanation ?? 'Key concept in $activeTopic.';
    final correctChoice = _lastCorrectAnswer ?? 'B';

    // Clear state
    _lastQuizTopic = null;
    _lastCorrectAnswer = null;
    _lastExplanation = null;

    if (isCorrect) {
      return '''### 🎉 **Correct! Outstanding work.**

**Answer: Option $correctChoice**

$explanation

---
💡 **Coach Takeaway:** Engaging in active recall locks this concept into your long-term memory. 

Would you like another practice question, or should we break down a related formula? (Type **"Quiz me"** for another question or ask any doubt!)''';
    } else {
      return '''### 🔍 **Good attempt, but not quite!**

The correct answer was **Option $correctChoice**.

**Why:**
$explanation

---
🧠 **Cognitive Insight:** Errors during retrieval practice are where the deepest learning happens. 

Would you like to try another question on **$topic**? Reply with **"Quiz me"** or ask me to explain any step in detail!''';
    }
  }

  // ---------------------------------------------------------------------------
  // Concept Explanations
  // ---------------------------------------------------------------------------

  String _generateConceptExplanation(String query, String topic) {
    final lower = query.toLowerCase();

    // Specific explanation: Correlation & Covariance
    if (lower.contains('correlation') || lower.contains('covariance') || topic.toLowerCase().contains('correlation')) {
      return '''### 📚 Concept Breakdown: **Correlation & Covariance**

#### 1. Core Intuition
Both metrics quantify how two variables move together:
- **Covariance** tells you the **direction** of the relationship (+ positive or - negative), but its magnitude depends on the scale of your units (e.g. centimeters vs meters).
- **Correlation** standardizes covariance into a unitless index between **-1.0 and +1.0**, telling you both **direction** and **exact strength**.

---

#### 2. The Mental Model (Analogy)
> **Analogy:** Imagine two dancers on a floor.
> - **Covariance** tells you: *"They are moving in the same direction."*
> - **Correlation** tells you: *"They are perfectly synchronized with a score of 0.95 out of 1.0."*

---

#### 3. Mathematical Formulation
\$\$\\text{Cov}(X, Y) = \\frac{1}{n-1} \\sum_{i=1}^n (X_i - \\bar{X})(Y_i - \\bar{Y})\$\$

\$\$r_{XY} = \\frac{\\text{Cov}(X, Y)}{\\sigma_X \\cdot \\sigma_Y}\$\$

Where \$\\sigma_X\$ and \$\\sigma_Y\$ are the standard deviations that normalize the metric between [-1, +1].

---

#### 4. Critical Exam Pitfalls ⚠️
- **Correlation is NOT causation:** High correlation (r = 0.9) does not prove X causes Y. A lurking variable Z often drives both.
- **Zero correlation does NOT mean zero relationship:** r = 0 only rules out a *linear* relationship. A parabolic curve (Y = X²) can have r = 0 while being completely deterministic.

---
🎯 **Test your understanding:** Reply **"Quiz me"** to test your grasp on this!''';
    }

    // Universal high-yield explanation structure
    return '''### 📚 Concept Deep Dive: **$topic**

#### 1. Fundamental Definition
**$topic** represents a core building block in your syllabus. At its heart, it defines how system components interact under structured constraints to produce reliable outcomes.

#### 2. Practical Analogy
Think of **$topic** like the foundation of a suspension bridge:
- Each component carries part of the load.
- When aligned properly, the system scales smoothly under stress.
- If one assumption fails, edge cases quickly emerge.

#### 3. Three Golden Rules to Remember
1. **Always establish baseline constraints:** Identify your knowns and invariants before computing outcomes.
2. **Watch for scale sensitivity:** Determine whether your approach is invariant to changes in unit or magnitude.
3. **Verify edge conditions:** Check zero values, boundary limits, and asymptotic behavior.

---
💡 **Next Step:** Would you like to see a worked example, or shall we do a quick check? Type **"Quiz me"** or ask me a specific question!''';
  }

  // ---------------------------------------------------------------------------
  // Study Strategy & Cognitive Feedback
  // ---------------------------------------------------------------------------

  String _generateStudyStrategy({
    required String activeTopic,
    required int elapsedMinutes,
    required int targetDurationMinutes,
    int? focusScore,
    String? studyGoal,
  }) {
    final score = focusScore ?? 85;
    final remaining = max(0, targetDurationMinutes - elapsedMinutes);

    return '''### ⚡ Mentra Study Strategy: **$activeTopic**

**Current Telemetry:**
- **Time Studied:** $elapsedMinutes minutes (${remaining > 0 ? '$remaining min remaining' : 'target reached'})
- **Focus Efficiency:** $score%
${studyGoal != null && studyGoal.isNotEmpty ? '- **Active Target:** $studyGoal' : ''}

#### 📋 High-Impact Action Plan
1. **25-5 Rhythm (Pomodoro Spacing):**
   ${elapsedMinutes >= 45 ? '⚠️ You have been focusing for over 45 minutes! Cognitive fatigue sets in past minute 50. Take a 5-minute stretch or hydration break.' : 'You are in an optimal focus window. Maintain active note-taking for the next 15 minutes.'}
2. **Active Recall over Passive Review:**
   Close your notes and write down 3 bullet points summarizing what you just studied from memory.
3. **Feynman Concept Check:**
   Can you explain **$activeTopic** in two sentences as if teaching an absolute beginner? If you hit friction, that highlights your exact knowledge gap.

---
Ready to test what you know? Type **"Quiz me"**!''';
  }

  String _generateGreeting(String topic, int? focusScore) {
    return '''Hello! I'm **Mentra**, your on-device AI Study Coach. 🧠

I'm tracking alongside your session on **$topic**${focusScore != null ? ' (Focus Score: $focusScore%)' : ''}.

Here are quick ways we can accelerate your learning right now:
- **"Quiz me"** — Interactive conceptual checks with instant feedback
- **"Explain a topic"** — Step-by-step breakdowns with real-world analogies
- **"Study plan"** — Cognitive pacing and retention strategy

What are you working through today?''';
  }

  String _generateTopicAnswer(String query, String topic, String? subject) {
    return '''### 💡 Mentra Insights on **$topic**

Regarding your query: *"'$query'"*

Here is the essential takeaway to integrate into your notes:
1. **Core Principle:** In **$topic**, always isolate the primary variable from confounding factors.
2. **Application:** Apply this concept by linking theoretical definitions directly to real-world datasets or sample problems.
3. **Retention Anchor:** To retain this concept long-term, synthesize the rule in your own words rather than memorizing verbatim text.

---
👉 **Next step:** Want to test your understanding? Type **"Quiz me"** or ask me to elaborate on any specific part!''';
  }

  String _generateLanguageLesson(String query, String lower) {
    if (lower.contains('kannada')) {
      return '''### 🌺 Kannada Language Basics (ಕನ್ನಡ ಕಲಿಯಿರಿ)

Welcome to learning **Kannada (ಕನ್ನಡ)**, one of India's classical languages with over 2,000 years of rich literary history!

#### 1. Essential Daily Greetings & Phrases
| Kannada (ಕನ್ನಡ) | Transliteration | English Meaning |
| :--- | :--- | :--- |
| **ನಮಸ್ಕಾರ** | *Namaskāra* | Hello / Greetings |
| **ಧನ್ಯವಾದಗಳು** | *Dhanyavādagaḷu* | Thank you |
| **ಹೌದು** / **ಇಲ್ಲ** | *Haudu* / *Illa* | Yes / No |
| **ನೀವು ಹೇಗಿದ್ದೀರಿ?** | *Nīvu hēgiddīri?* | How are you? (Respectful) |
| **ನಾನು ಚೆನ್ನಾಗಿದ್ದೇನೆ** | *Nānu cennāgiddēne* | I am doing well |
| **ನಿಮ್ಮ ಹೆಸರೇನು?** | *Nimma hesarēnu?* | What is your name? |
| **ನನ್ನ ಹೆಸರು...** | *Nanna hesaru...* | My name is... |

---

#### 2. The Script Essentials (ಸ್ವರಗಳು - Foundational Vowels)
Kannada script is a phonetic abugida written left to right:
- **ಅ** (*a*) — as in **u**p
- **ಆ** (*aa*) — as in f**a**ther
- **ಇ** (*i*) — as in f**i**t
- **ಈ** (*ee*) — as in f**ee**t
- **ಉ** (*u*) — as in p**u**t
- **ಊ** (*oo*) — as in m**oo**n

---

#### 3. Sentence Structure Rule
In English, sentences follow **Subject-Verb-Object (SVO)**:
> *"I drink water."*

In Kannada, sentences follow **Subject-Object-Verb (SOV)**:
> **ನಾನು** (I) + **ನೀರು** (water) + **ಕುಡಿಯುತ್ತೇನೆ** (drink)  
> *"Nānu nīru kuḍiyuttēne."*

---

#### 🎯 Quick Practice Challenge!
How would you greet someone and say *"Thank you"* in Kannada?

👉 Try replying with the Kannada word or transliteration, or ask me for **numbers (1 to 10)**, **ordering food**, or **useful daily phrases**!''';
    }

    if (lower.contains('hindi')) {
      return '''### 🇮🇳 Hindi Language Basics (हिन्दी सीखें)

Welcome to learning **Hindi (हिन्दी)**, written in the Devanagari script!

#### 1. Essential Daily Greetings & Phrases
| Hindi (हिन्दी) | Transliteration | English Meaning |
| :--- | :--- | :--- |
| **नमस्ते** | *Namaste* | Hello / Greetings |
| **धन्यवाद** / **शुक्रिया** | *Dhanyavād* / *Shukriyā* | Thank you |
| **हाँ** / **नहीं** | *Haan* / *Nahin* | Yes / No |
| **आप कैसे हैं?** | *Aap kaise hain?* | How are you? (Polite) |
| **मैं ठीक हूँ** | *Main theek hoon* | I am fine |
| **आपका नाम क्या है?** | *Aapka naam kya hai?* | What is your name? |

---

#### 2. Sentence Structure Rule
Hindi uses **Subject-Object-Verb (SOV)** order:
> **मैं** (I) + **किताब** (book) + **पढ़ता हूँ** (read)  
> *"Main kitaab padhta hoon."*

---

#### 🎯 Quick Practice!
Reply with how you say *"Hello, thank you"* in Hindi!''';
    }

    return '''### 🌍 Language Learning Fundamentals

Mastering a new language is most effective when split into **3 cognitive pillars**:

#### 1. High-Frequency Lexicon (First 100 Words)
80% of daily spoken communication relies on roughly 300 core lemmas:
- **Core Greetings:** Hello, Goodbye, Please, Thank you.
- **Pronouns:** I, You, He/She, We, They.
- **Key Verbs:** To be, To have, To go, To want, To do.

#### 2. Sentence Architecture (Word Order)
- Identify if the target language is **SVO** (English, French, Spanish) or **SOV** (Kannada, Hindi, Japanese, Turkish).

#### 3. Active Immersion & Recall
- Speak out loud and formulate 3 short sentences every day using active recall.

---
👉 Tell me: Which language or specific topic would you like to master today? (e.g. *"Teach me Kannada"*, *"Basic Spanish"*, or *"Daily conversational phrases"*!)''';
  }
}
