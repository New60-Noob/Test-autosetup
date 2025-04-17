#!/bin/bash

# Minecraft Server Management Auto-Installer
# Version 2.3
# Mit Progress-Bars und verbessertem UI

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

# ========== PROGRESS BAR FUNKTIONEN ==========

# Animierte Progress-Bar
progress_bar() {
    local duration=${1}
    local width=50
    local increment=$((100/$width))
    local progress=0
    local done=0
    local left=$width
    
    printf "\n${CYAN}["
    
    for ((i=0; i<=$width; i++)); do
        printf " "
    done
    
    printf "] 0%%${NC}"
    
    for ((i=0; i<=$width; i++)); do
        sleep $duration
        printf "\r${CYAN}["
        printf -v prog "%0.s#" $(seq 1 $i)
        printf -v rest "%0.s " $(seq 1 $(($width-$i)))
        printf "$prog$rest] $((i*$increment))%%${NC}"
    done
    printf "\n"
}

# Spinner-Animation
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ========== INSTALLATIONSFUNKTIONEN ==========

# Debug-Ausgabe
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Fehlerbehandlung
error() {
    echo -e "\n${RED}[✗] FEHLER: $1${NC}"
    echo -e "${YELLOW}Installation wurde abgebrochen.${NC}"
    exit 1
}

# Überprüfung auf Root-Rechte
check_root() {
    echo -ne "${YELLOW}▶ Prüfe Root-Rechte...${NC}"
    if [ "$EUID" -ne 0 ]; then
        error "Bitte führen Sie dieses Skript als root oder mit sudo aus."
    fi
    echo -e "\r${GREEN}✓ Root-Rechte bestätigt${NC}"
    debug "Root-Check erfolgreich"
}

# Systemaktualisierung
system_update() {
    echo -e "${YELLOW}▶ Führe Systemupdate durch...${NC}"
    
    # Progress-Bar im Hintergrund
    (apt update > /dev/null 2>&1) & spinner
    echo -e "\r${GREEN}✓ Paketquellen aktualisiert${NC}"
    
    # Fortschrittsanzeige für Upgrade
    echo -ne "${YELLOW}▶ Installiere Systemupdates...${NC}"
    (apt upgrade -y > /dev/null 2>&1) & spinner
    echo -e "\r${GREEN}✓ Systemupgrades abgeschlossen${NC}"
    
    progress_bar 0.02
}

# Paketinstallation mit Prüfung
install_package() {
    local pkg=$1
    local pkg_name=${2:-$pkg}
    
    echo -ne "${YELLOW}▶ Prüfe $pkg_name...${NC}"
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "\r${GREEN}✓ $pkg_name bereits installiert${NC}"
        return 0
    fi
    
    echo -ne "${YELLOW}▶ Installiere $pkg_name...${NC}"
    (apt install -y $pkg > /dev/null 2>&1) & spinner
    
    if [ $? -ne 0 ]; then
        echo -ne "\r${YELLOW}⚠ Problem bei $pkg_name, versuche Reparatur...${NC}"
        (apt --fix-broken install -y > /dev/null 2>&1 && apt install -y $pkg > /dev/null 2>&1) & spinner
        
        if [ $? -ne 0 ]; then
            error "Installation von $pkg_name fehlgeschlagen"
        fi
    fi
    
    echo -e "\r${GREEN}✓ $pkg_name erfolgreich installiert${NC}"
    progress_bar 0.01
    return 1
}

