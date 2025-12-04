"""
Сервис для работы с товарами
"""
from typing import List, Dict, Any, Optional, Tuple
from rapidfuzz import fuzz
from app.core.constants import (
    STOP_WORDS, MATCH_PRIORITIES, SIMILARITY_THRESHOLDS, 
    PRICE_TOLERANCE, SIMILARITY_WEIGHTS, FUZZY_THRESHOLDS, FUZZY_WEIGHTS
)
from app.models import ProductMatch, MatchType
from app.core.logger import get_logger

logger = get_logger(__name__)


class ProductService:
    """Сервис для работы с товарами"""
    
    @staticmethod
    def remove_stop_words(text: str) -> str:
        """Удалить стоп-слова из текста"""
        words = text.lower().split()
        filtered_words = [word for word in words if word not in STOP_WORDS]
        return ' '.join(filtered_words)

    @staticmethod
    def calculate_fuzzy_similarity(query: str, target: str) -> float:
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

    @staticmethod
    def calculate_category_similarity(target_category: Optional[str], product_category: str) -> float:
        """
        Рассчитать схожесть категорий

        Args:
            target_category: Целевая категория (может быть None)
            product_category: Категория товара из БД

        Returns:
            float: Оценка от 0 до 1
        """
        if target_category is None:
            return 0.5  # Нейтральная оценка, если категория не указана

        if target_category.lower() == product_category.lower():
            return 1.0  # Точное совпадение категорий

        # Проверяем, есть ли общие слова в названиях категорий
        # Например: "Фрукты" и "Свежие фрукты"
        target_words = set(target_category.lower().split())
        product_words = set(product_category.lower().split())

        if target_words & product_words:  # Есть пересечение (общие слова)
            return 0.7  # Частичное совпадение

        return 0.0  # Совершенно разные категории

    @staticmethod
    def calculate_price_similarity(target_price: Optional[float], product_price: float) -> float:
        """
        Рассчитать схожесть цен

        Args:
            target_price: Целевая цена (может быть None)
            product_price: Цена товара из БД

        Returns:
            float: Оценка от 0 до 1
        """
        if target_price is None or target_price <= 0:
            return 0.5  # Нейтральная оценка, если цена не указана

        # Рассчитываем относительное отклонение цены в процентах
        price_diff = abs(target_price - product_price) / target_price

        if price_diff <= PRICE_TOLERANCE:
            # Линейная функция: чем ближе цена, тем выше оценка
            # При 0% отклонения = 1.0, при 30% отклонения = 0.0
            return 1.0 - (price_diff / PRICE_TOLERANCE)

        return 0.0  # Цена отличается больше чем на 30%

    @staticmethod
    def find_best_product_match(
            target_product: str,
            shop_products: Dict[str, Dict[str, Any]],
            used_products: set,
            target_category: Optional[str] = None,
            target_price: Optional[float] = None
    ) -> Tuple[Optional[str], Optional[Dict[str, Any]], float, MatchType]:
        """
        Найти лучшее сопоставление товара в магазине используя fuzzy matching (rapidfuzz)

        Args:
            target_product: Искомый товар
            shop_products: Товары магазина
            used_products: Уже использованные товары
            target_category: Целевая категория товара (опционально)
            target_price: Целевая цена товара (опционально)

        Returns:
            Tuple: (product_id, product_data, similarity_score, match_type)
        """
        best_match = None
        best_combined_score = 0
        best_fuzzy_score = 0
        best_match_type = MatchType.NONE
        
        target_lower = target_product.lower()
        target_clean = ProductService.remove_stop_words(target_product)
        target_clean_lower = target_clean.lower()
        
        # Минимальный порог для рассмотрения кандидата
        min_threshold = FUZZY_THRESHOLDS['low'] / 100.0
        
        logger.debug(f"Fuzzy searching for product: '{target_product}' (clean: '{target_clean}')")
        logger.debug(f"Target category: {target_category}, Target price: {target_price}")
        logger.debug(f"Available products count: {len(shop_products)}")
        
        for product_id, product_data in shop_products.items():
            if product_id in used_products:
                continue
            
            product_name = product_data["name"]
            product_name_lower = product_name.lower()
            product_clean = product_data["clean_name"]
            product_clean_lower = product_clean.lower()
            product_category = product_data.get("category", "")
            product_price = product_data["price"]

            # Рассчитываем fuzzy similarity для обоих вариантов
            fuzzy_full = ProductService.calculate_fuzzy_similarity(target_lower, product_name_lower)
            fuzzy_clean = ProductService.calculate_fuzzy_similarity(target_clean_lower, product_clean_lower)
            
            # Берём лучший score
            fuzzy_score = max(fuzzy_full, fuzzy_clean)
            
            # Пропускаем если ниже минимального порога
            if fuzzy_score < min_threshold:
                continue
            
            # Определяем match_type на основе fuzzy score
            match_type = MatchType.NONE
            match_priority = 0
            
            # 1. ТОЧНОЕ СОВПАДЕНИЕ (fuzzy score >= 95%)
            if fuzzy_score >= 0.95:
                if target_lower == product_name_lower:
                    match_type = MatchType.EXACT_FULL
                    match_priority = MATCH_PRIORITIES['exact_full']
                elif target_clean_lower == product_clean_lower:
                    match_type = MatchType.EXACT_CLEAN
                    match_priority = MATCH_PRIORITIES['exact_clean']
                else:
                    match_type = MatchType.PARTIAL_FULL
                    match_priority = MATCH_PRIORITIES['partial_full']
            
            # 2. ВЫСОКОЕ СХОДСТВО (fuzzy score >= 80%)
            elif fuzzy_score >= FUZZY_THRESHOLDS['high'] / 100.0:
                if fuzzy_full >= fuzzy_clean:
                    match_type = MatchType.PARTIAL_FULL
                    match_priority = MATCH_PRIORITIES['partial_full']
                else:
                    match_type = MatchType.PARTIAL_CLEAN
                    match_priority = MATCH_PRIORITIES['partial_clean']
            
            # 3. СРЕДНЕЕ СХОДСТВО (fuzzy score >= 60%)
            elif fuzzy_score >= FUZZY_THRESHOLDS['medium'] / 100.0:
                match_type = MatchType.PARTIAL_CLEAN
                match_priority = MATCH_PRIORITIES['partial_clean']
            
            # 4. НИЗКОЕ СХОДСТВО (fuzzy score >= 45%)
            elif fuzzy_score >= min_threshold:
                match_type = MatchType.PARTIAL_CLEAN
                match_priority = MATCH_PRIORITIES['partial_clean']

            if match_priority > 0:
                # Нормализуем текстовую схожесть
                text_similarity = (match_priority / MATCH_PRIORITIES['exact_full']) * fuzzy_score

                # Рассчитываем схожесть по категории и цене
                category_similarity = ProductService.calculate_category_similarity(
                    target_category, product_category
                )
                price_similarity = ProductService.calculate_price_similarity(
                    target_price, product_price
                )

                # Итоговая оценка с учётом весов
                combined_score = (
                    SIMILARITY_WEIGHTS['text_match'] * text_similarity +
                    SIMILARITY_WEIGHTS['category_match'] * category_similarity +
                    SIMILARITY_WEIGHTS['price_proximity'] * price_similarity
                )

                logger.debug(f"Fuzzy scores for '{product_name}': fuzzy={fuzzy_score:.2f}, "
                             f"text={text_similarity:.2f}, category={category_similarity:.2f}, "
                             f"price={price_similarity:.2f}, combined={combined_score:.2f}")

                if best_match is None or combined_score > best_combined_score:
                    best_match = (product_id, product_data)
                    best_combined_score = combined_score
                    best_fuzzy_score = fuzzy_score
                    best_match_type = match_type
        
        if best_match:
            product_id, product_data = best_match

            logger.info(f"Fuzzy best match found: '{product_data['name']}' "
                        f"(type: {best_match_type.value}, fuzzy_score: {best_fuzzy_score:.2f}, "
                        f"combined_score: {best_combined_score:.2f})")
            return product_id, product_data, best_fuzzy_score, best_match_type
        
        logger.warning(f"No fuzzy match found for product: '{target_product}'")
        return None, None, 0, MatchType.NONE