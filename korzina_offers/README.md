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

### Сборка и запуск
```bash
make docker-build
# или
docker build -t korzina-api .
docker run -p 5000:5000 --env-file .env korzina-api
```

## 📚 API Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| `GET` | `/api/health` | Проверка работы сервера |
| `GET` | `/api/stats` | Статистика БД |
| `POST` | `/api/search` | Поиск товаров (основной) |
| `GET` | `/api/search/get` | Поиск товаров (GET для тестов) |

### Примеры запросов

#### Поиск товаров (POST)
```bash
curl -X POST http://localhost:5000/api/search \
  -H "Content-Type: application/json" \
  -d '{"products": ["яблоки", "молоко", "хлеб"]}'
```

#### Поиск товаров (GET)
```bash
curl "http://localhost:5000/api/search/get?products=яблоки,молоко"
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

Основные переменные окружения:

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

### Создание .env файла

```bash
# Скопируйте файл примера
cp .env.example .env

# Заполните необходимые переменные
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
```

## 🧠 Алгоритм сопоставления

Система использует 4-уровневую приоритизацию:

1. **Точное совпадение** (с учетом стоп-слов) - приоритет 4
2. **Частичное совпадение** (с учетом стоп-слов) - приоритет 3
3. **Точное совпадение** (без стоп-слов) - приоритет 2
4. **Частичное совпадение** (без стоп-слов) - приоритет 1

### Стоп-слова
Система автоматически фильтрует описательные слова:
`большой`, `маленький`, `свежий`, `спелый`, `крупный` и др.

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

## 📝 Лицензия

MIT License
