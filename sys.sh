#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="s"
MARK_START="# SYS_MONITOR_START"
MARK_END="# SYS_MONITOR_END"

USER_BIN_DIR="${HOME}/.local/bin"
SYSTEM_BIN_DIR="/usr/local/bin"

STATE_DIR="${HOME}/.local/share/${APP_NAME}"
INSTALL_SOURCE_FILE="${STATE_DIR}/install-source.txt"

# Pick install dir
INSTALL_DIR="$USER_BIN_DIR"
if [[ -w "$SYSTEM_BIN_DIR" && -d "$SYSTEM_BIN_DIR" ]]; then
  INSTALL_DIR="$SYSTEM_BIN_DIR"
fi
TARGET_PATH="${INSTALL_DIR}/${APP_NAME}"

# Colors only for TTY
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; B=$'\033[0;34m'; W=$'\033[0m'
else
  G=""; Y=""; R=""; B=""; W=""
fi

msg_ok()   { printf '%s[OK]%s %s\n' "$G" "$W" "$*"; }
msg_warn() { printf '%s[!]%s %s\n' "$Y" "$W" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

rc_candidates() {
  printf '%s\n' \
    "${HOME}/.bashrc" \
    "${HOME}/.bash_profile" \
    "${HOME}/.profile"
}

remove_block() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  sed -i.bak "/^${MARK_START//\//\\/}\$/,/^${MARK_END//\//\\/}\$/d" "$f" || true
}

remove_autostart_everywhere() {
  while IFS= read -r f; do
    remove_block "$f"
  done < <(rc_candidates)
}

ensure_block_in_bashrc() {
  local bashrc="${HOME}/.bashrc"
  touch "$bashrc"
  if grep -Fq "$MARK_START" "$bashrc"; then
    msg_ok "Автозапуск уже включён в ~/.bashrc"
    return 0
  fi

  {
    printf '\n%s\n' "$MARK_START"
    printf 'if [[ -t 1 ]] && command -v %q >/dev/null 2>&1; then %q; fi\n' "$APP_NAME" "$APP_NAME"
    printf '%s\n' "$MARK_END"
  } >>"$bashrc"

  msg_ok "Автозапуск включён в ~/.bashrc"
}

delete_saved_install_source() {
  [[ -f "$INSTALL_SOURCE_FILE" ]] || return 0
  local src
  src="$(<"$INSTALL_SOURCE_FILE")"
  src="${src//$'\r'/}"

  # Delete only if it exists and is not the installed target
  if [[ -n "$src" && -f "$src" && "$(readlink -f "$src" 2>/dev/null || echo "$src")" != "$(readlink -f "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")" ]]; then
    rm -f -- "$src" 2>/dev/null || true
  fi
}

# -------- Commands --------
if [[ "${1:-}" == "--uninstall" ]]; then
  msg_warn "Полная очистка (удаление команды и автозапуска)..."

  # Remove autostart blocks
  remove_autostart_everywhere

  # Remove installed binaries (both locations)
  for p in "${USER_BIN_DIR}/${APP_NAME}" "${SYSTEM_BIN_DIR}/${APP_NAME}"; do
    [[ -f "$p" ]] && rm -f "$p" 2>/dev/null || true
  done

  # Try remove the original first-run script file (saved)
  delete_saved_install_source

  # Remove state file
  rm -f "$INSTALL_SOURCE_FILE" 2>/dev/null || true

  unalias "$APP_NAME" 2>/dev/null || true
  hash -r 2>/dev/null || true

  msg_ok "Готово. Откройте новый терминал, чтобы изменения вступили в силу."
  exit 0
fi

if [[ "${1:-}" == "--autostart" ]]; then
  ensure_block_in_bashrc
  exit 0
fi

if [[ "${1:-}" == "--autostart-remove" ]]; then
  remove_autostart_everywhere
  msg_ok "Автозапуск удалён (если был)."
  exit 0
fi

# -------- Install self (first run) --------
FIRST_RUN=false
script_self="$(readlink -f "${BASH_SOURCE[0]}")"

if [[ ! -f "$TARGET_PATH" ]]; then
  mkdir -p "$INSTALL_DIR"
  mkdir -p "$STATE_DIR"

  # Save original source path (the first script file user executed)
  printf '%s\n' "$script_self" >"$INSTALL_SOURCE_FILE"

  cp -f "$script_self" "$TARGET_PATH"
  chmod +x "$TARGET_PATH"
  hash -r 2>/dev/null || true
  FIRST_RUN=true

  # If user install dir not on PATH, hint
  if [[ "$INSTALL_DIR" == "$USER_BIN_DIR" ]] && ! echo ":$PATH:" | grep -q ":$USER_BIN_DIR:"; then
    msg_warn "~/.local/bin не в PATH. Добавьте в ~/.bashrc:"
    printf '  export PATH="$HOME/.local/bin:$PATH"\n'
  fi

  # Delete the original script file after successful install (as requested)
  if [[ "$script_self" != "$(readlink -f "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")" ]]; then
    rm -f -- "$script_self" 2>/dev/null || true
  fi
fi

