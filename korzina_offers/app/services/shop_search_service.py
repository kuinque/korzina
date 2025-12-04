"""
Сервис для поиска магазинов
"""
from typing import List, Dict, Any, Optional
from collections import Counter
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

    def find_products_in_shop(self, search_request: SearchRequest, shop_name: str) -> Optional[ShopSolution]:
        """
        Найти товары в конкретном магазине
        
        Args:
            search_request: Запрос с списком товаров
            shop_name: Название магазина
            
        Returns:
            ShopSolution или None если магазин не найден
        """
        logger.info(f"Searching products in shop: {shop_name}")
        
        try:
            # Получаем предложения конкретного магазина
            shop_offers = cache_manager.get_offers_by_seller(shop_name)
            
            if not shop_offers:
                logger.warning(f"No offers found for shop: {shop_name}")
                return None
            
            # Группируем предложения по продавцам (только для этого магазина)
            sellers_data = self._group_offers_by_sellers(shop_offers)
            
            if shop_name not in sellers_data:
                logger.warning(f"Shop {shop_name} not found in grouped data")
                return None
            
            # Оцениваем продавца для сравнения цен (разрешаем дубликаты)
            solution = self._evaluate_seller_for_comparison(search_request.products, shop_name, sellers_data[shop_name])
            
            logger.info(f"Shop {shop_name}: found {solution.products_found_count} products, total price: {solution.total_price}")
            
            return solution
            
        except Exception as e:
            logger.error(f"Error searching products in shop {shop_name}: {e}")
            return None

    def find_alternatives_for_offers(self, offer_ids: List[int]) -> List[Dict[str, Any]]:
        """
        Найти альтернативные предложения для списка офферов по всем магазинам

        Args:
            offer_ids: Список ID исходных офферов

        Returns:
            Список с альтернативами по магазинам
        """
        logger.info(f"Searching alternatives for offers: {offer_ids}")

        all_offers = cache_manager.get_all_offers()
        selected_offers_map: Dict[int, Dict[str, Any]] = {}
        for offer in all_offers:
            offer_id = offer.get("offer_id")
            if offer_id in offer_ids and offer_id not in selected_offers_map:
                selected_offers_map[offer_id] = offer

        missing_ids = [offer_id for offer_id in offer_ids if offer_id not in selected_offers_map]
        if missing_ids:
            raise ValueError(f"Offers not found: {missing_ids}")

        target_offers = [
            selected_offers_map[offer_id]
            for offer_id in offer_ids
            if offer_id in selected_offers_map
        ]
        sellers_data = self._group_offers_by_sellers(all_offers)

        # Подготовим структуры для накопления результатов в порядке магазинов
        shop_results: Dict[str, Dict[str, Any]] = {
            seller_name: {
                "shop_name": seller_data["name"],
                "matches": []
            }
            for seller_name, seller_data in sellers_data.items()
        }

        ordered_sellers = sorted(sellers_data.keys())

        # Идём по списку искомых офферов и находим альтернативы в каждом магазине
        for target in target_offers:
            target_title = target.get("title", "")
            target_category = target.get("category_name")
            target_price = self._normalize_price(target.get("price"))
            target_id = target.get("offer_id")

            for seller_name in ordered_sellers:
                seller_data = sellers_data[seller_name]
                offer_id, offer_data, similarity, match_type = self.product_service.find_best_product_match(
                    target_product=target_title,
                    shop_products=seller_data["offers"],
                    used_products=set(),  # Каждый оффер рассматривается независимо
                    target_category=target_category,
                    target_price=target_price
                )

                if offer_id and offer_data:
                    matched_offer = offer_data.get("offer_data") or {
                        "offer_id": offer_id,
                        "title": offer_data.get("name"),
                        "description": None,
                        "price": offer_data.get("price"),
                        "currency": None,
                        "category_name": offer_data.get("category"),
                        "seller_name": seller_data["name"],
                        "images": []
                    }
                else:
                    similarity = 0.0
                    match_type = MatchType.NONE
                    matched_offer = self._build_empty_offer(seller_data["name"])

                shop_results[seller_name]["matches"].append({
                    "target_offer_id": target_id,
                    "target_title": target_title,
                    "similarity": similarity,
                    "match_type": match_type,
                    "matched_offer": matched_offer
                })

        alternatives = {
            shop_results[name]["shop_name"]: shop_results[name]["matches"]
            for name in ordered_sellers
        }
        logger.info(f"Alternatives calculated for {len(alternatives)} shops")
        return alternatives

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

            # Преобразуем цену в число
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

    def _evaluate_seller_for_comparison(self, target_products: List[str], seller_name: str, seller_data: Dict[str, Any]) -> ShopSolution:
        """Оценить продавца для сравнения цен (разрешает дубликаты товаров)"""
        total_price = 0
        found_products = []
        
        logger.debug(f"Evaluating seller for comparison: {seller_data['name']}")
        
        # Группируем товары по названию для подсчета количества
        product_counts = Counter(target_products)
        
        for product_name, count in product_counts.items():
            # Ищем товар в магазине
            offer_id, offer_data, similarity, match_type = self.product_service.find_best_product_match(
                product_name, seller_data["offers"], set()  # Не используем used_offer_ids
            )
            
            if offer_id:
                # Умножаем цену на количество
                product_total_price = offer_data["price"] * count
                total_price += product_total_price
                
                # Добавляем запись для каждого экземпляра товара
                for i in range(count):
                    found_products.append(ProductMatch(
                        target=product_name,
                        found=offer_data["name"],
                        price=offer_data["price"],
                        similarity=similarity,
                        match_type=match_type,
                        product_id=str(offer_id),
                        offer_data=offer_data.get("offer_data")
                    ))
                logger.debug(f"Found: '{offer_data['name']}' for '{product_name}' (count: {count}, total: {product_total_price})")
            else:
                # Штраф за ненайденный товар (умножаем на количество)
                penalty_total = config.PENALTY_PRICE * count
                total_price += penalty_total
                
                # Добавляем запись для каждого экземпляра товара
                for i in range(count):
                    found_products.append(ProductMatch(
                        target=product_name,
                        found="НЕ НАЙДЕН",
                        price=config.PENALTY_PRICE,
                        similarity=0,
                        match_type=MatchType.NONE
                    ))
                logger.debug(f"Not found: '{product_name}' (count: {count}, penalty: {penalty_total})")
        
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

            # Ищем по вхождению подстроки, а не точному совпадению
            for offer in all_offers:
                title = offer.get("title", "").lower()
                if product_name_lower in title:
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

    @staticmethod
    def _normalize_price(price: Any) -> Optional[float]:
        """Преобразовать цену к float при необходимости"""
        if price is None:
            return None
        try:
            numeric_price = float(price)
            return numeric_price if numeric_price >= 0 else None
        except (TypeError, ValueError):
            logger.warning(f"Unable to normalize price value: {price}")
            return None

    @staticmethod
    def _build_empty_offer(shop_name: str) -> Dict[str, Any]:
        """Вернуть шаблон пустого оффера"""
        return {
            "offer_id": None,
            "title": None,
            "description": None,
            "price": None,
            "currency": None,
            "category_name": None,
            "seller_name": shop_name,
            "images": []
        }
