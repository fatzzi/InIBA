from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_db
from app.errors import install_error_handlers

app = FastAPI(title="InIBA API", version="0.1.0")
install_error_handlers(app)


@app.get("/health")
def health(db: Session = Depends(get_db)) -> dict[str, str]:
    """Liveness plus a database round-trip. Used by hosting health checks and CI."""
    db.execute(text("SELECT 1"))
    return {"status": "ok"}


# Feature routers are added per sprint (see docs/api-doc.pdf):
#   auth (E1), students/profile (E3), feed/posts/moments (E4), search+filter (E2), admin (E5)
