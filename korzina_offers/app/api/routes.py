"""
FastAPI роуты
"""
from fastapi import APIRouter, HTTPException, Query
from typing import Optional

from app.models import (
    SearchRequest,
    ComparePricesRequest,
    SearchResponse,
    HealthResponse,
    StatsResponse,
    ErrorResponse,
    ProductMatch,
    AlternativesRequest,
    AlternativesResponse
)
from app.services.shop_search_service import ShopSearchService
from app.database.client import cache_manager
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
        db_healthy = cache_manager.health_check()
        
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
        sellers = cache_manager.get_unique_sellers()
        offers = cache_manager.get_all_offers()
        
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
        all_offers = cache_manager.get_all_offers()
        logger.info(f"Total offers: {len(all_offers)}")

        filtered_offers = all_offers

        if seller:
            filtered_offers = [o for o in filtered_offers if o.get("seller_name") == seller]
            logger.info(f"After seller filter: {len(filtered_offers)}")

        if category:
            filtered_offers = [o for o in filtered_offers if o.get("category_name") == category]
            logger.info(f"After category filter: {len(filtered_offers)}")

        if q:
            q_lower = q.lower()
            filtered_offers = [
                o for o in filtered_offers
                if q_lower in str(o.get("title", "")).lower()
            ]
            logger.info(f"After q filter '{q}': {len(filtered_offers)}")
        
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
    q: Optional[str] = Query(None, description="Поисковый запрос"),
    category: Optional[str] = Query(None, description="Фильтр по категории")
):
    """Получить предложения для конкретного продавца с опциональным поиском"""
    try:
        if not shop.strip():
            raise HTTPException(
                status_code=400,
                detail="Missing 'shop' parameter"
            )

        seller_info = cache_manager.get_seller_info(shop)
        if not seller_info:
            raise HTTPException(
                status_code=404,
                detail="Seller not found"
            )

        offers = cache_manager.get_offers_by_seller(shop)

        # Формируем список предложений
        offers_list = []
        for offer in offers:
            # Безопасное преобразование цены
            price_raw = offer.get("price", 0)
            try:
                price = float(price_raw) if price_raw else 0.0
            except (ValueError, TypeError):
                price = 0.0
            
            offers_list.append({
                "id": offer["offer_id"],
                "name": offer.get("title", ""),
                "price": price,
                "description": offer.get("description"),
                "category": offer.get("category_name"),
                "images": offer.get("images", [])
            })

        # Применяем фильтры
        if q:
            qlower = q.lower()
            offers_list = [o for o in offers_list if qlower in str(o["name"]).lower()]
        
        if category:
            offers_list = [o for o in offers_list if o.get("category") == category]

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


