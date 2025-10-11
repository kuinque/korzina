"""
Создание и настройка Flask приложения
"""
from flask import Flask
from flask_cors import CORS
from app.config import config
from app.api.controller import APIController
from app.core.logger import get_logger

logger = get_logger(__name__)


def create_app() -> Flask:
    """Создать и настроить Flask приложение"""
    
    app = Flask(__name__)
    
    # Настройка CORS
    cors_origins = config.CORS_ORIGINS.split(',') if config.CORS_ORIGINS != '*' else '*'
    CORS(app, origins=cors_origins)
    
    # Создаем контроллер
    controller = APIController()
    
    # Регистрируем маршруты
    app.add_url_rule('/api/health', 'health_check', controller.health_check, methods=['GET'])
    app.add_url_rule('/api/stats', 'get_stats', controller.get_stats, methods=['GET'])
    app.add_url_rule('/api/search', 'search_products', controller.search_products, methods=['POST'])
    app.add_url_rule('/api/search/get', 'search_products_get', controller.search_products_get, methods=['GET'])
    app.add_url_rule('/api/products', 'get_products', controller.get_products, methods=['GET'])
    
    # Обработчики ошибок
    @app.errorhandler(404)
    def not_found(error):
        return controller._create_error_response("Endpoint not found", 404)
    
    @app.errorhandler(500)
    def internal_error(error):
        return controller._create_error_response("Internal server error", 500)
    
    logger.info("Flask app created successfully")
    return app