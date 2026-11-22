from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_db
from app.errors import install_error_handlers
from app.routers import auth

app = FastAPI(title="InIBA API", version="0.1.0")
install_error_handlers(app)
# Lets the Flutter app run in Chrome (flutter run -d chrome) call the API on localhost.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)


@app.get("/health")
def health(db: Session = Depends(get_db)) -> dict[str, str]:
    """Liveness plus a database round-trip. Used by hosting health checks and CI."""
    db.execute(text("SELECT 1"))
    return {"status": "ok"}


# Feature routers are added per sprint (see docs/api-doc.pdf):
#   auth (E1), students/profile (E3), feed/posts/moments (E4), search+filter (E2), admin (E5)
