# Contributing

## Branches

| Branch | Purpose |
|---|---|
| `main` | Protected, always demo-ready. Changes land only through a reviewed pull request. |
| `feature/SCRUM-N-short-description` | One branch per Jira story, cut from `main` (e.g. `feature/SCRUM-19-register`, `feature/SCRUM-73-74-camera`). |
| `fix/…`, `chore/…`, `docs/…` | Bug fixes, CI/tooling and documentation. Add the Jira key when there is one (e.g. `fix/SCRUM-31-otp-expiry`). |

Branch names are lowercase words joined by hyphens. The `PR rules` check rejects anything else.

## Workflow

1. Pick a story in Jira (project SCRUM) and move it to In Progress.
2. `git checkout main && git pull && git checkout -b feature/SCRUM-19-register`
3. Commit small and often. Start the message with the story key: `SCRUM-19: validate IBA email domain`.
4. Push the branch and open a pull request into `main`. The template fills in automatically.
5. Get at least one teammate's approval and a green CI.
6. Squash-merge, delete the branch, and move the story to Done.

## What GitHub enforces on `main`

Defined in [`.github/rulesets/protect-main.json`](.github/rulesets/protect-main.json):

- No direct pushes: every change needs a pull request.
- At least **1 approving review** from a teammate.
- Required checks: `backend` and `mobile` (CI) and `PR rules` (branch name, target branch, Jira key).
- No force-pushes and no deleting `main`.

A repo admin applies it once: **Settings → Rules → Rulesets → New ruleset → Import a ruleset**, then pick `protect-main.json`. Rulesets on a private repository need GitHub Pro or Team (free with the GitHub Student Developer Pack); on a public repo they're free.

Optional local guard so you never push to `main` by accident:

```bash
git config core.hooksPath .githooks
```

## Reviewing

- Pull the branch and run it, or at least run the tests, before approving.
- Comment on specifics; use "Request changes" only for things that must be fixed before merge.
- The author merges once approved, not the reviewer.

## Rules

- Never commit secrets. Copy `backend/.env.example` to `backend/.env` and keep it local.
- Database changes go through an Alembic migration (`alembic revision --autogenerate -m "..."`), never by editing tables by hand.
- Backend code lives in `backend/`, the Flutter app in `mobile/`, documents in `docs/`.
