# Environment setup

## Prerequisites

- Git, Python 3.12+, Docker Desktop (for local Postgres), Flutter stable (Dart SDK ^3.13).

## Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # then edit JWT_SECRET
```

Start the database and apply migrations:

```bash
docker compose up -d db         # from the repo root
cd backend
alembic upgrade head
$env:SEED_PASSWORD = "choose-a-dev-password" #12345
python -m scripts.seed
uvicorn app.main:app --reload
```

Open http://localhost:8000/health (returns `{"status":"ok"}`) and http://localhost:8000/docs.

Without Docker, leave `DATABASE_URL` unset and the app falls back to a local SQLite file (`iniba_dev.db`), which is fine for day-to-day work. Postgres is the target for hosting.

Run the tests: `pytest -q` (uses in-memory SQLite, needs no database).

## Mobile

```bash
cd mobile
flutter pub get
flutter run
```

## Hosting (free tier)

| Part | Service | Notes |
|---|---|---|
| API | Render or Railway | Deploy `backend/` using `backend/Dockerfile`. It runs `alembic upgrade head` on start. |
| Database | Supabase or Railway Postgres | Set `DATABASE_URL` to `postgresql+psycopg://...` |
| Images | Firebase Storage or Cloudinary | Story SCRUM-17 |

Set `DATABASE_URL`, `JWT_SECRET` and `ALLOWED_EMAIL_DOMAIN` as service environment variables. Never commit them.
