"""
Точка входа в приложение Korzina Offers API
"""
from app.api import create_app
from app.config import config
from app.core.logger import get_logger

logger = get_logger(__name__)

if __name__ == "__main__":
    try:
        app = create_app()
        
        logger.info(f"Starting Korzina Offers API on {config.HOST}:{config.PORT}")
        logger.info(f"Environment: {config.FLASK_ENV}")
        logger.info(f"Debug mode: {config.DEBUG}")
        
        app.run(
            host=config.HOST,
            port=config.PORT,
            debug=config.DEBUG
        )
        
    except Exception as e:
        logger.error(f"Failed to start application: {e}")
        raise