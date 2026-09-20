# Mentra — Application Flow & User Journeys (APP-FLOW)

> **Document Version:** 2.0  
> **Status:** Implemented  
> **Platform:** Flutter Desktop & Web  
> **Live Deployment:** [https://mentra-ai-studycoach.netlify.app/](https://mentra-ai-studycoach.netlify.app/)

---

## 1. Global User Journey Map

```mermaid
graph TD
    A[Launch Mentra App] --> B{Stored Auth Token?}
    B -- Yes --> C[Verify Token /api/v1/auth/me]
    B -- No --> D[Onboarding / Auth Page]
    
    C -- Valid --> E[Workspace Home Dashboard]
    C -- Invalid / Expired --> F[Clear Token & Show Login]
    
    D --> G[Login or Register or Guest Bypass]
    G --> E
    
    E --> H[Subjects & Topics Workspace]
    E --> I[Start Study Session Flow]
    E --> J[Study Notes Workspace]
    E --> K[Goals & Milestones]
    E --> L[Analytics Dashboard]
    E --> M[AI Coach Chat]
```

---

## 2. Five-Stage Study Session Lifecycle

The core study experience is governed by the `SessionController` finite state machine:

```mermaid
stateDiagram-v2
    [*] --> Idle: App Startup / Dashboard
    
    Idle --> Preparing: User clicks "Start Session" & configures parameters
    note right of Preparing
        5-Second Countdown
        Camera Check & Lighting Validation
        State Study Intention
    end note
    
    Preparing --> Active: Countdown expires or user clicks "Start Now"
    Preparing --> Idle: User clicks "Cancel"
    
    Active --> Paused: User clicks "Pause" (Camera Hardware Released)
    Paused --> Active: User clicks "Resume"
    
    Active --> Completed: Target timer reaches 0 or user clicks "Finish"
    
    Completed --> Reflection: Post-Session Reflection Modal
    note right of Reflection
        Select Feeling: Great / Good / Distracted / Tired
        Enter Session Summary Notes
    end note
    
    Reflection --> Idle: Telemetry persisted to DB / Fallback Storage
```

---

## 3. Real-Time Computer Vision & Distraction Flow

During an active session, camera frames are evaluated locally on-device:

```mermaid
sequenceDiagram
    autonumber
    participant Camera as Webcam Hardware
    participant CV as CV Monitoring Engine
    participant Debounce as Debounce / Cooldown Logic
    participant UI as Active Session HUD
    participant DB as Backend Telemetry Buffer

    Camera->>CV: In-memory raw video frame
    CV->>CV: Calculate Face Presence & EAR (Eye Aspect Ratio)
    CV-->>Camera: Immediate frame disposal (RAM only)
    
    alt Face Absent > 500ms
        CV->>Debounce: Face Absence Event
        Debounce->>UI: Show subtle "Face Absent" banner
    else Normal Blink (< 500ms)
        CV->>Debounce: Ignore blink
    else Eye Closure > 1500ms (Drowsiness)
        CV->>Debounce: Drowsiness Alert Trigger
        Debounce->>UI: Show "Drowsiness Detected - Take a Stretch"
        Debounce->>DB: Increment Distraction Counter
    else Sustained Head Turn / Gaze Shift
        CV->>Debounce: Gaze Drift Trigger (10s Cooldown)
        Debounce->>UI: Show "Distraction Alert"
        Debounce->>DB: Increment Distraction Counter
    end
```

---

## 4. Local AI Study Coach Conversational Flow

```mermaid
sequenceDiagram
    autonumber
    participant Student as Student UI
    participant Client as ApiAiCoachRepository
    participant API as FastAPI Server
    participant Ollama as Local Ollama Runtime (Qwen2.5)

    Student->>Client: "Can you explain recursion with an example?"
    Client->>API: POST /api/v1/ai-coach/stream (Prompt + Turn History)
    API->>Ollama: POST /api/chat (qwen2.5:1.5b, stream=true)
    
    loop Real-Time Token Generation
        Ollama-->>API: Emits token chunk JSON
        API-->>Client: Emits SSE chunk: data: {"chunk": "...", "done": false}
        Client-->>Student: Renders tokens progressively in chat bubble (~20 tps)
    end
    
    Ollama-->>API: Stream completed (done: true)
    API-->>Client: Final SSE chunk: data: {"chunk": "", "done": true}
    Client-->>Student: Mark bubble complete & enable follow-up input
```

---

## 5. Offline & HTTPS Fallback Flow

When running on Netlify over HTTPS (or when backend is offline), the dual-layer repository architecture prevents network failures from disrupting student workflows:

```mermaid
flowchart TD
    A[User triggers action: Load Notes / Toggle Milestone / View Analytics] --> B[ApiRepository]
    B --> C{HTTP Request to Backend}
    
    C -- 200 OK --> D[Parse Backend Response & Update UI]
    C -- Failed / Blocked / Offline --> E{Fallback Repository Defined?}
    
    E -- Yes --> F[Delegate to MockRepository in RAM / LocalStorage]
    F --> G[Return Cached / Realistic Fallback Data]
    G --> H[Update UI cleanly with zero spinners]
    
    E -- No --> I[Rethrow error cleanly to UI Error Handler]
```

---

## 6. Navigation & Workspace Sub-Routes

Inside `WorkspaceLayout`, sub-routes transition seamlessly within the main shell:

1. **`AppRoute.home`**:
   - High-level study streak, recent sessions, quick start button.
2. **`AppRoute.subjects`**:
   - `SubjectsPage`: Grid of enrolled courses/subjects.
   - `SubjectWorkspacePage`: Topics, progress bars, hours studied, action buttons.
   - `TopicWorkspacePage`: Topic concept breakdown and notes.
3. **`AppRoute.notes`**:
   - `NotesPage`: Filterable list of study notes with full-text search.
   - `NoteEditorView`: Side-by-side Markdown editor and rendered preview.
4. **`AppRoute.goals`**:
   - `GoalsPage`: Goal cards with milestone checkboxes and progress indicators.
5. **`AppRoute.analytics`**:
   - `AnalyticsPage`: Study metrics, timeline charts, and distraction breakdown.
6. **`AppRoute.aiCoach`**:
   - `AiCoachPage`: Conversational tutor workspace.
7. **`AppRoute.settings`**:
   - `SettingsPage`: Theme selection, monitoring thresholds, and account options.
