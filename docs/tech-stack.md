# Tech Stack

## Platform

Mobile app only, built in **Flutter**, so one codebase ships to both iOS and Android.

## Frontend

- **Flutter (Dart)**: UI, camera capture flow (front + back), profile screens, feed
- **Provider** or **Riverpod** for state management (keep it simple — avoid heavier options like Bloc for a semester project)

## Backend

- **Python with FastAPI**: REST API for auth, posts, profiles, reactions
- **SQLAlchemy** as the ORM — maps Python classes to database tables for structured, secure data manipulation

## Cryptography

- **passlib[bcrypt]** for secure password hashing
- **PyJWT** for access token generation

## Database

- **PostgreSQL**: relational, handles users/posts/reactions relationships cleanly
- Free-tier hosting available on Supabase or Railway

## Auth

- Email/password signup restricted to the IBA email domain (e.g. `@khi.iba.edu.pk`), with an OTP/verification email step
- **JWT tokens** for session handling
