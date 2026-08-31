# Mentra

> **AI Study Coach**  
> *Understand your focus. Improve your learning.*

Mentra is a privacy-first, Notion-inspired study workspace that uses on-device computer vision to understand study behavior during sessions, converting real-time telemetry into actionable analytics and personalized AI coaching.

---

## Current Development Status

- **Active Milestone:** **M0 — Project Foundation** (Completed)
- **Status:** Core monorepo architecture, Flutter client foundation, FastAPI backend, CV/ML environment, and Docker development infrastructure established and verified.

---

## Architecture Overview

Mentra is structured as a modular monorepo separating client presentation, backend business logic, and local computer vision processing:

```text
┌────────────────────────────────────────────────────────┐
│                   Mentra Client                        │
│          (Flutter / Dart - Material 3)                 │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
       REST / WebSocket          Local IPC / Event Stream
                │                        │
┌───────────────▼────────────┐  ┌────────▼───────────────┐
│     FastAPI Backend        │  │       CV Engine        │
│ (Python / SQLAlchemy/ Alembic)│  │(OpenCV/MediaPipe/YOLO) │
└───────────────▲────────────┘  └────────────────────────┘
                │
     ┌──────────┴──────────┐
     │                     │
┌────▼───────┐      ┌──────▼─────┐
│ PostgreSQL │      │   Redis    │
│ (Database) │      │  (Cache)   │
└────────────┘      └────────────┘
```

- **Frontend (`apps/mentra`)**: Flutter cross-platform client (macOS, Windows, Android, iOS) adhering to Material 3 design system.
- **Backend (`backend`)**: FastAPI REST API with structured layered architecture (API routes, Core settings, Database, Models, Schemas, Repositories, Services).
- **CV Engine (`cv-engine`)**: Python-based local computer vision environment (OpenCV, MediaPipe, Ultralytics YOLO) for on-device privacy-preserving attention and behavioral analysis.
- **Infrastructure (`infrastructure/docker`)**: Docker Compose environment providing local PostgreSQL 16 and Redis 7.

---

## Repository Structure

```text
mentra/
├── apps/
│   └── mentra/                 # Flutter application (macOS, Windows, Android, iOS)
│       ├── lib/
│       │   └── main.dart       # Flutter entrypoint
│       └── test/               # Flutter widget tests
│
├── backend/                    # FastAPI REST API
│   ├── app/
│   │   ├── api/v1/             # Versioned API routes and endpoints
│   │   ├── core/               # Configuration and application settings
│   │   ├── db/                 # Database engine and session management
│   │   ├── models/             # SQLAlchemy ORM models
│   │   ├── schemas/            # Pydantic data validation schemas
│   │   ├── repositories/       # Data access layer
│   │   ├── services/           # Business logic layer
│   │   └── main.py             # FastAPI entrypoint (/health endpoint)
│   ├── tests/                  # Backend test suite (pytest)
│   ├── requirements.txt        # Backend dependencies
│   └── Dockerfile              # Backend container definition
│
├── cv-engine/                  # Computer Vision ML engine
│   ├── src/
│   │   ├── camera/             # Video capture & pipeline
│   │   ├── face/               # Face detection & landmark extraction
│   │   ├── eyes/               # Gaze & blink estimation
│   │   ├── attention/          # Attention score calculation
│   │   ├── drowsiness/         # Fatigue detection
│   │   ├── objects/            # Phone & object detection
│   │   └── behavior/           # Behavioral event generation
│   ├── tests/                  # CV environment verification tests
│   └── requirements.txt        # CV engine dependencies
│
├── infrastructure/
│   └── docker/
│       └── docker-compose.yml   # PostgreSQL & Redis services
│
├── docs/                       # Product and technical specifications
│   ├── PRD.md
│   ├── TRD.md
│   ├── UI-UX.md
│   ├── APP-FLOW.md
│   ├── DATABASE-SCHEMA.md
│   └── IMPLEMENTATION-PLAN.md
│
├── scripts/                    # Development automation scripts
├── .env.example                # Environment variables template
├── .gitignore                  # Git ignore rules
├── LICENSE                     # License
└── README.md                   # Project documentation
```

---

## Prerequisites

- **Flutter SDK**: `>= 3.47.0` (Dart `>= 3.13.0`)
- **Python**: `>= 3.11` (or [`uv`](https://github.com/astral-sh/uv) package manager)
- **Docker & Docker Compose**: Docker `>= 24.0`

---

## Local Setup & Quickstart

### 1. Environment Configuration

Copy the sample environment file:

```bash
cp .env.example .env
```

### 2. Start Infrastructure (PostgreSQL & Redis)

Start development containers in background:

```bash
docker compose -f infrastructure/docker/docker-compose.yml up -d
```

To stop containers:

```bash
docker compose -f infrastructure/docker/docker-compose.yml down
```

### 3. Backend Setup (FastAPI)

```bash
cd backend

# Create virtual environment and install dependencies
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -r requirements.txt

# Run tests
pytest

# Start development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verify backend health:
```bash
curl http://127.0.0.1:8000/health
```

API documentation:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

### 4. CV Engine Setup

```bash
cd cv-engine

# Create virtual environment and install dependencies
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -r requirements.txt

# Run import and environment tests
pytest
```

### 5. Flutter Client Setup

```bash
cd apps/mentra

# Fetch dependencies
flutter pub get

# Run tests
flutter test

# Run application (select your preferred target device)
flutter run
```

---

## Milestone Roadmap

| Milestone | Description | Status |
| :--- | :--- | :--- |
| **M0** | **Project Foundation (Monorepo, Flutter, FastAPI, CV Env, Docker)** | **Completed** |
| **M1** | Database Models, Migrations & Auth Service | Upcoming |
| **M2** | Subjects, Topics & Study Session Workspace | Upcoming |
| **M3** | On-Device CV Engine & Telemetry Pipeline | Upcoming |
| **M4** | Focus Scoring, Event Aggregation & Real-Time Feedback | Upcoming |
| **M5** | Analytics Dashboard & Learning Pattern Visualizations | Upcoming |
| **M6** | AI Study Coach Insights & Personalized Recommendations | Upcoming |
| **M7** | End-to-End Hardening, Privacy Verification & Release Packaging | Upcoming |

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
