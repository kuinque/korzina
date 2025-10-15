"""
Слой для работы с базой данных
"""
from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from app.config import config
from app.core.logger import get_logger

logger = get_logger(__name__)


class DatabaseClient:
    """Клиент для работы с Supabase"""
    
    def __init__(self):
        self.client: Client = create_client(config.SUPABASE_URL, config.SUPABASE_KEY)
        logger.info("Database client initialized")
    
    def get_all_products(self) -> List[Dict[str, Any]]:
        """Получить все товары"""
        try:
            result = self.client.table("products").select("*").execute()
            logger.info(f"Retrieved {len(result.data)} products")
            return result.data
        except Exception as e:
            logger.error(f"Error getting products: {e}")
            raise
    
    def get_all_prices_with_details(self) -> List[Dict[str, Any]]:
        """Получить все цены с деталями магазинов и товаров"""
        try:
            result = self.client.table("prices").select("*, shops(name), products(name)").execute()
            logger.info(f"Retrieved {len(result.data)} price records")
            return result.data
        except Exception as e:
            logger.error(f"Error getting prices: {e}")
            raise
    
    def get_shops(self) -> List[Dict[str, Any]]:
        """Получить все магазины"""
        try:
            result = self.client.table("shops").select("*").execute()
            logger.info(f"Retrieved {len(result.data)} shops")
            return result.data
        except Exception as e:
            logger.error(f"Error getting shops: {e}")
            raise

    def get_shop_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Получить магазин по имени"""
        try:
            result = self.client.table("shops").select("*").eq("name", name).limit(1).execute()
            shops = result.data or []
            logger.info(f"Lookup shop by name '{name}': found {len(shops)}")
            return shops[0] if shops else None
        except Exception as e:
            logger.error(f"Error getting shop by name '{name}': {e}")
            raise

    def get_prices_for_shop_with_details(self, shop_id: str) -> List[Dict[str, Any]]:
        """Получить цены для магазина с деталями товаров

        Возвращает строки из таблицы prices и вложенные объекты products(name) и shops(name)
        """
        try:
            result = (
                self.client
                .table("prices")
                .select("*, shops(name), products(name)")
                .eq("shop_id", shop_id)
                .execute()
            )
            logger.info(f"Retrieved {len(result.data)} price records for shop {shop_id}")
            return result.data
        except Exception as e:
            logger.error(f"Error getting prices for shop {shop_id}: {e}")
            raise
    
    def health_check(self) -> bool:
        """Проверка подключения к базе данных"""
        try:
            self.client.table("shops").select("id").limit(1).execute()
            logger.info("Database health check passed")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False


# Глобальный экземпляр клиента БД
db_client = DatabaseClient()
