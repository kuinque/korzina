"""
Сервис для поиска магазинов
"""
from typing import List, Dict, Any, Optional
from app.database.client import db_client
from app.services.product_service import ProductService
from app.models import ShopSolution, ProductMatch, SearchRequest, MatchType
from app.config import config
from app.core.logger import get_logger

logger = get_logger(__name__)


class ShopSearchService:
    """Сервис для поиска оптимального магазина"""
    
    def __init__(self):
        self.product_service = ProductService()
    
    def find_cheapest_shop(self, search_request: SearchRequest) -> Optional[ShopSolution]:
        """
        Найти самый дешевый магазин для списка товаров
        
        Args:
            search_request: Запрос с списком товаров
            
        Returns:
            ShopSolution или None если не найдено подходящих магазинов
        """
        logger.info(f"Starting search for products: {', '.join(search_request.products)}")
        
        try:
            # Получаем данные из БД
            all_products = db_client.get_all_products()
            all_prices = db_client.get_all_prices_with_details()
            
            # Группируем данные по магазинам
            shops_data = self._group_data_by_shops(all_prices)
            
            # Ищем лучший магазин для каждого
            shop_solutions = []
            
            for shop_id, shop_data in shops_data.items():
                solution = self._evaluate_shop(search_request.products, shop_id, shop_data)
                shop_solutions.append(solution)
            
            # Сортируем по количеству найденных товаров и цене
            shop_solutions.sort(key=lambda x: (-x.products_found_count, x.total_price))
            valid_shops = [shop for shop in shop_solutions if shop.products_found_count > 0]
            
            if not valid_shops:
                logger.warning("No suitable shops found")
                return None
            
            best_shop = valid_shops[0]
            logger.info(f"Best shop found: {best_shop.shop_name} (price: {best_shop.total_price}, found: {best_shop.products_found_count})")
            
            return best_shop
            
        except Exception as e:
            logger.error(f"Error in shop search: {e}")
            raise
    
    def _group_data_by_shops(self, all_prices: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """Группировать данные по магазинам"""
        shops_data = {}
        
        for price in all_prices:
            shop_id = price["shop_id"]
            shop_name = price["shops"]["name"]
            product_id = price["product_id"]
            product_name = price["products"]["name"]
            product_price = price["price"]
            
            if shop_id not in shops_data:
                shops_data[shop_id] = {
                    "name": shop_name,
                    "products": {},
                    "total_price": 0,
                    "matched_products": set()
                }
            
            shops_data[shop_id]["products"][product_id] = {
                "name": product_name,
                "price": product_price,
                "clean_name": self.product_service.remove_stop_words(product_name)
            }
        
        logger.debug(f"Grouped data for {len(shops_data)} shops")
        return shops_data
    
    def _evaluate_shop(self, target_products: List[str], shop_id: str, shop_data: Dict[str, Any]) -> ShopSolution:
        """Оценить магазин для списка товаров"""
        total_price = 0
        found_products = []
        used_product_ids = set()
        
        logger.debug(f"Evaluating shop: {shop_data['name']}")
        
        for target_product in target_products:
            product_id, product_data, similarity, match_type = self.product_service.find_best_product_match(
                target_product, shop_data["products"], used_product_ids
            )
            
            if product_id:
                total_price += product_data["price"]
                found_products.append(ProductMatch(
                    target=target_product,
                    found=product_data["name"],
                    price=product_data["price"],
                    similarity=similarity,
                    match_type=match_type,
                    product_id=product_id
                ))
                used_product_ids.add(product_id)
                logger.debug(f"Found: '{product_data['name']}' for '{target_product}'")
            else:
                # Штраф за ненайденный товар
                total_price += config.PENALTY_PRICE
                found_products.append(ProductMatch(
                    target=target_product,
                    found="НЕ НАЙДЕН",
                    price=config.PENALTY_PRICE,
                    similarity=0,
                    match_type=MatchType.NONE
                ))
                logger.debug(f"Not found: '{target_product}'")
        
        products_found_count = len([p for p in found_products if p.found != "НЕ НАЙДЕН"])
        match_percentage = products_found_count / len(target_products)
        
        return ShopSolution(
            shop_id=shop_id,
            shop_name=shop_data["name"],
            total_price=total_price,
            found_products=found_products,
            match_percentage=match_percentage,
            products_found_count=products_found_count
        )