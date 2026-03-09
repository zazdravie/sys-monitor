#!/usr/bin/env bash
set -Eeuo pipefail

# Конфигурация
GITHUB_USER="zazdravie"
REPO_NAME="sys-monitor"
SCRIPT_NAME="sys.sh"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/${SCRIPT_NAME}"

echo -e "\033[0;34m--- Установка System Monitor ---\033[0m"

# 1. Проверка наличия curl
if ! command -v curl >/dev/null 2>&1; then
    echo -e "\033[0;31m[ERR]\033[0m Для установки нужен curl. Установите его: sudo apt install curl"
    exit 1
fi

# 2. Скачивание во временный файл
TEMP_FILE=$(mktemp)
echo "📥 Загрузка скрипта..."
if curl -sSL "$RAW_URL" -o "$TEMP_FILE"; then
    chmod +x "$TEMP_FILE"
    
    # 3. Запуск встроенного инсталлера
    echo "⚙️  Настройка системы..."
    # Теперь мы просто вызываем скачанный файл с флагом --install
    "$TEMP_FILE" --install
    
    # 4. Самоочистка
    rm -f "$TEMP_FILE"
    echo "--------------------------------"
    echo -e "\033[0;32m✅ Все готово!\033[0m"
    echo "Используйте команду: s"
else
    echo -e "\033[0;31m[ERR]\033[0m Не удалось скачать скрипт."
    rm -f "$TEMP_FILE"
    exit 1
fi
