"""
Создание и настройка FastAPI приложения
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import config
from app.api.routes import router
from app.core.logger import get_logger

logger = get_logger(__name__)


def create_app() -> FastAPI:
    """Создать и настроить FastAPI приложение"""
    
    app = FastAPI(
        title=config.API_TITLE,
        description=config.API_DESCRIPTION,
        version=config.API_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json"
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
