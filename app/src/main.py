"""Notes API: a small web service used to demonstrate private-network deployment on Azure."""

import logging
import os
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, Integer, String, create_engine, select, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("notes-api")

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./local.db")
APP_VERSION = os.getenv("APP_VERSION", "dev")
DEPLOY_ENV = os.getenv("DEPLOY_ENV", "local")

engine = create_engine(DATABASE_URL, pool_pre_ping=True)


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    text: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))


class NoteIn(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class NoteOut(BaseModel):
    id: int
    text: str
    created_at: datetime


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        Base.metadata.create_all(engine)
        log.info("database schema ready")
    except Exception:  # keep the process alive; /readyz reports the failure
        log.exception("could not initialize database schema")
    yield


app = FastAPI(title="Notes API", version=APP_VERSION, lifespan=lifespan)


@app.get("/")
def info():
    return {"service": "notes-api", "version": APP_VERSION, "environment": DEPLOY_ENV}


@app.get("/healthz")
def liveness():
    """Liveness: the process is up. Never touches dependencies."""
    return {"status": "ok"}


@app.get("/readyz")
def readiness():
    """Readiness: the app can reach its database."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as exc:
        log.warning("readiness check failed: %s", exc)
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "ready"}


@app.get("/api/notes", response_model=list[NoteOut])
def list_notes(limit: int = 50):
    with Session(engine) as s:
        rows = s.scalars(select(Note).order_by(Note.id.desc()).limit(min(limit, 200))).all()
        return [NoteOut(id=r.id, text=r.text, created_at=r.created_at) for r in rows]


@app.post("/api/notes", response_model=NoteOut, status_code=201)
def create_note(body: NoteIn):
    with Session(engine) as s:
        note = Note(text=body.text)
        s.add(note)
        s.commit()
        s.refresh(note)
        return NoteOut(id=note.id, text=note.text, created_at=note.created_at)
