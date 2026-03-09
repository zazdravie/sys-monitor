# 🚀 System Monitor (s)

> Минималистичный и мощный мониторинг ресурсов для Linux/WSL.

<details>
  <summary>📸 Посмотреть скриншот интерфейса</summary>
  <br>
  <img src="https://github.com/zazdravie/sys-monitor/blob/main/screenshot.png?raw=true" alt="System Monitor Screenshot" width="800">
</details

## 🔥 Ключевые особенности

* **🐳 Docker Ready:** Мгновенное отображение количества активных (`act.`) контейнеров.
* **🛡 Service Watchdog:** Визуальный статус служб (**UFW**, **Caddy**, **SSH**) с цветовой индикацией.
* **📦 Update Notifier:** Информирует о наличии доступных пакетов для обновления системы.
* **⚡ Мгновенный доступ:** После установки вызывается одной буквой — `s`.
* **🏠 SSH Autostart:** Автоматический вывод сводки при входе на сервер.
* **🛠 Zero Dependencies:** Чистый Bash, не требует Python, Node.js или Go.

## 📥 Быстрая установка

Установите и настройте всё одной командой:

```bash
curl -sSL https://raw.githubusercontent.com/zazdravie/sys-monitor/main/install.sh | bash

```

## ⌨️ Команды управления

| Команда | Описание |
| --- | --- |
| `s` | Показать текущую сводку (CPU, RAM, Docker, Network). |
| `s --autostart` | Включить автоматический запуск монитора при входе по SSH. |
| `s --autostart-remove` | Отключить автозапуск. |
| `s --uninstall` | Полностью удалить скрипт из системы. |

## 📊 Что отображается в сводке?

* **System & Location:** Имя хоста, ОС, аптайм, локальный IP и даже геолокация сервера.
* **Resources:** Load Average, детальный расход RAM и загрузка CPU.
* **Storage:** Наглядные прогресс-бары заполненности дисков.
* **Activity:** Активность сети (Download/Upload) и статус Docker.
* **Sessions:** Проверка наличия активных сессий **Tmux**.

## 🛠 Требования

* **ОС:** Linux или WSL2 (Ubuntu, Debian, CentOS и др.).
* **Инструменты:** `bash`, `awk`, `docker`, `curl`.



