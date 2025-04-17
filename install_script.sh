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
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗"
    echo -e "║${MAGENTA}         Crafty & Playit Installer (v3.0)         ${YELLOW}║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
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

# Funktion zur Befehlsausführung mit automatischer Bestätigung
run_cmd() {
    echo -e "${BLUE}┌── ${MAGENTA}Befehl:${NC} ${YELLOW}$1${NC}"
    echo -e "${BLUE}└──${NC} $(date)"
    
    # Spezialbehandlung für crafty installer
    if [[ "$1" == *"install_crafty.sh"* ]]; then
        # Automatische Bestätigung aller Fragen
        echo -e "y\n" | sudo ./install_crafty.sh > /tmp/install.log 2>&1
    else
        eval "$1" > /tmp/install.log 2>&1
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}└── FEHLER!${NC} Log: /tmp/install.log"
        return 1
    else
        echo -e "${GREEN}└── Erfolgreich${NC}"
        return 0
    fi
}

# Crafty Installation
install_crafty() {
    header
    progress "Crafty Controller Installation"
    
    # Voraussetzungen prüfen
    if ! command -v git &> /dev/null; then
        progress "Installiere Git..."
        run_cmd "sudo apt update"
        run_cmd "sudo apt install -y git"
    fi
    
    # Crafty Installer herunterladen
    if [ ! -d "crafty-installer-4.0" ]; then
        run_cmd "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
    else
        warning "Crafty Installer Verzeichnis existiert bereits - Überspringe Download"
    fi
    
    # Crafty installieren
    cd crafty-installer-4.0 || error "Verzeichnis nicht gefunden"
    
    progress "Starte Crafty Installation (automatische Bestätigung aktiviert)..."
    run_cmd "sudo ./install_crafty.sh"
    
    # Auf Abschluss warten
    local timeout=300
    local start_time=$(date +%s)
    
    while [ ! -f "/var/opt/minecraft/crafty/run_crafty.sh" ]; do
        sleep 5
        progress "Warte auf Crafty Installation..."
        
        # Timeout prüfen
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout ]; then
            error "Timeout bei Crafty Installation"
        fi
    done
    
    # Crafty starten
    progress "Starte Crafty Controller im Hintergrund..."
    sudo su - crafty -c "cd /var/opt/minecraft/crafty && nohup ./run_crafty.sh > crafty.log 2>&1 &"
    
    # Warten bis Dienst läuft
    sleep 15
    cd ..
    success "Crafty Controller erfolgreich installiert und gestartet"
}

# Playit Installation
install_playit() {
    header
    progress "Playit.gg Installation"
    
    run_cmd "wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64 -O playit-linux-amd64"
    run_cmd "chmod +x playit-linux-amd64"
    
    # Service erstellen
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
    
    success "Playit.gg erfolgreich installiert und als Service eingerichtet"
}

# Hauptinstallation
main() {
    # Systemaktualisierung
    run_cmd "sudo apt update"
    run_cmd "sudo apt upgrade -y"
    
    # Crafty Installation
    install_crafty
    
    # Playit Installation
    install_playit
    
    # Zusammenfassung anzeigen
    header
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗"
    echo -e "║          Installation erfolgreich abgeschlossen!         ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}════════════════════ Zusammenfassung ════════════════════${NC}"
    echo -e "${YELLOW}🔹 Crafty Controller:${NC}"
    echo -e "  - Zugriff: ${GREEN}https://$(hostname -I | cut -d' ' -f1):8443${NC}"
    echo -e "  - Standard Login: admin / crafty"
    echo -e "  - Verzeichnis: /var/opt/minecraft/crafty"
    echo -e "  - Logs: sudo tail -f /var/opt/minecraft/crafty/logs/*.log"
    echo ""
    echo -e "${YELLOW}🔹 Playit.gg:${NC}"
    echo -e "  - Setup: ./playit-linux-amd64 setup"
    echo -e "  - Status: systemctl status playit"
    echo -e "  - Logs: journalctl -u playit -f"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Fertig! Drücken Sie eine Taste zum Beenden.${NC}"
    read -n 1 -s -r
}

# Hauptprogramm
main
