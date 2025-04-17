#!/bin/bash

# Minecraft Server Management Auto-Installer
# Version 2.0
# Für Debian/Ubuntu Linux
# Mit erweiterten Prüfroutinen und Debug-Funktionen

# ========== KONFIGURATION ==========
DEBUG=false
FORCE_INSTALL=false
BACKUP_ENABLED=true

# ========== FARBDEFINITIONEN ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========== FUNKTIONEN ==========

# Debug-Ausgabe
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Fehlerbehandlung
error() {
    echo -e "${RED}[FEHLER] $1${NC}"
    exit 1
}

# Überprüfung auf Root-Rechte
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Bitte führen Sie dieses Skript als root oder mit sudo aus."
    fi
    debug "Root-Check erfolgreich"
}

# Systemaktualisierung
system_update() {
    echo -e "${YELLOW}▶ Führe Systemupdate durch...${NC}"
    apt update > /dev/null 2>&1 || error "Systemupdate fehlgeschlagen"
    apt upgrade -y > /dev/null 2>&1 || error "Systemupgrade fehlgeschlagen"
    echo -e "${GREEN}✓ Systemupdate erfolgreich${NC}"
}

# Paketinstallation mit Prüfung
install_package() {
    local pkg=$1
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "${YELLOW}✓ $pkg ist bereits installiert${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}▶ Installiere $pkg...${NC}"
    apt install -y $pkg > /dev/null 2>&1 || error "Installation von $pkg fehlgeschlagen"
    echo -e "${GREEN}✓ $pkg erfolgreich installiert${NC}"
    return 1
}

# Java Installation mit Versionsprüfung
install_java() {
    local required_version="21"
    local installed_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    
    if [ ! -z "$installed_version" ] && [ "$installed_version" -ge "$required_version" ]; then
        echo -e "${YELLOW}✓ Java $installed_version ist bereits installiert${NC}"
        if [ "$FORCE_INSTALL" = false ]; then
            return 0
        fi
    fi

    echo -e "${YELLOW}▶ Installiere OpenJDK $required_version...${NC}"
    install_package "openjdk-${required_version}-jdk" || {
        echo -e "${GREEN}✓ Java erfolgreich installiert${NC}"
        java -version || error "Java-Version konnte nicht überprüft werden"
    }
}

# Crafty-Controller Installation
install_crafty() {
    local install_dir="/var/opt/minecraft/crafty"
    local installer_dir="crafty-installer-4.0"
    
    if [ -d "$install_dir" ]; then
        echo -e "${YELLOW}⚠ Crafty ist bereits installiert in $install_dir${NC}"
        if [ "$BACKUP_ENABLED" = true ]; then
            local backup_dir="${install_dir}_backup_$(date +%Y%m%d_%H%M%S)"
            echo -e "${YELLOW}▶ Erstelle Backup nach $backup_dir...${NC}"
            cp -r "$install_dir" "$backup_dir" || error "Backup fehlgeschlagen"
            echo -e "${GREEN}✓ Backup erfolgreich erstellt${NC}"
        fi
        
        if [ "$FORCE_INSTALL" = false ]; then
            read -p "Neuinstallation durchführen? (j/N) " response
            if [[ ! "$response" =~ ^[jJ] ]]; then
                return 0
            fi
        fi
    fi

    echo -e "${YELLOW}▶ Installiere Crafty-Controller...${NC}"
    [ -d "$installer_dir" ] && rm -rf "$installer_dir"
    git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git || error "Git-Clone fehlgeschlagen"
    
    cd "$installer_dir" || error "Verzeichniswechsel fehlgeschlagen"
    sudo ./install_crafty.sh || error "Crafty-Installation fehlgeschlagen"
    cd ..
    
    echo -e "${GREEN}✓ Crafty-Controller erfolgreich installiert${NC}"
}

# Crafty Service einrichten
setup_crafty_service() {
    local service_file="/etc/systemd/system/crafty.service"
    
    if [ -f "$service_file" ]; then
        echo -e "${YELLOW}⚠ Crafty-Service existiert bereits${NC}"
        if [ "$FORCE_INSTALL" = false ]; then
            return 0
        fi
    fi

    echo -e "${YELLOW}▶ Richte Crafty-Service ein...${NC}"
    cat <<EOF > "$service_file"
[Unit]
Description=Crafty Minecraft Panel
After=network.target

[Service]
Type=simple
User=crafty
WorkingDirectory=/var/opt/minecraft/crafty
ExecStart=/var/opt/minecraft/crafty/run_crafty.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl enable crafty.service > /dev/null 2>&1
    systemctl start crafty.service || error "Service-Start fehlgeschlagen"
    echo -e "${GREEN}✓ Crafty-Service erfolgreich eingerichtet${NC}"
}

# Playit.gg Installation
install_playit() {
    local playit_bin="/usr/local/bin/playit"
    local playit_version="v0.15.26"
    
    if [ -f "$playit_bin" ]; then
        echo -e "${YELLOW}⚠ Playit ist bereits installiert${NC}"
        if [ "$FORCE_INSTALL" = false ]; then
            return 0
        fi
    fi

    echo -e "${YELLOW}▶ Installiere Playit.gg ($playit_version)...${NC}"
    wget "https://github.com/playit-cloud/playit-agent/releases/download/$playit_version/playit-linux-amd64" -O playit-linux-amd64 || error "Download fehlgeschlagen"
    chmod +x playit-linux-amd64
    mv playit-linux-amd64 "$playit_bin" || error "Installation fehlgeschlagen"
    echo -e "${GREEN}✓ Playit.gg erfolgreich installiert${NC}"
}

# ========== HAUPTSCRIPT ==========

# Parameter verarbeiten
while getopts ":dfb" opt; do
    case $opt in
        d) DEBUG=true ;;
        f) FORCE_INSTALL=true ;;
        b) BACKUP_ENABLED=false ;;
        \?) error "Ungültige Option: -$OPTARG" ;;
    esac
done

# Header anzeigen
echo -e "\n${GREEN}=== Minecraft Server Management Installer v2.0 ===${NC}\n"
echo -e "Debug-Modus: $DEBUG"
echo -e "Erzwinge Installation: $FORCE_INSTALL"
echo -e "Backup aktiv: $BACKUP_ENABLED\n"

# Hauptinstallation
check_root
system_update

install_package "wget"
install_package "git"
install_package "sudo"
install_package "coreutils"

install_java
install_crafty
setup_crafty_service
install_playit

# Zusammenfassung
echo -e "\n${GREEN}=== Installation abgeschlossen ===${NC}"
echo -e "Crafty-Controller: http://$(hostname -I | cut -d' ' -f1):8000"
echo -e "Java Version: $(java -version 2>&1 | head -n 1)"
echo -e "Playit.gg: Bitte 'playit setup' ausführen\n"

echo -e "${YELLOW}Überprüfen Sie die Dienste mit:${NC}"
echo -e "Crafty Status: systemctl status crafty.service"
echo -e "Playit Status: ps aux | grep playit\n"

exit 0