# -------- Metrics (best-effort) --------
LOC="Unknown"; CITY="Unknown"; IP="No IP"
if have curl; then
  IP_INFO="$(curl -fsS --max-time 3 "http://ip-api.com/json/?lang=ru" 2>/dev/null || true)"
  if [[ -n "${IP_INFO:-}" ]]; then
    LOC="$(printf '%s' "$IP_INFO" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p' | head -n1)"
    CITY="$(printf '%s' "$IP_INFO" | sed -n 's/.*"city":"\([^"]*\)".*/\1/p' | head -n1)"
    IP="$(printf '%s' "$IP_INFO" | sed -n 's/.*"query":"\([^"]*\)".*/\1/p' | head -n1)"
    LOC="${LOC:-Unknown}"; CITY="${CITY:-Unknown}"; IP="${IP:-No IP}"
  fi
fi

CPU_LOAD="?"
if [[ -r /proc/stat ]]; then
  read -r _ u1 n1 s1 i1 io1 irq1 sirq1 st1 _ < /proc/stat
  t1=$((u1+n1+s1+i1+io1+irq1+sirq1+st1))
  idle1=$((i1+io1))
  sleep 0.2
  read -r _ u2 n2 s2 i2 io2 irq2 sirq2 st2 _ < /proc/stat
  t2=$((u2+n2+s2+i2+io2+irq2+sirq2+st2))
  idle2=$((i2+io2))
  dt=$((t2-t1))
  didle=$((idle2-idle1))
  if (( dt > 0 )); then
    CPU_LOAD="$(awk -v dt="$dt" -v di="$didle" 'BEGIN{printf "%.1f", (100*(dt-di))/dt}')"
  fi
fi

RAM_T="?"; RAM_U="?"; SW_U="?"
if have free; then
  RAM_T="$(free -m | awk '/Mem:/ {print $2}' | head -n1)"
  RAM_U="$(free -m | awk '/Mem:/ {print $3}' | head -n1)"
  SW_U="$(free -m | awk '/Swap:/ {print $3}' | head -n1)"
fi

DISK_U="?"; DISK_T="?"
if have df; then
  DISK_U="$(df -h / 2>/dev/null | awk 'NR==2{print $3}' | head -n1 || echo "?")"
  DISK_T="$(df -h / 2>/dev/null | awk 'NR==2{print $2}' | head -n1 || echo "?")"
fi

DOCKER="0"
if have docker; then
  DOCKER="$(docker ps -q 2>/dev/null | wc -l | awk '{print $1}' || echo "0")"
fi

RX="?"; TX="?"
IFACE=""
if have ip; then
  IFACE="$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}' || true)"
fi
if [[ -n "$IFACE" && -r "/sys/class/net/$IFACE/statistics/rx_bytes" && -r "/sys/class/net/$IFACE/statistics/tx_bytes" ]]; then
  R1="$(<"/sys/class/net/$IFACE/statistics/rx_bytes")"
  T1="$(<"/sys/class/net/$IFACE/statistics/tx_bytes")"
  sleep 1
  R2="$(<"/sys/class/net/$IFACE/statistics/rx_bytes")"
  T2="$(<"/sys/class/net/$IFACE/statistics/tx_bytes")"
  RX=$(( (R2 - R1) / 1024 ))
  TX=$(( (T2 - T1) / 1024 ))
fi

SSH_F="0"
if have journalctl && have date; then
  MSK="$(TZ='Europe/Moscow' date -d 'today 00:00' +'%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
  if [[ -n "${MSK:-}" ]]; then
    SSH_F="$(journalctl --no-pager --since "$MSK" 2>/dev/null \
      | grep -Eic 'Failed password|Invalid user|authentication failure' || echo "0")"
  fi
elif [[ -r /var/log/auth.log ]]; then
  SSH_F="$(grep -Eic 'Failed password|Invalid user|authentication failure' /var/log/auth.log 2>/dev/null || echo "0")"
fi

FW="Unknown"
if have ufw; then
  FW="$(ufw status 2>/dev/null | awk 'NR==1{print $2}' | head -n1 || echo "Unknown")"
elif have firewall-cmd; then
  FW="$(firewall-cmd --state 2>/dev/null || echo "Unknown")"
fi

UPT="?"
if have uptime; then
  UPT="$(uptime -p 2>/dev/null | sed 's/^up //')"
fi

# -------- Output --------
printf '%s● СЕРВЕР:%s %s%s%s (%s%s%s) [%s%s%s]\n' \
  "$B" "$W" "$G" "$LOC" "$W" "$G" "$CITY" "$W" "$G" "$IP" "$W"

printf ' ├ %sCPU:%s %s%% | %sRAM:%s %s/%s MB | %sSwap:%s %s MB\n' \
  "$Y" "$W" "$CPU_LOAD" "$Y" "$W" "$RAM_U" "$RAM_T" "$Y" "$W" "$SW_U"

printf ' ├ %sSSD:%s %s/%s | %sDocker:%s %s act. | %sNet:%s ↓%s KB/s ↑%s KB/s\n' \
  "$Y" "$W" "$DISK_U" "$DISK_T" "$Y" "$W" "$DOCKER" "$Y" "$W" "$RX" "$TX"

printf ' └ %sUptime:%s %s | %sSSH Fail:%s %s%s%s | %sFW:%s %s%s%s\n' \
  "$Y" "$W" "$UPT" "$Y" "$W" "$R" "$SSH_F" "$W" "$Y" "$W" "$G" "$FW" "$W"

printf '%s\n' "---------------------------------------------------"

if [[ "$FIRST_RUN" == true ]]; then
  printf '%s[УСТАНОВЛЕНО]%s Команда: %s\n' "$G" "$W" "$APP_NAME"
  printf ' %s%s%s -- Показать сводку\n' "$Y" "$APP_NAME" "$W"
  printf ' %s%s --autostart%s -- Включить запуск при входе\n' "$Y" "$APP_NAME" "$W"
  printf ' %s%s --autostart-remove%s -- Удалить автозапуск\n' "$Y" "$APP_NAME" "$W"
  printf ' %s%s --uninstall%s -- Удалить всё из системы\n' "$Y" "$APP_NAME" "$W"
  printf '%s\n' "---------------------------------------------------"
fi