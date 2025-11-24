"""
Создание и настройка FastAPI приложения
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import config
from app.api.routes import router
from app.database.client import cache_manager
from app.core.logger import get_logger

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifecycle events для приложения
    - При старте: загружаем данные в кэш
    - При остановке: очистка ресурсов (если нужно)
    """
    # Startup: загружаем данные в кэш
    logger.info("Starting application... Loading data into cache...")
    success = cache_manager.refresh_cache()
    if success:
        cache_info = cache_manager.get_cache_info()
        logger.info(
            f"Cache loaded successfully: {cache_info['offers_count']} offers, "
            f"{cache_info['sellers_count']} sellers"
        )
    else:
        logger.warning("Failed to load cache on startup. Cache will be loaded on first request.")
    
    yield
    
    # Shutdown: очистка ресурсов (если нужно)
    logger.info("Shutting down application...")


def create_app() -> FastAPI:
    """Создать и настроить FastAPI приложение"""
    
    app = FastAPI(
        title=config.API_TITLE,
        description=config.API_DESCRIPTION,
        version=config.API_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan
    )
    
    # Настройка CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Регистрируем роутер
    app.include_router(router)
    
    logger.info("FastAPI app created successfully")
    return app
