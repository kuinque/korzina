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
    subcategory: Optional[str] = None


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


class AlternativesRequest(BaseModel):
    """Запрос для поиска альтернатив по списку офферов"""
    offer_ids: List[int] = Field(..., description="Список ID офферов", min_length=1)

    @field_validator("offer_ids")
    @classmethod
    def validate_offer_ids(cls, value: List[int]) -> List[int]:
        """Проверка списка офферов"""
        if not value:
            raise ValueError("offer_ids list cannot be empty")

        normalized = []
        for offer_id in value:
            offer_int = int(offer_id)
            if offer_int < 0:
                raise ValueError("offer_ids must contain only positive values")
            normalized.append(offer_int)
        return normalized


class AlternativeMatch(BaseModel):
    """Результат поиска альтернатив для товара"""
    offer_number: int = 1
    target_offer_id: int
    target_title: Optional[str]
    match_type: MatchType = MatchType.NONE
    similarity: float = 0.0
    is_identical: bool = False
    is_duplicated: bool = False  # True если товар продублирован из другого магазина
    matched_offer: Optional[Dict[str, Any]] = None


class AlternativesResponse(BaseModel):
    """Ответ с альтернативами по магазинам"""
    status: str = "success"
    request_count: int
    total_shops: int
    shops: Dict[str, List[AlternativeMatch]]