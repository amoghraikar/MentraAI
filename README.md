# Mentra

> **AI Study Coach & Real-Time Focus Intelligence**  
> *Understand your focus. Improve your learning.*

Mentra is a privacy-first study workspace that uses on-device computer vision to understand study behavior during sessions, converting real-time telemetry into actionable analytics and personalized AI coaching.

---

## Architecture & System Overview

Mentra is structured as a modular, hardened monorepo separating client presentation, backend business logic, and local computer vision processing:

```text
┌────────────────────────────────────────────────────────┐
│                   Mentra Client                        │
│          (Flutter / Dart - Material 3)                 │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
       REST / JWT Auth           On-Device CV Pipeline
                │                        │
┌───────────────▼────────────┐  ┌────────▼───────────────┐
│     FastAPI Backend        │  │       CV Engine        │
│ (Python / SQLAlchemy/ Alembic)│  │(Debounced State Engine)│
└───────────────▲────────────┘  └────────────────────────┘
                │
     ┌──────────┴──────────┐
     │                     │
┌────▼───────┐      ┌──────▼─────┐
│ PostgreSQL │      │   Redis    │
│ (Database) │      │  (Cache)   │
└────────────┘      └────────────┘
```

- **Frontend (`apps/mentra`)**: Flutter cross-platform client (macOS, Web, Windows, Android, iOS) adhering to the Material 3 design system.
- **Backend (`backend`)**: FastAPI REST API with structured layered architecture (API routes, Core security, Database sessions, SQLAlchemy models, Pydantic DTOs, Repositories, Services).
- **CV Engine (`cv-engine` & `lib/features/cv_monitoring`)**: On-device privacy-preserving attention, blink/drowsiness estimation, and distraction telemetry. Camera frames are processed strictly in-memory and destroyed immediately after feature extraction.
- **Analytics & Intelligence**: Server-side continuous timeline aggregation, distraction classification, study streak tracking, and verified AI Coach insights.
- **Infrastructure (`infrastructure/docker`)**: Docker Compose environment providing local PostgreSQL 16 and Redis 7.

---

## Milestone Progress

| Milestone | Description | Status |
| :--- | :--- | :--- |
| **M1** | Complete Frontend UI (Workspaces, Sidebar, Dark Mode, Themes, Navigation) | **Completed** |
| **M2** | Backend Architecture, PostgreSQL Database, Alembic Migrations & Auth | **Completed** |
| **M3** | Frontend ↔ Backend Integration, JWT Tokens, Secure Storage & Repositories | **Completed** |
| **M4** | Study Session Engine (5-Stage State Machine, Timers, Reflections) | **Completed** |
| **M5** | Computer Vision & Focus Monitoring (On-Device Telemetry, Debouncing, Cooldowns) | **Completed** |
| **M6** | AI Coach & Intelligent Interventions (Chat, Explanations, Study Plans, Fallbacks) | **Completed** |
| **M7** | Analytics & Intelligence (Time Ranges, Timeline Zero-Filling, AI Observations) | **Completed** |
| **M8** | Testing, Security & Optimization (IDOR Defense, Hardening, Chaos Tests) | **Completed** |

---

## Security & Reliability Hardening (M8)

1. **Strict IDOR & Multi-Tenant Isolation**:
   - Every protected endpoint strictly validates `resource.user_id == current_user.id`.
   - Cross-tenant injection of topics, notes, sessions, or goals belonging to another user is rejected with `404 Not Found`.
2. **Authentication & Token Integrity**:
   - Passwords hashed with salted `bcrypt`.
   - JWT tokens signed with configurable algorithm (`HS256`) and dynamic expiration.
   - Tampered signatures and expired tokens are rejected with `401 Unauthorized` and trigger client-side token wipe.
3. **Input & Boundary Validation**:
   - Pydantic models enforce string lengths, non-negative numbers, focus scores (0–100), and ISO-8601 timestamp formats.
   - Long payloads (>2000 chars) are rejected with `422 Unprocessable Entity`.
4. **Camera & Privacy Safeguards**:
   - Zero raw camera imagery is sent to the network or persisted to disk.
   - Camera sessions automatically release hardware resources upon pause, completion, or error.
5. **AI Safety & Graceful Degradation**:
   - External LLM prompts are populated exclusively with verified server-side metrics.
   - When external LLM APIs are unreachable or offline, the system seamlessly falls back to the deterministic local Heuristic AI Provider.

---

## Local Setup & Quickstart

### 1. Environment Configuration

Copy the sample environment file:

```bash
cp .env.example .env
cp .env.example backend/.env
```

### 2. Start Infrastructure (PostgreSQL & Redis)

Start development containers:

```bash
docker compose -f infrastructure/docker/docker-compose.yml up -d
```

### 3. Backend Setup (FastAPI)

```bash
cd backend

# Create virtual environment and install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run migrations
alembic upgrade head

# Run backend test suite (32 tests)
pytest -v

# Start development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API documentation:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

### 4. Flutter Client Setup

```bash
cd apps/mentra

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit, widget, and chaos test suite (42 tests)
flutter test

# Run application on preferred device (Chrome, macOS desktop, etc.)
flutter run -d chrome
```

---

## Testing Verification Summary

- **Backend Pytest Suite**: `32 / 32 PASSED` (100% pass rate across auth, database, subjects, topics, notes, goals, sessions, ai coach, analytics, and security hardening).
- **Frontend Flutter Suite**: `42 / 42 PASSED` (100% pass rate across onboarding, authentication, 5-stage study session lifecycle, computer vision detectors, distraction cooldowns, analytics UI, and failure/chaos resilience).
- **Static Analysis**: `flutter analyze` completed with 0 errors / 0 warnings.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
