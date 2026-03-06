#!/usr/bin/env bash
set -Eeuo pipefail

# Конфигурация
GITHUB_USER="zazdravie"
REPO_NAME="sys-monitor"
SCRIPT_NAME="sys.sh"
# Прямая ссылка на raw-файл
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/${SCRIPT_NAME}"

echo "--- Установка System Monitor ---"

# 1. Проверка наличия curl
if ! command -v curl >/dev/null 2>&1; then
    echo "[ERR] Для установки нужен curl. Установите его: sudo apt install curl"
    exit 1
fi

# 2. Скачивание во временный файл
TEMP_FILE=$(mktemp)
echo "📥 Загрузка скрипта..."
if curl -sSL "$RAW_URL" -o "$TEMP_FILE"; then
    chmod +x "$TEMP_FILE"
    
    # 3. Запуск скрипта (он сам скопирует себя куда нужно)
    echo "⚙️  Настройка системы..."
    "$TEMP_FILE"
    
    # 4. Самоочистка
    rm -f "$TEMP_FILE"
    echo "--------------------------------"
    echo "✅ Установка завершена!"
    echo "Теперь вы можете использовать команду: s"
else
    echo "[ERR] Не удалось скачать скрипт. Проверьте интернет или имя ветки (main/master)."
    rm -f "$TEMP_FILE"
    exit 1
fi