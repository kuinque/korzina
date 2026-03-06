"""
Сервис для поиска магазинов
"""
from typing import List, Dict, Any, Optional
from rapidfuzz import fuzz
from app.database.client import cache_manager
from app.services.product_service import ProductService
from app.models import ShopSolution, ProductMatch, SearchRequest, MatchType
from app.config import config
from app.core.logger import get_logger
from app.core.constants import FUZZY_THRESHOLDS, FUZZY_WEIGHTS
from app.services.title_normalizer import normalize_title

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

    def find_alternatives_for_offers(self, offer_ids: List[int]) -> Dict[str, List[Dict[str, Any]]]:
        """
        Найти альтернативные предложения для списка офферов по всем магазинам
        """
        logger.info(f"=== ALTERNATIVES SEARCH START ===")
        logger.info(f"Searching alternatives for offers: {offer_ids}")

        all_offers = cache_manager.get_all_offers()

        # Находим исходные офферы
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
        logger.info(f"Target offers loaded: {len(target_offers)}")

        # Группируем ВСЕ офферы по продавцам
        sellers_data = self._group_offers_by_sellers(all_offers)
        logger.info(f"Grouped into {len(sellers_data)} sellers")

        alternatives: Dict[str, List[Dict[str, Any]]] = {}
        ordered_sellers = sorted(sellers_data.keys())

        for seller_name in ordered_sellers:
            seller_data = sellers_data[seller_name]
            shop_name = seller_data["name"]
            shop_matches = []

            logger.debug(f"Processing shop: {shop_name} ({len(seller_data['offers'])} offers)")

            for idx, target in enumerate(target_offers, 1):
                target_title = target.get("title", "")
                target_category_num = target.get("category_code")
                target_price = self._normalize_price(target.get("price"))
                target_id = target.get("offer_id")
                target_tags = target.get("tags") or []  # <-- ИЗВЛЕКАЕМ ТЕГИ

                search_query = self._extract_key_words(target_title)

                logger.info(f"  [{idx}/{len(target_offers)}] Target: '{target_title[:60]}...'")
                logger.info(f"    Extracted keywords: '{search_query}'")
                logger.info(f"    Target tags: {target_tags}")  # <-- ЛОГИРУЕМ ТЕГИ

                # ФИЛЬТРУЕМ товары магазина по тегам исходного оффера
                if target_tags:
                    filtered_shop_products = {
                        offer_id: product
                        for offer_id, product in seller_data["offers"].items()
                        if self._has_matching_tag(product, target_tags)
                    }
                    logger.info(
                        f"    Filtered by tags: {len(filtered_shop_products)} products (was {len(seller_data['offers'])})")
                else:
                    filtered_shop_products = seller_data["offers"]

                # Ищем лучший вариант среди ОТФИЛЬТРОВАННЫХ товаров
                top_matches = self._find_top_matches(
                    search_query=search_query,
                    shop_products=filtered_shop_products,  # <-- ФИЛЬТРОВАННЫЕ
                    target_category=target_category,
                    target_price=target_price,
                    limit=1
                )

                logger.info(f"    Found {len(top_matches)} matches in {shop_name}")

                if top_matches:
                    match = top_matches[0]
                    matched_offer = match["offer"]
                    
                    # Проверяем, идентичен ли найденный оффер исходному
                    is_identical = self._is_identical_offer(target, matched_offer)
                    
                    shop_matches.append({
                        "offer_number": 1,
                        "target_offer_id": target_id,
                        "target_title": target_title,
                        "similarity": match["similarity"],
                        "match_type": match["match_type"],
                        "is_identical": is_identical,
                        "is_duplicated": False,
                        "matched_offer": matched_offer
                    })
                    
                    if is_identical:
                        logger.info(f"    ✓ Identical offer found in {shop_name}")
                else:
                    shop_matches.append({
                        "offer_number": 1,
                        "target_offer_id": target_id,
                        "target_title": target_title,
                        "similarity": 1.0,  # Полное совпадение (это тот же товар)
                        "match_type": MatchType.EXACT_FULL,
                        "is_identical": True,
                        "is_duplicated": True,  # Помечаем как дубликат
                        "matched_offer": duplicated_offer
                    })
                    logger.info(f"    ⚡ Duplicated offer created for {shop_name} (price: {duplicated_offer['price']})")

            alternatives[shop_name] = shop_matches
            logger.info(f"  {shop_name}: {len(shop_matches)} alternatives found")

        logger.info(f"=== ALTERNATIVES SEARCH END ===")
        logger.info(f"Total shops processed: {len(alternatives)}")

        return alternatives

    def _has_matching_tag(self, product: Dict[str, Any], target_tags: List[str]) -> bool:
        """
        Проверить, есть ли у товара хотя бы один совпадающий тег

        Args:
            product: Данные товара из seller_data["offers"]
            target_tags: Теги исходного оффера

        Returns:
            True если есть совпадение
        """
        # Теги хранятся в offer_data
        offer_data = product.get("offer_data", {})
        product_tags = offer_data.get("tags") or []

        # Проверяем пересечение тегов
        return bool(set(target_tags) & set(product_tags))

    def _group_offers_by_sellers(self, all_offers: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """
        Группировать предложения по продавцам и категориям
        
        Каждый оффер добавляется во все уровни своей иерархии категорий.
        Пример: оффер с category_num="1.2.3" будет в categories["1"], ["1.2"], ["1.2.3"]
        """
        sellers_data = {}

        for offer in all_offers:
            seller_name = offer.get("seller_name")
            if not seller_name:
                continue

            offer_id = offer["offer_id"]
            title = offer.get("title", "")
            price_raw = offer.get("price", 0)
            category_num = offer.get("category_code", "")

            try:
                price = float(price_raw) if price_raw else 0
            except (ValueError, TypeError):
                logger.warning(f"Invalid price format for offer {offer_id}: {price_raw}")
                price = 0

            if seller_name not in sellers_data:
                sellers_data[seller_name] = {
                    "name": seller_name,
                    "offers": {},
                    "categories": {},
                }

            normalized = normalize_title(title)
            offer_data_item = {
                "name": title,
                "price": price,
                "clean_name": self.product_service.remove_stop_words(title),
                "normalized_name": normalized,
                "category": offer.get("category_name", ""),
                "category_code": category_num,
                "offer_data": offer
            }

            # Добавляем в общий список офферов
            sellers_data[seller_name]["offers"][offer_id] = offer_data_item

            # Добавляем в категории по иерархии (пропускаем None и "None")
            if category_num and category_num != "None":
                for level in self._get_category_hierarchy(category_num):
                    if level not in sellers_data[seller_name]["categories"]:
                        sellers_data[seller_name]["categories"][level] = {}
                    sellers_data[seller_name]["categories"][level][offer_id] = offer_data_item

        # Диагностика: показываем какие категории загружены
        for seller_name, data in sellers_data.items():
            categories = list(data.get("categories", {}).keys())[:10]
            logger.info(f"  {seller_name}: {len(data['offers'])} offers, categories: {categories}")
        
        logger.debug(f"Grouped data for {len(sellers_data)} sellers")
        return sellers_data

    @staticmethod
    def _get_category_hierarchy(category_num: str) -> List[str]:
        """
        Получить все уровни иерархии: "1.2.3" -> ["1", "1.2", "1.2.3"]
        """
        if not category_num:
            return []
        parts = category_num.split(".")
        return [".".join(parts[:i]) for i in range(1, len(parts) + 1)]

    @staticmethod
    def _get_parent_category(category_num: str) -> Optional[str]:
        """
        Получить родительскую категорию: "1.2.3" -> "1.2", "1" -> None
        """
        if not category_num or "." not in category_num:
            return None
        return ".".join(category_num.split(".")[:-1])

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
            product_name_normalized = normalize_title(product_name)

            for offer in all_offers:
                title = offer.get("title", "").lower()
                title_normalized = normalize_title(title)
                if product_name_lower in title or product_name_normalized in title_normalized:
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

    def _extract_key_words(self, title: str, max_words: int = 6) -> str:
        """
        Извлечь ключевые слова из названия товара для fuzzy matching.

        Сначала нормализует название (единицы, сокращения, синонимы),
        затем убирает стоп-слова и берёт первые max_words слов.

        Args:
            title: Полное название товара
            max_words: Максимальное количество слов (по умолчанию 6)

        Returns:
            Ключевые слова для поиска
        """
        normalized = normalize_title(title)
        clean = self.product_service.remove_stop_words(normalized)

        words = clean.split()[:max_words]
        result = " ".join(words)

        logger.debug(f"Extracted key words from '{title}': '{result}'")
        return result

    def _calculate_fuzzy_score(self, query: str, target: str) -> float:
        """
        Рассчитать комбинированный fuzzy score используя rapidfuzz
        
        Комбинирует несколько метрик:
        - token_set_ratio: устойчив к перестановкам слов и дубликатам
        - token_sort_ratio: сортирует слова перед сравнением
        - partial_ratio: находит лучшее частичное совпадение
        
        Args:
            query: Поисковый запрос
            target: Строка для сравнения
            
        Returns:
            Нормализованный score от 0 до 1
        """
        # Получаем разные метрики (rapidfuzz возвращает 0-100)
        token_set = fuzz.token_set_ratio(query, target)
        token_sort = fuzz.token_sort_ratio(query, target)
        partial = fuzz.partial_ratio(query, target)
        
        # Комбинируем с весами
        combined = (
            FUZZY_WEIGHTS['token_set'] * token_set +
            FUZZY_WEIGHTS['token_sort'] * token_sort +
            FUZZY_WEIGHTS['partial'] * partial
        )
        
        # Нормализуем к 0-1
        return combined / 100.0

    def _normalize_title_for_identity(self, title: str) -> str:
        """
        Нормализовать название для определения идентичности.

        Делегирует основную работу в TitleNormalizer (единицы, сокращения,
        синонимы, маркировки), затем дополнительно убирает стоп-слова
        и предлоги для максимально «чистого» сравнения.

        Args:
            title: Исходное название

        Returns:
            Нормализованное название
        """
        normalized = normalize_title(title)

        normalized = self.product_service.remove_stop_words(normalized)

        prepositions = {'с', 'и', 'в', 'на', 'для', 'от', 'до', 'по', 'из', 'к', 'о', 'об', 'со', 'во'}
        words = normalized.split()
        words = [w for w in words if w not in prepositions]
        normalized = ' '.join(words)

        import re
        normalized = re.sub(r'\s+', ' ', normalized).strip()

        return normalized

    def _is_identical_offer(self, source_offer: Dict[str, Any], matched_offer: Dict[str, Any]) -> bool:
        """
        Проверить, идентичны ли два оффера (один и тот же товар в разных магазинах)
        
        Критерии идентичности основаны ТОЛЬКО на названии:
        - Очень высокая схожесть названий (fuzzy score >= 95% или >= 85% после нормализации)
        - Полное совпадение после нормализации
        
        Args:
            source_offer: Исходный оффер
            matched_offer: Найденный оффер для сравнения
            
        Returns:
            True если офферы идентичны, False иначе
        """
        source_title = source_offer.get("title", "").strip()
        matched_title = matched_offer.get("title", "").strip()
        
        # Если названия пустые, не идентичны
        if not source_title or not matched_title:
            return False
        
        # Проверяем схожесть исходных названий через fuzzy matching
        token_sort_score = fuzz.token_sort_ratio(source_title.lower(), matched_title.lower())
        
        # Если token_sort_ratio очень высокий (>= 95) - считаем идентичными
        if token_sort_score >= 95:
            return True
        
        # Нормализуем названия для более точного сравнения
        source_normalized = self._normalize_title_for_identity(source_title)
        matched_normalized = self._normalize_title_for_identity(matched_title)
        
        # Если нормализованные названия идентичны - точно один товар
        if source_normalized == matched_normalized and source_normalized:
            return True
        
        # Проверяем схожесть нормализованных названий
        token_sort_norm = fuzz.token_sort_ratio(source_normalized, matched_normalized)
        token_set_norm = fuzz.token_set_ratio(source_normalized, matched_normalized)
        
        # После нормализации порог можно снизить до 85%
        if token_sort_norm >= 85 or token_set_norm >= 85:
            return True
        
        # Дополнительная проверка: если оба нормализованных названия содержат одинаковые ключевые слова
        if source_normalized and matched_normalized:
            source_words = set(source_normalized.split())
            matched_words = set(matched_normalized.split())
            
            # Если все слова из одного названия есть в другом (или наоборот)
            if source_words and matched_words:
                if source_words == matched_words:
                    return True
                
                # Проверяем через token_set_ratio для более точной оценки
                token_set_score = fuzz.token_set_ratio(source_title.lower(), matched_title.lower())
                if token_set_score >= 95:
                    return True
        
        return False

    def _determine_match_type(self, fuzzy_score: float, query: str, product_name: str, product_clean: str) -> MatchType:
        """
        Определить тип совпадения на основе fuzzy score и проверок
        
        Args:
            fuzzy_score: Нормализованный fuzzy score (0-1)
            query: Поисковый запрос
            product_name: Полное название товара
            product_clean: Очищенное название товара
            
        Returns:
            MatchType
        """
        query_lower = query.lower()
        name_lower = product_name.lower()
        clean_lower = product_clean.lower()
        
        # Точное совпадение (очень высокий score + вхождение)
        if fuzzy_score >= FUZZY_THRESHOLDS['high'] / 100.0:
            if query_lower in name_lower or name_lower in query_lower:
                return MatchType.PARTIAL_FULL
            if query_lower in clean_lower or clean_lower in query_lower:
                return MatchType.PARTIAL_CLEAN
            return MatchType.PARTIAL_FULL
        
        # Среднее совпадение
        if fuzzy_score >= FUZZY_THRESHOLDS['medium'] / 100.0:
            if query_lower in name_lower:
                return MatchType.PARTIAL_FULL
            return MatchType.PARTIAL_CLEAN
        
        # Низкое совпадение
        if fuzzy_score >= FUZZY_THRESHOLDS['low'] / 100.0:
            return MatchType.PARTIAL_CLEAN
        
        return MatchType.NONE

    def _find_top_matches(
            self,
            search_query: str,
            seller_data: Dict[str, Any],
            target_category_num: Optional[str],
            target_price: Optional[float],
            limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Найти топ-N лучших совпадений в магазине используя fuzzy matching
        с подъёмом по иерархии категорий
        
        Алгоритм:
        1. Ищем в точной категории (например, "1.2.3")
        2. Если не найдено — поднимаемся на "1.2"
        3. Если не найдено — поднимаемся на "1"
        4. Если ничего не найдено — возвращаем пустой список
        
        Args:
            search_query: Поисковый запрос (ключевые слова)
            seller_data: Данные магазина с категориями
            target_category_num: Номер категории товара (x.y.z...)
            target_price: Цена товара
            limit: Количество результатов
            
        Returns:
            Список лучших совпадений (пустой, если не найдено)
        """
        search_lower = search_query.lower()
        min_threshold = FUZZY_THRESHOLDS['low'] / 100.0

        logger.debug(f"Fuzzy searching for: '{search_query}', category_num: '{target_category_num}'")

        # Если категория не указана — не ищем
        if not target_category_num or target_category_num == "None":
            logger.debug("No category_num specified, skipping search")
            return []

        categories = seller_data.get("categories", {})
        
        # Поднимаемся по иерархии от точной категории к корню
        current_category = target_category_num
        
        while current_category:
            category_products = categories.get(current_category, {})
            
            if category_products:
                matches = self._search_in_category(
                    search_lower, category_products, target_price, min_threshold, search_query
                )
                
                if matches:
                    matches.sort(key=lambda x: x["similarity"], reverse=True)
                    top_matches = matches[:limit]
                    
                    logger.info(
                        f"Found {len(matches)} matches in category '{current_category}', "
                        f"returning top {len(top_matches)}"
                    )
                    for i, match in enumerate(top_matches, 1):
                        title = match['offer'].get('title', 'N/A')
                        title_preview = title[:60] if title else 'N/A'
                        logger.info(f"  {i}. [{match['similarity']:.2f}] {title_preview}...")
                    
                    return top_matches
                else:
                    logger.debug(f"No matches in category '{current_category}', going up")
            else:
                logger.debug(f"Category '{current_category}' not found, going up")
            
            # Поднимаемся на уровень выше
            current_category = self._get_parent_category(current_category)
        
        logger.debug("No matches found in category hierarchy")
        return []

    def _search_in_category(
            self,
            search_lower: str,
            category_products: Dict[int, Dict[str, Any]],
            target_price: Optional[float],
            min_threshold: float,
            search_query: str
    ) -> List[Dict[str, Any]]:
        """Поиск совпадений внутри одной категории"""
        matches = []
        
        for offer_id, product in category_products.items():
            product_name = product.get("name", "")
            product_clean = product.get("clean_name", "")

            score_full = self._calculate_fuzzy_score(search_lower, product_name.lower())
            score_clean = self._calculate_fuzzy_score(search_lower, product_clean.lower())
            best_score = max(score_full, score_clean)

            # Бонус за близость цены
            price_bonus = 0.0
            if target_price and target_price > 0:
                product_price = product.get("price", 0)
                if product_price > 0:
                    price_diff = abs(target_price - product_price) / target_price
                    if price_diff <= 0.3:
                        price_bonus = 0.05 * (1 - price_diff / 0.3)

            final_score = min(best_score + price_bonus, 1.0)

            if final_score >= min_threshold:
                match_type = self._determine_match_type(
                    best_score, search_query, product_name, product_clean
                )
                matches.append({
                    "offer_id": offer_id,
                    "similarity": final_score,
                    "match_type": match_type,
                    "offer": product.get("offer_data") or {
                        "offer_id": offer_id,
                        "title": product_name,
                        "price": product.get("price"),
                        "category_name": product.get("category"),
                    }
                })
        
        return matches

    def find_similar_offers_in_same_shop(self, offer_id: int, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Найти похожие офферы в том же магазине
        
        Использует ту же логику, что и find_alternatives_for_offers:
        - Извлечение ключевых слов через _extract_key_words
        - Поиск совпадений через _find_top_matches
        - Группировка офферов через _group_offers_by_sellers
        
        Args:
            offer_id: ID исходного оффера
            limit: Максимальное количество похожих офферов
            
        Returns:
            Список похожих офферов с информацией о similarity и match_type
        """
        logger.info(f"Searching similar offers for offer_id: {offer_id}")
        
        # Получаем все офферы из кэша
        all_offers = cache_manager.get_all_offers()
        
        # Находим исходный оффер
        source_offer = None
        for offer in all_offers:
            if offer.get("offer_id") == offer_id:
                source_offer = offer
                break
        
        if not source_offer:
            logger.warning(f"Offer {offer_id} not found")
            return []
        
        source_title = source_offer.get("title", "")
        source_category_num = source_offer.get("category_code")
        source_price = self._normalize_price(source_offer.get("price"))
        source_seller = source_offer.get("seller_name")
        
        if not source_seller:
            logger.warning(f"Offer {offer_id} has no seller_name")
            return []
        
        logger.info(f"Source offer: '{source_title[:60]}...' from shop: {source_seller}, category_num: {source_category_num}")
        
        sellers_data = self._group_offers_by_sellers(all_offers)
        
        if source_seller not in sellers_data:
            logger.warning(f"Shop {source_seller} not found in sellers data")
            return []
        
        seller_data = sellers_data[source_seller]
        
        # Создаём копию seller_data с исключённым исходным оффером
        filtered_seller_data = {
            "name": seller_data["name"],
            "offers": {oid: p for oid, p in seller_data["offers"].items() if oid != offer_id},
            "categories": {}
        }
        for cat_num, cat_offers in seller_data.get("categories", {}).items():
            filtered = {oid: p for oid, p in cat_offers.items() if oid != offer_id}
            if filtered:
                filtered_seller_data["categories"][cat_num] = filtered
        
        logger.info(f"Found {len(filtered_seller_data['offers'])} offers in shop {source_seller} (excluding source)")
        
        search_query = self._extract_key_words(source_title)
        logger.info(f"Extracted keywords: '{search_query}'")
        
        similar_offers = self._find_top_matches(
            search_query=search_query,
            seller_data=filtered_seller_data,
            target_category_num=source_category_num,
            target_price=source_price,
            limit=limit
        )
        
        # Формируем результат
        result = []
        for match in similar_offers:
            result.append({
                "offer_id": match["offer_id"],
                "similarity": match["similarity"],
                "match_type": match["match_type"],
                "offer": match["offer"]
            })
        
        logger.info(f"Found {len(result)} similar offers for offer_id: {offer_id}")
        return result

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

    def _create_duplicated_offer(self, source_offer: Dict[str, Any], target_shop: str) -> Dict[str, Any]:
        """
        Создать дублированный оффер на основе исходного с изменённой ценой
        
        Используется когда в магазине не найден похожий товар в категории.
        Берём исходный товар и создаём "виртуальную" копию для другого магазина
        с небольшим изменением цены (±5-10%), цена заканчивается на .99
        
        Args:
            source_offer: Исходный оффер для дублирования
            target_shop: Название магазина, для которого создаём дубликат
            
        Returns:
            Дублированный оффер с изменённой ценой и seller_name
        """
        import random
        import math
        
        # Получаем исходную цену
        original_price = self._normalize_price(source_offer.get("price")) or 0
        
        # Изменяем цену на ±5-10%
        price_change_percent = random.uniform(-0.10, 0.10)  # От -10% до +10%
        adjusted_price = original_price * (1 + price_change_percent)
        
        # Округляем до целого и добавляем .99
        new_price = math.floor(adjusted_price) + 0.99
        
        # Убеждаемся что цена не отрицательная
        if new_price < 0.99:
            new_price = math.floor(original_price) + 0.99
        
        # Создаём копию оффера
        duplicated = {
            "offer_id": source_offer.get("offer_id"),  # Сохраняем оригинальный ID
            "title": source_offer.get("title"),
            "description": source_offer.get("description"),
            "price": new_price,
            "original_price": original_price,  # Сохраняем оригинальную цену
            "currency": source_offer.get("currency"),
            "category_name": source_offer.get("category_name"),
            "category_code": source_offer.get("category_code"),
            "seller_name": target_shop,  # Меняем магазин
            "original_seller": source_offer.get("seller_name"),  # Сохраняем оригинальный магазин
            "images": source_offer.get("images", []),
            "tags": source_offer.get("tags", []),
            "is_duplicated": True,  # Помечаем как дубликат
        }
        
        logger.debug(
            f"Created duplicated offer: '{duplicated['title'][:40]}...' "
            f"price: {original_price} -> {new_price}"
        )
        
        return duplicated