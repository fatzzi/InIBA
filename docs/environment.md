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

## Shared database and public API (SCRUM-76)

Running the steps above gives each developer a **private** sandbox: their own database and `backend/media/`
folder. The real app works differently: every user's phone talks to **one hosted backend**, which reads and
writes one shared database and one image bucket. A post uploaded by anyone is in everyone's `GET /feed` on
their next refresh.

```
 every user's app ──HTTPS──> iniba-api (Render) ──> Supabase Postgres  (users, posts, profiles, reactions)
                                                └──> Supabase Storage  "media" bucket (photos, public URLs)
```

Users never get any keys: the database URL and storage key exist only in the Render dashboard.

### One-time setup (one person)

1. **Database + images:** create a free project at supabase.com (region near Karachi, e.g. Mumbai). Save the
   database password. Storage > New bucket > `media`, tick **Public bucket**.
2. **Email:** pick an SMTP sender for OTP emails (a Gmail account with an App Password, or Brevo's free relay).
3. **API:** on render.com, New > Blueprint > this repo. `render.yaml` creates `iniba-api`; fill in the values it
   asks for (`DATABASE_URL` = Supabase > Connect > **Session pooler** URI with `postgresql://` changed to
   `postgresql+psycopg://`, the Supabase URL and `service_role` key, the SMTP details). `JWT_SECRET` is generated.
4. Deploy. The container runs `alembic upgrade head` on every start, so the schema is created and kept current.
   Check `https://<your-service>.onrender.com/health`.
5. Optional sample data: run `python -m scripts.seed` once from a laptop whose `.env` points at the Supabase
   `DATABASE_URL` (the seed is idempotent).

With `ENVIRONMENT=production` the API **refuses to start** if the JWT secret is weak, the database is SQLite,
images would go to the container's disk (wiped on every redeploy), or SMTP is missing; the log names the problem.

### Pointing the app at it

```bash
flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com
flutter build apk --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com
```

Share the APK (or later publish it); anyone with an `@khi.iba.edu.pk` email can sign up and sees the same feed.

### Rules

- Develop against your local Docker database. Point a laptop at the real `DATABASE_URL` only to debug live data,
  and never run `alembic downgrade` against it.
- New migrations reach production by merging to `main`: Render redeploys and migrates automatically.
- Render's free plan sleeps after ~15 min idle, so the first request afterwards takes ~30-50 s. Upgrade the plan
  before a public launch or the demo.
- Supabase's free plan pauses a project after a week with no activity; open the dashboard to resume it.

## Mobile

```bash
cd mobile
flutter pub get
flutter run
```

## Hosting (free tier)

| Part | Service | Notes |
|---|---|---|
| API | Render (`render.yaml`) | Deploys `backend/Dockerfile`. It runs `alembic upgrade head` on start. |
| Database | Supabase Postgres | Set `DATABASE_URL` to the Session pooler URI with `postgresql+psycopg://` |
| Images | Supabase Storage | `IMAGE_STORE=supabase`, public bucket `media` |

All secrets are service environment variables (see "Shared database and public API" above). Never commit them.
