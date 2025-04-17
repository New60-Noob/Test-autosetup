#!/bin/bash

# Minecraft Server Management Auto-Installer
# Version 3.2
# Mit vollständiger Crafty-Problembehebung

# ========== KONFIGURATION ==========
DEBUG=false
FORCE_INSTALL=false
BACKUP_ENABLED=true
JAVA_VERSION="21"
CRAFTY_PORT="8000"
CRAFTY_DIR="/var/opt/minecraft/crafty"
CRAFTY_USER="crafty"

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
        # Versuch 2: Adoptium-Repository
        echo -ne "\r${YELLOW}⚠ Standard fehlgeschlagen, versuche Adoptium...${NC}"
        
        apt install -y wget apt-transport-https gnupg > /dev/null 2>&1
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /etc/apt/trusted.gpg.d/adoptium.asc
        echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/adoptium.list
        apt update > /dev/null 2>&1
        
        if apt install -y temurin-${JAVA_VERSION}-jdk > /dev/null 2>&1; then
            echo -e "\r${GREEN}✓ Java aus Adoptium-Repository installiert${NC}"
        else
            # Versuch 3: Manueller Download
            echo -ne "\r${YELLOW}⚠ Repository fehlgeschlagen, versuche manuellen Download...${NC}"
            
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

    # Verifikation
    echo -ne "${YELLOW}▶ Verifiziere Java-Installation...${NC}"
    if ! java -version > /dev/null 2>&1; then
        export PATH=$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin
        if ! java -version > /dev/null 2>&1; then
            error "Java-Version konnte nicht überprüft werden\nManuell versuchen: 'export PATH=\$PATH:/usr/lib/jvm/jdk-${JAVA_VERSION}/bin'"
        fi
    fi
    echo -e "\r${GREEN}✓ Java-Version bestätigt: $(java -version 2>&1 | head -n 1)${NC}"
}

setup_crafty_user() {
    echo -ne "${YELLOW}▶ Prüfe Crafty-Benutzer...${NC}"
    if ! id -u $CRAFTY_USER &>/dev/null; then
        useradd -r -d $CRAFTY_DIR -s /bin/bash $CRAFTY_USER || error "Benutzer $CRAFTY_USER konnte nicht angelegt werden"
        echo -e "\r${GREEN}✓ Benutzer $CRAFTY_USER angelegt${NC}"
    else
        echo -e "\r${GREEN}✓ Benutzer $CRAFTY_USER existiert bereits${NC}"
    fi

    # Berechtigungen setzen
    mkdir -p $CRAFTY_DIR
    chown -R $CRAFTY_USER:$CRAFTY_USER $CRAFTY_DIR
    chmod 755 $CRAFTY_DIR
}

install_crafty() {
    local installer_dir="crafty-installer-4.0"
    
    if [ -d "$CRAFTY_DIR" ]; then
        echo -e "${YELLOW}⚠ Crafty ist bereits installiert in $CRAFTY_DIR${NC}"
        if [ "$BACKUP_ENABLED" = true ]; then
            local backup_dir="${CRAFTY_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
            echo -ne "${YELLOW}▶ Erstelle Backup...${NC}"
            cp -r "$CRAFTY_DIR" "$backup_dir" || error "Backup fehlgeschlagen"
            echo -e "\r${GREEN}✓ Backup erstellt: $backup_dir${NC}"
        fi
        
        if [ "$FORCE_INSTALL" = false ]; then
            read -p "Neuinstallation durchführen? (j/N) " response
            [[ "$response" =~ ^[jJ] ]] || return 0
        fi
    fi

    echo -e "${YELLOW}▶ Installiere Crafty-Controller...${NC}"
    [ -d "$installer_dir" ] && rm -rf "$installer_dir"
    
    echo -ne "${YELLOW}▶ Klone Installer...${NC}"
    git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git || error "Git-Clone fehlgeschlagen"
    echo -e "\r${GREEN}✓ Installer geklont${NC}"
    
    cd "$installer_dir" || error "Verzeichniswechsel fehlgeschlagen"
    
    # Automatische Antworten für die Crafty-Installation
    echo -ne "${YELLOW}▶ Konfiguriere automatische Installation...${NC}"
    sed -i 's/input("\n{}{} - {}{}: ".format(bcolors.BOLD, q, valid_answers, bcolors.ENDC)).lower()/"y"/g' app/helper.py
    echo -e "\r${GREEN}✓ Automatische Konfiguration abgeschlossen${NC}"
    
    echo -ne "${YELLOW}▶ Führe Installation aus...${NC}"
    sudo ./install_crafty.sh || error "Crafty-Installation fehlgeschlagen"
    echo -e "\r${GREEN}✓ Crafty-Installation abgeschlossen${NC}"
    cd ..
}

