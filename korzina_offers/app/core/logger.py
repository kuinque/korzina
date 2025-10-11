"""
Система логирования
"""
import logging
import sys
from typing import Optional
from app.config import config


def setup_logging() -> None:
    """Настройка системы логирования"""
    
    # Формат логов
    formatter = logging.Formatter(config.LOG_FORMAT)
    
    # Обработчик для консоли
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    
    # Корневой логгер
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, config.LOG_LEVEL.upper()))
    root_logger.addHandler(console_handler)
    
    # Отключаем логи от внешних библиотек в продакшене
    if config.is_production:
        logging.getLogger('werkzeug').setLevel(logging.WARNING)
        logging.getLogger('urllib3').setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Получить логгер для модуля"""
    return logging.getLogger(name)


# Инициализация логирования при импорте модуля
setup_logging()
