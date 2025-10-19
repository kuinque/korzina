"""
Модели данных
"""
from typing import List, Optional, Dict, Any, Union
from enum import Enum
from pydantic import BaseModel, Field, field_validator


class Offer(BaseModel):
    """Модель предложения (offer) из базы данных"""
    offer_id: int
    title: str
    description: Optional[str] = None
    price: Optional[int] = None
    currency: Optional[str] = None
    images: Optional[List[str]] = None
    category_id: Optional[int] = None
    category_name: Optional[str] = None
    tags: Optional[List[str]] = None
    seller_name: Optional[str] = None


class MatchType(str, Enum):
    """Типы сопоставления товаров"""
    EXACT_FULL = "exact_full"
    PARTIAL_FULL = "partial_full"
    EXACT_CLEAN = "exact_clean"
    PARTIAL_CLEAN = "partial_clean"
    NONE = "none"


class ProductMatch(BaseModel):
    """Результат сопоставления товара"""
    target: str
    found: str
    price: float
    similarity: float
    match_type: MatchType
    product_id: Optional[str] = None
    offer_data: Optional[Dict[str, Any]] = None  # Полные данные оффера из БД

    class Config:
        use_enum_values = True


class ShopSolution(BaseModel):
    """Решение для магазина"""
    shop_id: str
    shop_name: str
    total_price: float
    found_products: List[ProductMatch]
    match_percentage: float
    products_found_count: int


class SearchRequest(BaseModel):
    """Запрос на поиск товаров"""
    products: List[str]
    
    @field_validator('products', mode='before')
    @classmethod
    def validate_products(cls, v: Union[List[str], str]) -> List[str]:
        """Валидация и преобразование товаров"""
        if isinstance(v, str):
            products = [name.strip() for name in v.split(",") if name.strip()]
        elif isinstance(v, list):
            products = [str(p).strip() for p in v if str(p).strip()]
        else:
            raise ValueError("Products must be either a string or a list")
        
        if not products:
            raise ValueError("Products list cannot be empty")
        
        return products


class SearchResponse(BaseModel):
    """Ответ на поиск товаров"""
    status: str
    best_shop: Optional[Dict[str, Any]] = None
    total_price: Optional[float] = None
    products_found: Optional[int] = None
    products_total: Optional[int] = None
    match_percentage: Optional[float] = None
    products: Optional[List[Dict[str, Any]]] = None
    error: Optional[str] = None


class ProductsQueryParams(BaseModel):
    """Параметры запроса товаров магазина"""
    shop: str = Field(..., description="Название магазина")
    q: Optional[str] = Field(None, description="Поисковый запрос")


class HealthResponse(BaseModel):
    """Ответ health check"""
    status: str
    message: str
    version: str
    database: str


class StatsResponse(BaseModel):
    """Ответ со статистикой"""
    status: str
    shops_count: int
    products_count: int
    shops: List[str]


class ErrorResponse(BaseModel):
    """Ответ с ошибкой"""
    status: str = "error"
    message: str