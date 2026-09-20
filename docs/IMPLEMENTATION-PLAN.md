# Mentra — Implementation Plan & Milestone Roadmap

> **Document Status:** All Milestones (M1 – M9) Implemented & Verified  
> **Date:** September 2026  
> **Repository:** `https://github.com/amoghraikar/MentraAI.git`  
> **Live Web Deployment:** [https://mentra-ai-studycoach.netlify.app/](https://mentra-ai-studycoach.netlify.app/)

---

## 1. Milestone Overview & Delivery Status

| Milestone | Scope | Deliverables | Verification Status |
| :--- | :--- | :--- | :--- |
| **M1** | Design System & UI | Material 3 custom theme, typography, cards, badges, layout, sidebar navigation. | ✅ Completed |
| **M2** | Backend & Database | FastAPI async app, PostgreSQL 16 schema, Alembic migrations, JWT Auth with bcrypt. | ✅ Completed |
| **M3** | Integration & Auth | ApiClient, SecureTokenStorage, login/register flow, workspace repository binding. | ✅ Completed |
| **M4** | Study Session Engine | 5-stage SessionController state machine, HUD, timers, reflection dialog. | ✅ Completed |
| **M5** | Computer Vision Monitoring | On-device face presence debouncer, EAR drowsiness detector, distraction cooldowns. | ✅ Completed |
| **M6** | Real Local LLM Engine | Ollama runtime, `Qwen2.5-1.5B` GGUF, SSE progressive token streaming (~20 tps). | ✅ Completed |
| **M7** | Analytics & Intelligence | Aggregation service, 7d/30d/90d views, daily focus trends, distraction breakdown. | ✅ Completed |
| **M8** | Security & Chaos Hardening| Strict IDOR defense, 401 token wipe, network drop resilience, 100% test pass. | ✅ Completed |
| **M9** | Web & Cloud Deployment | Netlify automated build script, SPA routing, offline & HTTPS fallback resilience. | ✅ Completed |

---

## 2. Milestone Deep Dives

### Milestone 1: Design System & Frontend Workspaces
- **Objectives**: Build a cohesive, modern desktop and web workspace for focused studying.
- **Key Artifacts**:
  - `core/theme/`: `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `MentraTheme`.
  - `shared/widgets/`: `MentraButton`, `MentraCard`, `MentraBadge`, `MentraProgressBar`, `MentraPageHeader`, `MentraEmptyState`, `MentraStatCard`.
  - `shared/layouts/`: `WorkspaceLayout` with responsive collapsible sidebar and breadcrumb navigation.

### Milestone 2: Backend Architecture & Database Schema
- **Objectives**: Establish high-performance, asynchronous REST API with PostgreSQL.
- **Key Artifacts**:
  - FastAPI application structure (`backend/app/main.py`, `core/config.py`, `core/security.py`).
  - SQLAlchemy 2.0 async models for `User`, `Subject`, `Topic`, `Note`, `Goal`, `GoalMilestone`, `StudySession`.
  - Alembic migrations setting up foreign key cascades and indexed user queries.

### Milestone 3: Client-Backend Integration & Secure Authentication
- **Objectives**: Connect the Flutter client to the backend REST API with persistent authentication.
- **Key Artifacts**:
  - `core/network/api_client.dart`: Centralized HTTP handler with token injection and unified error parsing.
  - `core/storage/secure_token_storage.dart`: Secure persistent storage across Web (localStorage) and native platforms.
  - Auth screens: `LoginPage`, `RegisterPage`, and auto-login authentication state management.

### Milestone 4: Five-Stage Study Session Engine
- **Objectives**: Create a deliberate, structured study session flow that combats passive study habits.
- **Key Artifacts**:
  - `SessionController`: Enforces valid state transitions (`idle` → `preparing` → `active` → `paused` → `completed` → `idle`).
  - `StudyPrepPage`: 5-second countdown, lighting check, and goal intention entry.
  - `ActiveSessionHUD`: Clean minimalist fullscreen HUD with elapsed timer, live focus score, and distraction badges.
  - `SessionReflectionModal`: Qualitative reflection input (`great`, `good`, `distracted`, `tired`) persisted with session telemetry.

### Milestone 5: Computer Vision & Focus Monitoring
- **Objectives**: Implement privacy-first, on-device attention and fatigue telemetry.
- **Key Artifacts**:
  - `FacePresenceDetector`: Sliding window debouncer (500ms grace period) prevents noisy alerts from single dropped frames.
  - `DrowsinessDetector`: Eye Aspect Ratio (EAR) tracking distinguishes natural blinks (<500ms) from sustained microsleeps (>1500ms).
  - `DistractionDetector`: Cooldown timer (10s) prevents repeated acoustic and visual notification spam.
  - Privacy guarantee: Raw camera video frames are processed in-memory and immediately destroyed.

### Milestone 6: AI Coach Rebuild — Real Local LLM
- **Objectives**: Replace all canned/template responses with a real on-device neural language model.
- **Key Artifacts**:
  - Ollama integration on `http://127.0.0.1:11434` loading `Qwen2.5-1.5B-Instruct` (986 MB GGUF Q4_K_M).
  - `backend/app/services/ai/local_llm.py`: Asynchronous streaming client invoking the local model without any cloud API keys.
  - Progressive Server-Sent Events (SSE) router (`POST /api/v1/ai-coach/stream`) delivering ~18–22 tokens/sec on Intel CPU.
  - Conversational tests verified: natural greetings ("hi", "bye"), progressive first-principles explanations, multi-turn context retention.

### Milestone 7: Analytics & Focus Intelligence
- **Objectives**: Aggregate and visualize student study trends and habits over customizable time windows.
- **Key Artifacts**:
  - `backend/app/services/analytics_service.py`: Computes continuous daily timelines with zero-filling for unstudied days.
  - Distraction categorization: Identifies whether distractions stem from device use, fatigue, or gaze drift.
  - `apps/mentra/lib/features/analytics/`: Interactive UI featuring bar charts, breakdown progress bars, and stat cards.

### Milestone 8: Security, IDOR Defense & Chaos Hardening
- **Objectives**: Harden the application against data leaks, unauthorized access, and unexpected network dropouts.
- **Key Artifacts**:
  - Strict IDOR defense: All endpoints verify `resource.user_id == current_user.id`.
  - Auth token hygiene: Client-side `AuthService` wipes expired tokens on receiving `401 Unauthorized`.
  - Pydantic length and value validations reject oversized or malformed payloads with HTTP 422.
  - Automated Chaos test suite (`failure_chaos_test.dart`).

### Milestone 9: Web Production & Netlify Cloud Deployment
- **Objectives**: Deploy the production web client to Netlify with offline resilience.
- **Key Artifacts**:
  - `netlify.toml` and `netlify_build.sh`: Automated build script for downloading Flutter stable and compiling `--release --base-href /`.
  - Single-Page Application rewrite rules (`apps/mentra/web/_redirects`).
  - Dual-layer repository fallbacks (`ApiNoteRepository`, `ApiGoalRepository`, `ApiAnalyticsRepository`) enabling complete functionality when offline or under browser HTTPS mixed-content policies.

---

## 3. Verification & Quality Assurance Results

| Test Suite | Scope | Target | Result |
| :--- | :--- | :--- | :--- |
| **Backend Pytest** | Security, Auth, DB, Sessions, AI Stream, Analytics | 100% pass | **62 / 62 PASSED** |
| **Frontend Flutter Test** | Widget, State Machine, CV Detectors, Chaos | 100% pass | **47 / 47 PASSED** |
| **Static Analysis** | Dart analyzer (`flutter analyze`) | 0 issues | **0 issues found** |
| **Live Web Check** | Netlify HTTP status (`curl -I`) | 200 OK | **HTTP/2 200 OK** |
