#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Debug-Modus (0=aus, 1=ein)
DEBUG=0

# Logdatei
LOG_FILE="install.log"

# Funktionen
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    if [ "$DEBUG" -eq 1 ]; then
        echo -e "$1"
    fi
}

progress() {
    echo -ne "${BLUE}[${NC}${GREEN}${1}%${NC}${BLUE}]${NC} ${2}\r"
    sleep 0.1
}

error() {
    echo -e "${RED}Fehler: ${NC}$1"
    log "FEHLER: $1"
    exit 1
}

check_root() {
    progress 5 "Überprüfe Root-Rechte..."
    if [ "$(id -u)" -ne 0 ]; then
        error "Dieses Skript muss als root ausgeführt werden!"
    fi
    log "Root-Rechte bestätigt"
}

check_debian() {
    progress 10 "Überprüfe Debian-Version..."
    if [ ! -f /etc/debian_version ]; then
        error "Dies ist kein Debian-System!"
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version)
    if [[ ! "$DEBIAN_VERSION" =~ ^12 ]]; then
        echo -e "${YELLOW}Warnung: Dieses Skript wurde für Debian 12 entwickelt. Aktuelle Version: $DEBIAN_VERSION${NC}"
        log "Warnung: Nicht getestete Debian-Version: $DEBIAN_VERSION"
    fi
    log "Debian-Version bestätigt: $DEBIAN_VERSION"
}

update_system() {
    progress 15 "Aktualisiere Systempakete..."
    log "Starte apt update"
    apt update -y >> "$LOG_FILE" 2>&1 || error "apt update fehlgeschlagen"
    
    progress 30 "Upgrade Systempakete..."
    log "Starte apt upgrade"
    apt upgrade -y >> "$LOG_FILE" 2>&1 || error "apt upgrade fehlgeschlagen"
    
    progress 45 "Installiere erforderliche Abhängigkeiten..."
    log "Installiere git und andere Abhängigkeiten"
    apt install -y git curl wget >> "$LOG_FILE" 2>&1 || error "Paketinstallation fehlgeschlagen"
}

install_crafty() {
    progress 50 "Installiere Crafty Controller..."
    log "Klone Crafty Installer"
    git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git >> "$LOG_FILE" 2>&1 || error "Git clone fehlgeschlagen"
    
    cd crafty-installer-4.0 || error "Verzeichniswechsel fehlgeschlagen"
    
    progress 65 "Führe Crafty Installer aus..."
    log "Starte install_crafty.sh"
    chmod +x install_crafty.sh
    ./install_crafty.sh >> "$LOG_FILE" 2>&1 || error "Crafty Installation fehlgeschlagen"
    
    progress 80 "Starte Crafty Controller..."
    log "Starte Crafty Dienst"
    sudo -u crafty bash -c 'cd /var/opt/minecraft/crafty && ./run_crafty.sh' >> "$LOG_FILE" 2>&1 &
    
    # Warte kurz um sicherzustellen, dass der Dienst läuft
    sleep 5
    if ! pgrep -f run_crafty.sh > /dev/null; then
        echo -e "${YELLOW}Warnung: Crafty scheint nicht zu laufen. Bitte manuell überprüfen.${NC}"
        log "Warnung: Crafty läuft möglicherweise nicht"
    else
        log "Crafty erfolgreich gestartet"
    fi
}

install_playit() {
    progress 85 "Installiere Playit.gg..."
    log "Lade Playit.gg herunter"
    wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-amd64 -O /usr/local/bin/playit >> "$LOG_FILE" 2>&1 || error "Download fehlgeschlagen"
    
    chmod +x /usr/local/bin/playit >> "$LOG_FILE" 2>&1
    
    progress 90 "Konfiguriere Playit.gg Service..."
    log "Erstelle Systemd Service für Playit"
    
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
    systemctl enable playit >> "$LOG_FILE" 2>&1 || error "Playit Service konnte nicht aktiviert werden"
    systemctl start playit >> "$LOG_FILE" 2>&1 || error "Playit Service konnte nicht gestartet werden"
    
    log "Playit.gg erfolgreich installiert und gestartet"
}

cleanup() {
    progress 95 "Aufräumen..."
    if [ -d "crafty-installer-4.0" ]; then
        rm -rf crafty-installer-4.0 >> "$LOG_FILE" 2>&1
    fi
    log "Aufräumen abgeschlossen"
}

show_completion() {
    echo -e "\n${GREEN}Installation abgeschlossen!${NC}"
    echo -e "${BLUE}Zusammenfassung:${NC}"
    echo -e " - Crafty Controller installiert und gestartet"
    echo -e " - Playit.gg installiert und als Service eingerichtet"
    echo -e "\n${YELLOW}Wichtige Informationen:${NC}"
    echo -e " - Crafty läuft auf Port 8000 (http://$(hostname -I | awk '{print $1}'):8000)"
    echo -e " - Playit.gg muss noch konfiguriert werden. Führe 'playit setup' aus."
    echo -e " - Installationslog: $PWD/$LOG_FILE"
    echo -e "\n${GREEN}Viel Spaß mit deinem Minecraft Server Controller!${NC}"
}

# Hauptprogramm
main() {
    clear
    echo -e "${GREEN}=== Automatische Installation von Crafty Controller und Playit.gg ===${NC}\n"
    
    # Logdatei initialisieren
    echo "=== Installationslog $(date) ===" > "$LOG_FILE"
    
    check_root
    check_debian
    update_system
    install_crafty
    install_playit
    cleanup
    
    # Fortschritt auf 100% setzen
    progress 100 "Fertig!"
    sleep 0.5
    
    show_completion
}

# Skript ausführen
main
