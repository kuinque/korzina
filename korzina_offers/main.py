"""
Точка входа в приложение Korzina Offers API
"""
import uvicorn
from app.api import create_app
from app.config import config
from app.core.logger import get_logger

logger = get_logger(__name__)

# Создаем приложение для production (Gunicorn/Uvicorn)
app = create_app()

if __name__ == "__main__":
    try:
        logger.info(f"Starting Korzina Offers API on {config.HOST}:{config.PORT}")
        logger.info(f"Environment: {config.APP_ENV}")
        logger.info(f"Debug mode: {config.DEBUG}")
        logger.info(f"Docs available at: http://{config.HOST}:{config.PORT}/docs")
        
        uvicorn.run(
            "main:app",
            host=config.HOST,
            port=config.PORT,
            reload=config.DEBUG,
            log_level=config.LOG_LEVEL.lower()
        )
        
    except Exception as e:
        logger.error(f"Failed to start application: {e}")
        raise