@router.post(
    "/search-product-in-shop",
    summary="Поиск одного товара в магазине",
    description="Найти похожий товар в конкретном магазине (для инкрементального обновления корзины)"
)
async def search_product_in_shop(
    product_name: str = Query(..., description="Название товара для поиска"),
    shop_name: str = Query(..., description="Название магазина")
):
    """Найти похожий товар в конкретном магазине"""
    try:
        # Создаем простой запрос с одним товаром
        request = SearchRequest(products=[product_name], shop=shop_name)
        
        # Ищем товар в магазине
        result = shop_search_service.find_products_in_shop(request, shop_name)
        
        if result and result.products_found_count > 0:
            # Возвращаем первый найденный товар
            found_product = result.found_products[0]
            
            if found_product.found != "НЕ НАЙДЕН" and found_product.offer_data:
                # Безопасное преобразование цены
                price_raw = found_product.offer_data.get("price")
                try:
                    price = float(price_raw) if price_raw else 0.0
                except (ValueError, TypeError):
                    price = 0.0
                
                return {
                    "status": "success",
                    "found": True,
                    "product": {
                        "name": found_product.offer_data.get("title"),
                        "price": price,
                        "image": found_product.offer_data.get("images", [None])[0],
                        "description": found_product.offer_data.get("description"),
                        "category": found_product.offer_data.get("category_name"),
                        "similarity": found_product.similarity
                    }
                }
        
        return {
            "status": "success",
            "found": False,
            "product": None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Search product in shop error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.post(
    "/compare_prices",
    summary="Сравнение цен по магазинам",
    description="Находит магазин с самой дешевой корзиной и возвращает список товаров из этого магазина"
)
async def compare_prices(
        offer_ids: list[str] = Query(..., description="Список ID офферов для сравнения")
):
    """Сравнить цены корзины и вернуть товары из самого дешевого магазина"""
    try:
        if not offer_ids:
            raise HTTPException(
                status_code=400,
                detail="Missing 'offer_ids' parameter"
            )

        # Получаем все офферы
        all_offers = cache_manager.get_all_offers()

        # Фильтруем нужные офферы
        selected_offers = [
            offer for offer in all_offers
            if offer.get("offer_id") in offer_ids
        ]

        if not selected_offers:
            raise HTTPException(
                status_code=404,
                detail="No offers found with provided IDs"
            )

        # Группируем по магазинам и считаем сумму
        shop_totals = {}
        shop_products = {}

        for offer in selected_offers:
            shop_name = offer.get("seller_name")
            price = offer.get("price", 0)

            if shop_name not in shop_totals:
                shop_totals[shop_name] = 0
                shop_products[shop_name] = []

            shop_totals[shop_name] += price
            shop_products[shop_name].append({
                "id": offer.get("offer_id"),
                "name": offer.get("title"),
                "price": price,
                "category": offer.get("category_name"),
                "description": offer.get("description"),
                "images": offer.get("images", [])
            })

        # Находим самый дешевый магазин
        cheapest_shop = min(shop_totals.items(), key=lambda x: x[1])
        cheapest_shop_name = cheapest_shop[0]
        cheapest_total_price = cheapest_shop[1]

        return {
            "status": "success",
            "shop_name": cheapest_shop_name,
            "total_price": cheapest_total_price,
            "products_count": len(shop_products[cheapest_shop_name]),
            "products": shop_products[cheapest_shop_name]
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Compare prices error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.post(
    "/compare-prices",
    summary="Сравнение цен",
    description="Сравнить цены товаров из корзины во всех магазинах"
)
async def compare_prices_v2(request: ComparePricesRequest):
    """Сравнить цены товаров во всех магазинах"""
    try:
        if not request.products:
            # Возвращаем пустой результат для пустой корзины
            return {
                "status": "success",
                "comparisons": []
            }
        
        # Получаем все магазины
        all_sellers = cache_manager.get_unique_sellers()
        comparison_results = []
        
        for seller in all_sellers:
            try:
                # Ищем товары в конкретном магазине
                result = shop_search_service.find_products_in_shop(request, seller)
                
                if result and result.products_found_count > 0:
                    # Формируем полную информацию о товарах
                    products_list = []
                    for p in result.found_products:
                        if p.found != "НЕ НАЙДЕН" and p.offer_data:
                            # Безопасное преобразование цены
                            price_raw = p.offer_data.get("price")
                            try:
                                price = float(price_raw) if price_raw else 0.0
                            except (ValueError, TypeError):
                                price = 0.0
                            
                            products_list.append({
                                "target": p.target,
                                "found": p.found,
                                "price": price,
                                "similarity": p.similarity,
                                "match_type": p.match_type if isinstance(p.match_type, str) else p.match_type.value,
                                "name": p.offer_data.get("title"),
                                "image": p.offer_data.get("images", [None])[0],
                                "description": p.offer_data.get("description"),
                                "category": p.offer_data.get("category_name")
                            })
                    
                    comparison_results.append({
                        "shop_name": seller,
                        "total_price": result.total_price,
                        "products_found": result.products_found_count,
                        "products_total": len(request.products),
                        "match_percentage": result.match_percentage,
                        "products": products_list
                    })
                else:
                    # Если товары не найдены в этом магазине
                    comparison_results.append({
                        "shop_name": seller,
                        "total_price": None,
                        "products_found": 0,
                        "products_total": len(request.products),
                        "match_percentage": 0.0,
                        "products": []
                    })
            except Exception as e:
                logger.error(f"Error comparing prices for {seller}: {e}")
                comparison_results.append({
                    "shop_name": seller,
                    "total_price": None,
                    "products_found": 0,
                    "products_total": len(request.products),
                    "match_percentage": 0.0,
                    "products": []
                })
        
        # Сортируем по цене (сначала магазины с найденными товарами)
        comparison_results.sort(key=lambda x: (x["total_price"] is None, x["total_price"] or float('inf')))
        
        return {
            "status": "success",
            "comparisons": comparison_results
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Compare prices error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.post(
    "/all_alternatives",
    response_model=AlternativesResponse,
    summary="Альтернативы по всем магазинам",
    description="Для списка офферов возвращает похожие предложения для каждого магазина"
)
async def get_all_alternatives(request: AlternativesRequest) -> AlternativesResponse:
    """Получить альтернативы для набора офферов по всем магазинам"""
    try:
        alternatives = shop_search_service.find_alternatives_for_offers(request.offer_ids)
        return AlternativesResponse(
            status="success",
            request_count=len(request.offer_ids),
            total_shops=len(alternatives),
            shops=alternatives
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc)
        ) from exc
    except Exception as exc:
        logger.error(f"All alternatives error: {exc}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        ) from exc


@router.get(
    "/cache/info",
    summary="Информация о кэше",
    description="Получить информацию о состоянии кэша в памяти"
)
async def get_cache_info():
    """Получить информацию о состоянии кэша"""
    try:
        cache_info = cache_manager.get_cache_info()
        return {
            "status": "success",
            **cache_info
        }
    except Exception as e:
        logger.error(f"Error getting cache info: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.post(
    "/cache/refresh",
    summary="Обновить кэш",
    description="Принудительно обновить кэш, загрузив данные из базы данных"
)
async def refresh_cache():
    """Обновить кэш"""
    try:
        logger.info("Manual cache refresh requested")
        success = cache_manager.refresh_cache()
        
        if success:
            cache_info = cache_manager.get_cache_info()
            return {
                "status": "success",
                "message": "Cache refreshed successfully",
                **cache_info
            }
        else:
            raise HTTPException(
                status_code=500,
                detail="Failed to refresh cache"
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error refreshing cache: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )


@router.get("/debug/search-in-cache")
async def debug_search_in_cache(q: str = Query(..., description="Что искать")):
    """Поиск товара напрямую в кэше для отладки"""
    try:
        all_offers = cache_manager.get_all_offers()

        q_lower = q.lower()
        found = []

        for offer in all_offers:
            title = str(offer.get("title", "")).lower()
            if q_lower in title:
                found.append({
                    "offer_id": offer.get("offer_id"),
                    "title": offer.get("title"),
                    "seller": offer.get("seller_name"),
                    "price": offer.get("price")
                })

        return {
            "query": q,
            "total_in_cache": len(all_offers),
            "found_count": len(found),
            "results": found[:10]  # первые 10
        }
    except Exception as e:
        logger.error(f"Debug search error: {e}", exc_info=True)
        return {"error": str(e)}
