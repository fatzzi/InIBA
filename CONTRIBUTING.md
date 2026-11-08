# Contributing

## Branches

| Branch | Purpose |
|---|---|
| `main` | Always demo-ready. Only updated by merging `dev` at the end of a sprint. |
| `dev` | Integration branch. Every feature PR targets this. |
| `sprint-N/short-description` | One branch per Jira story, cut from `dev` (e.g. `sprint-1/auth-register`). |

## Workflow

1. Pick a story in Jira (project SCRUM) and move it to In Progress.
2. `git checkout dev && git pull && git checkout -b sprint-1/auth-register`
3. Commit small and often. Start the message with the story key: `SCRUM-19: validate IBA email domain`.
4. Open a pull request into `dev` using the template. At least one teammate must review.
5. Squash-merge once CI is green, then move the story to Done.

## Rules

- Never commit directly to `main` or `dev`.
- Never commit secrets. Copy `backend/.env.example` to `backend/.env` and keep it local.
- Database changes go through an Alembic migration (`alembic revision --autogenerate -m "..."`), never by editing tables by hand.
- Backend code lives in `backend/`, the Flutter app in `mobile/`, documents in `docs/`.
