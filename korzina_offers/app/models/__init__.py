"""
Модели данных
"""
from dataclasses import dataclass
from typing import List, Optional, Dict, Any
from enum import Enum


class MatchType(Enum):
    """Типы сопоставления товаров"""
    EXACT_FULL = "exact_full"
    PARTIAL_FULL = "partial_full"
    EXACT_CLEAN = "exact_clean"
    PARTIAL_CLEAN = "partial_clean"
    NONE = "none"


@dataclass
class ProductMatch:
    """Результат сопоставления товара"""
    target: str
    found: str
    price: float
    similarity: float
    match_type: MatchType
    product_id: Optional[str] = None


@dataclass
class ShopSolution:
    """Решение для магазина"""
    shop_id: str
    shop_name: str
    total_price: float
    found_products: List[ProductMatch]
    match_percentage: float
    products_found_count: int


@dataclass
class SearchRequest:
    """Запрос на поиск товаров"""
    products: List[str]
    
    @classmethod
    def from_string(cls, products_string: str) -> 'SearchRequest':
        """Создать из строки товаров"""
        products = [name.strip() for name in products_string.split(",") if name.strip()]
        return cls(products=products)
    
    @classmethod
    def from_list(cls, products_list: List[str]) -> 'SearchRequest':
        """Создать из списка товаров"""
        products = [str(p).strip() for p in products_list if str(p).strip()]
        return cls(products=products)


@dataclass
class SearchResponse:
    """Ответ на поиск товаров"""
    status: str
    best_shop: Optional[Dict[str, Any]] = None
    total_price: Optional[float] = None
    products_found: Optional[int] = None
    products_total: Optional[int] = None
    match_percentage: Optional[float] = None
    products: Optional[List[Dict[str, Any]]] = None
    error: Optional[str] = None