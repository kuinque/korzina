"""
Менеджер кэша для хранения данных в памяти
"""
from typing import List, Dict, Any, Optional
from datetime import datetime
from threading import Lock
from supabase import Client
from app.core.logger import get_logger

logger = get_logger(__name__)


class CacheManager:
    """Менеджер кэша для хранения данных в памяти"""
    
    def __init__(self, db_client: Client):
        """
        Инициализация кэш-менеджера
        
        Args:
            db_client: Клиент Supabase для загрузки данных
        """
        self.db_client = db_client
        self._lock = Lock()
        
        # Кэшированные данные
        self._all_offers: List[Dict[str, Any]] = []
        self._offers_by_seller: Dict[str, List[Dict[str, Any]]] = {}
        self._unique_sellers: List[str] = []
        self._seller_info: Dict[str, Dict[str, Any]] = {}
        
        # Метаданные кэша
        self._last_update: Optional[datetime] = None
        self._is_loaded = False
        
        logger.info("CacheManager initialized")
    
    def load_all_data(self) -> bool:
        """
        Загрузить все данные из БД в кэш
        
        Returns:
            True если загрузка успешна, False в противном случае
        """
        try:
            logger.info("Loading all data into cache...")
            
            # Загружаем все офферы
            result = self.db_client.table("offers").select("*").execute()
            all_offers = result.data or []
            
            with self._lock:
                # Сохраняем все офферы
                self._all_offers = all_offers
                
                # Группируем по продавцам
                self._offers_by_seller = {}
                self._seller_info = {}
                sellers_set = set()
                
                for offer in all_offers:
                    seller_name = offer.get("seller_name")
                    if seller_name:
                        sellers_set.add(seller_name)
                        
                        # Группируем офферы по продавцам
                        if seller_name not in self._offers_by_seller:
                            self._offers_by_seller[seller_name] = []
                        self._offers_by_seller[seller_name].append(offer)
                        
                        # Сохраняем информацию о продавце (первый оффер)
                        if seller_name not in self._seller_info:
                            self._seller_info[seller_name] = {
                                "name": seller_name,
                                "id": seller_name
                            }
                
                # Сохраняем уникальных продавцов
                self._unique_sellers = sorted(list(sellers_set))
                
                # Обновляем метаданные
                self._last_update = datetime.now()
                self._is_loaded = True
            
            logger.info(
                f"Cache loaded successfully: {len(all_offers)} offers, "
                f"{len(self._unique_sellers)} sellers"
            )
            return True
            
        except Exception as e:
            logger.error(f"Error loading data into cache: {e}")
            return False
    
    def get_all_offers(self) -> List[Dict[str, Any]]:
        """
        Получить все офферы из кэша
        
        Returns:
            Список всех офферов
        """
        with self._lock:
            if not self._is_loaded:
                logger.warning("Cache not loaded, attempting to load...")
                self.load_all_data()
            return self._all_offers.copy()
    
    def get_offers_by_seller(self, seller_name: str) -> List[Dict[str, Any]]:
        """
        Получить офферы конкретного продавца из кэша
        
        Args:
            seller_name: Имя продавца
            
        Returns:
            Список офферов продавца
        """
        with self._lock:
            if not self._is_loaded:
                logger.warning("Cache not loaded, attempting to load...")
                self.load_all_data()
            return self._offers_by_seller.get(seller_name, []).copy()
    
    def get_unique_sellers(self) -> List[str]:
        """
        Получить список уникальных продавцов из кэша
        
        Returns:
            Список уникальных продавцов
        """
        with self._lock:
            if not self._is_loaded:
                logger.warning("Cache not loaded, attempting to load...")
                self.load_all_data()
            return self._unique_sellers.copy()
    
    def get_seller_info(self, seller_name: str) -> Optional[Dict[str, Any]]:
        """
        Получить информацию о продавце из кэша
        
        Args:
            seller_name: Имя продавца
            
        Returns:
            Информация о продавце или None
        """
        with self._lock:
            if not self._is_loaded:
                logger.warning("Cache not loaded, attempting to load...")
                self.load_all_data()
            return self._seller_info.get(seller_name)
    
    def health_check(self) -> bool:
        """
        Проверка подключения к базе данных (минимальный запрос)
        
        Returns:
            True если подключение работает
        """
        try:
            self.db_client.table("offers").select("offer_id").limit(1).execute()
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False
    
    def refresh_cache(self) -> bool:
        """
        Обновить кэш (перезагрузить данные из БД)
        
        Returns:
            True если обновление успешно
        """
        logger.info("Refreshing cache...")
        return self.load_all_data()
    
    def get_cache_info(self) -> Dict[str, Any]:
        """
        Получить информацию о состоянии кэша
        
        Returns:
            Словарь с информацией о кэше
        """
        with self._lock:
            return {
                "is_loaded": self._is_loaded,
                "last_update": self._last_update.isoformat() if self._last_update else None,
                "offers_count": len(self._all_offers),
                "sellers_count": len(self._unique_sellers),
                "cache_age_seconds": (
                    (datetime.now() - self._last_update).total_seconds()
                    if self._last_update else None
                )
            }

