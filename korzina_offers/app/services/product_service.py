"""
Сервис для работы с товарами
"""
from typing import List, Dict, Any, Optional, Tuple
from difflib import SequenceMatcher
from app.core.constants import STOP_WORDS, MATCH_PRIORITIES, SIMILARITY_THRESHOLDS, PRICE_TOLERANCE, SIMILARITY_WEIGHTS
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
        Найти лучшее сопоставление товара в магазине

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
        best_similarity = 0
        best_priority = 0
        target_clean = ProductService.remove_stop_words(target_product)
        
        logger.debug(f"Searching for product: '{target_product}' (clean: '{target_clean}')")
        logger.debug(f"Target category: {target_category}, Target price: {target_price}")
        logger.debug(f"Available products count: {len(shop_products)}")
        
        for product_id, product_data in shop_products.items():
            if product_id in used_products:
                continue
            
            product_name = product_data["name"]
            product_clean = product_data["clean_name"]
            product_category = product_data.get("category", "")
            product_price = product_data["price"]
            match_priority = 0
            similarity_score = 0

            logger.debug(
                f"Checking product: id={product_id}, name='{product_name}', clean='{product_clean}', category='{product_category}', price={product_price}")

            # 1. ТОЧНОЕ СОВПАДЕНИЕ (полное, с учетом стоп-слов)
            if target_product.lower() == product_name.lower():
                match_priority = MATCH_PRIORITIES['exact_full']
                similarity_score = 1.0
                logger.debug(f"Exact full match: '{product_name}'")
            
            # 2. ЧАСТИЧНОЕ СОВПАДЕНИЕ (с учетом стоп-слов)
            if (match_priority < MATCH_PRIORITIES['partial_full'] and
                  (target_product.lower() in product_name.lower() or
                   product_name.lower() in target_product.lower())):
                similarity = SequenceMatcher(None, target_product.lower(), product_name.lower()).ratio()
                logger.debug(f"Partial full check: similarity={similarity:.2f}, threshold={SIMILARITY_THRESHOLDS['partial_full']}")
                if similarity >= SIMILARITY_THRESHOLDS['partial_full'] and match_priority < MATCH_PRIORITIES['partial_full']:
                    match_priority = MATCH_PRIORITIES['partial_full']
                    similarity_score = similarity
                    logger.debug(f"Partial full match: '{product_name}' (similarity: {similarity:.2f})")
            
            # 3. ТОЧНОЕ СОВПАДЕНИЕ БЕЗ СТОП-СЛОВ
            if match_priority < MATCH_PRIORITIES['exact_clean'] and target_clean.lower() == product_clean.lower():
                match_priority = MATCH_PRIORITIES['exact_clean']
                similarity_score = 0.9
                logger.debug(f"Exact clean match: '{product_name}'")
            
            # 4. ЧАСТИЧНОЕ СОВПАДЕНИЕ БЕЗ СТОП-СЛОВ
            if (match_priority < MATCH_PRIORITIES['partial_clean'] and
                  (target_clean.lower() in product_clean.lower() or
                   product_clean.lower() in target_clean.lower())):
                # Если одно слово содержится в другом, используем более мягкий порог
                similarity = SequenceMatcher(None, target_clean.lower(), product_clean.lower()).ratio()
                # Если target полностью содержится в product - это хорошее совпадение
                contains_threshold = SIMILARITY_THRESHOLDS['partial_clean']
                if target_clean.lower() in product_clean.lower():
                    contains_threshold = 0.2  # Еще более мягкий порог при вхождении
                
                logger.debug(f"Partial clean check: similarity={similarity:.2f}, threshold={contains_threshold}")
                if similarity >= contains_threshold and match_priority < MATCH_PRIORITIES['partial_clean']:
                    match_priority = MATCH_PRIORITIES['partial_clean']
                    similarity_score = similarity
                    logger.debug(f"Partial clean match: '{product_name}' (similarity: {similarity:.2f})")
            
            # 5. ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА ДЛЯ ПОХОЖИХ ТОВАРОВ
            if match_priority == 0:
                # Проверяем общие слова между товарами
                target_words = set(target_clean.lower().split())
                product_words = set(product_clean.lower().split())
                common_words = target_words.intersection(product_words)
                
                if len(common_words) > 0:
                    # Если есть общие слова, считаем это потенциальным совпадением
                    word_similarity = len(common_words) / max(len(target_words), len(product_words))
                    if word_similarity >= 0.3:  # Если 30% слов совпадают
                        similarity = SequenceMatcher(None, target_clean.lower(), product_clean.lower()).ratio()
                        if similarity >= 0.2:  # Очень мягкий порог для похожих товаров
                            match_priority = MATCH_PRIORITIES['partial_clean']
                            similarity_score = similarity
                            logger.debug(f"Similar product match: '{product_name}' (word similarity: {word_similarity:.2f}, text similarity: {similarity:.2f})")

            # Если нашли совпадение, рассчитываем итоговую оценку
            if match_priority > 0:
                # Нормализуем текстовую схожесть от 0 до 1
                # Приоритет делим на максимальный (4), умножаем на схожесть
                text_similarity = (match_priority / MATCH_PRIORITIES['exact_full']) * similarity_score

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

                logger.debug(f"Scores for '{product_name}': text={text_similarity:.2f}, "
                             f"category={category_similarity:.2f}, price={price_similarity:.2f}, "
                             f"combined={combined_score:.2f}")

                if best_match is None or combined_score > best_combined_score:
                    best_match = (product_id, product_data)
                    best_combined_score = combined_score
                    best_text_similarity = similarity_score
                    best_priority = match_priority
        
        if best_match:
            product_id, product_data = best_match
            match_type = MatchType.NONE
            
            # Определяем тип сопоставления
            for match_type_name, priority in MATCH_PRIORITIES.items():
                if best_priority == priority:
                    match_type = MatchType(match_type_name)
                    break

            logger.info(f"Best match found: '{product_data['name']}' "
                        f"(type: {match_type.value}, text_score: {best_text_similarity:.2f}, "
                        f"combined_score: {best_combined_score:.2f})")
            return product_id, product_data, best_text_similarity, match_type
        
        logger.warning(f"No match found for product: '{target_product}'")
        return None, None, 0, MatchType.NONE
