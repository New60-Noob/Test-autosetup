#!/bin/bash

# Minecraft Server Management Auto-Installer
# Version 3.0
# Mit Progress-Bars, robuster Java-Installation und erweitertem Error-Handling

# ========== KONFIGURATION ==========
DEBUG=false
FORCE_INSTALL=false
BACKUP_ENABLED=true
JAVA_VERSION="21"
CRAFTY_PORT="8000"

# ========== FARBDEFINITIONEN ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========== PROGRESS BAR FUNKTIONEN ==========

progress_bar() {
    local duration=$1
    local width=50
    local progress=0
    local steps=$((duration*10))
    local step=0
    
    printf "["
    while [ $step -lt $width ]; do
        printf "#"
        sleep 0.1
        step=$((step+1))
        printf "\r["
        printf "%0.s#" $(seq 1 $step)
        printf "%0.s " $(seq 1 $((width-step)))
        printf "] $((step*2))%%"
    done
    printf "\n"
}

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
    (apt update > /dev/null 2>&1) & spinner
    echo -e "\r${GREEN}✓ Paketquellen aktualisiert${NC}"
    
    echo -ne "${YELLOW}▶ Installiere Systemupdates...${NC}"
    (apt upgrade -y > /dev/null 2>&1) & spinner
    echo -e "\r${GREEN}✓ Systemupgrades abgeschlossen${NC}"
    
    progress_bar 2
}

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
        [ $? -ne 0 ] && error "Installation von $pkg_name fehlgeschlagen"
    fi
    
    echo -e "\r${GREEN}✓ $pkg_name erfolgreich installiert${NC}"
    progress_bar 1
}

