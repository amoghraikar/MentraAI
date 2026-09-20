# Mentra

> **AI Study Coach & Real-Time Focus Intelligence**  
> *Understand your focus. Improve your learning.*

Mentra is a privacy-first, cross-platform study companion that pairs on-device computer vision focus monitoring with an integrated local LLM study coach. It converts real-time study telemetry into actionable analytics, habit insights, and interactive guided learning.

🌐 **Live Web Application**: [https://mentra-ai-studycoach.netlify.app/](https://mentra-ai-studycoach.netlify.app/)

---

## Key Highlights

- **Privacy-First Focus Monitoring**: On-device computer vision detects face presence, drowsiness, and distraction without ever uploading or persisting camera imagery.
- **Genuine Local LLM Engine**: Powered by on-device neural model weights (`Qwen2.5-1.5B-Instruct` via Ollama) with true progressive token streaming (~18-22 tokens/sec), multi-turn reasoning, and zero cloud API keys or cloud lock-in.
- **5-Stage Study Session Engine**: Structured session lifecycle (`Idle` → `Preparing` → `Active` → `Paused` → `Completed`) with pre-session intentions, live HUD, and post-session reflections.
- **Resilient Offline Architecture**: Dual-layer repository design with automatic local fallback delegation ensures uninterrupted access to Notes, Goals, Analytics, and Workspaces even in offline or HTTPS web sandbox environments.
- **Actionable Analytics**: Comprehensive study trends, focus score distributions, distraction breakdown charts, and streak analysis.
- **Hardened Security**: Multi-tenant IDOR isolation, bcrypt password hashing, JWT authentication, and automated chaos/failure test suites.

---

## Architecture & System Overview

Mentra is structured as a modular, hardened monorepo:

```text
┌────────────────────────────────────────────────────────┐
│                   Mentra Client                        │
│             (Flutter 3.x / Dart 3.x)                   │
│      Material 3 • Responsive Web, macOS, Mobile       │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
       REST / SSE Streaming      On-Device CV Pipeline
                │                        │
┌───────────────▼────────────┐  ┌────────▼───────────────┐
│     FastAPI Backend        │  │       CV Engine        │
│ (Python / SQLAlchemy async)│  │(Debounced State Engine)│
└───────▲────────────▲───────┘  └────────────────────────┘
        │            │
 ┌──────▼─────┐ ┌────▼──────────────┐
 │ PostgreSQL │ │ Local LLM Engine  │
 │ (Database) │ │ (Ollama / Qwen2.5)│
 └────────────┘ └───────────────────┘
```

- **Frontend (`apps/mentra`)**: Flutter cross-platform client with custom design system (`MentraTheme`), dual API/Mock repository fallback pattern, and web deployment support.
- **Backend (`backend`)**: FastAPI REST API with structured layered architecture (API routes, Core security, SQLAlchemy 2.0 async models, Pydantic DTOs, Repositories, Services).
- **CV Engine (`cv-engine` & `lib/features/cv_monitoring`)**: In-memory computer vision pipeline measuring head pose, eye-aspect ratio (EAR) for blink/drowsiness detection, and debounced distraction tracking.
- **AI Engine (`backend/app/services/ai`)**: Local Ollama runtime orchestrating `qwen2.5:1.5b` (with `qwen2.5:0.5b` lightweight secondary option) delivering SSE streaming at low latency.
- **Infrastructure (`infrastructure/docker`)**: Docker Compose environment providing local PostgreSQL 16 and Redis 7.

---

## Feature Matrix

| Feature Area | Capabilities |
| :--- | :--- |
| **Workspace & Subjects** | Hierarchical Subjects & Topics, progress tracking, estimated hours, color-coded tagging. |
| **Study Sessions** | Configurable duration, Pomodoro / Focus modes, distraction alerts, post-session reflections. |
| **CV Focus Telemetry** | Face presence debouncing, drowsiness detection, posture shift detection, privacy guarantees. |
| **AI Study Coach** | Multi-turn chat, concept explanations, progressive SSE streaming, cancellation support. |
| **Notes System** | Rich markdown preview/editing, subject association, keyword search, tag filtering. |
| **Goals & Milestones** | Target date scheduling, interactive milestone checklists, progress calculation. |
| **Analytics Dashboard** | 7-day / 30-day / 90-day timeframes, focus score timeline, distraction categorization. |

---

## Milestone Progress

| Milestone | Description | Status |
| :--- | :--- | :--- |
| **M1** | Complete Frontend UI (Workspaces, Sidebar, Dark Mode, Themes, Navigation) | **Completed** |
| **M2** | Backend Architecture, PostgreSQL Database, Alembic Migrations & Auth | **Completed** |
| **M3** | Frontend ↔ Backend Integration, JWT Tokens, Secure Storage & Repositories | **Completed** |
| **M4** | Study Session Engine (5-Stage State Machine, Timers, Reflections) | **Completed** |
| **M5** | Computer Vision & Focus Monitoring (On-Device Telemetry, Debouncing, Cooldowns) | **Completed** |
| **M6** | AI Coach & Real Local LLM Rebuild (Ollama + Qwen2.5 Neural Engine, SSE Stream) | **Completed** |
| **M7** | Analytics & Intelligence (Time Ranges, Timeline Zero-Filling, AI Observations) | **Completed** |
| **M8** | Testing, Security & Optimization (IDOR Defense, Hardening, Chaos Tests) | **Completed** |
| **M9** | Web Deployment & Cloud Automation (Netlify CI/CD, HTTPS Fallback Resilience) | **Completed** |

---

## Security & Reliability Hardening

1. **Strict Multi-Tenant Isolation**:
   - Every protected API endpoint enforces `resource.user_id == current_user.id`. Cross-user access returns `404 Not Found`.
2. **Offline & HTTPS Dual-Layer Resilience**:
   - Frontend repositories implement a `fallbackRepository` pattern. When network requests encounter mixed-content blocks, CORS restrictions, or offline conditions, the application falls back to local data gracefully.
3. **Privacy-Preserving Telemetry**:
   - Camera video frames never leave device memory. No images or video streams are ever stored on disk or transmitted over the network.
4. **Token Security**:
   - Bcrypt-hashed credentials and signed JWT tokens with client-side automated token expiration wipes on `401 Unauthorized`.

---

## Local Setup & Quickstart

### 1. Prerequisites
- **Flutter SDK**: 3.x+ (`flutter --version`)
- **Python**: 3.10+
- **Docker & Docker Compose** (for PostgreSQL)
- **Ollama** (optional, for local LLM AI Coach): `brew install ollama` or download from [ollama.com](https://ollama.com)

### 2. Start Infrastructure & Local LLM

```bash
# Start PostgreSQL & Redis
docker compose -f infrastructure/docker/docker-compose.yml up -d

# Start Ollama & pull model (if running local AI coach)
ollama serve &
ollama pull qwen2.5:1.5b
```

### 3. Backend Setup (FastAPI)

```bash
cd backend

# Virtual environment setup
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run database migrations
alembic upgrade head

# Run backend test suite (62 tests)
pytest -v

# Start FastAPI server
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- Swagger API Docs: `http://127.0.0.1:8000/docs`
- ReDoc Docs: `http://127.0.0.1:8000/redoc`

### 4. Flutter Client Setup

```bash
cd apps/mentra

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget test suite (47 tests)
flutter test

# Run application (Chrome Web or Desktop)
flutter run -d chrome
```

---

## Testing & Quality Summary

- **Backend Pytest Suite**: `62 / 62 PASSED` (100% pass rate across auth, security hardening, database, subjects, notes, goals, sessions, local AI stream, and analytics).
- **Frontend Flutter Suite**: `47 / 47 PASSED` (100% pass rate across onboarding, authentication, 5-stage study session lifecycle, computer vision debouncing, analytics UI, and failure/chaos resilience).
- **Static Analysis**: `flutter analyze` completed with `0 issues found`.

---

## Documentation Directory

Comprehensive documentation is available in the [`docs/`](docs/) directory:
- [Product Requirements Document (PRD)](docs/PRD.md)
- [Technical Requirements Document (TRD)](docs/TRD.md)
- [Implementation Plan & Progress](docs/IMPLEMENTATION-PLAN.md)
- [Database Schema](docs/DATABASE-SCHEMA.md)
- [UI/UX Specifications & Design System](docs/UI-UX.md)
- [Application Flow & User Journeys](docs/APP-FLOW.md)

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
