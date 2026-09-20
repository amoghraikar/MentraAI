# Mentra — Product Requirements Document (PRD)

> **Document Version:** 2.0  
> **Status:** Approved / Implemented  
> **Target Release:** Mentra 1.0 (Desktop & Web)  
> **Live Web Application:** [https://mentra-ai-studycoach.netlify.app/](https://mentra-ai-studycoach.netlify.app/)

---

## 1. Executive Summary & Product Vision

Students and lifelong self-directed learners face an unprecedented distraction crisis: digital interruptions, cognitive fatigue, fragmented study sessions, and passive memorization habits. 

**Mentra** is an intelligent, privacy-first study workspace that bridges real-time behavioral observation with cognitive scaffolding. By pairing lightweight, on-device computer vision (detecting presence, drowsiness, and focus shifts) with an on-device conversational AI tutor (generating first-principles explanations and structured practice), Mentra transforms passive study time into deliberate, measurable learning gains.

### Key Value Propositions
1. **Zero-Cloud Vision Privacy**: Webcam telemetry is calculated entirely in memory; raw video never touches the disk or cloud.
2. **Real Local LLM Intelligence**: An on-device language model (`Qwen2.5-1.5B`) provides genuine natural conversation, step-by-step guidance, and real-time streaming without subscription fees, cloud lock-in, or canned templates.
3. **Structured Focus Architecture**: A 5-stage study session lifecycle encourages conscious goal setting, sustained active focus, and structured post-session reflections.
4. **Resilient Offline Workspace**: Complete parity across Notes, Goals, Subjects, and Analytics whether connected to the server, working offline, or sandboxed on the web.

---

## 2. Target Personas

### Persona A: The University Student ("Alex", 20)
- **Context**: Preparing for computer science and mathematics exams.
- **Pain Points**: Prone to phone distractions; loses track of study duration; struggles with complex theoretical proofs late at night.
- **Needs**: Real-time drowsiness/distraction alerts, deep explanations from an AI tutor, and progress metrics for subject mastery.

### Persona B: The Self-Directed Professional ("Priya", 29)
- **Context**: Transitioning into data science while working full-time.
- **Pain Points**: Fragmented 45-minute evening study blocks; lacks a personal mentor to answer niche technical questions.
- **Needs**: Structured focus timers, organized markdown notes tagged by topic, and weekly focus score analytics.

---

## 3. Core Functional Requirements

### 3.1. User Accounts & Multi-Tenant Security
- **FR-1.1**: Students can register with email and password, log in, and receive a cryptographically signed JWT access token.
- **FR-1.2**: User sessions persist securely using platform keychain/secure storage (or web local storage).
- **FR-1.3**: Complete tenant isolation (IDOR protection); any query or mutation targeting another student's subject, session, note, or goal must return HTTP 404.
- **FR-1.4**: Guest/Local mode allows students to try all features without immediate account registration.

### 3.2. Subject & Topic Workspace Management
- **FR-2.1**: Students can create Subjects with custom title, course code, color hex, and target hours.
- **FR-2.2**: Subjects contain hierarchical Topics with completion percentages, key concept tags, and notes snippets.
- **FR-2.3**: Progress is automatically recalculated when associated study sessions are completed.

### 3.3. Five-Stage Study Session Engine
- **FR-3.1**: Students can configure session target duration (15m, 25m, 45m, 60m, custom), study mode (Focus Mode / Pomodoro), subject, and topic.
- **FR-3.2 (Preparing)**: 5-second countdown HUD displaying camera preview, lighting validation, and intention setting.
- **FR-3.3 (Active)**: Countdown timer, real-time focus score gauge (0-100), distraction count counter, and pause/resume controls.
- **FR-3.4 (Paused)**: Timer halted; camera hardware released to conserve battery and protect privacy.
- **FR-3.5 (Completed)**: Post-session reflection modal prompting qualitative rating (Great / Good / Distracted / Tired) and summary statistics.

### 3.4. On-Device Computer Vision & Focus Monitoring
- **FR-4.1 (Face Presence)**: Detects user presence; debounces momentary frame drops (e.g. 500ms grace period) before registering an absence event.
- **FR-4.2 (Drowsiness & Fatigue)**: Evaluates Eye Aspect Ratio (EAR). Ignores normal blinks (<500ms); triggers fatigue alert on prolonged eye-closure (>1500ms).
- **FR-4.3 (Distraction)**: Detects sustained head turn or off-screen gaze; triggers a non-intrusive visual indicator on the session HUD.
- **FR-4.4 (Privacy Guarantee)**: No frames, video files, or raw landmarks are written to persistent storage or transmitted over network sockets.

### 3.5. On-Device AI Study Coach
- **FR-5.1 (Real Inference)**: Powered by local open-weight instruction-tuned LLM (`Qwen2.5-1.5B-Instruct` via Ollama) with true token-by-token generation.
- **FR-5.2 (Progressive Streaming)**: Emits decoded tokens via Server-Sent Events (SSE) to the Flutter client, achieving TTFT < 500ms and ~20 tokens/sec.
- **FR-5.3 (Conversational Multi-Turn)**: Context-aware memory that maintains discussion threads across multiple questions and answers.
- **FR-5.4 (Stop Generation)**: Student can cancel token generation mid-stream with a dedicated cancel button.
- **FR-5.5 (Zero Canned Templates)**: Prohibits artificial canned strings ("Master Guide: ...") or rigid keyword rules.

### 3.6. Markdown Notes Workspace
- **FR-6.1**: Rich Markdown note editor with real-time rendered preview.
- **FR-6.2**: Association of notes with specific subjects or topics.
- **FR-6.3**: Tagging support and instant full-text client-side and server-side search.
- **FR-6.4 (Offline Fallback)**: Notes can be created, edited, and deleted locally when offline or sandboxed.

### 3.7. Goals & Milestone Tracking
- **FR-7.1**: Creation of SMART study goals with target completion dates.
- **FR-7.2**: Interactive milestone checklist with toggleable completion checkboxes.
- **FR-7.3**: Dynamic progress bar calculating percentage of completed milestones.
- **FR-7.4 (Offline Fallback)**: Full offline creation and milestone toggling support.

### 3.8. Analytics & Focus Intelligence
- **FR-8.1**: Summary metrics: Total Study Time, Total Sessions, Completed Sessions, Average Session Duration, Longest Session, Average Focus Score, Total Distractions.
- **FR-8.2**: Time range filtering: 7 Days (`7d`), 30 Days (`30d`), 90 Days (`90d`), All Time (`all`).
- **FR-8.3**: Daily focus score and study minute trend graphs with zero-filled historical continuity.
- **FR-8.4**: Distraction breakdown categorized into Phone/Device, Drowsiness, Gaze Deviation, and Other.
- **FR-8.5**: Subject distribution breakdown displaying study time percentages.

---

## 4. Non-Functional Requirements

### 4.1. Performance & Latency
- **NFR-1**: Flutter UI must render consistently at 60 FPS on desktop and modern web browsers.
- **NFR-2**: Time-to-first-token (TTFT) for local AI coach responses must remain under 1.5 seconds on a quad-core Intel i5 CPU.
- **NFR-3**: REST API responses from FastAPI must return within < 50ms for indexed user queries.

### 4.2. Reliability & Fault Tolerance
- **NFR-4**: UI components must never stay in an infinite loading spinner state if an API call fails or times out.
- **NFR-5**: Dual-layer repository fallback ensures full UI usability even when backend services are down.

### 4.3. Security & Compliance
- **NFR-6**: Zero video frame persistence.
- **NFR-7**: Salted bcrypt password hashing with cost factor 12.
- **NFR-8**: Tokens signed with HS256 secret keys stored in environment variables.

---

## 5. Success Metrics (KPIs)

1. **Session Completion Rate**: > 80% of initiated study sessions completed without premature abandonment.
2. **Focus Score Improvement**: Average user focus score increases by 10% over 14 consecutive study days.
3. **AI Coach Utility**: > 85% of AI Coach interactions involve multi-turn clarification and positive student engagement.
4. **Crash-Free Sessions**: > 99.9% crash-free session rate across web and desktop platforms.
