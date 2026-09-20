# Mentra — Technical Requirements Document (TRD)

> **Document Version:** 2.0  
> **Status:** Implemented  
> **Architecture Style:** Monorepo (Client + Layered FastAPI + On-Device Runtime)  
> **Live Web Application:** [https://mentra-ai-studycoach.netlify.app/](https://mentra-ai-studycoach.netlify.app/)

---

## 1. System Architecture & Topology

Mentra is architected as an offline-resilient, modular monorepo:

```
                               ┌───────────────────────────────────┐
                               │       Client (Flutter/Dart)       │
                               │   - Responsive UI (Material 3)    │
                               │   - Session State Machine (5-stg) │
                               │   - On-Device CV (Face/Gaze/EAR)  │
                               │   - Secure Token Storage          │
                               │   - Dual-Layer Fallback Repos     │
                               └─────────┬───────────────▲─────────┘
                                         │               │
                            HTTP / REST  │               │ Server-Sent Events (SSE)
                            (port 8000)  │               │ (Token Chunks)
                                         ▼               │
┌────────────────────────────────────────────────────────┴───────────────────────┐
│                           FastAPI Backend (Python 3.11)                        │
│                                                                                │
│  ┌─────────────────┐   ┌──────────────────┐   ┌─────────────────────────────┐  │
│  │   Auth Router   │   │ Workspaces Router│   │   AI Coach Stream Router    │  │
│  │ (/api/v1/auth)  │   │  (Subjects/Notes/│   │  (/api/v1/ai-coach/stream)  │  │
│  │                 │   │   Goals/Sessions)│   │                             │  │
│  └────────┬────────┘   └────────┬─────────┘   └──────────────┬──────────────┘  │
│           │                     │                            │                 │
│  ┌────────▼─────────────────────▼─────────┐       ┌──────────▼──────────────┐  │
│  │        Service & Business Layer        │       │   Local LLM Provider    │  │
│  │ (AuthService, WorkspaceService, etc.)  │       │ (Ollama HTTP /api/chat) │  │
│  └────────────────┬───────────────────────┘       └──────────┬──────────────┘  │
│                   │                                          │                 │
│  ┌────────────────▼───────────────────────┐                  │                 │
│  │     SQLAlchemy 2.0 Async ORM           │                  │                 │
│  │   (Repositories & Unit of Work)        │                  │                 │
│  └────────────────┬───────────────────────┘                  │                 │
└───────────────────┼──────────────────────────────────────────┼─────────────────┘
                    │                                          │
                    ▼                                          ▼
       ┌────────────────────────┐                 ┌─────────────────────────┐
       │ PostgreSQL 16 Database │                 │  Ollama Inference Engine│
       │ (Port 5432, Migrations)│                 │  (Port 11434, Qwen2.5)  │
       └────────────────────────┘                 └─────────────────────────┘
```

---

## 2. Technology Stack & Component Responsibilities

| Tier / Component | Technology | Version | Key Responsibility |
| :--- | :--- | :--- | :--- |
| **Frontend Framework** | Flutter | 3.24+ | Cross-platform rendering, reactive widget tree, Material 3 theming. |
| **Client Language** | Dart | 3.5+ | Strong static typing, async Streams, Web compilation (`wasm` / js). |
| **State Management** | ChangeNotifier / Scoped | Native | Lightweight state controllers without heavy third-party framework overhead. |
| **API Backend** | FastAPI | 0.111+ | Asynchronous REST endpoints, Pydantic validation, SSE streaming. |
| **Backend Language** | Python | 3.11+ | Core server logic, token streaming orchestration. |
| **Database ORM** | SQLAlchemy | 2.0+ (async) | Async PostgreSQL sessions, model relations, connection pooling. |
| **Database Migrations**| Alembic | 1.13+ | Versioned database schema evolution and rollback support. |
| **Relational Database**| PostgreSQL | 16-alpine | ACID transactions, foreign key cascades, indices on `user_id`. |
| **Local LLM Engine** | Ollama / llama.cpp | 0.3+ | Native CPU AVX2 acceleration, GGUF Q4_K_M quant execution. |
| **LLM Weights** | `Qwen2.5-1.5B-Instruct` | 1.54B params | Low latency, first-principles instruction following. |
| **Web Hosting & CI/CD**| Netlify Edge | Latest | Automated Flutter build script, SSL termination, SPA routing. |

---

## 3. Data Flow & Resilience Patterns

### 3.1. Dual-Layer Repository Fallback Pattern
To guarantee zero-crash execution in offline conditions or web browser security boundaries (mixed content / CORS), every client repository adheres to the dual-layer architecture:

```dart
abstract class NoteRepository {
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId});
  Future<NoteModel> createNote({...});
  Future<void> deleteNote(String id);
}

class ApiNoteRepository implements NoteRepository {
  ApiNoteRepository({required this.apiClient, this.fallbackRepository});

  final ApiClient apiClient;
  final NoteRepository? fallbackRepository;

  @override
  Future<List<NoteModel>> getNotes({String? searchQuery, String? subjectId}) async {
    try {
      final res = await apiClient.get('/api/v1/notes');
      return (res as List).map((j) => NoteModel.fromJson(j)).toList();
    } catch (_) {
      if (fallbackRepository != null) {
        return fallbackRepository!.getNotes(searchQuery: searchQuery, subjectId: subjectId);
      }
      rethrow;
    }
  }
}
```

### 3.2. Real Local LLM Streaming Pipeline
1. **Client Request**: The client sends a `POST /api/v1/ai-coach/stream` containing the prompt and previous conversation messages.
2. **FastAPI Controller**: Extracts `current_user_or_local` credentials and forwards payload to `AiCoachService`.
3. **Local LLM Streamer**: Connects via HTTP stream to `http://127.0.0.1:11434/api/chat` passing temperature 0.7, top-p 0.8, and conversation history.
4. **Token Decoding**: As Ollama emits JSON token chunks, FastAPI wraps them into standard SSE format:
   ```text
   data: {"chunk": "Hello", "done": false}
   data: {"chunk": " there", "done": false}
   data: {"chunk": "!", "done": true}
   ```
5. **Client Rendering**: Flutter `Stream<String>` decodes text chunks and appends them to the active chat bubble without buffering delays.

---

## 4. API Endpoints Specification

### 4.1. Authentication (`/api/v1/auth`)
- `POST /register`: Registers a new user (`email`, `password`, `full_name`). Returns user DTO.
- `POST /login`: Verifies password with `bcrypt`. Returns `access_token` and user profile.
- `GET /me`: Returns the authenticated user's profile.

### 4.2. Subjects & Topics (`/api/v1/subjects`)
- `GET /`: Lists all subjects belonging to the authenticated user.
- `POST /`: Creates a subject with `title`, `code`, `color_hex`, `target_hours`.
- `GET /{id}`: Gets details for a subject including nested topics.
- `DELETE /{id}`: Cascades deletion to child topics, notes, and sessions.
- `POST /{id}/topics`: Creates a topic within a subject.

### 4.3. Study Notes (`/api/v1/notes`)
- `GET /`: Lists notes, filterable by `subject_id` or `searchQuery`.
- `POST /`: Creates a note with markdown `content`, `title`, and `tags`.
- `PUT /{id}`: Updates note title, content, or tags.
- `DELETE /{id}`: Deletes a note.

### 4.4. Goals & Milestones (`/api/v1/goals`)
- `GET /`: Lists user goals with embedded milestones.
- `POST /`: Creates a goal with target date and milestone titles.
- `PATCH /{id}/milestones/{milestone_id}/toggle`: Toggles milestone completion.
- `DELETE /{id}`: Deletes a goal and associated milestones.

### 4.5. Study Sessions (`/api/v1/sessions`)
- `GET /`: Fetches session history (supports pagination via `limit` and `skip`).
- `POST /`: Persists completed session telemetry (`actual_duration_minutes`, `focus_score`, `distractions_count`, `reflection`).

### 4.6. Analytics (`/api/v1/analytics`)
- `GET /overview?range={7d|30d|90d|all}`: Returns aggregated study minutes, completed count, average focus score, daily trends, and distraction breakdown.

### 4.7. AI Study Coach (`/api/v1/ai-coach`)
- `POST /stream`: Initiates SSE token stream for student chat.
- `POST /cancel`: Aborts in-flight local generation.
- `GET /status`: Returns runtime status (`READY`, `GENERATING`, `OFFLINE`) and active model name.

---

## 5. Security & Privacy Safeguards

1. **Camera Privacy**:
   - Camera video stream is processed frame-by-frame in RAM.
   - Zero frames are written to filesystem or transmitted outside the host.
2. **Multi-Tenant Protection (IDOR Defense)**:
   - Database queries filter by `user_id == current_user.id`.
   - Access attempts to resources owned by another user return `404 Not Found`.
3. **Password Security**:
   - `passlib.context.CryptContext` using salted `bcrypt`.
4. **Token Expiration**:
   - Short-lived JWTs (default: 7 days) signed with `HS256`.

---

## 6. Testing & CI/CD Validation

- **Backend Pytest Suite**: 62 unit and integration tests executing against isolated SQLite/PostgreSQL databases.
- **Frontend Flutter Suite**: 47 unit, widget, and state-machine tests validating:
  - `SessionController` transitions (idle → preparing → active → paused → completed).
  - Computer vision debouncers (500ms face presence tolerance, 1500ms drowsiness window).
  - Chaos resilience: 401 token clearing, network socket timeout handling.
- **Static Analysis**: `flutter analyze` enforcing 0 issues.
