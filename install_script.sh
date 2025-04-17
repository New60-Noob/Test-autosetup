#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Funktionen für bessere Darstellung
header() {
    clear
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗"
    echo -e "║${MAGENTA}         Crafty & Playit Installer (v4.0)         ${YELLOW}║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

progress() {
    echo -e "${BLUE}==>${NC} ${CYAN}$1${NC}"
}

error() {
    echo -e "${RED}✖ ERROR:${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}✔${NC} $1"
}

# Crafty Installation mit korrekter Abfolge
install_crafty() {
    header
    progress "Starte Crafty Controller Installation"
    
    # Vorbereitung
    run_cmd "sudo apt update"
    run_cmd "sudo apt install -y git"
    
    # Clone Repository mit Fehlerbehandlung
    if [ ! -d "crafty-installer-4.0" ]; then
        run_cmd "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git" || error "Clone fehlgeschlagen"
    fi
    
    # Wechsel ins Verzeichnis mit Fehlerbehandlung
    run_cmd "cd crafty-installer-4.0" || error "Verzeichniswechsel fehlgeschlagen"
    
    # Installation mit automatischer Bestätigung
    progress "Starte Installationsskript (automatische Bestätigung)"
    echo -e "y\n" | sudo ./install_crafty.sh || error "Crafty Installation fehlgeschlagen"
    
    # Verifizierung der Installation
    if [ ! -f "/var/opt/minecraft/crafty/run_crafty.sh" ]; then
        error "Crafty Installation unvollständig - run_crafty.sh nicht gefunden"
    fi
    
    # Crafty starten
    progress "Starte Crafty Dienst"
    sudo su - crafty -c "cd /var/opt/minecraft/crafty && nohup ./run_crafty.sh > crafty.log 2>&1 &"
    sleep 10
    
    # Zurück zum ursprünglichen Verzeichnis
    cd ..
    
    success "Crafty Controller erfolgreich installiert"
}

# Playit.gg Installation
install_playit() {
    header
    progress "Starte Playit.gg Installation"
    
    run_cmd "wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64 -O playit-linux-amd64"
    run_cmd "chmod +x playit-linux-amd64"
    
    # Service einrichten
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
    
    success "Playit.gg erfolgreich installiert"
}

# Hauptfunktion
main() {
    # Systemvorbereitung
    header
    run_cmd "sudo apt update"
    run_cmd "sudo apt upgrade -y"
    
    # Crafty installieren
    install_crafty
    
    # Playit installieren
    install_playit
    
    # Zusammenfassung
    header
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗"
    echo -e "║          Installation erfolgreich abgeschlossen!         ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}════════════════════ Zusammenfassung ════════════════════${NC}"
    echo -e "${YELLOW}🔹 Crafty Controller:${NC}"
    echo -e "  - URL: ${GREEN}https://$(hostname -I | cut -d' ' -f1):8443${NC}"
    echo -e "  - Standard Login: admin / crafty"
    echo -e "  - Verzeichnis: /var/opt/minecraft/crafty"
    echo ""
    echo -e "${YELLOW}🔹 Playit.gg:${NC}"
    echo -e "  - Setup: ./playit-linux-amd64 setup"
    echo -e "  - Status: sudo systemctl status playit"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
}

# Hilfsfunktion für Befehlsausführung
run_cmd() {
    echo -e "${BLUE}┌── Befehl:${NC} ${YELLOW}$1${NC}"
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

# Skriptstart
main
