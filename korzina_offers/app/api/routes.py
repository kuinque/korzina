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


@router.api_route(
    "/health",
    methods=["GET", "POST"],
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
    description="Получить статистику о количестве продавцов и предложений в базе данных"
)
async def get_stats() -> StatsResponse:
    """Получить статистику базы данных"""
    try:
        sellers = db_client.get_unique_sellers()
        offers = db_client.get_all_offers()
        
        return StatsResponse(
            status="success",
            shops_count=len(sellers),
            products_count=len(offers),
            shops=sellers[:10]
        )
        
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get statistics"
        )


@router.get(
    "/offers",
    summary="Получить список офферов",
    description="Получить список офферов с пагинацией и фильтрацией"
)
async def get_offers(
    limit: int = Query(20, description="Количество офферов на странице", ge=1, le=100),
    offset: int = Query(0, description="Смещение для пагинации", ge=0),
    seller: Optional[str] = Query(None, description="Фильтр по продавцу"),
    category: Optional[str] = Query(None, description="Фильтр по категории"),
    q: Optional[str] = Query(None, description="Поиск по названию")
):
    """Получить список офферов с пагинацией"""
    try:
        # Получаем все офферы
        all_offers = db_client.get_all_offers()
        
        # Применяем фильтры
        filtered_offers = all_offers
        
        if seller:
            filtered_offers = [o for o in filtered_offers if o.get("seller_name") == seller]
        
        if category:
            filtered_offers = [o for o in filtered_offers if o.get("category_name") == category]
        
        if q:
            q_lower = q.lower()
            filtered_offers = [
                o for o in filtered_offers 
                if q_lower in str(o.get("title", "")).lower()
            ]
        
        # Применяем пагинацию
        total = len(filtered_offers)
        paginated_offers = filtered_offers[offset:offset + limit]
        
        return {
            "total": total,
            "limit": limit,
            "offset": offset,
            "count": len(paginated_offers),
            "offers": paginated_offers
        }
        
    except Exception as e:
        logger.error(f"Error getting offers: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.get(
    "/products",
    summary="Получить предложения продавца",
    description="Получить список предложений для конкретного продавца с опциональным поиском"
)
async def get_products(
    shop: str = Query(..., description="Название продавца"),
    q: Optional[str] = Query(None, description="Поисковый запрос")
):
    """Получить предложения для конкретного продавца с опциональным поиском"""
    try:
        if not shop.strip():
            raise HTTPException(
                status_code=400,
                detail="Missing 'shop' parameter"
            )

        seller_info = db_client.get_seller_info(shop)
        if not seller_info:
            raise HTTPException(
                status_code=404,
                detail="Seller not found"
            )

        offers = db_client.get_offers_by_seller(shop)

        # Формируем список предложений
        offers_list = []
        for offer in offers:
            offers_list.append({
                "id": offer["offer_id"],
                "name": offer.get("title", ""),
                "price": offer.get("price", 0),
                "description": offer.get("description"),
                "category": offer.get("category_name"),
                "images": offer.get("images", [])
            })

        if q:
            qlower = q.lower()
            offers_list = [o for o in offers_list if qlower in str(o["name"]).lower()]

        return {
            "status": "success",
            "shop": {"id": seller_info["id"], "name": seller_info["name"]},
            "count": len(offers_list),
            "products": offers_list
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
                        "match_type": p.match_type if isinstance(p.match_type, str) else p.match_type.value
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
    description="GET версия endpoint поиска. По умолчанию возвращает JSON массив найденных офферов. С параметром debug=1 возвращает полную отладочную информацию"
)
async def search_products_get(
    products: str = Query(..., description="Список товаров через запятую"),
    debug: int = Query(0, description="Режим отладки: 0 - только офферы, 1 - полная информация с метаданными")
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
            # Режим отладки - полная информация
            if debug == 1:
                return {
                    "status": "success",
                    "best_shop": result.shop_name,
                    "total_price": result.total_price,
                    "products_found": result.products_found_count,
                    "products_total": len(search_request.products),
                    "match_percentage": result.match_percentage,
                    "products": [
                        {
                            "target": p.target,
                            "found": p.found,
                            "price": p.price,
                            "similarity": p.similarity,
                            "match_type": p.match_type if isinstance(p.match_type, str) else p.match_type.value
                        }
                        for p in result.found_products
                    ]
                }
            
            # По умолчанию - только полные данные офферов из БД
            found_offers = []
            for p in result.found_products:
                if p.found != "НЕ НАЙДЕН" and p.offer_data:
                    found_offers.append(p.offer_data)
            return found_offers
        else:
            # Если ничего не найдено - возвращаем пустой массив
            return []
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )

