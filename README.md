# 🧱 Minecraft Server Auto-Installer

Dieses Skript automatisiert die Installation eines vollständigen Minecraft-Server-Management-Systems auf Debian-/Linux-Servern. Es installiert automatisch:

- **Crafty Controller** – Webinterface zur Verwaltung von Minecraft-Servern  
- **Playit.gg** – Tunneling-Service zur einfachen Serverfreigabe  
- **OpenJDK 21** – Java-Laufzeitumgebung für Minecraft  
- **Alle notwendigen Abhängigkeiten** – z. B. `wget`, `git`, `sudo`

---

## 🚀 Voraussetzungen

- Debian-basiertes Linux-System (z. B. Debian, Ubuntu)  
- Root-Zugriff oder `sudo`-Berechtigungen  
- Aktive Internetverbindung  

---

## ⚙️ Installation

Führe die folgenden Befehle im Terminal aus:

```bash

wget https://raw.githubusercontent.com/New60-Noob/Test-autosetup/main/install_script.sh
chmod +x install_script.sh
sudo ./install_script.sh

🔧 Erweiterte Optionen

Das Skript unterstützt zusätzliche Startparameter:

./install_script.sh -d    # Debug-Modus aktivieren (zeigt erweiterte Ausgaben)
./install_script.sh -f    # Erzwingt eine Neuinstallation, auch wenn bereits etwas installiert ist
./install_script.sh -b    # Deaktiviert automatische Backups vor der Installation

Du kannst die Optionen auch kombinieren, z. B.:

./install_script.sh -d -f

🧾 Manuelle Schritte nach der Installation

Richte den Tunneling-Dienst ein mit:

playit setup

🌐 Zugriff auf den Crafty Controller

    Standard-Adresse: http://<Ihre-IP>:8000

    Erstanmeldung
      Benutzername: admin
      Passwort anzeigen mit: sudo cat /var/opt/minecraft/crafty/crafty-4/app/config/default-creds.txt
