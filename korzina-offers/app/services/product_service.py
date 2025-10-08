"""
Сервис для работы с товарами
"""
from typing import List, Dict, Any, Optional, Tuple
from difflib import SequenceMatcher
from app.core.constants import STOP_WORDS, MATCH_PRIORITIES, SIMILARITY_THRESHOLDS
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
    def find_best_product_match(
        target_product: str, 
        shop_products: Dict[str, Dict[str, Any]], 
        used_products: set
    ) -> Tuple[Optional[str], Optional[Dict[str, Any]], float, MatchType]:
        """
        Найти лучшее сопоставление товара в магазине
        
        Args:
            target_product: Искомый товар
            shop_products: Товары магазина
            used_products: Уже использованные товары
            
        Returns:
            Tuple: (product_id, product_data, similarity_score, match_type)
        """
        best_match = None
        best_similarity = 0
        best_priority = 0
        target_clean = ProductService.remove_stop_words(target_product)
        
        logger.debug(f"Searching for product: '{target_product}' (clean: '{target_clean}')")
        
        for product_id, product_data in shop_products.items():
            if product_id in used_products:
                continue
            
            product_name = product_data["name"]
            product_clean = product_data["clean_name"]
            match_priority = 0
            similarity_score = 0
            
            # 1. ТОЧНОЕ СОВПАДЕНИЕ (полное, с учетом стоп-слов)
            if target_product.lower() == product_name.lower():
                match_priority = MATCH_PRIORITIES['exact_full']
                similarity_score = 1.0
                logger.debug(f"Exact full match: '{product_name}'")
            
            # 2. ЧАСТИЧНОЕ СОВПАДЕНИЕ (с учетом стоп-слов)
            elif (match_priority < MATCH_PRIORITIES['partial_full'] and
                  (target_product.lower() in product_name.lower() or
                   product_name.lower() in target_product.lower())):
                similarity = SequenceMatcher(None, target_product.lower(), product_name.lower()).ratio()
                if similarity >= SIMILARITY_THRESHOLDS['partial_full']:
                    match_priority = MATCH_PRIORITIES['partial_full']
                    similarity_score = similarity
                    logger.debug(f"Partial full match: '{product_name}' (similarity: {similarity:.2f})")
            
            # 3. ТОЧНОЕ СОВПАДЕНИЕ БЕЗ СТОП-СЛОВ
            elif match_priority < MATCH_PRIORITIES['exact_clean'] and target_clean.lower() == product_clean.lower():
                match_priority = MATCH_PRIORITIES['exact_clean']
                similarity_score = 0.9
                logger.debug(f"Exact clean match: '{product_name}'")
            
            # 4. ЧАСТИЧНОЕ СОВПАДЕНИЕ БЕЗ СТОП-СЛОВ (только если не было частичного совпадения с полным текстом)
            elif (match_priority < MATCH_PRIORITIES['partial_clean'] and 
                  match_priority < MATCH_PRIORITIES['partial_full'] and
                  (target_clean.lower() in product_clean.lower() or
                   product_clean.lower() in target_clean.lower())):
                similarity = SequenceMatcher(None, target_clean.lower(), product_clean.lower()).ratio()
                if similarity >= SIMILARITY_THRESHOLDS['partial_clean']:
                    match_priority = MATCH_PRIORITIES['partial_clean']
                    similarity_score = similarity
                    logger.debug(f"Partial clean match: '{product_name}' (similarity: {similarity:.2f})")
            
            # Если нашли совпадение, выбираем лучший вариант
            if match_priority > 0:
                # Для точного совпадения возвращаем оригинальную схожесть
                if match_priority == MATCH_PRIORITIES['exact_full']:
                    final_similarity = 1.0
                else:
                    final_similarity = similarity_score
                
                # Комбинированная оценка: приоритет + схожесть + цена
                price_factor = 1 / (product_data["price"] + 0.1) * 0.1
                combined_score = match_priority * 10 + final_similarity + price_factor
                
                if best_match is None or combined_score > best_similarity:
                    best_match = (product_id, product_data)
                    best_similarity = final_similarity  # Возвращаем оригинальную схожесть
                    best_priority = match_priority
        
        if best_match:
            product_id, product_data = best_match
            match_type = MatchType.NONE
            
            # Определяем тип сопоставления
            for match_type_name, priority in MATCH_PRIORITIES.items():
                if best_priority == priority:
                    match_type = MatchType(match_type_name)
                    break
            
            logger.info(f"Best match found: '{product_data['name']}' (type: {match_type.value}, score: {best_similarity:.2f})")
            return product_id, product_data, best_similarity, match_type
        
        logger.warning(f"No match found for product: '{target_product}'")
        return None, None, 0, MatchType.NONE