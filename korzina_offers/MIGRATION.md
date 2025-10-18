# Миграция с Flask на FastAPI

## 📋 Обзор изменений

Проект успешно мигрирован с **Flask** на **FastAPI** для улучшения производительности, автоматической документации и современного подхода к разработке API.

## 🎯 Основные улучшения

### 1. FastAPI вместо Flask
- ✅ Автоматическая документация (Swagger UI, ReDoc)
- ✅ Встроенная валидация данных через Pydantic
- ✅ Поддержка асинхронности (готовность к будущему)
- ✅ Лучшая производительность
- ✅ OpenAPI спецификация из коробки

### 2. Pydantic Models
- Все модели переведены с `dataclass` на `BaseModel` от Pydantic
- Автоматическая валидация входных данных
- Сериализация и десериализация JSON
- Type hints используются для валидации

### 3. Pydantic Settings
- Конфигурация теперь управляется через `pydantic-settings`
- Автоматическая загрузка из `.env` файла
- Валидация переменных окружения
- Type-safe конфигурация

### 4. Uvicorn Server
- FastAPI использует ASGI сервер Uvicorn
- Поддержка hot-reload в режиме разработки
- Лучшая производительность по сравнению с WSGI

## 🔄 Изменения в коде

### Dependencies (requirements.txt)

**Удалено:**
```
flask==3.1.2
flask-cors==6.0.1
```

**Добавлено:**
```
fastapi==0.115.0
uvicorn[standard]==0.32.0
pydantic-settings>=2.0.0
httpx==0.27.0  # для тестов
```

### Структура API

**Было (Flask):**
```python
# app/api/controller.py
class APIController:
    def search_products(self) -> Response:
        data = request.get_json()
        # ручная валидация
        ...
```

**Стало (FastAPI):**
```python
# app/api/routes.py
@router.post("/search", response_model=SearchResponse)
async def search_products(request: SearchRequest) -> SearchResponse:
    # автоматическая валидация через Pydantic
    ...
```

### Модели

**Было:**
```python
from dataclasses import dataclass

@dataclass
class SearchRequest:
    products: List[str]
```

**Стало:**
```python
from pydantic import BaseModel

class SearchRequest(BaseModel):
    products: Union[List[str], str]
    
    @field_validator('products', mode='before')
    @classmethod
    def validate_products(cls, v):
        # валидация
```

### Конфигурация

**Было:**
```python
@dataclass
class Config:
    FLASK_ENV: str = os.getenv('FLASK_ENV', 'development')
```

**Стало:**
```python
from pydantic_settings import BaseSettings

class Config(BaseSettings):
    APP_ENV: str = "development"
    
    model_config = SettingsConfigDict(env_file=".env")
```

### Тесты

**Было:**
```python
from app.api import create_app

def test_health(client):
    response = client.get('/api/health')
    data = response.get_json()
```

**Стало:**
```python
from fastapi.testclient import TestClient
from app.api import create_app

def test_health(client):
    response = client.get('/api/health')
    data = response.json()
```

## 🚀 Как запустить после миграции

### 1. Обновите зависимости

```bash
pip install -r requirements.txt
```

### 2. Создайте .env файл

```bash
cp .env.example .env
# Заполните SUPABASE_URL и SUPABASE_KEY
```

### 3. Запустите приложение

```bash
# С auto-reload для разработки
python main.py

# Или напрямую с uvicorn
uvicorn main:app --reload

# Для production
uvicorn main:app --host 0.0.0.0 --port 5000 --workers 4
```

### 4. Откройте документацию

- Swagger UI: http://localhost:5000/docs
- ReDoc: http://localhost:5000/redoc
- OpenAPI JSON: http://localhost:5000/openapi.json

## 📝 Переменные окружения

**Изменения в названиях:**
- `FLASK_ENV` → `APP_ENV`
- Все остальные переменные остались прежними

## 🧪 Тестирование

Все тесты обновлены для работы с FastAPI:

```bash
# Запуск тестов
pytest

# С покрытием
pytest --cov=app --cov-report=html
```

**Важные изменения в тестах:**
- Используем `TestClient` из `fastapi.testclient`
- `.get_json()` → `.json()`
- Коды ошибок валидации: `400` → `422` (FastAPI validation)
- Формат ошибок: `{'status': 'error', 'message': '...'}` → `{'detail': '...'}`

## 🐳 Docker

Dockerfile обновлен для использования uvicorn:

```dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
```

Для production рекомендуется добавить workers:

```dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000", "--workers", "4"]
```

## 📊 API Endpoints

Все endpoints остались прежними, изменилась только внутренняя реализация:

- `GET /api/health` - Health check
- `GET /api/stats` - Статистика БД
- `GET /api/products` - Товары магазина
- `POST /api/search` - Поиск оптимального магазина
- `GET /api/search/get` - GET версия поиска

## ⚠️ Breaking Changes

### Формат ошибок

**Было:**
```json
{
  "status": "error",
  "message": "Error description"
}
```

**Стало:**
```json
{
  "detail": "Error description"
}
```

### Коды ошибок валидации

- Flask возвращал `400` для ошибок валидации
- FastAPI возвращает `422` (Unprocessable Entity) для ошибок валидации

### Response Models

Теперь все ответы типизированы через Pydantic модели, что обеспечивает:
- Автоматическую валидацию ответов
- Документацию схем в OpenAPI
- Consistency в API

## 🎉 Преимущества после миграции

1. **Автоматическая документация** - Swagger UI и ReDoc доступны из коробки
2. **Валидация данных** - Pydantic обеспечивает строгую валидацию
3. **Производительность** - FastAPI быстрее Flask благодаря ASGI
4. **Type Safety** - Полная типизация с проверкой в runtime
5. **Современный стек** - Актуальные технологии и паттерны
6. **OpenAPI стандарт** - Совместимость с любыми OpenAPI инструментами

## 📚 Дополнительные ресурсы

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [Uvicorn Documentation](https://www.uvicorn.org/)

## 🐛 Известные проблемы

Пока нет известных проблем после миграции. Все тесты проходят успешно.

## 📞 Поддержка

Если у вас возникли проблемы с миграцией, проверьте:

1. Версию Python (требуется 3.9+)
2. Все зависимости установлены
3. .env файл создан и заполнен
4. Переменные окружения правильно названы (APP_ENV вместо FLASK_ENV)

