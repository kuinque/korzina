# 🚀 Быстрый старт после миграции на FastAPI

## 1️⃣ Установка зависимостей

```bash
pip install -r requirements.txt
```

## 2️⃣ Настройка окружения

```bash
# Создайте .env файл
cp .env.example .env

# Отредактируйте .env и укажите ваши credentials
nano .env  # или используйте любой редактор
```

Минимально необходимые переменные:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-api-key
```

## 3️⃣ Запуск приложения

```bash
# Через Python (с auto-reload)
python main.py

# Или напрямую с uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 5000
```

## 4️⃣ Проверка работы

### Откройте браузер:

1. **Swagger UI (интерактивная документация)**:
   ```
   http://localhost:5000/docs
   ```
   Здесь вы можете тестировать все endpoints прямо в браузере!

2. **ReDoc (альтернативная документация)**:
   ```
   http://localhost:5000/redoc
   ```

3. **Health Check**:
   ```bash
   curl http://localhost:5000/api/health
   ```

### Тестовые запросы

```bash
# 1. Health Check
curl http://localhost:5000/api/health

# 2. Статистика
curl http://localhost:5000/api/stats

# 3. Поиск товаров (POST)
curl -X POST http://localhost:5000/api/search \
  -H "Content-Type: application/json" \
  -d '{"products": ["яблоки", "молоко", "хлеб"]}'

# 4. Поиск товаров (GET)
curl "http://localhost:5000/api/search/get?products=яблоки,молоко"

# 5. Товары конкретного магазина
curl "http://localhost:5000/api/products?shop=Пятерочка"

# 6. Поиск в товарах магазина
curl "http://localhost:5000/api/products?shop=Пятерочка&q=молоко"
```

## 5️⃣ Запуск тестов

```bash
# Все тесты
pytest

# С покрытием
pytest --cov=app

# С HTML отчетом
pytest --cov=app --cov-report=html
# Откройте htmlcov/index.html в браузере
```

## 6️⃣ Docker (опционально)

```bash
# Сборка
docker build -t korzina-api .

# Запуск
docker run -p 5000:5000 --env-file .env korzina-api
```

## 🎯 Основные изменения после миграции

### ✅ Что улучшилось:
- 📚 Автоматическая документация API (Swagger/ReDoc)
- ✨ Валидация данных через Pydantic
- ⚡ Лучшая производительность (ASGI вместо WSGI)
- 🔒 Type-safe конфигурация
- 🚀 Современный стек технологий

### ⚠️ Что изменилось:
- `FLASK_ENV` → `APP_ENV`
- Ошибки валидации: код `400` → `422`
- Формат ошибок: `{status, message}` → `{detail}`
- Тесты используют `TestClient` вместо Flask test client

## 📖 Документация

После запуска сервера:
- **Swagger UI**: http://localhost:5000/docs
- **ReDoc**: http://localhost:5000/redoc
- **OpenAPI JSON**: http://localhost:5000/openapi.json

## 🐛 Решение проблем

### Ошибка: "SUPABASE_URL и SUPABASE_KEY должны быть установлены"
Создайте .env файл и укажите credentials от Supabase

### Ошибка: "ModuleNotFoundError: No module named 'fastapi'"
Установите зависимости: `pip install -r requirements.txt`

### Ошибка: "Address already in use"
Порт 5000 занят. Укажите другой порт:
```bash
uvicorn main:app --reload --port 8000
```

## 💡 Полезные команды

```bash
# Форматирование кода
black app tests

# Проверка линтером
flake8 app tests

# Проверка типов
mypy app

# Все проверки
make ci
```

## 🎉 Готово!

Ваш FastAPI сервер работает! Откройте http://localhost:5000/docs для интерактивной работы с API.