# Java Installation mit mehreren Fallbacks
install_java() {
    echo -ne "${YELLOW}▶ Prüfe Java-Version...${NC}"
    if type -p java > /dev/null 2>&1; then
        local installed_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
        if [ "$installed_version" -ge "$JAVA_VERSION" ]; then
            echo -e "\r${GREEN}✓ Java $installed_version bereits installiert${NC}"
            if [ "$FORCE_INSTALL" = false ]; then
                progress_bar 0.01
                return 0
            fi
        fi
    fi

    echo -e "\n${MAGENTA}=== Java $JAVA_VERSION Installation ===${NC}"
    
    # Versuch 1: Standard Repository
    echo -ne "${YELLOW}▶ Versuche Standard-Installation...${NC}"
    (apt install -y "openjdk-${JAVA_VERSION}-jdk" > /dev/null 2>&1) & spinner
    
    if [ $? -eq 0 ]; then
        echo -e "\r${GREEN}✓ Java aus Standard-Repository installiert${NC}"
    else
        echo -ne "\r${YELLOW}⚠ Standard fehlgeschlagen, versuche Adoptium...${NC}"
        
        # Versuch 2: Adoptium Repository
        (apt install -y wget apt-transport-https gnupg > /dev/null 2>&1 && \
         wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /etc/apt/trusted.gpg.d/adoptium.asc && \
         echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/adoptium.list && \
         apt update > /dev/null 2>&1 && \
         apt install -y temurin-${JAVA_VERSION}-jdk > /dev/null 2>&1) & spinner
        
        if [ $? -eq 0 ]; then
            echo -e "\r${GREEN}✓ Java aus Adoptium-Repository installiert${NC}"
        else
            echo -ne "\r${YELLOW}⚠ Repository fehlgeschlagen, versuche manuellen Download...${NC}"
            
            # Versuch 3: Manueller Download
            local jdk_url="https://download.java.net/java/GA/jdk${JAVA_VERSION}/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz"
            local temp_dir=$(mktemp -d)
            
            (wget -q "$jdk_url" -O "$temp_dir/jdk.tar.gz" && \
             tar -xzf "$temp_dir/jdk.tar.gz" -C "$temp_dir" && \
             mkdir -p /usr/lib/jvm && \
             mv "$temp_dir/jdk-${JAVA_VERSION}" /usr/lib/jvm/ && \
             update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-${JAVA_VERSION}/bin/java" 1 && \
             rm -rf "$temp_dir") & spinner
            
            if [ $? -ne 0 ]; then
                error "Java-Installation fehlgeschlagen"
            fi
            echo -e "\r${GREEN}✓ Java manuell installiert${NC}"
        fi
    fi
    
    echo -ne "${YELLOW}▶ Verifiziere Installation...${NC}"
    java -version > /dev/null 2>&1 || error "Java-Version konnte nicht überprüft werden"
    echo -e "\r${GREEN}✓ Java-Version bestätigt${NC}"
    
    progress_bar 0.03
}

# [...] (Die restlichen Funktionen install_crafty, setup_crafty_service, install_playit 
# werden analog mit Progress-Bars und Spinnern aktualisiert - aus Platzgründen gekürzt)

# ========== HAUPTSCRIPT ==========

# Parameter verarbeiten
while getopts ":dfbh" opt; do
    case $opt in
        d) DEBUG=true ;;
        f) FORCE_INSTALL=true ;;
        b) BACKUP_ENABLED=false ;;
        h) 
            echo -e "${GREEN}Minecraft Server Management Installer v2.3${NC}"
            echo -e "Verwendung: $0 [Optionen]"
            echo -e "Optionen:"
            echo -e "  -d  Debug-Modus"
            echo -e "  -f  Erzwinge Neuinstallation"
            echo -e "  -b  Deaktiviere Backups"
            echo -e "  -h  Diese Hilfe anzeigen"
            exit 0
            ;;
        \?) error "Ungültige Option: -$OPTARG" ;;
    esac
done

# Header anzeigen
clear
echo -e "\n${GREEN}┌───────────────────────────────────────────────────────┐"
echo -e "│ Minecraft Server Management Installer v2.3      │"
echo -e "│ Mit Progress-Anzeige und erweitertem Error-Handling │"
echo -e "└───────────────────────────────────────────────────────┘${NC}\n"

# Hauptinstallation
check_root
system_update

echo -e "${MAGENTA}=== Installiere Basis-Pakete ===${NC}"
install_package "wget" "Wget"
install_package "git" "Git"
install_package "sudo" "Sudo"
install_package "coreutils" "Core Utilities"
install_package "apt-transport-https" "HTTPS Transport"
install_package "gnupg" "GnuPG"

install_java

echo -e "${MAGENTA}=== Installiere Crafty-Controller ===${NC}"
install_crafty
setup_crafty_service

echo -e "${MAGENTA}=== Installiere Playit.gg ===${NC}"
install_playit

# Zusammenfassung
echo -e "\n${GREEN}┌───────────────────────────────────────────────────────┐"
echo -e "│ Installation erfolgreich abgeschlossen!          │"
echo -e "└───────────────────────────────────────────────────────┘${NC}"

echo -e "\n${YELLOW}Zusammenfassung:${NC}"
echo -e " ${GREEN}✓${NC} Crafty-Controller: http://$(hostname -I | cut -d' ' -f1):8000"
echo -e " ${GREEN}✓${NC} Java Version: $(java -version 2>&1 | head -n 1)"
echo -e " ${GREEN}✓${NC} Playit.gg: Bitte 'playit setup' ausführen\n"

echo -e "${YELLOW}Überprüfen Sie die Dienste mit:${NC}"
echo -e " - Crafty Status: ${CYAN}sudo systemctl status crafty.service${NC}"
echo -e " - Playit Status: ${CYAN}ps aux | grep playit${NC}\n"

exit 0
