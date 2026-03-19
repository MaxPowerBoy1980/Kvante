import logging
import socket
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine
from app.routers import assignments, feedback, health, pages, submissions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create tables, register Bonjour. Shutdown: unregister."""
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created")

    from sqlalchemy.orm import Session as DBSession
    from app.models.db import Student
    with DBSession(engine) as db:
        if not db.query(Student).filter(Student.id == "default").first():
            db.add(Student(id="default", name="Default Student", language="da"))
            db.commit()
            logger.info("Created default student")

    zeroconf = None
    try:
        from zeroconf import ServiceInfo, Zeroconf
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        info = ServiceInfo(
            "_kvante._tcp.local.",
            f"Kvante Math Assistant._kvante._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=settings.port,
            properties={"version": "0.1.0"},
        )
        zeroconf = Zeroconf()
        zeroconf.register_service(info)
        logger.info("Bonjour service registered: _kvante._tcp on port %d", settings.port)
    except Exception as e:
        logger.warning("Bonjour registration failed (non-fatal): %s", e)

    yield

    if zeroconf:
        zeroconf.unregister_all_services()
        zeroconf.close()
        logger.info("Bonjour service unregistered")


app = FastAPI(
    title="Kvante",
    description="Math learning assistant for primary school students",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(pages.router)
app.include_router(assignments.router)
app.include_router(submissions.router)
app.include_router(feedback.router)
