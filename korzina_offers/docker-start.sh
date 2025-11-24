#!/bin/bash
# Скрипт для запуска Korzina Offers API в Docker

set -e

echo "🚀 Запуск Korzina Offers API в Docker..."

# Проверка наличия .env файла
if [ ! -f .env ]; then
    echo "❌ Файл .env не найден!"
    echo "📝 Создайте файл .env с необходимыми переменными:"
    echo "   SUPABASE_URL=your_url"
    echo "   SUPABASE_KEY=your_key"
    exit 1
fi

# Определение команды docker compose (v2) или docker-compose (v1)
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Сборка и запуск контейнера
echo "🔨 Сборка Docker образа..."
$DOCKER_COMPOSE build

echo "▶️  Запуск контейнера..."
$DOCKER_COMPOSE up -d

# Получение IP адреса машины
MACHINE_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ Контейнер запущен!"
echo ""
echo "📡 API доступен по адресам:"
echo "   - Локально: http://localhost:5000"
echo "   - По IP:    http://${MACHINE_IP}:5000"
echo ""
echo "📚 Документация:"
echo "   - Swagger UI: http://${MACHINE_IP}:5000/docs"
echo "   - ReDoc:      http://${MACHINE_IP}:5000/redoc"
echo ""
echo "🔍 Полезные команды:"
echo "   - Просмотр логов:    docker compose logs -f"
echo "   - Остановка:         docker compose down"
echo "   - Перезапуск:        docker compose restart"
echo ""

# Проверка здоровья сервиса
echo "⏳ Ожидание запуска сервиса..."
sleep 5

if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
    echo "✅ Сервис работает!"
else
    echo "⚠️  Сервис еще запускается. Проверьте логи: docker compose logs"
fi

