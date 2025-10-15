# Dockerfile для Korzina Offers API
FROM python:3.13-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /app

# Копирование файлов зависимостей
COPY requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY . .

# Создание пользователя для безопасности
RUN useradd --create-home --shell /bin/bash app && chown -R app:app /app
USER app

# Переменные окружения
ENV FLASK_ENV=production
ENV PYTHONPATH=/app

# Открытие порта
EXPOSE 5000

# Команда запуска
CMD ["python", "main.py"]