install_java() {
    echo -ne "${YELLOW}▶ Prüfe Java-Version...${NC}"
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
    (apt install -y "openjdk-${JAVA_VERSION}-jdk" > /dev/null 2>&1) & spinner
    
    if [ $? -eq 0 ]; then
        echo -e "\r${GREEN}✓ Java aus Standard-Repository installiert${NC}"
    else
        # Versuch 2: Adoptium-Repository
        echo -ne "\r${YELLOW}⚠ Standard fehlgeschlagen, versuche Adoptium...${NC}"
        
        (apt install -y wget apt-transport-https gnupg > /dev/null 2>&1 && \
         wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /etc/apt/trusted.gpg.d/adoptium.asc && \
         echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/adoptium.list && \
         apt update > /dev/null 2>&1 && \
         apt install -y temurin-${JAVA_VERSION}-jdk > /dev/null 2>&1) & spinner
        
        if [ $? -eq 0 ]; then
            echo -e "\r${GREEN}✓ Java aus Adoptium-Repository installiert${NC}"
        else
            # Versuch 3: Manueller Download
            echo -ne "\r${YELLOW}⚠ Repository fehlgeschlagen, versuche manuellen Download...${NC}"
            
            local jdk_url="https://download.java.net/java/GA/jdk${JAVA_VERSION}/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz"
            local temp_dir=$(mktemp -d)
            
            (wget -q "$jdk_url" -O "$temp_dir/jdk.tar.gz" && \
             tar -xzf "$temp_dir/jdk.tar.gz" -C "$temp_dir" && \
             mkdir -p /usr/lib/jvm && \
             mv "$temp_dir/jdk-${JAVA_VERSION}" /usr/lib/jvm/ && \
             update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk-${JAVA_VERSION}/bin/java" 1 && \
             rm -rf "$temp_dir") & spinner
            
            [ $? -ne 0 ] && error "Java-Installation fehlgeschlagen"
            echo -e "\r${GREEN}✓ Java manuell installiert${NC}"
        fi
    fi

    # Verifikation
    echo -ne "${YELLOW}▶ Verifiziere Java-Installation...${NC}"
    if ! java -version > /dev/null 2>&1; then
        # Pfad aktualisieren
        export PATH=$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin
        if ! java -version > /dev/null 2>&1; then
            error "Java-Version konnte nicht überprüft werden\nManuell versuchen: 'export PATH=\$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin'"
        fi
    fi
    echo -e "\r${GREEN}✓ Java-Version bestätigt: $(java -version 2>&1 | head -n 1)${NC}"
    progress_bar 3
}

install_crafty() {
    local install_dir="/var/opt/minecraft/crafty"
    local installer_dir="crafty-installer-4.0"
    
    if [ -d "$install_dir" ]; then
        echo -e "${YELLOW}⚠ Crafty ist bereits installiert in $install_dir${NC}"
        if [ "$BACKUP_ENABLED" = true ]; then
            local backup_dir="${install_dir}_backup_$(date +%Y%m%d_%H%M%S)"
            echo -ne "${YELLOW}▶ Erstelle Backup...${NC}"
            (cp -r "$install_dir" "$backup_dir") & spinner
            echo -e "\r${GREEN}✓ Backup erstellt: $backup_dir${NC}"
        fi
        
        if [ "$FORCE_INSTALL" = false ]; then
            read -p "Neuinstallation durchführen? (j/N) " response
            [[ "$response" =~ ^[jJ] ]] || return 0
        fi
    fi

    echo -e "${YELLOW}▶ Installiere Crafty-Controller...${NC}"
    [ -d "$installer_dir" ] && (rm -rf "$installer_dir" & spinner)
    
    echo -ne "${YELLOW}▶ Klone Installer...${NC}"
    (git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git) & spinner
    [ $? -ne 0 ] && error "Git-Clone fehlgeschlagen"
    echo -e "\r${GREEN}✓ Installer geklont${NC}"
    
    cd "$installer_dir" || error "Verzeichniswechsel fehlgeschlagen"
    echo -ne "${YELLOW}▶ Führe Installation aus...${NC}"
    (sudo ./install_crafty.sh) & spinner
    [ $? -ne 0 ] && error "Crafty-Installation fehlgeschlagen"
    echo -e "\r${GREEN}✓ Crafty-Installation abgeschlossen${NC}"
    cd ..
    
    progress_bar 5
}

setup_crafty_service() {
    local service_file="/etc/systemd/system/crafty.service"
    
    if [ -f "$service_file" ]; then
        echo -e "${YELLOW}⚠ Crafty-Service existiert bereits${NC}"
        systemctl is-active --quiet crafty.service && (systemctl stop crafty.service & spinner)
    fi

    echo -ne "${YELLOW}▶ Erstelle Service-Datei...${NC}"
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
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    echo -e "\r${GREEN}✓ Service-Datei erstellt${NC}"
    
    echo -ne "${YELLOW}▶ Aktiviere Service...${NC}"
    (systemctl daemon-reexec && \
     systemctl enable crafty.service > /dev/null 2>&1 && \
     systemctl start crafty.service) & spinner
    [ $? -ne 0 ] && error "Service-Start fehlgeschlagen"
    echo -e "\r${GREEN}✓ Crafty-Service aktiviert${NC}"
    
    progress_bar 2
}

install_playit() {
    local playit_bin="/usr/local/bin/playit"
    local playit_version="v0.15.26"
    
    if [ -f "$playit_bin" ]; then
        echo -e "${YELLOW}⚠ Playit ist bereits installiert${NC}"
        [ "$FORCE_INSTALL" = false ] && return 0
    fi

    echo -e "${YELLOW}▶ Installiere Playit.gg ($playit_version)...${NC}"
    echo -ne "${YELLOW}▶ Lade herunter...${NC}"
    (wget "https://github.com/playit-cloud/playit-agent/releases/download/$playit_version/playit-linux-amd64" -O playit-linux-amd64) & spinner
    [ $? -ne 0 ] && error "Download fehlgeschlagen"
    echo -e "\r${GREEN}✓ Playit heruntergeladen${NC}"
    
    echo -ne "${YELLOW}▶ Setze Berechtigungen...${NC}"
    (chmod +x playit-linux-amd64 && \
     mv playit-linux-amd64 "$playit_bin") & spinner
    [ $? -ne 0 ] && error "Installation fehlgeschlagen"
    echo -e "\r${GREEN}✓ Playit installiert${NC}"
    
    progress_bar 2
}

# ========== HAUPTSCRIPT ==========

# Parameter verarbeiten
while getopts ":dfbh" opt; do
    case $opt in
        d) DEBUG=true ;;
        f) FORCE_INSTALL=true ;;
        b) BACKUP_ENABLED=false ;;
        h) 
            echo -e "${GREEN}Minecraft Server Management Installer v3.0${NC}"
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
echo -e "│ Minecraft Server Management Installer v3.0      │"
echo -e "│ Mit Progress-Bars und robuster Installation     │"
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
echo -e " ${GREEN}✓${NC} Crafty-Controller: http://$(hostname -I | cut -d' ' -f1):${CRAFTY_PORT}"
echo -e " ${GREEN}✓${NC} Java Version: $(java -version 2>&1 | head -n 1)"
echo -e " ${GREEN}✓${NC} Playit.gg: Bitte 'playit setup' ausführen\n"

echo -e "${YELLOW}Überprüfen Sie die Dienste mit:${NC}"
echo -e " - Crafty Status: ${CYAN}sudo systemctl status crafty.service${NC}"
echo -e " - Playit Status: ${CYAN}ps aux | grep playit${NC}\n"

echo -e "${YELLOW}Troubleshooting:${NC}"
echo -e " Falls Java nicht erkannt wird:"
echo -e " ${CYAN}export PATH=\$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin${NC}\n"

exit 0
