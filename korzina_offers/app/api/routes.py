"""
FastAPI роуты
"""
from fastapi import APIRouter, HTTPException, Query
from typing import Optional

from app.models import (
    SearchRequest,
    SearchResponse,
    HealthResponse,
    StatsResponse,
    ErrorResponse,
    ProductMatch
)
from app.services.shop_search_service import ShopSearchService
from app.database.client import db_client
from app.core.logger import get_logger

logger = get_logger(__name__)

# Создаем роутер
router = APIRouter(prefix="/api", tags=["api"])

# Инициализируем сервис
shop_search_service = ShopSearchService()


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Проверка работы сервера",
    description="Health check endpoint для проверки состояния сервера и подключения к базе данных"
)
async def health_check() -> HealthResponse:
    """Проверка работы сервера"""
    try:
        db_healthy = db_client.health_check()
        
        if db_healthy:
            return HealthResponse(
                status="success",
                message="Shop Finder API работает!",
                version="1.0",
                database="healthy"
            )
        else:
            raise HTTPException(
                status_code=500,
                detail="Database connection failed"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(
            status_code=500,
            detail="Health check failed"
        )


@router.get(
    "/stats",
    response_model=StatsResponse,
    summary="Статистика базы данных",
    description="Получить статистику о количестве магазинов и товаров в базе данных"
)
async def get_stats() -> StatsResponse:
    """Получить статистику базы данных"""
    try:
        shops = db_client.get_shops()
        products = db_client.get_all_products()
        
        return StatsResponse(
            status="success",
            shops_count=len(shops),
            products_count=len(products),
            shops=[shop["name"] for shop in shops[:10]]
        )
        
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get statistics"
        )


@router.get(
    "/products",
    summary="Получить товары магазина",
    description="Получить список товаров для конкретного магазина с опциональным поиском"
)
async def get_products(
    shop: str = Query(..., description="Название магазина"),
    q: Optional[str] = Query(None, description="Поисковый запрос")
):
    """Получить товары для конкретного магазина с опциональным поиском"""
    try:
        if not shop.strip():
            raise HTTPException(
                status_code=400,
                detail="Missing 'shop' parameter"
            )

        shop_obj = db_client.get_shop_by_name(shop)
        if not shop_obj:
            raise HTTPException(
                status_code=404,
                detail="Shop not found"
            )

        prices = db_client.get_prices_for_shop_with_details(shop_obj["id"])

        # Список уникальных товаров по продукту (если в ценах дубликаты)
        products_map = {}
        for price in prices:
            product_id = price["product_id"]
            product_name = price["products"]["name"]
            product_price = price["price"]
            if product_id not in products_map or product_price < products_map[product_id]["price"]:
                products_map[product_id] = {"id": product_id, "name": product_name, "price": product_price}

        products_list = list(products_map.values())

        if q:
            qlower = q.lower()
            products_list = [p for p in products_list if qlower in str(p["name"]).lower()]

        return {
            "status": "success",
            "shop": {"id": shop_obj["id"], "name": shop_obj["name"]},
            "count": len(products_list),
            "products": products_list
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get products error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.post(
    "/search",
    response_model=SearchResponse,
    summary="Поиск товаров",
    description="Основной endpoint для поиска самого дешевого магазина по списку товаров"
)
async def search_products(request: SearchRequest) -> SearchResponse:
    """Поиск товаров (POST)"""
    try:
        # Выполняем поиск
        result = shop_search_service.find_cheapest_shop(request)
        
        if result:
            return SearchResponse(
                status="success",
                best_shop={
                    "name": result.shop_name,
                    "id": result.shop_id
                },
                total_price=result.total_price,
                products_found=result.products_found_count,
                products_total=len(request.products),
                match_percentage=result.match_percentage,
                products=[
                    {
                        "target": p.target,
                        "found": p.found,
                        "price": p.price,
                        "similarity": p.similarity,
                        "match_type": p.match_type.value
                    }
                    for p in result.found_products
                ]
            )
        else:
            raise HTTPException(
                status_code=404,
                detail="No suitable shops found for your products"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.get(
    "/search/get",
    summary="Поиск товаров (GET)",
    description="GET версия endpoint поиска для тестирования"
)
async def search_products_get(
    products: str = Query(..., description="Список товаров через запятую")
):
    """Поиск товаров (GET для тестов)"""
    try:
        if not products:
            raise HTTPException(
                status_code=400,
                detail="Missing 'products' parameter"
            )
        
        search_request = SearchRequest(products=products)
        result = shop_search_service.find_cheapest_shop(search_request)
        
        if result:
            return {
                "status": "success",
                "best_shop": result.shop_name,
                "total_price": result.total_price,
                "products_found": result.products_found_count,
                "products_total": len(search_request.products),
                "products": [
                    {
                        "target": p.target,
                        "found": p.found,
                        "price": p.price,
                        "similarity": p.similarity,
                        "match_type": p.match_type.value
                    }
                    for p in result.found_products
                ]
            }
        else:
            raise HTTPException(
                status_code=404,
                detail="No suitable shops found"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )

