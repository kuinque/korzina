"""
Конфигурация приложения
"""
import os
from typing import Optional
from dataclasses import dataclass
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()


@dataclass
class Config:
    """Основная конфигурация приложения"""
    
    # Flask настройки
    FLASK_ENV: str = os.getenv('FLASK_ENV', 'development')
    DEBUG: bool = os.getenv('DEBUG', 'True').lower() == 'true'
    HOST: str = os.getenv('HOST', '0.0.0.0')
    PORT: int = int(os.getenv('PORT', '5000'))
    
    # Supabase настройки
    SUPABASE_URL: str = os.getenv('SUPABASE_URL', '')
    SUPABASE_KEY: str = os.getenv('SUPABASE_KEY', '')
    
    # Логирование
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FORMAT: str = os.getenv('LOG_FORMAT', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    # API настройки
    API_VERSION: str = os.getenv('API_VERSION', 'v1')
    CORS_ORIGINS: str = os.getenv('CORS_ORIGINS', '*')
    
    # Бизнес логика
    PENALTY_PRICE: float = float(os.getenv('PENALTY_PRICE', '1000.0'))
    MIN_SIMILARITY_THRESHOLD: float = float(os.getenv('MIN_SIMILARITY_THRESHOLD', '0.6'))
    
    def __post_init__(self):
        """Валидация конфигурации"""
        if not self.SUPABASE_URL or not self.SUPABASE_KEY:
            raise ValueError("SUPABASE_URL и SUPABASE_KEY должны быть установлены")
    
    @property
    def is_production(self) -> bool:
        """Проверка на продакшн окружение"""
        return self.FLASK_ENV.lower() == 'production'


# Глобальный экземпляр конфигурации
config = Config()
