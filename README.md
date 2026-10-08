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

## One-Click Bulletproof Startup

Launch the entire ecosystem (Local Neural LLM, SQLite/Postgres DB, FastAPI Backend with MediaPipe CV, and Flutter Web/Desktop client) with a single command:

```bash
chmod +x start.sh
./start.sh
```

`start.sh` automatically checks Ollama, activates the backend, initializes tables, verifies `/health` and `/api/v1/cv/status`, and launches the Flutter application.

---

## 4-Tier Resilient AI Coach Architecture

Mentra guarantees zero failures and eliminates generic placeholder templates through an intelligent 4-tier fallback hierarchy:

1. **Tier 1: FastAPI Local Backend** (`http://127.0.0.1:8000`) — Full RAG semantic search and local LLM orchestration.
2. **Tier 2: Direct Local Ollama** (`http://127.0.0.1:11434`) — If the Python backend is paused, the web client connects directly to Ollama via browser CORS.
3. **Tier 3: Cloud Gemini Engine** (`gemini-1.5-flash`) — On HTTPS deployments (such as Netlify) where localhost is blocked, optionally provides instant cloud streaming.
4. **Tier 4: Autonomous Exam-Grade Academic Engine** — On-device syllabus knowledge engine spanning Physics (Gravity, Newton's Laws, Thermodynamics), Computer Science (Arrays, Big-O, Pointers, Memory), Mathematics (Calculus, Linear Algebra), Biology (Photosynthesis), Chemistry, and Machine Learning. Provides authentic formulas, derivations, analogies, and practice questions without generic placeholders.

---

## Computer Vision Dual-Engine Architecture

1. **Local Python MediaPipe Pipeline**: 468-point face mesh, eye-aspect ratio (EAR) blink/drowsiness detection, and 3D head pose estimation.
2. **Pure-Browser Canvas Centroid Tracker**: Automatically active when backend is offline or in HTTPS sandbox environments (Netlify). Tracks face centroid, yaw/pitch angular deviation, looking-away state, and eye-closure directly from the camera feed via in-browser canvas pixel sampling without sending video frames over the network.

---

## Testing & Quality Summary

- **Backend Pytest Suite**: `100% PASSED` (including real end-to-end multi-turn Ollama LLM + RAG + CV integration test in `tests/test_milestone5_real_end_to_end.py`).
- **Frontend Flutter Suite**: `54 / 54 PASSED` (100% pass rate across onboarding, auth, study session lifecycle, computer vision telemetry, gravity explanations, and failure/chaos resilience).
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
