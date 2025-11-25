"""
Сервис для поиска магазинов
"""
from typing import List, Dict, Any, Optional
from app.database.client import cache_manager
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
            search_request: Запрос со списком товаров

        Returns:
            ShopSolution или None если не найдено подходящих магазинов
        """
        logger.info(f"Starting search for products: {', '.join(search_request.products)}")

        try:
            # Получаем все предложения из кэша
            all_offers = cache_manager.get_all_offers()
            target_products_info = self._get_target_products_info(search_request.products, all_offers)

            # Группируем предложения по продавцам
            sellers_data = self._group_offers_by_sellers(all_offers)

            # Ищем лучшего продавца для каждого
            seller_solutions = []

            for seller_name, seller_data in sellers_data.items():
                solution = self._evaluate_seller(search_request.products, seller_name, seller_data,
                                                 target_products_info)
                seller_solutions.append(solution)

            # Сортируем по количеству найденных товаров и цене
            seller_solutions.sort(key=lambda x: (-x.products_found_count, x.total_price))
            valid_sellers = [seller for seller in seller_solutions if seller.products_found_count > 0]

            if not valid_sellers:
                logger.warning("No suitable sellers found")
                return None

            best_seller = valid_sellers[0]
            logger.info(
                f"Best seller found: {best_seller.shop_name} (price: {best_seller.total_price}, found: {best_seller.products_found_count})")

            return best_seller

        except Exception as e:
            logger.error(f"Error in seller search: {e}")
            raise

    def _group_offers_by_sellers(self, all_offers: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """Группировать предложения по продавцам"""
        sellers_data = {}

        for offer in all_offers:
            seller_name = offer.get("seller_name")
            if not seller_name:
                continue

            offer_id = offer["offer_id"]
            title = offer.get("title", "")
            price_raw = offer.get("price", 0)

            # ИСПРАВЛЕНИЕ: Преобразуем цену в число
            try:
                price = float(price_raw) if price_raw else 0
            except (ValueError, TypeError):
                logger.warning(f"Invalid price format for offer {offer_id}: {price_raw}")
                price = 0

            if seller_name not in sellers_data:
                sellers_data[seller_name] = {
                    "name": seller_name,
                    "offers": {},
                    "total_price": 0,
                    "matched_offers": set()
                }

            sellers_data[seller_name]["offers"][offer_id] = {
                "name": title,
                "price": price,
                "clean_name": self.product_service.remove_stop_words(title),
                "category": offer.get("category_name", ""),
                "offer_data": offer  # сохраняем полные данные предложения
            }

        logger.debug(f"Grouped data for {len(sellers_data)} sellers")
        return sellers_data

    def _evaluate_seller(self, target_products: List[str], seller_name: str, seller_data: Dict[str, Any],
                         target_products_info: Dict[str, Dict[str, Any]]) -> ShopSolution:
        """Оценить продавца для списка товаров"""
        total_price = 0
        found_products = []
        used_offer_ids = set()

        logger.debug(f"Evaluating seller: {seller_data['name']}")

        for target_product in target_products:
            # Получаем информацию об искомом товаре
            product_info = target_products_info.get(target_product, {})

            offer_id, offer_data, similarity, match_type = self.product_service.find_best_product_match(
                target_product,
                seller_data["offers"],
                used_offer_ids,
                target_category=product_info.get("category"),
                target_price=product_info.get("price")
            )

            if offer_id:
                total_price += offer_data["price"]
                found_products.append(ProductMatch(
                    target=target_product,
                    found=offer_data["name"],
                    price=offer_data["price"],
                    similarity=similarity,
                    match_type=match_type,
                    product_id=str(offer_id),
                    offer_data=offer_data.get("offer_data")
                ))
                used_offer_ids.add(offer_id)
                logger.debug(f"Found: '{offer_data['name']}' for '{target_product}'")
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
            shop_id=seller_name,
            shop_name=seller_data["name"],
            total_price=total_price,
            found_products=found_products,
            match_percentage=match_percentage,
            products_found_count=products_found_count
        )

    def _get_target_products_info(self, product_names: List[str], all_offers: List[Dict[str, Any]]) -> Dict[
        str, Dict[str, Any]]:
        """Получить информацию об искомых товарах из БД"""
        products_info = {}

        for product_name in product_names:
            product_name_lower = product_name.lower()

            # ИСПРАВЛЕНИЕ: Ищем по вхождению подстроки, а не точному совпадению
            for offer in all_offers:
                title = offer.get("title", "").lower()
                if product_name_lower in title:  # <-- ЗДЕСЬ ИЗМЕНЕНИЕ
                    price_raw = offer.get("price")
                    try:
                        price = float(price_raw) if price_raw else None
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid price format for product '{product_name}': {price_raw}")
                        price = None

                    products_info[product_name] = {
                        "category": offer.get("category_name"),
                        "price": price
                    }
                    break  # Берём первое найденное совпадение

            if product_name not in products_info:
                products_info[product_name] = {
                    "category": None,
                    "price": None
                }
                logger.warning(f"Product '{product_name}' not found in database")

        return products_info