setup_crafty_service() {
    local service_file="/etc/systemd/system/crafty.service"
    
    # Service-Datei erstellen
    echo -ne "${YELLOW}▶ Erstelle Service-Datei...${NC}"
    cat <<EOF > "$service_file"
[Unit]
Description=Crafty Minecraft Panel
After=network.target

[Service]
Type=simple
User=$CRAFTY_USER
Group=$CRAFTY_USER
WorkingDirectory=$CRAFTY_DIR
ExecStart=$CRAFTY_DIR/run_crafty.sh
Restart=always
RestartSec=5
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/jvm/jdk-$JAVA_VERSION/bin"

[Install]
WantedBy=multi-user.target
EOF
    echo -e "\r${GREEN}✓ Service-Datei erstellt${NC}"

    # Berechtigungen setzen
    chmod 644 "$service_file"
    chown root:root "$service_file"
    chmod +x "$CRAFTY_DIR/run_crafty.sh"

    # Systemd aktualisieren
    echo -ne "${YELLOW}▶ Aktualisiere Systemd...${NC}"
    systemctl daemon-reload || error "Daemon-Reload fehlgeschlagen"
    echo -e "\r${GREEN}✓ Systemd aktualisiert${NC}"

    # Service aktivieren
    echo -ne "${YELLOW}▶ Aktiviere Service...${NC}"
    systemctl enable crafty.service > /dev/null 2>&1 || error "Service-Aktivierung fehlgeschlagen"
    echo -e "\r${GREEN}✓ Service aktiviert${NC}"

    # Service starten
    echo -ne "${YELLOW}▶ Starte Crafty-Service...${NC}"
    if ! systemctl start crafty.service; then
        echo -e "\r${YELLOW}⚠ Erster Startversuch fehlgeschlagen, versuche erneut...${NC}"
        sleep 2
        systemctl restart crafty.service || error "Service-Start fehlgeschlagen"
    fi
    echo -e "\r${GREEN}✓ Crafty-Service gestartet${NC}"

    # Finale Überprüfung
    echo -ne "${YELLOW}▶ Verifiziere Service-Status...${NC}"
    sleep 3  # Wartezeit für den Start
    if systemctl is-active --quiet crafty.service; then
        echo -e "\r${GREEN}✓ Crafty läuft korrekt${NC}"
    else
        echo -e "\r${YELLOW}⚠ Service läuft nicht, zeige Logs:${NC}"
        journalctl -u crafty.service -b --no-pager | tail -n 20
        error "Crafty-Service konnte nicht gestartet werden"
    fi
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
    wget "https://github.com/playit-cloud/playit-agent/releases/download/$playit_version/playit-linux-amd64" -O playit-linux-amd64 || error "Download fehlgeschlagen"
    echo -e "\r${GREEN}✓ Playit heruntergeladen${NC}"
    
    echo -ne "${YELLOW}▶ Setze Berechtigungen...${NC}"
    chmod +x playit-linux-amd64
    mv playit-linux-amd64 "$playit_bin" || error "Installation fehlgeschlagen"
    echo -e "\r${GREEN}✓ Playit installiert${NC}"
}

verify_installation() {
    echo -e "\n${MAGENTA}=== Verifikation der Installation ===${NC}"
    
    # Crafty-Status
    echo -ne "${YELLOW}▶ Prüfe Crafty-Service...${NC}"
    if systemctl is-active --quiet crafty.service; then
        echo -e "\r${GREEN}✓ Crafty-Service läuft${NC}"
    else
        echo -e "\r${RED}✗ Crafty-Service läuft nicht${NC}"
        journalctl -u crafty.service -b --no-pager | tail -n 20
    fi
    
    # Port-Verfügbarkeit
    echo -ne "${YELLOW}▶ Prüfe Port $CRAFTY_PORT...${NC}"
    if ss -tulpn | grep -q ":$CRAFTY_PORT"; then
        echo -e "\r${GREEN}✓ Port $CRAFTY_PORT ist in Benutzung${NC}"
    else
        echo -e "\r${RED}✗ Port $CRAFTY_PORT nicht belegt${NC}"
    fi
    
    # Web-Zugriff testen
    echo -ne "${YELLOW}▶ Teste Web-Zugriff...${NC}"
    if curl -sSf "http://127.0.0.1:$CRAFTY_PORT" >/dev/null; then
        echo -e "\r${GREEN}✓ Webinterface erreichbar unter: http://$(hostname -I | cut -d' ' -f1):$CRAFTY_PORT${NC}"
    else
        echo -e "\r${YELLOW}⚠ Webinterface nicht erreichbar${NC}"
    fi
}

# ========== HAUPTSCRIPT ==========

# Parameter verarbeiten
while getopts ":dfbh" opt; do
    case $opt in
        d) DEBUG=true ;;
        f) FORCE_INSTALL=true ;;
        b) BACKUP_ENABLED=false ;;
        h) 
            echo -e "${GREEN}Minecraft Server Management Installer v3.2${NC}"
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
echo -e "\n${GREEN}=== Minecraft Server Management Installer v3.2 ==="
echo -e "=== Mit garantierter Crafty-Startfunktion ===${NC}\n"

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

echo -e "${MAGENTA}=== Crafty-Controller Installation ===${NC}"
setup_crafty_user
install_crafty
setup_crafty_service

echo -e "${MAGENTA}=== Playit.gg Installation ===${NC}"
install_playit

# Verifikation
verify_installation

# Zusammenfassung
echo -e "\n${GREEN}=== Installation abgeschlossen! ==="
echo -e "=== Zugangsdaten und Befehle ==="
echo -e "Crafty-URL: http://$(hostname -I | cut -d' ' -f1):$CRAFTY_PORT"
echo -e "Service-Status: systemctl status crafty.service"
echo -e "Logs anzeigen: journalctl -u crafty.service -f${NC}\n"

exit 0
