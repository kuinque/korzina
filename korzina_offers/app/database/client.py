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
    
    def get_all_offers(self) -> List[Dict[str, Any]]:
        """Получить все предложения из таблицы offers"""
        try:
            result = self.client.table("offers").select("*").execute()
            logger.info(f"Retrieved {len(result.data)} offers")
            return result.data
        except Exception as e:
            logger.error(f"Error getting offers: {e}")
            raise
    
    def get_offers_by_seller(self, seller_name: str) -> List[Dict[str, Any]]:
        """Получить предложения для конкретного продавца"""
        try:
            result = self.client.table("offers").select("*").eq("seller_name", seller_name).execute()
            logger.info(f"Retrieved {len(result.data)} offers for seller '{seller_name}'")
            return result.data
        except Exception as e:
            logger.error(f"Error getting offers for seller '{seller_name}': {e}")
            raise
    
    def get_unique_sellers(self) -> List[str]:
        """Получить список уникальных продавцов"""
        try:
            # Получаем все предложения и извлекаем уникальные имена продавцов
            result = self.client.table("offers").select("seller_name").execute()
            sellers = list(set(offer.get("seller_name") for offer in result.data if offer.get("seller_name")))
            logger.info(f"Retrieved {len(sellers)} unique sellers")
            return sorted(sellers)
        except Exception as e:
            logger.error(f"Error getting unique sellers: {e}")
            raise
    
    def get_seller_info(self, seller_name: str) -> Optional[Dict[str, Any]]:
        """Получить информацию о продавце (первое предложение с этим продавцом)"""
        try:
            result = self.client.table("offers").select("seller_name").eq("seller_name", seller_name).limit(1).execute()
            offers = result.data or []
            logger.info(f"Lookup seller by name '{seller_name}': found {len(offers)}")
            if offers:
                return {"name": seller_name, "id": seller_name}
            return None
        except Exception as e:
            logger.error(f"Error getting seller info '{seller_name}': {e}")
            raise
    
    def health_check(self) -> bool:
        """Проверка подключения к базе данных"""
        try:
            self.client.table("offers").select("offer_id").limit(1).execute()
            logger.info("Database health check passed")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False


# Глобальный экземпляр клиента БД
db_client = DatabaseClient()
