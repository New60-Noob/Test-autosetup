#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress Bar Funktionen
PROGRESS_WIDTH=50
LAST_PROGRESS=0

show_progress_bar() {
    local progress=$1
    local message=$2
    local color=$3
    
    # Sicherstellen, dass Fortschritt zwischen 0-100 bleibt
    ((progress = progress > 100 ? 100 : progress))
    ((progress = progress < 0 ? 0 : progress))
    
    # Berechnung der gefüllten und leeren Teile
    local filled=$(($PROGRESS_WIDTH * $progress / 100))
    local empty=$(($PROGRESS_WIDTH - $filled))
    
    # Erstellen der Progress Bar
    local bar="["
    bar+="${color}"
    for ((i=0; i<filled; i++)); do bar+="■"; done
    bar+="${NC}"
    for ((i=0; i<empty; i++)); do bar+=" "; done
    bar+="]"
    
    # Ausgabe
    printf "\r%-${PROGRESS_WIDTH}s %s" "$bar" "${CYAN}${message}${NC}"
    LAST_PROGRESS=$progress
}

update_progress() {
    local target=$1
    local message=$2
    local step_delay=0.2
    
    while (( LAST_PROGRESS < target )); do
        ((LAST_PROGRESS++))
        show_progress_bar $LAST_PROGRESS "$message" "$BLUE"
        sleep $step_delay
    done
}

# Debug und Fehlerbehandlung
DEBUG=0
FORCE=0
BACKUP=1
LOG_FILE="install.log"
CRAFTY_DIR="/var/opt/minecraft/crafty"

# Hilfe anzeigen
show_help() {
    echo -e "${GREEN}Usage:${NC}"
    echo -e "  $0 [options]"
    echo -e "\n${GREEN}Options:${NC}"
    echo -e "  ${CYAN}-d${NC}    Debug mode (verbose output)"
    echo -e "  ${CYAN}-f${NC}    Force reinstall"
    echo -e "  ${CYAN}-b${NC}    Disable backups"
    echo -e "  ${CYAN}-h${NC}    Show this help"
    exit 0
}

# Parameter verarbeiten
while getopts ":dfbh" opt; do
    case $opt in
        d) DEBUG=1 ;;
        f) FORCE=1 ;;
        b) BACKUP=0 ;;
        h) show_help ;;
        \?) echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2; exit 1 ;;
    esac
done

# Logging Funktion
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "$timestamp - $1" >> "$LOG_FILE"
    if [ "$DEBUG" -eq 1 ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1"
    fi
}

# Fehlerbehandlung
handle_error() {
    local exit_code=$1
    local message=$2
    local context=$3
    
    echo -e "\n${RED}⯈ Error in ${context} (Code ${exit_code})${NC}"
    echo -e "${YELLOW}Details: ${message}${NC}"
    log "ERROR in ${context}: ${message} (Code ${exit_code})"
    exit $exit_code
}

# System Checks
check_root() {
    show_progress_bar 5 "Checking privileges..." "$BLUE"
    if [ "$(id -u)" -ne 0 ]; then
        handle_error 1 "This script must be run as root" "check_root"
    fi
    log "Root privileges confirmed"
    update_progress 10 "Privileges OK ✓"
}

check_debian() {
    show_progress_bar 15 "Checking Debian version..." "$BLUE"
    if [ ! -f /etc/debian_version ]; then
        handle_error 2 "Not a Debian system" "check_debian"
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version)
    if [[ ! "$DEBIAN_VERSION" =~ ^12 ]]; then
        log "Warn: Untested Debian version: $DEBIAN_VERSION"
        echo -e "${YELLOW}⚠ Warning: Developed for Debian 12 (Detected: $DEBIAN_VERSION)${NC}"
    fi
    update_progress 20 "Debian OK ✓"
}

# Installation Functions
install_dependencies() {
    show_progress_bar 25 "Updating system..." "$BLUE"
    log "Updating package lists"
    apt update -y >> "$LOG_FILE" 2>&1 || handle_error 3 "apt update failed" "install_dependencies"
    
    show_progress_bar 35 "Upgrading system..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y >> "$LOG_FILE" 2>&1 || handle_error 4 "apt upgrade failed" "install_dependencies"
    
    show_progress_bar 45 "Installing dependencies..."
    local dependencies=(git curl wget python3 python3-pip python3-venv expect)
    DEBIAN_FRONTEND=noninteractive apt install -y "${dependencies[@]}" >> "$LOG_FILE" 2>&1 || handle_error 5 "Dependency installation failed" "install_dependencies"
    
    update_progress 55 "Dependencies OK ✓"
}

install_crafty() {
    show_progress_bar 60 "Installing Crafty..." "$BLUE"
    local temp_dir=$(mktemp -d)
    
    log "Cloning Crafty installer"
    git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git "$temp_dir" >> "$LOG_FILE" 2>&1 || handle_error 6 "Git clone failed" "install_crafty"
    
    cd "$temp_dir" || handle_error 7 "Directory change failed" "install_crafty"
    
    log "Running Crafty installer"
    # Automatische Beantwortung der Installationsfragen
    echo -e "y\n/var/opt/minecraft/crafty\ny" | ./install_crafty.sh >> "$LOG_FILE" 2>&1 || handle_error 8 "Crafty installation failed" "install_crafty"
    
    # Service-Erstellung
    log "Creating Crafty service"
    cat > /etc/systemd/system/crafty.service <<EOL
[Unit]
Description=Crafty Controller
After=network.target

[Service]
Type=simple
User=crafty
WorkingDirectory=$CRAFTY_DIR
ExecStart=$CRAFTY_DIR/run_crafty.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable crafty >> "$LOG_FILE" 2>&1 || log "Warning: Failed to enable Crafty service"
    
    update_progress 80 "Crafty OK ✓"
}

setup_playit() {
    show_progress_bar 85 "Installing Playit.gg..." "$BLUE"
    wget -q https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-amd64 -O /usr/local/bin/playit || handle_error 9 "Playit download failed" "setup_playit"
    
    chmod +x /usr/local/bin/playit
    log "Creating Playit service"
    
    cat > /etc/systemd/system/playit.service <<EOL
[Unit]
Description=Playit.gg Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/playit
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    systemctl enable playit >> "$LOG_FILE" 2>&1 || handle_error 10 "Playit service setup failed" "setup_playit"
    
    update_progress 95 "Playit OK ✓"
}

# Main Execution
main() {
    clear
    echo -e "\n${BLUE}▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌"
    echo -e "▐  ${GREEN}Auto Server Installer${BLUE}         ▌"
    echo -e "▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌${NC}\n"
    
    # Initialisierung
    echo "=== Installation Log $(date) ===" > "$LOG_FILE"
    log "Starting installation with parameters: DEBUG=$DEBUG, FORCE=$FORCE, BACKUP=$BACKUP"
    
    check_root
    check_debian
    install_dependencies
    install_crafty
    setup_playit
    
    # Finalisierung
    show_progress_bar 100 "Installation complete!" "$GREEN"
    echo -e "\n\n${GREEN}✓ Successfully installed!${NC}"
    echo -e "${BLUE}Access Crafty: http://$(curl -s ifconfig.me):8000${NC}"
    echo -e "${YELLOW}Run 'playit setup' to configure Playit.gg${NC}"
    echo -e "${CYAN}Log file: $PWD/$LOG_FILE${NC}"
}

# Skript ausführen
trap 'handle_error $? "$BASH_COMMAND" "$BASH_SOURCE:$LINENO"' ERR
main "$@"
