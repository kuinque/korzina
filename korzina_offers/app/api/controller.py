"""
API слой с валидацией и обработкой ошибок
"""
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from typing import Dict, Any
import json

from app.config import config
from app.core.logger import get_logger
from app.models import SearchRequest, SearchResponse
from app.services.shop_search_service import ShopSearchService
from app.database.client import db_client
from app.core.constants import HTTP_STATUS

logger = get_logger(__name__)


class APIError(Exception):
    """Базовый класс для API ошибок"""
    def __init__(self, message: str, status_code: int = HTTP_STATUS['INTERNAL_ERROR']):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)


class ValidationError(APIError):
    """Ошибка валидации"""
    def __init__(self, message: str):
        super().__init__(message, HTTP_STATUS['BAD_REQUEST'])


class APIController:
    """Контроллер для API endpoints"""
    
    def __init__(self):
        self.shop_search_service = ShopSearchService()
    
    def health_check(self) -> Response:
        """Проверка работы сервера"""
        try:
            db_healthy = db_client.health_check()
            
            if db_healthy:
                data = {
                    "status": "success",
                    "message": "Shop Finder API работает!",
                    "version": "1.0",
                    "database": "healthy"
                }
                return self._create_response(data, HTTP_STATUS['OK'])
            else:
                data = {
                    "status": "error",
                    "message": "Database connection failed",
                    "version": "1.0",
                    "database": "unhealthy"
                }
                return self._create_response(data, HTTP_STATUS['INTERNAL_ERROR'])
            
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return self._create_error_response("Health check failed", HTTP_STATUS['INTERNAL_ERROR'])
    
    def get_stats(self) -> Response:
        """Получить статистику базы данных"""
        try:
            shops = db_client.get_shops()
            products = db_client.get_all_products()
            
            data = {
                "status": "success",
                "shops_count": len(shops),
                "products_count": len(products),
                "shops": [shop["name"] for shop in shops[:10]]
            }
            
            return self._create_response(data)
            
        except Exception as e:
            logger.error(f"Error getting stats: {e}")
            return self._create_error_response("Failed to get statistics", HTTP_STATUS['INTERNAL_ERROR'])

    def get_products(self) -> Response:
        """Получить товары для конкретного магазина с опциональным поиском

        Query params:
          - shop: имя магазина (обязательный)
          - q: строка поиска (необязательный)
        """
        try:
            shop_name = request.args.get('shop', '').strip()
            query = request.args.get('q', '').strip()

            if not shop_name:
                raise ValidationError("Missing 'shop' parameter")

            shop = db_client.get_shop_by_name(shop_name)
            if not shop:
                return self._create_error_response("Shop not found", HTTP_STATUS['NOT_FOUND'])

            prices = db_client.get_prices_for_shop_with_details(shop["id"])  # type: ignore[index]

            # Список уникальных товаров по продукту (если в ценах дубликаты)
            products_map = {}
            for price in prices:
                product_id = price["product_id"]
                product_name = price["products"]["name"]
                product_price = price["price"]
                if product_id not in products_map or product_price < products_map[product_id]["price"]:
                    products_map[product_id] = {"id": product_id, "name": product_name, "price": product_price}

            products_list = list(products_map.values())

            if query:
                qlower = query.lower()
                products_list = [p for p in products_list if qlower in str(p["name"]).lower()]

            data = {
                "status": "success",
                "shop": {"id": shop["id"], "name": shop["name"]},  # type: ignore[index]
                "count": len(products_list),
                "products": products_list
            }
            return self._create_response(data)
        except ValidationError as e:
            logger.warning(f"Validation error: {e.message}")
            return self._create_error_response(e.message, e.status_code)
        except Exception as e:
            logger.error(f"Get products error: {e}")
            return self._create_error_response("Internal server error", HTTP_STATUS['INTERNAL_ERROR'])
    
    def search_products(self) -> Response:
        """Поиск товаров (POST)"""
        try:
            # Валидация входных данных
            if not request.is_json:
                raise ValidationError("Content-Type must be application/json")
            
            data = request.get_json()
            if not data:
                raise ValidationError("No JSON data provided")
            
            if 'products' not in data:
                raise ValidationError("Missing 'products' field")
            
            products_data = data['products']
            
            # Обрабатываем как строку или список
            if isinstance(products_data, str):
                if not products_data or not products_data.strip():
                    raise ValidationError("Products string is empty")
                search_request = SearchRequest.from_string(products_data)
            elif isinstance(products_data, list):
                if not products_data:
                    raise ValidationError("Products list is empty")
                search_request = SearchRequest.from_list(products_data)
                if not search_request.products:
                    raise ValidationError("All products in list are empty")
            else:
                raise ValidationError("Products must be either a string or a list")
            
            # Выполняем поиск
            result = self.shop_search_service.find_cheapest_shop(search_request)
            
            if result:
                response_data = {
                    "status": "success",
                    "best_shop": {
                        "name": result.shop_name,
                        "id": result.shop_id
                    },
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
                            "match_type": p.match_type.value
                        }
                        for p in result.found_products
                    ]
                }
                
                return self._create_response(response_data)
            else:
                return self._create_error_response("No suitable shops found for your products", HTTP_STATUS['NOT_FOUND'])
                
        except ValidationError as e:
            logger.warning(f"Validation error: {e.message}")
            return self._create_error_response(e.message, e.status_code)
        except Exception as e:
            logger.error(f"Search error: {e}")
            return self._create_error_response("Internal server error", HTTP_STATUS['INTERNAL_ERROR'])
    
    def search_products_get(self) -> Response:
        """Поиск товаров (GET для тестов)"""
        try:
            products_string = request.args.get('products', '')
            
            if not products_string:
                raise ValidationError("Missing 'products' parameter")
            
            search_request = SearchRequest.from_string(products_string)
            result = self.shop_search_service.find_cheapest_shop(search_request)
            
            if result:
                response_data = {
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
                
                return self._create_response(response_data)
            else:
                return self._create_error_response("No suitable shops found", HTTP_STATUS['NOT_FOUND'])
                
        except ValidationError as e:
            logger.warning(f"Validation error: {e.message}")
            return self._create_error_response(e.message, e.status_code)
        except Exception as e:
            logger.error(f"Search error: {e}")
            return self._create_error_response("Internal server error", HTTP_STATUS['INTERNAL_ERROR'])
    
    def _create_response(self, data: Dict[str, Any], status_code: int = HTTP_STATUS['OK']) -> Response:
        """Создать успешный ответ"""
        return Response(
            json.dumps(data, ensure_ascii=False, indent=2),
            mimetype='application/json; charset=utf-8',
            status=status_code
        )
    
    def _create_error_response(self, message: str, status_code: int = HTTP_STATUS['INTERNAL_ERROR']) -> Response:
        """Создать ответ с ошибкой"""
        data = {
            "status": "error",
            "message": message
        }
        return Response(
            json.dumps(data, ensure_ascii=False),
            mimetype='application/json; charset=utf-8',
            status=status_code
        )