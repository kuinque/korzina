# Makefile для управления проектом

.PHONY: help install test lint format run docker-build docker-run docker-up docker-down docker-logs docker-restart clean

help: ## Показать справку
	@echo "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Установить зависимости
	pip install -r requirements.txt

test: ## Запустить тесты
	pytest

test-cov: ## Запустить тесты с покрытием
	pytest --cov=app --cov-report=html

lint: ## Проверить код линтерами
	flake8 app tests
	mypy app

format: ## Форматировать код
	black app tests

run: ## Запустить приложение
	python main.py

docker-build: ## Собрать Docker образ
	docker build -t korzina-api .

docker-run: ## Запустить в Docker (старый способ)
	docker run -p 5000:5000 --env-file .env korzina-api

docker-up: ## Запустить контейнер через docker compose
	docker compose up -d

docker-down: ## Остановить контейнер через docker compose
	docker compose down

docker-logs: ## Показать логи контейнера
	docker compose logs -f

docker-restart: ## Перезапустить контейнер
	docker compose restart

docker-rebuild: ## Пересобрать и перезапустить контейнер
	docker compose up -d --build

clean: ## Очистить временные файлы
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name "htmlcov" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +

dev-setup: install ## Настроить окружение для разработки
	@echo "Настройка окружения для разработки..."
	@if [ ! -f .env ]; then cp .env.example .env; echo "Создан файл .env из .env.example"; fi
	@echo "Не забудьте заполнить переменные в .env файле!"

ci: lint test ## Запустить CI pipeline (линтеры + тесты)
