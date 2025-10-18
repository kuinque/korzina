"""
Тесты для API
"""
import pytest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from app.api import create_app
from app.models import SearchRequest, ShopSolution, ProductMatch, MatchType


@pytest.fixture
def app():
    """Создать тестовое приложение"""
    return create_app()


@pytest.fixture
def client(app):
    """Создать тестовый клиент"""
    return TestClient(app)


@pytest.fixture
def mock_shop_solution():
    """Мок решения для магазина"""
    return ShopSolution(
        shop_id="1",
        shop_name="Test Shop",
        total_price=100.0,
        found_products=[
            ProductMatch(
                target="яблоки",
                found="Яблоки красные",
                price=50.0,
                similarity=0.9,
                match_type=MatchType.EXACT_CLEAN
            )
        ],
        match_percentage=1.0,
        products_found_count=1
    )


class TestHealthEndpoint:
    """Тесты для endpoint /api/health"""
    
    @patch('app.database.client.db_client.health_check')
    def test_health_check_success(self, mock_health_check, client):
        """Тест успешной проверки здоровья"""
        mock_health_check.return_value = True
        
        response = client.get('/api/health')
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'success'
        assert data['database'] == 'healthy'
    
    @patch('app.database.client.db_client.health_check')
    def test_health_check_failure(self, mock_health_check, client):
        """Тест неудачной проверки здоровья"""
        mock_health_check.return_value = False
        
        response = client.get('/api/health')
        
        assert response.status_code == 500
        data = response.json()
        assert data['detail'] == 'Database connection failed'


class TestStatsEndpoint:
    """Тесты для endpoint /api/stats"""
    
    @patch('app.database.client.db_client.get_shops')
    @patch('app.database.client.db_client.get_all_products')
    def test_get_stats_success(self, mock_products, mock_shops, client):
        """Тест успешного получения статистики"""
        mock_shops.return_value = [{'name': 'Shop 1'}, {'name': 'Shop 2'}]
        mock_products.return_value = [{'name': 'Product 1'}, {'name': 'Product 2'}]
        
        response = client.get('/api/stats')
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'success'
        assert data['shops_count'] == 2
        assert data['products_count'] == 2


class TestSearchEndpoint:
    """Тесты для endpoint /api/search"""
    
    def test_search_no_products_field(self, client):
        """Тест запроса без поля products"""
        response = client.post('/api/search', json={})
        
        assert response.status_code == 422  # FastAPI validation error
        data = response.json()
        assert 'detail' in data
    
    def test_search_empty_products(self, client):
        """Тест запроса с пустым списком товаров"""
        response = client.post('/api/search', json={'products': ''})
        
        assert response.status_code == 422  # FastAPI validation error
        data = response.json()
        assert 'detail' in data
    
    @patch('app.services.shop_search_service.ShopSearchService.find_cheapest_shop')
    def test_search_success(self, mock_find_shop, client, mock_shop_solution):
        """Тест успешного поиска"""
        mock_find_shop.return_value = mock_shop_solution
        
        response = client.post('/api/search', json={'products': 'яблоки'})
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'success'
        assert data['best_shop']['name'] == 'Test Shop'
        assert data['total_price'] == 100.0
    
    @patch('app.services.shop_search_service.ShopSearchService.find_cheapest_shop')
    def test_search_no_results(self, mock_find_shop, client):
        """Тест поиска без результатов"""
        mock_find_shop.return_value = None
        
        response = client.post('/api/search', json={'products': 'яблоки'})
        
        assert response.status_code == 404
        data = response.json()
        assert 'detail' in data
        assert 'No suitable shops found' in data['detail']


class TestSearchGetEndpoint:
    """Тесты для endpoint /api/search/get"""
    
    def test_search_get_no_products(self, client):
        """Тест GET запроса без параметра products"""
        response = client.get('/api/search/get')
        
        assert response.status_code == 422  # FastAPI validation error
        data = response.json()
        assert 'detail' in data
    
    @patch('app.services.shop_search_service.ShopSearchService.find_cheapest_shop')
    def test_search_get_success(self, mock_find_shop, client, mock_shop_solution):
        """Тест успешного GET поиска"""
        mock_find_shop.return_value = mock_shop_solution
        
        response = client.get('/api/search/get?products=яблоки')
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'success'
        assert data['best_shop'] == 'Test Shop'