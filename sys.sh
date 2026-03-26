#!/bin/bash

BIN_PATH="/usr/local/bin/s"

msg_ok() { echo -e "\033[0;32m[+] $1\033[0m"; }
msg_info() { echo -e "\033[0;34m[ℹ] $1\033[0m"; }
msg_warn() { echo -e "\033[1;33m[!] $1\033[0m"; }
msg_err() { echo -e "\033[0;31m[-] $1\033[0m"; }

if [[ "$1" == "--install" ]]; then
    sudo cp "$0" "$BIN_PATH"
    sudo chmod +x "$BIN_PATH"
    msg_ok "Успешно! Монитор установлен. Теперь можно просто ввести команду 's'."
    exit 0
fi

case "$1" in
    --autostart)
        if ! grep -q "$BIN_PATH" ~/.bashrc; then
            echo "$BIN_PATH" >> ~/.bashrc
            msg_info "Автозапуск включен: Сводка будет выводиться при каждом входе по SSH."
        else
            msg_warn "Автозапуск уже был включен ранее."
        fi
        exit 0
        ;;
    --autostart-remove)
        sed -i "\|$BIN_PATH|d" ~/.bashrc
        msg_err "Автозапуск отключен."
        exit 0
        ;;
    --uninstall)
        sudo rm -f "$BIN_PATH"
        sed -i "\|$BIN_PATH|d" ~/.bashrc
        msg_ok "Готово. Команда 's' удалена. Откройте новый терминал, чтобы изменения вступили в силу."
        exit 0
        ;;
esac

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTENT_WIDTH=50 

USER_HOST="$(whoami)@$(hostname)"
OS_INFO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
IP_ADDR=$(hostname -I | awk '{print $1}')
UPTIME=$(uptime -p | sed 's/up //')
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

COUNTRY_CODE=$(curl -s --connect-timeout 2 https://ipinfo.io/country)
case "$COUNTRY_CODE" in
    "SE") COUNTRY="Sweden" ;;
    "NL") COUNTRY="Netherlands" ;;
    "FI") COUNTRY="Finland" ;;
    "DE") COUNTRY="Germany" ;;
    *) COUNTRY=$(curl -s --connect-timeout 2 "http://ip-api.com/line?fields=country" | head -n 1) ;;
esac

format_speed() {
    local kb=$1
    if [ "$kb" -lt 1024 ]; then echo "${kb} KB/s"; else echo "$(awk "BEGIN {printf \"%.1f\", $kb/1024}") MB/s"; fi
}
INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk -- '{printf $5}')
[ -z "$INTERFACE" ] && INTERFACE=$(ls /sys/class/net | grep -v lo | head -n 1)
R1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes); T1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
sleep 1 
R2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes); T2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
NET_OUT="↓$(format_speed $(( (R2-R1)/1024 ))) ↑$(format_speed $(( (T2-T1)/1024 )))"

MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
MEM_FREE_RAW=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
[ -z "$MEM_FREE_RAW" ] && MEM_FREE_RAW=$(free -m | awk '/Mem:/ {print $7}')
MEM_USED=$((MEM_TOTAL - MEM_FREE_RAW))
MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))

DISK_USED=$(df -h / | awk 'NR==2 {print $3}'); DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}'); DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
DISK_PERC=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

draw_bar() {
    local perc=$1
    local filled=$(( perc * CONTENT_WIDTH / 100 ))
    local empty=$(( CONTENT_WIDTH - filled ))
    [ $filled -lt 0 ] && filled=0; [ $empty -lt 0 ] && empty=0
    printf "${BLUE}%-18s${RED}[%s${GREEN}%s]${NC}\n" "" "$(printf '%.0s=' $(seq 1 $filled 2>/dev/null))" "$(printf '%.0s=' $(seq 1 $empty 2>/dev/null))"
}

print_resource_line() {
    local label=$1
    local info=$2
    local total=$3
    local pad_size=$(( CONTENT_WIDTH + 2 - ${#info} - ${#total} ))
    local padding=""
    [ $pad_size -gt 0 ] && padding=$(printf '%.0s ' $(seq 1 $pad_size))
    printf "${BLUE}%-18s${GREEN}%s%s%s${NC}\n" "$label" "$info" "$padding" "$total"
}

clear
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "Logged as:" "$USER_HOST"
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "OS:" "$OS_INFO"
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "Local IP:" "$IP_ADDR"
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "Location:" "$COUNTRY"
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "Uptime:" "$UPTIME"
printf "${BLUE}%-18s${GREEN}%s${NC}\n" "Load average:" "$LOAD_AVG"

print_resource_line "Memory:" "RAM - ${MEM_USED}M used, ${MEM_FREE_RAW}M available" "/ ${MEM_TOTAL}M"
draw_bar $MEM_PERC

print_resource_line "Disk space:" "vda1 (/) - ${DISK_USED} used, ${DISK_FREE} free" "/ ${DISK_TOTAL}"
draw_bar $DISK_PERC

DOCKER_ACT=$(docker ps -q 2>/dev/null | wc -l)
printf "${BLUE}%-18s${GREEN}Docker: ${NC}%-s act. ${BLUE}| ${GREEN}Net: ${NC}%s\n" "Activity:" "$DOCKER_ACT" "$NET_OUT"

printf "${BLUE}%-18s${NC}" "Services:"
grep -qi "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null 2>/dev/null && printf "${GREEN}▲ UFW${NC}" || printf "${RED}▼ UFW${NC}"
printf ", "
if systemctl is-active --quiet caddy 2>/dev/null || (command -v docker >/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -qi "caddy"); then
    printf "${GREEN}▲ Caddy${NC}"
else
    printf "${RED}▼ Caddy${NC}"
fi
printf ", "
(systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null) && printf "${GREEN}▲ SSH${NC}" || printf "${RED}▼ SSH${NC}"
printf "\n"

TMUX_SESS=$(tmux ls 2>/dev/null | wc -l)
if [ "$TMUX_SESS" -eq 0 ]; then
    printf "${BLUE}%-18s${GREEN}no sessions${NC}\n" "Tmux sessions:"
else
    printf "${BLUE}%-18s${GREEN}%s active${NC}\n" "Tmux sessions:" "$TMUX_SESS"
fi

UPD_C=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
printf "${BLUE}%-18s${YELLOW}%s available${NC}\n" "Updates:" "$UPD_C"
