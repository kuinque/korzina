# Korzina Offers API

Микросервис для поиска товаров в магазинах с интеллектуальным алгоритмом сопоставления.

Построен на **FastAPI** с автоматической документацией (OpenAPI/Swagger).

## 🏗️ Архитектура

Проект построен по принципам **Clean Architecture** с разделением на слои:

```
app/
├── api/              # API слой (FastAPI роуты)
├── services/         # Бизнес-логика
├── database/         # Слой работы с БД
├── models/           # Pydantic модели данных
├── core/             # Основные компоненты (конфиг, логи, константы)
└── config.py         # Конфигурация приложения (Pydantic Settings)
```

## 🚀 Быстрый старт

### Требования
- Python 3.9+ (рекомендуется 3.13.2)
- pip

### Установка зависимостей
```bash
# Установка Python зависимостей
make install
# или
pip install -r requirements.txt
```

### Настройка окружения
```bash
make dev-setup
# или
cp .env.example .env
# Заполните переменные в .env файле
```

### Запуск приложения
```bash
make run
# или
python main.py
# или напрямую с uvicorn
uvicorn main:app --reload
```

После запуска документация API доступна по адресу:
- **Swagger UI**: http://localhost:5000/docs
- **ReDoc**: http://localhost:5000/redoc

## 🐳 Docker

> 📖 **Подробная инструкция**: См. [DOCKER.md](DOCKER.md) для детального руководства по запуску и управлению Docker контейнером.

### Быстрый запуск

#### Способ 1: Используя скрипт (рекомендуется)
```bash
./docker-start.sh
```

#### Способ 2: Используя docker compose
```bash
# Сборка и запуск
make docker-up
# или
docker compose up -d

# Просмотр логов
make docker-logs
# или
docker compose logs -f

# Остановка
make docker-down
# или
docker compose down
```

#### Способ 3: Используя docker напрямую
```bash
# Сборка образа
make docker-build
# или
docker build -t korzina-api .

# Запуск контейнера
docker run -d \
  --name korzina-offers-api \
  -p 5000:5000 \
  --env-file .env \
  --restart unless-stopped \
  korzina-api
```

### Доступ к API

После запуска контейнера API будет доступен:

- **Локально**: `http://localhost:5000`
- **По IP машины**: `http://<IP_МАШИНЫ>:5000`
  - Узнать IP: `hostname -I | awk '{print $1}'`
  - Пример: `http://10.128.0.32:5000`

- **Документация**:
  - Swagger UI: `http://<IP>:5000/docs`
  - ReDoc: `http://<IP>:5000/redoc`

### Полезные команды

```bash
# Пересобрать и перезапустить
make docker-rebuild

# Перезапустить контейнер
make docker-restart

# Просмотр логов
make docker-logs

# Остановить контейнер
make docker-down

# Проверка статуса
docker compose ps
```

### Требования

- Docker и Docker Compose установлены
- Файл `.env` с переменными окружения:
  ```
  SUPABASE_URL=your_supabase_url
  SUPABASE_KEY=your_supabase_key
  ```

## 📚 API Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| `GET/POST` | `/api/health` | Проверка работы сервера и БД |
| `GET` | `/api/stats` | Статистика БД (продавцы и предложения) |
| `GET` | `/api/offers` | Получить список офферов (пагинация + фильтры) |
| `GET` | `/api/products` | Получить предложения конкретного продавца |
| `POST` | `/api/search` | Поиск товаров (основной) |
| `GET` | `/api/search/get` | Поиск товаров (упрощенный формат) |

### Примеры запросов

#### 1. Health Check
```bash
# GET или POST
curl http://localhost:5000/api/health
```

#### 2. Получить офферы (пагинация)
```bash
# Первые 20 офферов (по умолчанию)
curl "http://localhost:5000/api/offers"

# С пагинацией
curl "http://localhost:5000/api/offers?limit=10&offset=20"

# Фильтр по продавцу
curl -G "http://localhost:5000/api/offers" --data-urlencode "seller=Магнит"

# Фильтр по категории
curl -G "http://localhost:5000/api/offers" --data-urlencode "category=Фрукты"

# Поиск по названию
curl -G "http://localhost:5000/api/offers" --data-urlencode "q=молоко"
```

#### 3. Поиск товаров (POST)
```bash
curl -X POST http://localhost:5000/api/search \
  -H "Content-Type: application/json" \
  -d '{"products": ["яблоки", "молоко", "хлеб"]}'
```

#### 4. Поиск товаров (GET - упрощенный)
```bash
# По умолчанию - только массив найденных офферов
curl -G "http://localhost:5000/api/search/get" \
  --data-urlencode "products=яблоки,молоко"

# С debug=1 - полная информация
curl -G "http://localhost:5000/api/search/get" \
  --data-urlencode "products=яблоки,молоко" \
  --data-urlencode "debug=1"
```

## 🧪 Тестирование

### Запуск тестов
```bash
make test
# или
pytest
```

### Тесты с покрытием
```bash
make test-cov
# или
pytest --cov=app --cov-report=html
```

## 🔍 Качество кода

### Линтеры
```bash
make lint
# или
flake8 app tests
mypy app
```

### Форматирование
```bash
make format
# или
black app tests
```

## ⚙️ Конфигурация

### Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `APP_ENV` | Окружение приложения | `development` |
| `DEBUG` | Режим отладки | `true` |
| `HOST` | Хост сервера | `0.0.0.0` |
| `PORT` | Порт сервера | `5000` |
| `SUPABASE_URL` | URL Supabase | - |
| `SUPABASE_KEY` | Ключ Supabase | - |
| `LOG_LEVEL` | Уровень логирования | `INFO` |
| `CORS_ORIGINS` | Разрешенные CORS origins | `*` |
| `PENALTY_PRICE` | Штраф за ненайденный товар | `1000.0` |

### Схема базы данных

```sql
CREATE TABLE offers (
    offer_id      SERIAL PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    price         BIGINT,                -- цена в копейках
    currency      VARCHAR(10),
    images        TEXT[],                -- массив URL изображений
    category_id   INTEGER,
    category_name VARCHAR(255),
    tags          TEXT[],                -- массив тегов
    seller_name   VARCHAR(255)           -- имя продавца
);
```

### Создание .env файла

```bash
# Скопируйте файл примера
cp .env.example .env

# Заполните необходимые переменные
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
```

## 🧠 Алгоритм сопоставления

Система использует умный 4-уровневый алгоритм сопоставления товаров:

### Уровни приоритета

1. **Точное совпадение** (приоритет 4)
   - "яблоки" == "яблоки" 
   - Similarity: 1.0

2. **Частичное совпадение с стоп-словами** (приоритет 3)
   - "яблоки" in "свежие яблоки"
   - Порог similarity: ≥ 0.7

3. **Точное совпадение без стоп-слов** (приоритет 2)
   - "яблоки" == "яблоки" (после удаления "свежие", "большие" и т.д.)
   - Similarity: 0.9

4. **Частичное совпадение без стоп-слов** (приоритет 1)
   - "яблоки" in "яблоки голден"
   - Адаптивный порог:
     - **0.4** если target содержится в product (substring)
     - **0.6** в остальных случаях

### Стоп-слова
Система автоматически фильтрует описательные слова:
`большой`, `маленький`, `свежий`, `спелый`, `крупный`, `сочный`, `целый` и др.

### Примеры работы

| Запрос | Найденный товар | Similarity | Match Type |
|--------|----------------|------------|------------|
| "яблоки" | "Яблоки красные" | 0.60 | partial_clean |
| "молоко" | "Молоко Домик в деревне" | 0.43 | partial_clean |
| "хлеб" | "Хлеб белый" | 0.57 | partial_clean |
| "яблоки красные" | "Яблоки красные" | 1.00 | exact_full |

## 📊 Мониторинг и Документация

- **Автоматическая документация API**: Swagger UI (`/docs`) и ReDoc (`/redoc`)
- **OpenAPI спецификация**: `/openapi.json`
- **Логирование**: стандартный Python logging
- **Health check**: `/api/health` для проверки состояния
- **Статистика БД**: `/api/stats`

## 🛠️ Разработка

### Структура проекта
- **API слой**: FastAPI роуты с автоматической валидацией через Pydantic
- **Сервисы**: Бизнес-логика, алгоритмы сопоставления
- **База данных**: Абстракция для работы с Supabase
- **Модели**: Pydantic модели для валидации и сериализации

### Добавление новых функций
1. Создайте Pydantic модель в `app/models/`
2. Добавьте бизнес-логику в `app/services/`
3. Создайте API endpoint в `app/api/routes.py`
4. Напишите тесты в `tests/` используя `TestClient`

### Технологический стек
- **Framework**: FastAPI 0.115.0
- **Server**: Uvicorn
- **Database**: Supabase (PostgreSQL)
- **Validation**: Pydantic 2.9+
- **Testing**: pytest, httpx
- **Type Checking**: mypy (strict mode)
- **Code Quality**: black, flake8

## 📄 Примеры ответов API

### GET /api/offers
```json
{
  "total": 62,
  "limit": 20,
  "offset": 0,
  "count": 20,
  "offers": [
    {
      "offer_id": 1,
      "title": "Яблоки Голден",
      "description": "Свежие импортные яблоки",
      "price": 12990,
      "currency": "RUB",
      "images": null,
      "category_id": null,
      "category_name": "Фрукты",
      "tags": null,
      "seller_name": "Ашан"
    }
  ]
}
```

### GET /api/search/get?products=яблоки,молоко&debug=1
```json
{
  "status": "success",
  "best_shop": "Магнит",
  "total_price": 19390.0,
  "products_found": 2,
  "products_total": 2,
  "match_percentage": 1.0,
  "products": [
    {
      "target": "яблоки",
      "found": "Яблоки Семеренко",
      "price": 11490.0,
      "similarity": 0.55,
      "match_type": "partial_clean"
    },
    {
      "target": "молоко",
      "found": "Молоко Веселый молочник",
      "price": 7900.0,
      "similarity": 0.41,
      "match_type": "partial_clean"
    }
  ]
}
```

### GET /api/search/get?products=яблоки,молоко (по умолчанию)
```json
[
  {
    "offer_id": 9,
    "title": "Яблоки Семеренко",
    "description": "Зеленые кисло-сладкие",
    "price": 11490,
    "currency": "RUB",
    "category_name": "Фрукты",
    "seller_name": "Магнит"
  },
  {
    "offer_id": 10,
    "title": "Молоко Веселый молочник",
    "description": "Отборное молоко 3.2%",
    "price": 7900,
    "currency": "RUB",
    "category_name": "Молочные продукты",
    "seller_name": "Магнит"
  }
]
```

## 📝 Лицензия

MIT License
