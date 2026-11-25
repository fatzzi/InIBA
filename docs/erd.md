# Entity Relationship Diagram

Source of truth for the database. Implemented in `backend/app/models.py` and the Alembic migration `0001_initial_schema`.

```mermaid
erDiagram
    STUDENTS ||--o{ POSTS : writes
    STUDENTS ||--o{ REACTIONS : gives
    STUDENTS ||--o{ COMMENTS : writes
    STUDENTS ||--o{ REPORTS : files
    STUDENTS ||--o{ HIGHLIGHTS : owns
    STUDENTS ||--o{ OTP_CODES : receives
    STUDENTS ||--o{ DEVICE_TOKENS : registers
    STUDENTS ||--o| SPOTTED_AT : has
    STUDENTS ||--o{ MOMENT_WINDOWS : gets
    STUDENTS }o--o{ SOCIETIES : "joins (student_societies)"
    LOCATION_TAGS ||--o{ POSTS : tags
    LOCATION_TAGS ||--o{ SPOTTED_AT : "current zone"
    POSTS ||--o{ REACTIONS : receives
    POSTS ||--o{ COMMENTS : has
    POSTS ||--o{ REPORTS : "reported in"
    POSTS }o--o{ HIGHLIGHTS : "grouped in (highlight_posts)"

    STUDENTS {
        int id PK
        string email UK
        string password_hash
        string name
        string batch
        string department
        string bio
        string profile_photo
        string mood_sticker
        string role "student | admin"
        bool is_verified
        bool is_suspended
        int streak_count
        datetime created_at
    }
    POSTS {
        int id PK
        int author_id FK
        text content
        string image_front
        string image_back
        int location_tag_id FK
        bool is_moment
        bool is_removed
        datetime created_at
    }
    REACTIONS {
        int id PK
        int post_id FK
        int student_id FK
        string kind "heart fire laugh wow sad clap"
    }
    COMMENTS {
        int id PK
        int post_id FK
        int author_id FK
        string text
        datetime created_at
    }
    REPORTS {
        int id PK
        int reporter_id FK
        int post_id FK
        int reported_student_id FK
        string reason
        string status "open | ignored | removed"
        int decided_by FK
        datetime decided_at
    }
    LOCATION_TAGS {
        int id PK
        string zone_name UK
    }
    HIGHLIGHTS {
        int id PK
        int owner_id FK
        string title
        string cover_url
    }
    SPOTTED_AT {
        int id PK
        int student_id FK
        int location_tag_id FK
        datetime updated_at
    }
    OTP_CODES {
        int id PK
        int student_id FK
        string code_hash
        datetime expires_at
        int attempts
    }
    DEVICE_TOKENS {
        int id PK
        int student_id FK
        string token UK
        string platform
    }
    SOCIETIES {
        int id PK
        string name UK
    }
    MOMENT_WINDOWS {
        int id PK
        int student_id FK
        date day
        datetime opens_at
        datetime closes_at
    }
```

## Constraints worth knowing

- One reaction per student per post: unique `(post_id, student_id)`.
- One report per reporter per post, and per reporter per reported student (API returns 409 on a duplicate).
- `MOMENT_WINDOWS` holds each student's own random daily IBA Moment time and its 2-minute close (API `GET /moments/current`): unique `(student_id, day)`.
- OTP codes are stored hashed and expire; `attempts` supports the 429 rate limit.
