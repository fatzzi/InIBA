# InIBA

An IBA-exclusive, BeReal-inspired mobile app that gives verified students one place for low-pressure social content and structured campus updates.

> Status: early design phase — this repo currently holds specifications and design docs. Implementation has not started yet.

## Core Features

- **Login / Authentication** — sign up with an `@khi.iba.edu.pk` email, OTP email verification, login/logout via JWT
- **Search & Filter** — look up students by name/batch; filter the feed by campus, batch, department, or society
- **User Profile** — view and edit profile photo, mood sticker, bio, badges, and streak
- **Content Creation** — daily "IBA Moment" dual-camera photo post (BeReal-style, on a randomly-timed push notification with a 2-minute window) or a short text post, with optional location tagging, reactions/comments, and reporting

## Documentation

- [`docs/use-case-view.pdf`](docs/use-case-view.pdf) — actors, use-case diagram, detailed use-case descriptions, and system class diagram
- [`docs/tech-stack.md`](docs/tech-stack.md) — planned platform and technology choices

## Planned Tech Stack

| Layer | Choice |
|---|---|
| Platform | Flutter (single codebase for iOS + Android) |
| Frontend | Flutter (Dart), Provider/Riverpod for state management |
| Backend | Python, FastAPI |
| ORM | SQLAlchemy |
| Auth | passlib[bcrypt] for password hashing, PyJWT for tokens, IBA email domain restriction + OTP |
| Database | PostgreSQL (Supabase / Railway free tier) |

See [`docs/tech-stack.md`](docs/tech-stack.md) for full detail.

## Team

Markzingerburger
