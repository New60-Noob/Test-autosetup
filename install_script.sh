#!/bin/bash

# Minecraft Server Management Auto-Installer
# Version 2.4
# Mit robuster Java-Installation und erweitertem Error-Handling

# ========== KONFIGURATION ==========
DEBUG=false
FORCE_INSTALL=false
BACKUP_ENABLED=true
JAVA_VERSION="21"

# ========== FARBDEFINITIONEN ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========== FUNKTIONEN ==========

debug() {
    [ "$DEBUG" = true ] && echo -e "${BLUE}[DEBUG] $1${NC}"
}

error() {
    echo -e "\n${RED}[✗] FEHLER: $1${NC}"
    echo -e "${YELLOW}Installation wurde abgebrochen.${NC}"
    exit 1
}

check_root() {
    echo -ne "${YELLOW}▶ Prüfe Root-Rechte...${NC}"
    [ "$EUID" -ne 0 ] && error "Bitte führen Sie dieses Skript als root oder mit sudo aus."
    echo -e "\r${GREEN}✓ Root-Rechte bestätigt${NC}"
}

system_update() {
    echo -e "${YELLOW}▶ Führe Systemupdate durch...${NC}"
    apt update > /dev/null 2>&1 || error "Systemupdate fehlgeschlagen"
    apt upgrade -y > /dev/null 2>&1 || error "Systemupgrade fehlgeschlagen"
    echo -e "${GREEN}✓ Systemupdate erfolgreich${NC}"
}

install_package() {
    local pkg=$1
    echo -ne "${YELLOW}▶ Installiere $pkg...${NC}"
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "\r${GREEN}✓ $pkg bereits installiert${NC}"
        return 0
    fi
    
    if apt install -y $pkg > /dev/null 2>&1; then
        echo -e "\r${GREEN}✓ $pkg erfolgreich installiert${NC}"
        return 1
    else
        echo -ne "\r${YELLOW}⚠ Installationsproblem, versuche Reparatur...${NC}"
        apt --fix-broken install -y > /dev/null 2>&1
        apt install -y $pkg > /dev/null 2>&1 || error "Installation von $pkg fehlgeschlagen"
        echo -e "\r${GREEN}✓ $pkg nach Reparatur installiert${NC}"
        return 1
    fi
}

install_java() {
    echo -ne "${YELLOW}▶ Prüfe Java-Version...${NC}"
    
    # Prüfe vorhandene Java-Installation
    if type -p java > /dev/null 2>&1; then
        local installed_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
        if [ -n "$installed_version" ] && [ "$installed_version" -ge "$JAVA_VERSION" ]; then
            echo -e "\r${GREEN}✓ Java $installed_version bereits installiert${NC}"
            [ "$FORCE_INSTALL" = false ] && return 0
        fi
    fi

    echo -e "\n${MAGENTA}=== Java $JAVA_VERSION Installation ===${NC}"
    
    # Versuch 1: Standard-Repository
    echo -ne "${YELLOW}▶ Versuche Standard-Installation...${NC}"
    if apt install -y "openjdk-${JAVA_VERSION}-jdk" > /dev/null 2>&1; then
        echo -e "\r${GREEN}✓ Java aus Standard-Repository installiert${NC}"
    else
        echo -ne "\r${YELLOW}⚠ Standard fehlgeschlagen, versuche Adoptium...${NC}"
        
        # Versuch 2: Adoptium-Repository
        apt install -y wget apt-transport-https gnupg > /dev/null 2>&1
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /etc/apt/trusted.gpg.d/adoptium.asc
        echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/adoptium.list
        apt update > /dev/null 2>&1
        
        if apt install -y temurin-${JAVA_VERSION}-jdk > /dev/null 2>&1; then
            echo -e "\r${GREEN}✓ Java aus Adoptium-Repository installiert${NC}"
        else
            echo -ne "\r${YELLOW}⚠ Repository fehlgeschlagen, versuche manuellen Download...${NC}"
            
            # Versuch 3: Manueller Download
            local jdk_url="https://download.java.net/java/GA/jdk${JAVA_VERSION}/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz"
            local temp_dir=$(mktemp -d)
            
            wget -q "$jdk_url" -O "$temp_dir/jdk.tar.gz" || error "Java-Download fehlgeschlagen"
            tar -xzf "$temp_dir/jdk.tar.gz" -C "$temp_dir" || error "Entpacken fehlgeschlagen"
            mkdir -p /usr/lib/jvm || error "Verzeichnis konnte nicht erstellt werden"
            mv "$temp_dir/jdk-${JAVA_VERSION}" /usr/lib/jvm/ || error "Verschieben fehlgeschlagen"
            update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-${JAVA_VERSION}/bin/java" 1 || error "Update-Alternatives fehlgeschlagen"
            rm -rf "$temp_dir"
            
            echo -e "\r${GREEN}✓ Java manuell installiert${NC}"
        fi
    fi

    # Verifikation der Installation
    echo -ne "${YELLOW}▶ Verifiziere Java-Installation...${NC}"
    if ! java -version > /dev/null 2>&1; then
        # Versuche Pfad zu aktualisieren
        export PATH=$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin
        if ! java -version > /dev/null 2>&1; then
            error "Java-Version konnte nicht überprüft werden\nVersuche manuell mit: 'export PATH=\$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin'"
        fi
    fi
    echo -e "\r${GREEN}✓ Java-Version bestätigt: $(java -version 2>&1 | head -n 1)${NC}"
}

# [...] (Die restlichen Funktionen install_crafty, setup_crafty_service, install_playit bleiben gleich)

# ========== HAUPTSCRIPT ==========

# Header anzeigen
clear
echo -e "\n${GREEN}=== Minecraft Server Management Installer v2.4 ==="
echo -e "=== Mit verbesserter Java-Installation ===${NC}\n"

# Hauptinstallation
check_root
system_update

echo -e "${MAGENTA}=== Installiere Basis-Pakete ===${NC}"
install_package "wget"
install_package "git"
install_package "sudo"
install_package "coreutils"
install_package "apt-transport-https"
install_package "gnupg"

install_java

echo -e "${MAGENTA}=== Installiere Crafty-Controller ===${NC}"
install_crafty
setup_crafty_service

echo -e "${MAGENTA}=== Installiere Playit.gg ===${NC}"
install_playit

# Zusammenfassung
echo -e "\n${GREEN}=== Installation erfolgreich abgeschlossen! ==="
echo -e "=== Zugangsdaten und Überprüfungsbefehle ===${NC}\n"

echo -e "${YELLOW}Crafty-Controller:${NC}"
echo -e " URL: http://$(hostname -I | cut -d' ' -f1):8000"
echo -e " Status: ${CYAN}sudo systemctl status crafty.service${NC}\n"

echo -e "${YELLOW}Java Installation:${NC}"
echo -e " Version: $(java -version 2>&1 | head -n 1)"
echo -e " Pfad: $(which java)\n"

echo -e "${YELLOW}Playit.gg:${NC}"
echo -e " Konfiguration: ${CYAN}playit setup${NC}"
echo -e " Status: ${CYAN}ps aux | grep playit${NC}\n"

exit 0
