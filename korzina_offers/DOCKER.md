# 🐳 Docker - Инструкция по запуску

Краткое руководство по запуску Korzina Offers API в Docker контейнере.

## Требования

- Docker и Docker Compose установлены
- Файл `.env` с переменными `SUPABASE_URL` и `SUPABASE_KEY`

## Быстрый запуск

### Способ 1: Автоматический скрипт (рекомендуется)

```bash
cd korzina_offers
./docker-start.sh
```

### Способ 2: Docker Compose

```bash
cd korzina_offers
docker compose up -d
```

### Способ 3: Make команды

```bash
make docker-up
```

## Доступ к API

### Определение IP адреса

```bash
hostname -I | awk '{print $1}'
```

### Адреса

- **Локально**: `http://localhost:5000`
- **По IP**: `http://<IP_МАШИНЫ>:5000`
- **Документация**: `http://<IP>:5000/docs`

### Примеры запросов

```bash
# Health check
curl http://localhost:5000/api/health

# Поиск товаров
curl -X POST http://localhost:5000/api/search \
  -H "Content-Type: application/json" \
  -d '{"products": ["яблоки", "молоко"]}'

# Получить офферы
curl "http://localhost:5000/api/offers?limit=10"
```

## Управление контейнером

```bash
# Запуск
docker compose up -d

# Остановка
docker compose down

# Просмотр логов
docker compose logs -f

# Перезапуск
docker compose restart

# Пересборка
docker compose up -d --build
```

### Make команды

```bash
make docker-up      # Запуск
make docker-down    # Остановка
make docker-logs    # Логи
make docker-restart # Перезапуск
make docker-rebuild # Пересборка
```

## Решение проблем

### Порт 5000 занят

Измените порт в `docker-compose.yml`:
```yaml
ports:
  - "8080:5000"  # Внешний:Внутренний
```

### Контейнер не запускается

```bash
# Просмотр логов
docker compose logs

# Проверка конфигурации
docker compose config

# Проверка .env файла
cat .env
```

### API недоступен по IP

```bash
# Проверить firewall
sudo ufw status
sudo ufw allow 5000/tcp

# Проверить порт
docker port korzina-offers-api
```

### Healthcheck не проходит

```bash
# Проверить логи
docker compose logs | grep -i health

# Проверить вручную
curl http://localhost:5000/api/health
```

## Просмотр логов

### Основные команды

```bash
# Все логи в реальном времени (следить за новыми записями)
docker compose logs -f

# Все логи (без следования)
docker compose logs

# Последние 100 строк логов
docker compose logs --tail=100

# Логи с временными метками
docker compose logs -f -t

# Логи за последние 10 минут
docker compose logs --since 10m

# Логи за определенный период
docker compose logs --since 2024-01-01T00:00:00 --until 2024-01-01T12:00:00
```

### Альтернативные способы

```bash
# Через docker logs (если знаете имя контейнера)
docker logs korzina-offers-api -f

# Логи с фильтрацией
docker compose logs | grep ERROR
docker compose logs | grep -i "health"

# Сохранить логи в файл
docker compose logs > logs.txt
docker compose logs --since 1h > logs_last_hour.txt
```

### Make команды

```bash
# Просмотр логов
make docker-logs
```

## Полезные команды

```bash
# Статус контейнера
docker compose ps

# Использование ресурсов
docker stats korzina-offers-api

# Вход в контейнер
docker exec -it korzina-offers-api /bin/bash

# Проверка переменных окружения
docker exec korzina-offers-api env | grep SUPABASE
```

## Очистка

```bash
# Остановка и удаление
docker compose down

# Полная очистка
docker compose down -v --rmi all
```
