#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zur Fortschrittsanzeige
progress() {
    echo -e "${BLUE}[${NC}${YELLOW}INFO${NC}${BLUE}]${NC} ${GREEN}$1${NC}"
}

# Funktion zur Fehlerbehandlung
error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Funktion zur Ausführung von Befehlen mit Fortschrittsanzeige
run_command() {
    progress "Starte: $1"
    eval "$1" > /tmp/install.log 2>&1
    if [ $? -ne 0 ]; then
        error "Fehler bei: $1\nLog anzeigen mit: cat /tmp/install.log"
    fi
    progress "Abgeschlossen: $1"
}

# Header anzeigen
echo -e "${YELLOW}===========================================${NC}"
echo -e "${YELLOW}  Crafty Controller & Playit.gg Installer  ${NC}"
echo -e "${YELLOW}===========================================${NC}"
echo ""

# Systemupdate
run_command "sudo apt update"
run_command "sudo apt upgrade -y"

# Git installieren
run_command "sudo apt install -y git"

# Crafty Controller installieren
run_command "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
run_command "cd crafty-installer-4.0 && sudo ./install_crafty.sh"

# Zu Crafty-Benutzer wechseln und Crafty starten
progress "Wechsle zu crafty Benutzer und starte Crafty..."
sudo su - crafty -c "cd /var/opt/minecraft/crafty && ./run_crafty.sh" &
sleep 5

# Playit.gg installieren
progress "Installiere Playit.gg..."
run_command "wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64 -O playit-linux-amd64"
run_command "chmod +x playit-linux-amd64"

# Playit als Service einrichten
progress "Richte Playit als Service ein..."
sudo tee /etc/systemd/system/playit.service > /dev/null <<EOL
[Unit]
Description=Playit.gg Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=$(pwd)/playit-linux-amd64
WorkingDirectory=$(pwd)
Restart=always

[Install]
WantedBy=multi-user.target
EOL

run_command "sudo systemctl daemon-reload"
run_command "sudo systemctl start playit"
run_command "sudo systemctl enable playit"

# Installation abgeschlossen
echo -e "${GREEN}"
echo "==========================================="
echo "  Installation erfolgreich abgeschlossen!  "
echo "==========================================="
echo -e "${NC}"
echo -e "${YELLOW}Zugriff auf Crafty Controller:${NC}"
echo -e "  - Im Browser: http://$(hostname -I | cut -d' ' -f1):8000"
echo -e "${YELLOW}Playit.gg Setup:${NC}"
echo -e "  - Führe aus: ./playit-linux-amd64 setup"
echo -e "  - Oder besuche: https://playit.gg"
echo ""
echo -e "${BLUE}Für Debug-Informationen:${NC}"
echo -e "  - Crafty Logs: /var/opt/minecraft/crafty/logs"
echo -e "  - Playit Logs: journalctl -u playit -f"
echo ""
echo -e "${GREEN}Viel Spaß mit deinem Minecraft Server Management!${NC}"
