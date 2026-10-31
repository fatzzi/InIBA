# InIBA

An IBA-exclusive, BeReal-inspired mobile app that gives verified students one place for low-pressure social content and structured campus updates.

> Status: Sprint 0 (project setup). Repo, backend skeleton, database schema and environment are in place; feature work starts in Sprint 1.

## Core Features

- **Login / Authentication**: sign up with an `@khi.iba.edu.pk` email, OTP email verification, login/logout via JWT
- **Search & Filter**: look up students by name/batch; filter the feed by campus, batch, department, or society
- **User Profile**: view and edit profile photo, mood sticker, bio, badges, and streak
- **Content Creation**: daily "IBA Moment" dual-camera photo post (BeReal-style, on a randomly-timed push notification with a 2-minute window) or a short text post, with optional location tagging, reactions/comments, and reporting

## Milestones

Dates come from the course project guidelines. Work is tracked in Jira (project SCRUM); each milestone below maps to a sprint.

| # | Milestone | Dates | Goal |
|---|---|---|---|
| 0 | **Sprint Zero** | 30 Oct – **8 Nov** | Set up Jira, Git, database and environment. Wireframes complete. |
| 1 | **Sprint 1** | 9 – **19 Nov** | Working sign up / OTP / login, feed, student search and profile basics, ready for the interim review. |
| - | **Interim project review** | **19 Nov** | Demo what Sprint 1 delivered. |
| 2 | **Sprint 2** | 20 Nov – **3 Dec** | IBA Moment (dual camera, countdown, push), feed filters, reactions, reporting and admin review. |
| 3 | **Sprint 3** | 4 – **10 Dec** | Comments, highlights, polish, bug bash and demo preparation. |
| - | **Final presentation and demo** | **8 / 10 Dec** | Working demo of all four core features. |
| - | **Final submission** | **20 Dec** | Backlog, 2+ complete sprints, wireframes, specs, ERD, architecture, API doc and all code. |

### Milestone 0: Sprint Zero (due 8 Nov)
- [x] Jira project, product backlog and estimates
- [x] Git repository, branching rules, PR template and CI
- [x] Backend skeleton, database schema and migration, seed script
- [x] ERD and environment guide
- [x] Wireframes drafted in Figma (39 screens)
- [ ] Wireframes exported to PDF for submission
- [ ] Sprint 1 created in Jira with dates and stories (not started)
- [ ] Jira board shared with the instructor and TA
- [ ] All four teammates have cloned the repo and run the backend locally

### Milestone 1: Sprint 1 (9 to 19 Nov)
- [ ] Sign up with `@khi.iba.edu.pk` email and OTP verification (API and screens)
- [ ] Log in, log out, and JWT session check on app launch
- [ ] Shared JWT/ownership checks available to every endpoint
- [ ] Main feed and posts API with the feed screen
- [ ] Student search (API and screen)
- [ ] Profile view (API and screen)
- [ ] Backend deployed and reachable over HTTPS

### Milestone 2: Sprint 2 (20 Nov to 3 Dec)
- [ ] Daily IBA Moment scheduler and push notification
- [ ] Dual-camera capture flow with the 2-minute countdown
- [ ] Post composer with caption, campus-zone tag and text posts
- [ ] Combinable feed filters (zone, department, society, batch) with empty states
- [ ] Edit profile with 1:1 photo crop, timeline
- [ ] Emoji reactions
- [ ] NSFW image screening, post reporting, admin review queue and decision

### Milestone 3: Sprint 3 (4 to 10 Dec)
- [ ] Comments, highlights, streak and tags
- [ ] Test cases executed, security review and bug bash
- [ ] Demo build and rehearsal

### Final submission (20 Dec)
- [ ] Product backlog and 2+ completed sprints in Jira
- [ ] Wireframes, specifications, ERD, architecture document, API doc
- [ ] All backend and frontend code

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
