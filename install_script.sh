#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Funktion für Header
header() {
    clear
    echo -e "${YELLOW}╔════════════════════════════════════════════╗"
    echo -e "║${MAGENTA}          Crafty & Playit Installer          ${YELLOW}║"
    echo -e "╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Funktion für Fortschrittsanzeige
progress() {
    echo -e "${BLUE}==>${NC} ${CYAN}$1${NC}"
}

# Funktion für Fehler
error() {
    echo -e "${RED}✖ ERROR:${NC} $1"
    exit 1
}

# Funktion für Erfolgsmeldung
success() {
    echo -e "${GREEN}✔${NC} $1"
}

# Funktion für Warnung
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Funktion für Benutzerabfrage
ask() {
    echo -e "${BLUE}?${NC} ${CYAN}$1${NC} [y/N] "
    read -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Funktion zur Befehlsausführung
run_cmd() {
    echo -e "${BLUE}┌── ${MAGENTA}Befehl:${NC} ${YELLOW}$1${NC}"
    echo -e "${BLUE}└──${NC} $(date)"
    eval "$1" > /tmp/install.log 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}└── FEHLER!${NC} Log: /tmp/install.log"
        return 1
    else
        echo -e "${GREEN}└── Erfolgreich${NC}"
        return 0
    fi
}

# Hauptinstallation
main() {
    header
    progress "Systemvorbereitung"
    
    if ask "Systemupdates durchführen (apt update & upgrade)?"; then
        run_cmd "sudo apt update"
        run_cmd "sudo apt upgrade -y"
        success "System aktualisiert"
    fi
    
    if ask "Git installieren?"; then
        run_cmd "sudo apt install -y git"
        success "Git installiert"
    fi
    
    if ask "Crafty Controller installieren?"; then
        run_cmd "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
        cd crafty-installer-4.0 || error "Verzeichnis nicht gefunden"
        warning "Die Crafty-Installation benötigt möglicherweise manuelle Eingaben"
        run_cmd "sudo ./install_crafty.sh"
        cd ..
        success "Crafty Controller installiert"
        
        if ask "Crafty Controller jetzt starten?"; then
            progress "Starte Crafty Controller..."
            sudo su - crafty -c "cd /var/opt/minecraft/crafty && ./run_crafty.sh" &
            sleep 5
            success "Crafty Controller gestartet"
        fi
    fi
    
    if ask "Playit.gg installieren?"; then
        run_cmd "wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64 -O playit-linux-amd64"
        run_cmd "chmod +x playit-linux-amd64"
        success "Playit.gg heruntergeladen"
        
        run_cmd "sudo tee /etc/systemd/system/playit.service > /dev/null <<EOL
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
EOL"
        
        run_cmd "sudo systemctl daemon-reload"
        run_cmd "sudo systemctl start playit"
        run_cmd "sudo systemctl enable playit"
        success "Playit.gg als Service eingerichtet"
    fi
    
    header
    echo -e "${GREEN}╔════════════════════════════════════════════╗"
    echo -e "║          Installation abgeschlossen!         ║"
    echo -e "╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Zusammenfassung:${NC}"
    echo -e "${YELLOW}Crafty Controller:${NC}"
    echo -e "  - Zugriff: http://$(hostname -I | cut -d' ' -f1):8000"
    echo -e "  - Verzeichnis: /var/opt/minecraft/crafty"
    echo -e "  - Starten: sudo su - crafty -c 'cd /var/opt/minecraft/crafty && ./run_crafty.sh'"
    echo ""
    echo -e "${YELLOW}Playit.gg:${NC}"
    echo -e "  - Setup: ./playit-linux-amd64 setup"
    echo -e "  - Status: systemctl status playit"
    echo -e "  - Logs: journalctl -u playit -f"
    echo ""
    echo -e "${GREEN}Fertig! Drücken Sie eine Taste zum Beenden.${NC}"
    read -n 1 -s -r
}

main
