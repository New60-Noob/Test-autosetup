#!/bin/bash

# Skript für automatische Installation von Crafty-Controller und Playit.gg
# Für Debian/Linux
# Erweitert um Java-Installation

# Funktion zur Überprüfung, ob das Skript als root ausgeführt wird
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Bitte führen Sie dieses Skript als root oder mit sudo aus."
        exit 1
    fi
}

# Systemaktualisierung durchführen
system_update() {
    echo "Führe Systemupdate durch..."
    apt update && apt upgrade -y
    echo "Update abgeschlossen."
}

# Notwendige Pakete installieren
install_packages() {
    echo "Installiere notwendige Pakete..."
    apt-get install -y wget git sudo
    echo "Paketinstallation abgeschlossen."
}

# Java 21 JDK installieren
install_java() {
    echo "Installiere OpenJDK 21..."
    apt install -y openjdk-21-jdk
    echo "Java Installation abgeschlossen."
    java -version
}

# Crafty-Controller installieren
install_crafty() {
    echo "Installiere Crafty-Controller..."
    apt update && apt upgrade -y && apt install -y git
    git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git
    cd crafty-installer-4.0 || exit
    sudo ./install_crafty.sh
    cd ..
    echo "Crafty-Controller Installation abgeschlossen."
}

# Crafty Autostart einrichten
setup_crafty_service() {
    echo "Richte Crafty Autostart ein..."
    cat <<EOF > /etc/systemd/system/crafty.service
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
    systemctl enable crafty.service
    systemctl start crafty.service
    echo "Crafty Autostart eingerichtet."
}

# Playit.gg installieren
install_playit() {
    echo "Installiere Playit.gg..."
    wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64 -O playit-linux-amd64
    chmod +x playit-linux-amd64
    mv playit-linux-amd64 /usr/local/bin/playit
    echo "Playit.gg Installation abgeschlossen."
}

# Playit Autostart einrichten
setup_playit_service() {
    echo "Richte Playit Autostart ein..."
    ./playit-linux-amd64 &
    echo "Playit Autostart eingerichtet."
    echo "Führe 'playit setup' manuell aus, um die Konfiguration abzuschließen."
}

# Hauptfunktion
main() {
    check_root
    system_update
    install_packages
    install_java
    install_crafty
    setup_crafty_service
    install_playit
    setup_playit_service
    
    echo ""
    echo "Installation abgeschlossen!"
    echo "Crafty-Controller sollte jetzt unter der angegebenen IP erreichbar sein."
    echo "Für Playit.gg müssen Sie noch 'playit setup' manuell ausführen."
    echo "Java Version:"
    java -version
}

# Skript ausführen
main
