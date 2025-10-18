"""
Конфигурация приложения
"""
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator


class Config(BaseSettings):
    """Основная конфигурация приложения"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # Application настройки
    APP_ENV: str = "development"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 5000
    
    # Supabase настройки
    SUPABASE_URL: str
    SUPABASE_KEY: str
    
    # Логирование
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # API настройки
    API_VERSION: str = "v1"
    API_TITLE: str = "Korzina Offers API"
    API_DESCRIPTION: str = "Микросервис для поиска товаров в магазинах с интеллектуальным алгоритмом сопоставления"
    CORS_ORIGINS: str = "*"
    
    # Бизнес логика
    PENALTY_PRICE: float = 1000.0
    MIN_SIMILARITY_THRESHOLD: float = 0.6
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Получить список CORS origins"""
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(',')]
    
    @property
    def is_production(self) -> bool:
        """Проверка на продакшн окружение"""
        return self.APP_ENV.lower() == 'production'


# Глобальный экземпляр конфигурации
config = Config()
