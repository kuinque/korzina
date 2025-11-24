"""
Слой для работы с базой данных и кэшированием
"""
from supabase import create_client, Client
from app.config import config
from app.core.logger import get_logger
from app.cache import CacheManager

logger = get_logger(__name__)

# Создаем клиент Supabase для кэш-менеджера
_supabase_client: Client = create_client(config.SUPABASE_URL, config.SUPABASE_KEY)

# Глобальный экземпляр кэш-менеджера
cache_manager = CacheManager(_supabase_client)

logger.info("Cache manager initialized")
