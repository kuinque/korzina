# 🛒 Korzina - Умный помощник для покупок

**Korzina** — это интеллектуальная система для поиска и сравнения товаров в различных магазинах. Проект помогает найти лучшие цены и оптимальный магазин для вашего списка покупок.

## 📦 Структура проекта

Это монорепозиторий, содержащий:

### 1. **korzina_offers/** - Backend микросервис
API сервис на **FastAPI** для поиска и сопоставления товаров с умным алгоритмом matching.

**Основные возможности:**
- 🔍 Интеллектуальный поиск товаров по названию
- 📊 4-уровневый алгоритм сопоставления (exact/partial matching)
- 💰 Определение оптимального магазина по цене
- 📡 REST API с автоматической документацией (Swagger/ReDoc)
- 🐳 Docker поддержка
- ✅ Полное покрытие тестами

**Технологии:** Python 3.13, FastAPI, Supabase (PostgreSQL), Pydantic, pytest

📚 [Подробная документация →](korzina_offers/README.md)

### 2. **KorzinaApp/** - iOS приложение
Нативное iOS приложение на **Swift** для удобного использования сервиса.

**Архитектура:** VIPER
**Модули:**
- 🏠 MainModule - главный экран
- 🛒 BasketModule - корзина покупок  
- 🏪 ShopModule - выбор магазина
- 👤 ProfileModule - профиль пользователя
- ⚡ StartModule - стартовый экран

**Технологии:** Swift, UIKit, VIPER

## 🚀 Быстрый старт

### Backend (korzina_offers)

```bash
cd korzina_offers

# Установка зависимостей
pip install -r requirements.txt

# Настройка окружения
cp .env.example .env
# Заполните SUPABASE_URL и SUPABASE_KEY

# Запуск сервера
python main.py
```

API будет доступен по адресу: http://localhost:5000  
Документация: http://localhost:5000/docs

### iOS приложение (KorzinaApp)

```bash
cd KorzinaApp

# Откройте проект в Xcode
open KorzinaApp.xcodeproj

# Запустите проект через Xcode (⌘R)
```

## 📚 API Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| `GET/POST` | `/api/health` | Проверка работы сервера |
| `GET` | `/api/stats` | Статистика БД |
| `GET` | `/api/offers` | Список офферов с фильтрами |
| `POST` | `/api/search` | Поиск товаров (основной) |
| `GET` | `/api/search/get` | Поиск товаров (упрощенный) |

### Пример использования

```bash
# Поиск товаров
curl -X POST http://localhost:5000/api/search \
  -H "Content-Type: application/json" \
  -d '{"products": ["яблоки", "молоко", "хлеб"]}'
```

## 🧠 Алгоритм сопоставления

Система использует умный 4-уровневый алгоритм:

1. **Точное совпадение** (similarity: 1.0)
2. **Частичное совпадение с стоп-словами** (≥ 0.7)
3. **Точное совпадение без стоп-слов** (0.9)
4. **Частичное совпадение без стоп-слов** (≥ 0.4-0.6)

Автоматически фильтруются описательные слова: "свежий", "большой", "спелый" и др.

## 🛠️ Технологический стек

### Backend
- **Framework:** FastAPI 0.115.0
- **Server:** Uvicorn
- **Database:** Supabase (PostgreSQL)
- **Validation:** Pydantic 2.9+
- **Testing:** pytest, httpx
- **Code Quality:** mypy, black, flake8

### Mobile
- **Language:** Swift
- **Architecture:** VIPER
- **UI:** UIKit
- **Custom fonts:** Inter, Montserrat

## 🧪 Тестирование

### Backend тесты
```bash
cd korzina_offers
pytest
# С покрытием
pytest --cov=app --cov-report=html
```

## 🐳 Docker

```bash
cd korzina_offers
docker build -t korzina-api .
docker run -p 5000:5000 --env-file .env korzina-api
```

## ⚙️ Конфигурация

### Backend (.env)
```bash
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
PORT=5000
DEBUG=true
PENALTY_PRICE=1000.0
```

## 📊 Архитектура системы

```
┌─────────────────┐
│   iOS App       │
│   (Swift)       │
└────────┬────────┘
         │ HTTP/REST
         ▼
┌─────────────────┐
│  FastAPI Server │
│  (Python)       │
└────────┬────────┘
         │ PostgreSQL
         ▼
┌─────────────────┐
│   Supabase DB   │
│  (PostgreSQL)   │
└─────────────────┘
```

## 👥 Разработка

### Добавление новых функций в Backend
1. Создайте Pydantic модель в `korzina_offers/app/models/`
2. Добавьте бизнес-логику в `korzina_offers/app/services/`
3. Создайте API endpoint в `korzina_offers/app/api/routes.py`
4. Напишите тесты в `korzina_offers/tests/`

### Добавление новых модулей в iOS
1. Создайте новый модуль следуя VIPER архитектуре
2. Зарегистрируйте модуль в `RootTabFactory.swift` (если нужен в TabBar)
3. Добавьте необходимые ассеты в `Assets.xcassets/`

## 📝 Лицензия

MIT License

---

**Документация подпроектов:**
- [Backend API →](korzina_offers/README.md)
- iOS приложение (см. KorzinaApp/)

