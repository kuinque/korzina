"""
Тесты для сервисов
"""
import pytest
from unittest.mock import Mock, patch
from app.services.product_service import ProductService
from app.services.shop_search_service import ShopSearchService
from app.models import SearchRequest, MatchType


class TestProductService:
    """Тесты для ProductService"""
    
    def test_remove_stop_words(self):
        """Тест удаления стоп-слов"""
        service = ProductService()
        
        # Тест с стоп-словами
        result = service.remove_stop_words("большие красные яблоки")
        assert result == "красные яблоки"
        
        # Тест без стоп-слов
        result = service.remove_stop_words("красные яблоки")
        assert result == "красные яблоки"
    
    def test_find_best_product_match_exact(self):
        """Тест точного совпадения"""
        service = ProductService()
        
        shop_products = {
            "1": {
                "name": "Яблоки красные",
                "price": 50.0,
                "clean_name": "яблоки красные"
            }
        }
        
        product_id, product_data, similarity, match_type = service.find_best_product_match(
            "Яблоки красные", shop_products, set()
        )
        
        assert product_id == "1"
        assert product_data["name"] == "Яблоки красные"
        assert similarity == 1.0
        assert match_type == MatchType.EXACT_FULL
    
    def test_find_best_product_match_clean(self):
        """Тест совпадения без стоп-слов"""
        service = ProductService()
        
        shop_products = {
            "1": {
                "name": "Большие красные яблоки",
                "price": 50.0,
                "clean_name": "красные яблоки"
            }
        }
        
        product_id, product_data, similarity, match_type = service.find_best_product_match(
            "красные яблоки", shop_products, set()
        )
        
        assert product_id == "1"
        assert match_type == MatchType.PARTIAL_FULL
    
    def test_find_best_product_match_none(self):
        """Тест отсутствия совпадения"""
        service = ProductService()
        
        shop_products = {
            "1": {
                "name": "Бананы",
                "price": 50.0,
                "clean_name": "бананы"
            }
        }
        
        product_id, product_data, similarity, match_type = service.find_best_product_match(
            "яблоки", shop_products, set()
        )
        
        assert product_id is None
        assert product_data is None
        assert similarity == 0
        assert match_type == MatchType.NONE


class TestShopSearchService:
    """Тесты для ShopSearchService"""
    
    @patch('app.database.client.db_client.get_all_offers')
    def test_find_cheapest_shop_success(self, mock_offers):
        """Тест успешного поиска магазина"""
        mock_offers.return_value = [
            {
                "offer_id": 1,
                "title": "Яблоки",
                "seller_name": "Test Shop",
                "price": 50
            }
        ]
        
        service = ShopSearchService()
        search_request = SearchRequest(products=["яблоки"])
        
        result = service.find_cheapest_shop(search_request)
        
        assert result is not None
        assert result.shop_name == "Test Shop"
        assert result.total_price == 50.0
        assert result.products_found_count == 1
    
    @patch('app.database.client.db_client.get_all_offers')
    def test_find_cheapest_shop_no_results(self, mock_offers):
        """Тест поиска без результатов"""
        mock_offers.return_value = [
            {
                "offer_id": 1,
                "title": "Бананы",
                "seller_name": "Test Shop",
                "price": 50
            }
        ]
        
        service = ShopSearchService()
        search_request = SearchRequest(products=["яблоки"])
        
        result = service.find_cheapest_shop(search_request)
        
        assert result is None
