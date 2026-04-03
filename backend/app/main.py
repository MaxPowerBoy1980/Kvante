import logging
import os
import socket
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine
from app.routers import assignments, feedback, health, pages, submissions

from app.logging_config import setup_logging

setup_logging(log_level=settings.log_level, log_dir=settings.log_dir)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create tables, register Bonjour. Shutdown: unregister."""
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created")
    logger.info(
        "Kvante starting: port=%d, ai_provider=%s, log_level=%s",
        settings.port,
        settings.ai_provider,
        settings.log_level,
    )

    from sqlalchemy.orm import Session as DBSession
    from app.models.db import Student
    with DBSession(engine) as db:
        if not db.query(Student).filter(Student.id == "default").first():
            db.add(Student(id="default", name="Default Student", language="da"))
            db.commit()
            logger.info("Created default student")

    aiozc = None
    if not os.environ.get("KVANTE_TESTING"):
        try:
            from zeroconf import IPVersion, ServiceInfo
            from zeroconf.asyncio import AsyncZeroconf

            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            info = ServiceInfo(
                "_kvante._tcp.local.",
                f"Kvante Math Assistant._kvante._tcp.local.",
                addresses=[socket.inet_aton(local_ip)],
                port=settings.port,
                properties={"version": "0.1.0"},
            )
            aiozc = AsyncZeroconf(
                interfaces=[local_ip], ip_version=IPVersion.V4Only
            )
            await aiozc.async_register_service(info, cooperating_responders=True)
            logger.info("Bonjour service registered: _kvante._tcp on %s:%d", local_ip, settings.port)
        except Exception as e:
            logger.warning("Bonjour registration failed (non-fatal): %s", e)

    yield

    if aiozc:
        await aiozc.async_unregister_all_services()
        await aiozc.async_close()
        logger.info("Bonjour service unregistered")
    logger.info("Kvante shutting down")


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
