import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.database import close_db, connect_db, get_db
from app.routers import api_router
from app.services.booking_service import BookingService

logger = logging.getLogger(__name__)


async def _expire_no_shows_loop() -> None:
    while True:
        try:
            await BookingService(get_db()).expire_no_shows()
        except Exception:
            logger.exception("Failed to expire no-show bookings")
        await asyncio.sleep(60)


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
    await connect_db()
    task = asyncio.create_task(_expire_no_shows_loop())
    yield
    task.cancel()
    await close_db()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Emad CRM — Sales Center",
        description="Residential complex sales center management API",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(api_router)
    app.mount(
        "/uploads",
        StaticFiles(directory=settings.upload_dir),
        name="uploads",
    )

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return app


app = create_app()
