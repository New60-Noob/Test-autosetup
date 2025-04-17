#!/bin/bash

# Funktion zur Überprüfung, ob ein Befehl erfolgreich war
check_success() {
    if [ $? -ne 0 ]; then
        echo "Fehler beim Ausführen des Befehls: $1"
        exit 1
    fi
}

# Systemaktualisierung und Installation von Git
echo "Aktualisiere System und installiere Git..."
sudo apt update && sudo apt upgrade -y && sudo apt install git -y
check_success "Systemaktualisierung und Git-Installation"

# Crafty-Controller Installation
echo "Installiere Crafty-Controller..."
git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git
check_success "Git Clone von Crafty-Installer"

cd crafty-installer-4.0
check_success "Wechsel in Crafty-Installer-Verzeichnis"

echo "Starte Crafty-Installation (manuelle Bestätigung erforderlich)..."
sudo ./install_crafty.sh
check_success "Crafty-Installationsskript"

# Crafty starten
echo "Starte Crafty..."
sudo su - crafty -c "cd /var/opt/minecraft/crafty && ./run_crafty.sh &"
check_success "Starten von Crafty"

# Playit.gg Installation
echo "Installiere Playit.gg..."
wget https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64
check_success "Download von Playit"

chmod +x playit-linux-amd64
check_success "Berechtigungen für Playit setzen"

# Playit als Service einrichten
echo "Richte Playit als Service ein..."
sudo mv playit-linux-amd64 /usr/local/bin/playit
sudo bash -c 'cat > /etc/systemd/system/playit.service <<EOF
[Unit]
Description=Playit Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/playit
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl start playit
sudo systemctl enable playit
check_success "Playit-Service-Einrichtung"

echo "Setup abgeschlossen!"
echo "1. Crafty sollte jetzt laufen (Port 8443)"
echo "2. Playit wurde installiert und als Service eingerichtet"
echo "3. Führe 'playit setup' manuell aus, um die Playit-Konfiguration abzuschließen"
