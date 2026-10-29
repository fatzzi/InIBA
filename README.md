# InIBA

An IBA-exclusive, BeReal-inspired mobile app that gives verified students one place for low-pressure social content and structured campus updates.

> Status: Sprint 0 (project setup). Repo, backend skeleton, database schema and environment are in place; feature work starts in Sprint 1.

## Core Features

- **Login / Authentication**: sign up with an `@khi.iba.edu.pk` email, OTP email verification, login/logout via JWT
- **Search & Filter**: look up students by name/batch; filter the feed by campus, batch, department, or society
- **User Profile**: view and edit profile photo, mood sticker, bio, badges, and streak
- **Content Creation**: daily "IBA Moment" dual-camera photo post (BeReal-style, on a randomly-timed push notification with a 2-minute window) or a short text post, with optional location tagging, reactions/comments, and reporting

## Repo layout

| Path | What |
|---|---|
| `mobile/` | Flutter app (Android 8.0+, iOS 13+) |
| `backend/` | FastAPI + SQLAlchemy + Alembic API |
| `docs/` | Proposal, use-case view, class model, ERD, API doc, test strategy, wireframes |
| `docker-compose.yml` | Local PostgreSQL |
| `.github/` | CI workflow and pull request template |

## Quick start

```bash
docker compose up -d db
cd backend && python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt && cp .env.example .env
alembic upgrade head && uvicorn app.main:app --reload     # http://localhost:8000/health
cd ../mobile && flutter pub get && flutter run
```

Full steps and hosting notes: [`docs/environment.md`](docs/environment.md). Branching and PR rules: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Documentation

- [`docs/use-case-view.pdf`](docs/use-case-view.pdf): actors, use-case diagram, descriptions, class diagram
- [`docs/erd.md`](docs/erd.md): entity relationship diagram (matches the Alembic migration)
- [`docs/api-doc.pdf`](docs/api-doc.pdf): REST API reference
- [`docs/test-strategy.pdf`](docs/test-strategy.pdf): test approach, environments, risks
- [`docs/class-model.md`](docs/class-model.md), [`docs/tech-stack.md`](docs/tech-stack.md), [`docs/project-proposal.docx`](docs/project-proposal.docx)
- [`docs/wireframes/`](docs/wireframes/): wireframes (PDF added for the Sprint 0 submission)

## Tech stack

| Layer | Choice |
|---|---|
| Platform | Flutter (single codebase for iOS + Android) |
| State management | Riverpod |
| Backend | Python, FastAPI |
| ORM / migrations | SQLAlchemy 2.0, Alembic |
| Auth | bcrypt for password hashing, PyJWT for tokens, IBA email domain restriction + OTP |
| Database | PostgreSQL (Supabase / Railway free tier); SQLite for tests |

## Team

Markzingerburger: Oliya Sirhindi, Nawail Khan, Zunaira Faheem, Fatima Kaleem
