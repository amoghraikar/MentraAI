# Mentra Database Schema (PostgreSQL)

This document details the PostgreSQL relational schema implemented for the Mentra AI Study Coach backend.

```
                    ┌─────────────────────────┐
                    │          USERS          │
                    ├─────────────────────────┤
                    │ id (PK, UUID String)    │
                    │ email (Unique)          │
                    │ full_name               │
                    │ hashed_password         │
                    │ is_active               │
                    │ created_at, updated_at  │
                    └────────────┬────────────┘
                                 │
     ┌───────────────────────────┼───────────────────────────┬───────────────────────────┐
     │ 1:N                       │ 1:N                       │ 1:N                       │ 1:N
     ▼                           ▼                           ▼                           ▼
┌──────────────┐          ┌──────────────┐          ┌──────────────┐          ┌───────────────────────┐
│   SUBJECTS   │          │    NOTES     │          │    GOALS     │          │    STUDY_SESSIONS     │
├──────────────┤          ├──────────────┤          ├──────────────┤          ├───────────────────────┤
│ id (PK)      │          │ id (PK)      │          │ id (PK)      │          │ id (PK)               │
│ user_id (FK) │◄──┐      │ user_id (FK) │          │ user_id (FK) │          │ user_id (FK)          │
│ title        │   │      │ subject_id   │          │ subject_id   │          │ subject_id (FK)       │
│ code         │   │      │ topic_id (FK)│          │ title        │          │ topic_id (FK, Null)   │
│ description  │   │      │ title        │          │ target_date  │          │ target_duration_mins  │
│ color_hex    │   │      │ content      │          │ is_completed │          │ actual_duration_mins  │
│ total_hours  │   │      │ tags (JSON)  │          │ created_at   │          │ study_mode            │
│ target_hours │   │      │ created_at   │          │ updated_at   │          │ is_focus_monitoring   │
│ created_at   │   │      │ updated_at   │          └──────┬───────┘          │ focus_score (0-100)   │
│ updated_at   │   │      └──────────────┘                 │ 1:N                  │ distractions_count    │
└──────┬───────┘   │                                       ▼                      │ reflection            │
       │ 1:N       │                               ┌────────────────┐             │ started_at            │
       ▼           │                               │ GOAL_MILESTONES│             │ ended_at              │
┌──────────────┐   │                               ├────────────────┤             │ created_at            │
│    TOPICS    │   │                               │ id (PK)        │             └───────────────────────┘
├──────────────┤   │                               │ goal_id (FK)   │
│ id (PK)      │   │                               │ title          │
│ subject_id   ├───┘                               │ is_completed   │
│ title        │                                   │ created_at     │
│ description  │                                   └────────────────┘
│ progress     │
│ total_minutes│
│ key_concepts │ (JSON Array)
│ notes_snippet│
│ is_completed │
│ created_at   │
│ updated_at   │
└──────────────┘
```

## Tables & Constraints

### 1. `users`
- `id`: VARCHAR(36) PRIMARY KEY
- `email`: VARCHAR(255) UNIQUE NOT NULL (Index)
- `full_name`: VARCHAR(255) NULLABLE
- `hashed_password`: VARCHAR(255) NOT NULL
- `is_active`: BOOLEAN DEFAULT TRUE NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
- `updated_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 2. `subjects`
- `id`: VARCHAR(36) PRIMARY KEY
- `user_id`: VARCHAR(36) FOREIGN KEY (`users.id` ON DELETE CASCADE) (Index)
- `title`: VARCHAR(255) NOT NULL
- `code`: VARCHAR(50) NOT NULL
- `description`: TEXT DEFAULT '' NOT NULL
- `color_hex`: VARCHAR(20) DEFAULT '#4F46E5' NOT NULL
- `total_hours`: FLOAT DEFAULT 0.0 NOT NULL
- `target_hours`: FLOAT DEFAULT 20.0 NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
- `updated_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 3. `topics`
- `id`: VARCHAR(36) PRIMARY KEY
- `subject_id`: VARCHAR(36) FOREIGN KEY (`subjects.id` ON DELETE CASCADE) (Index)
- `title`: VARCHAR(255) NOT NULL
- `description`: TEXT DEFAULT '' NOT NULL
- `progress`: FLOAT DEFAULT 0.0 NOT NULL (0.0 to 1.0)
- `total_minutes`: INTEGER DEFAULT 0 NOT NULL
- `key_concepts`: JSON NOT NULL
- `notes_snippet`: TEXT DEFAULT '' NOT NULL
- `is_completed`: BOOLEAN DEFAULT FALSE NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
- `updated_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 4. `notes`
- `id`: VARCHAR(36) PRIMARY KEY
- `user_id`: VARCHAR(36) FOREIGN KEY (`users.id` ON DELETE CASCADE) (Index)
- `subject_id`: VARCHAR(36) FOREIGN KEY (`subjects.id` ON DELETE CASCADE) (Index)
- `topic_id`: VARCHAR(36) FOREIGN KEY (`topics.id` ON DELETE SET NULL) NULLABLE (Index)
- `title`: VARCHAR(255) NOT NULL
- `content`: TEXT DEFAULT '' NOT NULL
- `tags`: JSON NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
- `updated_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 5. `goals`
- `id`: VARCHAR(36) PRIMARY KEY
- `user_id`: VARCHAR(36) FOREIGN KEY (`users.id` ON DELETE CASCADE) (Index)
- `subject_id`: VARCHAR(36) FOREIGN KEY (`subjects.id` ON DELETE CASCADE) (Index)
- `title`: VARCHAR(255) NOT NULL
- `target_date`: TIMESTAMPTZ NOT NULL
- `is_completed`: BOOLEAN DEFAULT FALSE NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
- `updated_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 6. `goal_milestones`
- `id`: VARCHAR(36) PRIMARY KEY
- `goal_id`: VARCHAR(36) FOREIGN KEY (`goals.id` ON DELETE CASCADE) (Index)
- `title`: VARCHAR(255) NOT NULL
- `is_completed`: BOOLEAN DEFAULT FALSE NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL

### 7. `study_sessions`
- `id`: VARCHAR(36) PRIMARY KEY
- `user_id`: VARCHAR(36) FOREIGN KEY (`users.id` ON DELETE CASCADE) (Index)
- `subject_id`: VARCHAR(36) FOREIGN KEY (`subjects.id` ON DELETE CASCADE) (Index)
- `topic_id`: VARCHAR(36) FOREIGN KEY (`topics.id` ON DELETE SET NULL) NULLABLE (Index)
- `target_duration_minutes`: INTEGER DEFAULT 45 NOT NULL
- `actual_duration_minutes`: INTEGER NOT NULL
- `study_mode`: VARCHAR(50) DEFAULT 'Focus Mode' NOT NULL
- `is_focus_monitoring_enabled`: BOOLEAN DEFAULT TRUE NOT NULL
- `focus_score`: INTEGER DEFAULT 100 NOT NULL (0 to 100)
- `distractions_count`: INTEGER DEFAULT 0 NOT NULL
- `reflection`: VARCHAR(50) DEFAULT 'good' NOT NULL
- `started_at`: TIMESTAMPTZ NOT NULL
- `ended_at`: TIMESTAMPTZ NOT NULL
- `created_at`: TIMESTAMPTZ DEFAULT now() NOT NULL
