#!/bin/bash

# =====================================================================
# ███████╗███████╗██████╗░░█████╗░░██╗░░░░░░░██╗░█████╗░██████╗░██╗░░██╗
# ╚════██║██╔════╝██╔══██╗██╔══██╗░██║░░██╗░░██║██╔══██╗██╔══██╗██║░██╔╝
# ░░███╔═╝█████╗░░██████╔╝██║░░██║░╚██╗████╗██╔╝██║░░██║██████╔╝█████═╝░
# ██╔══╝░░██╔══╝░░██╔══██╗██║░░██║░░████╔═████║░██║░░██║██╔══██╗██╔═██╗░
# ███████╗███████╗██║░░██║╚█████╔╝░░╚██╔╝░╚██╔╝░╚█████╔╝██║░░██║██║░╚██╗
# ╚══════╝╚══════╝╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝
# ZeroWork Installer v1.0.0 | Créé par Romain Jolly Martoia | 
# Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF
# ======================================================================

# Activer la vérification stricte des erreurs
set -e

# Variables globales pour les versions
ZEROWORK_VERSION="${1:-1.1.60}"
RUSTDESK_VERSION="${2:-1.3.8}"

# Sauvegarder le chemin absolu du script pour la suppression à la fin
SCRIPT_ABSOLUTE_PATH="$(realpath "$0")"

# Détecter la version d'Ubuntu dès le début
UBUNTU_VERSION=$(lsb_release -rs)

# Initialiser RUSTDESK_START_METHOD avec une valeur par défaut
RUSTDESK_START_METHOD="s"

# ====================== FONCTIONS UTILITAIRES ======================

# Couleurs pour améliorer la lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Pas de couleur

# Fonction pour afficher des messages d'information
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction pour afficher des messages de succès
success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1"
}

# Fonction pour afficher des messages d'avertissement
warning() {
    echo -e "${YELLOW}[AVERTISSEMENT]${NC} $1"
}

# Fonction pour afficher des messages d'erreur
error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# Fonction pour afficher un en-tête de section
section() {
    echo ""
    echo -e "${PURPLE}======================= $1 =======================${NC}"
}

# Fonction de vérification d'erreur
check_error() {
    local exit_code=$?
    local error_message="$1"
    
    if [ $exit_code -ne 0 ]; then
        error "$error_message (code : $exit_code)"
        error "Exécution du script arrêtée pour éviter d'autres problèmes."
        exit $exit_code
    fi
}

# Vérifier l'espace disque avant de continuer
check_disk_space() {
    local MIN_SPACE=3  # GB minimum requis
    local AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [ "$AVAILABLE" -lt "$MIN_SPACE" ]; then
        error "Espace disque insuffisant. Au moins ${MIN_SPACE}G requis, mais seulement ${AVAILABLE}G disponible."
        exit 1
    fi
    
    info "Vérification de l'espace disque réussie : ${AVAILABLE}G disponible"
}

# Vérifier et installer les dépendances requises
check_dependencies() {
    local dependencies=("bc" "curl" "wget" "apache2-utils")
    local missing_deps=()
    
    info "Vérification des dépendances requises..."
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null && ! is_package_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        info "Installation des dépendances manquantes : ${missing_deps[*]}"
        sudo apt update && sudo apt install -y "${missing_deps[@]}" || {
            error "Échec de l'installation des dépendances requises"
            exit 1
        }
    fi
}

# Fonction pour vérifier si un paquet est installé
is_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Fonction pour valider un nom d'utilisateur
validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
        return 1
    fi
    return 0
}

# Fonction pour sauvegarder les identifiants de manière sécurisée
save_credentials_securely() {
    local filename="$1"
    local content="$2"
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$(dirname "$filename")"
    
    # Créer un fichier d'identifiants avec des permissions restreintes
    echo -e "$content" > "$filename"
    
    # Définir des permissions sécurisées
    chmod 600 "$filename"
    
    success "Identifiants sauvegardés en toute sécurité dans $filename"
}

# Fonction pour gérer le nettoyage du script
cleanup_script() {
    local delete_choice="$1"
    
    if [[ "$delete_choice" == "o" ]]; then
        rm -- "$SCRIPT_ABSOLUTE_PATH"
        success "Fichier script supprimé."
    else
        info "Fichier script conservé."
    fi
}

# Fonction de mise à jour du système pour consolider toutes les mises à jour apt
system_update() {
    info "Vérification des problèmes dpkg et correction..."
    
    # Vérifier si le répertoire des mises à jour contient des fichiers problématiques
    if [ -d "/var/lib/dpkg/updates" ] && [ "$(ls -A /var/lib/dpkg/updates 2>/dev/null)" ]; then
        info "Nettoyage du répertoire des mises à jour dpkg..."
        sudo rm -f /var/lib/dpkg/updates/* || warning "Impossible de nettoyer le répertoire des mises à jour dpkg."
    fi
    
    # Essayer de configurer les paquets en attente
    info "Configuration des paquets en attente..."
    sudo dpkg --configure -a || warning "La configuration dpkg a rencontré des problèmes, tentative de continuer..."
    
    # Essayer de réparer les dépendances cassées
    info "Réparation des dépendances cassées..."
    sudo apt-get -f install -y || warning "Impossible de réparer toutes les dépendances, tentative de continuer..."
    
    info "Mise à jour du système..."
    sudo apt update || check_error "Impossible de mettre à jour les paquets"
    sudo apt upgrade -y || check_error "Impossible de mettre à niveau le système"
}

# ====================== FONCTIONS PRINCIPALES ======================

# Fonction pour installer les outils de sécurité du système
install_security_tools() {
    section "CONFIGURATION DE LA SÉCURITÉ"
    
    # Fail2ban
    if ! is_package_installed "fail2ban"; then
        info "Installation de fail2ban..."
        sudo apt install -y fail2ban || check_error "Échec de l'installation de fail2ban"
        
        info "Configuration de Fail2ban pour protéger contre les attaques par force brute..."
        sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
    else
        info "fail2ban déjà installé, vérification de la configuration..."
        # Vérifier si le fichier jail.local existe, le créer si nécessaire
        if [ ! -f /etc/fail2ban/jail.local ]; then
            info "Création du fichier de configuration fail2ban..."
            sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
            sudo systemctl restart fail2ban
        fi
    fi

    # UFW
    if ! is_package_installed "ufw"; then
        info "Installation de ufw (Pare-feu non compliqué)..."
        sudo apt install -y ufw || check_error "Échec de l'installation de ufw"
    else
        info "ufw déjà installé, vérification de la configuration..."
    fi

    # Configurer UFW (même s'il est déjà installé, nous devons assurer une configuration correcte des ports)
    info "Configuration du pare-feu (UFW)..."
    
    # Vérifier si les règles par défaut sont configurées
    if ! sudo ufw status verbose | grep -q "Default: deny (incoming)"; then
        sudo ufw default deny incoming
    fi
    
    if ! sudo ufw status verbose | grep -q "Default: allow (outgoing)"; then
        sudo ufw default allow outgoing
    fi
    
    # Vérifier et ajouter les règles SSH
    if ! sudo ufw status | grep -q "22/tcp"; then
        sudo ufw allow ssh
        info "Règle SSH ajoutée à UFW."
    fi
    
    # Ports RustDesk pour la connexion, le relais et la découverte
    sudo ufw allow 21115:21119/tcp
    sudo ufw allow 21115:21119/udp
    # Port RustDesk supplémentaire pour la connexion directe
    sudo ufw allow 21116/tcp
    
    # Activer uniquement si ce n'est pas déjà activé pour éviter de perturber les connexions existantes
    if ! sudo ufw status | grep -q "Status: active"; then
        sudo ufw --force enable || check_error "Échec de l'activation d'UFW"
    else
        info "UFW déjà activé, règles de port mises à jour."
    fi

    # Mises à jour automatiques
    if ! is_package_installed "unattended-upgrades"; then
        info "Installation de unattended-upgrades..."
        sudo apt install -y unattended-upgrades || check_error "Échec de l'installation de unattended-upgrades"
        
        # Configurer les mises à jour de sécurité automatiques
        info "Configuration des mises à jour de sécurité automatiques..."
        sudo dpkg-reconfigure -plow unattended-upgrades
    else
        info "unattended-upgrades déjà installé, installation ignorée."
    fi
    
    success "Outils de sécurité installés et configurés"
}

# Fonction pour configurer l'environnement GUI
setup_gui_environment() {
    section "CONFIGURATION DE L'ENVIRONNEMENT GUI"
    
    info "Installation du bureau XFCE..."
    sudo apt install xfce4 xfce4-goodies -y || check_error "Échec de l'installation du bureau XFCE"

    # Configuration de l'utilisateur GUI
    read -p "Entrez un nom d'utilisateur pour l'utilisateur GUI (par défaut : gui-user) : " GUI_USERNAME
    GUI_USERNAME=${GUI_USERNAME:-gui-user}
    # Valider le nom d'utilisateur
    if ! validate_username "$GUI_USERNAME"; then
        warning "Format de nom d'utilisateur invalide."
        echo "Le nom d'utilisateur doit commencer par une lettre minuscule et ne peut contenir que des lettres minuscules, des chiffres et des tirets."
        echo "Options :"
        echo "1) Utiliser le nom d'utilisateur par défaut (gui-user)"
        echo "2) Entrer un nouveau nom d'utilisateur"
        read -p "Votre choix (1/2) : " USERNAME_CHOICE
        
        if [[ "$USERNAME_CHOICE" == "2" ]]; then
            while true; do
                read -p "Veuillez entrer un nom d'utilisateur valide : " GUI_USERNAME
                if validate_username "$GUI_USERNAME"; then
                    echo "Nom d'utilisateur valide : $GUI_USERNAME"
                    break
                else
                    echo "Format invalide. Réessayez."
                fi
            done
        else
            GUI_USERNAME="gui-user"
            info "Utilisation du nom d'utilisateur par défaut : gui-user"
        fi
    fi

    # Confirmation du nom d'utilisateur
    echo ""
    echo "==> Le nom d'utilisateur GUI sera : $GUI_USERNAME"
    read -p "Confirmez-vous ce choix ? (o/n) : " CONFIRM_USERNAME
    if [[ "$CONFIRM_USERNAME" != "o" ]]; then
        error "Installation interrompue. Veuillez redémarrer le script."
        exit 1
    fi

    # Initialiser GUI_PASSWORD avec une valeur par défaut
    GUI_PASSWORD="[Mot de passe existant non modifié]"

    # Vérifier si l'utilisateur existe déjà
    if id "$GUI_USERNAME" &>/dev/null; then
        info "L'utilisateur $GUI_USERNAME existe déjà. Création d'utilisateur ignorée."
        # Option pour réinitialiser le mot de passe
        read -p "Voulez-vous réinitialiser le mot de passe pour $GUI_USERNAME? (o/n) : " RESET_PASSWORD
        if [[ "$RESET_PASSWORD" == "o" ]]; then
            GUI_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
            echo "$GUI_USERNAME:$GUI_PASSWORD" | sudo chpasswd
            success "Mot de passe réinitialisé pour $GUI_USERNAME"
        fi
    else
        # Créer un utilisateur dédié pour l'environnement graphique
        info "Création d'un utilisateur dédié pour l'interface graphique : $GUI_USERNAME"
        sudo adduser --gecos "" --disabled-password $GUI_USERNAME || check_error "Échec de la création de l'utilisateur GUI"
        # Donner les droits sudo à cet utilisateur (utile pour les opérations administratives)
        sudo usermod -aG sudo $GUI_USERNAME || check_error "Échec de l'ajout de l'utilisateur GUI au groupe sudo"
        # Définir un mot de passe aléatoire
        GUI_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
        echo "$GUI_USERNAME:$GUI_PASSWORD" | sudo chpasswd

        echo ""
        echo -e "${YELLOW}**************************************************************************${NC}"
        echo -e "${YELLOW}*                  INFORMATION IMPORTANTE                                *${NC}"
        echo -e "${YELLOW}**************************************************************************${NC}"
        echo -e "${YELLOW}*                                                                        *${NC}"
        echo -e "${YELLOW}* Un mot de passe aléatoire a été généré pour l'utilisateur              *${NC}"
        echo -e "${YELLOW}* Tous les identifiants seront sauvegardés dans credentials.txt          *${NC}"
        echo -e "${YELLOW}* à la fin du processus d'installation.                                  *${NC}"
        echo -e "${YELLOW}*                                                                        *${NC}"
        echo -e "${YELLOW}**************************************************************************${NC}"
        echo ""
    fi

    # Configurer la connexion automatique pour l'utilisateur dédié
    info "Configuration de la connexion automatique pour l'utilisateur dédié..."
    # Détection plus robuste du gestionnaire d'affichage
    if dpkg -l | grep -q "lightdm"; then
        info "Gestionnaire d'affichage LightDM détecté"
        # S'assurer que le répertoire existe
        sudo mkdir -p /etc/lightdm/lightdm.conf.d/
        
        # Créer une configuration d'auto-login plus complète
        sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf > /dev/null << EOF
[Seat:*]
autologin-user=$GUI_USERNAME
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-greeter
EOF
    
        # S'assurer que lightdm est activé au démarrage
        sudo systemctl enable lightdm
        
        # Définir les permissions correctes
        sudo chmod 644 /etc/lightdm/lightdm.conf.d/50-autologin.conf
        
    elif dpkg -l | grep -q "gdm3"; then
        info "Gestionnaire d'affichage GDM3 détecté"
        # Sauvegarder la configuration existante si elle existe
        if [ -f /etc/gdm3/custom.conf ]; then
            sudo cp /etc/gdm3/custom.conf /etc/gdm3/custom.conf.bak
        fi
        
        # Créer ou modifier la configuration
        if grep -q "^\[daemon\]" /etc/gdm3/custom.conf 2>/dev/null; then
            # Section daemon existe déjà, ajouter/remplacer les paramètres
            sudo sed -i "/^\[daemon\]/,/^\[.*\]/ s/^AutomaticLoginEnable=.*/AutomaticLoginEnable=true/" /etc/gdm3/custom.conf
            sudo sed -i "/^\[daemon\]/,/^\[.*\]/ s/^AutomaticLogin=.*/AutomaticLogin=$GUI_USERNAME/" /etc/gdm3/custom.conf
            
            # Si les paramètres n'existent pas, les ajouter
            if ! grep -q "AutomaticLoginEnable" /etc/gdm3/custom.conf; then
                sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=true" /etc/gdm3/custom.conf
            fi
            if ! grep -q "AutomaticLogin=" /etc/gdm3/custom.conf; then
                sudo sed -i "/^\[daemon\]/a AutomaticLogin=$GUI_USERNAME" /etc/gdm3/custom.conf
            fi
        else
            # Créer la section daemon et les paramètres
            sudo tee -a /etc/gdm3/custom.conf > /dev/null << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$GUI_USERNAME
EOF
        fi
        
        # S'assurer que gdm3 est activé au démarrage
        sudo systemctl enable gdm3
        
        # Définir les permissions correctes
        sudo chmod 644 /etc/gdm3/custom.conf
        
    else
        # Essayer d'installer LightDM comme solution de secours
        warning "Aucun gestionnaire d'affichage reconnu détecté. Installation de LightDM..."
        sudo apt install -y lightdm
        
        # Configurer LightDM pour l'auto-login
        sudo mkdir -p /etc/lightdm/lightdm.conf.d/
        sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf > /dev/null << EOF
[Seat:*]
autologin-user=$GUI_USERNAME
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-greeter
EOF
    
        # Activer LightDM
        sudo systemctl enable lightdm
        
        # Définir les permissions correctes
        sudo chmod 644 /etc/lightdm/lightdm.conf.d/50-autologin.conf
    fi

    # Ajouter cette section pour désactiver l'écran de verrouillage
    info "Désactivation de l'écran de verrouillage pour XFCE..."
    sudo mkdir -p /home/$GUI_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/
    sudo tee /home/$GUI_USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="LockCommand" type="empty"/>
  </property>
  <property name="shutdown" type="empty">
    <property name="LockScreen" type="bool" value="false"/>
  </property>
</channel>
EOF

    # S'assurer que les permissions sont correctes
    sudo chown -R $GUI_USERNAME:$GUI_USERNAME /home/$GUI_USERNAME/.config/


        # S'assurer que la session XFCE est correctement configurée
        sudo mkdir -p /var/lib/AccountsService/users/
        sudo tee /var/lib/AccountsService/users/$GUI_USERNAME > /dev/null << EOF
[User]
XSession=xfce
SystemAccount=false
EOF
    
        success "Environnement GUI configuré avec succès"
}

# Fonction pour installer RustDesk
install_rustdesk() {
    section "INSTALLATION DE RUSTDESK"
    
    info "Téléchargement de RustDesk version $RUSTDESK_VERSION..."
    # Télécharger dans /tmp pour éviter les problèmes de permission
    cd /tmp
    wget https://github.com/rustdesk/rustdesk/releases/download/$RUSTDESK_VERSION/rustdesk-$RUSTDESK_VERSION-x86_64.deb || check_error "Échec du téléchargement de RustDesk"
    
    info "Installation de RustDesk..."
    sudo apt install -fy ./rustdesk-$RUSTDESK_VERSION-x86_64.deb -y || check_error "Échec de l'installation de RustDesk"
    cd -  # Retourner au répertoire précédent

    # Installer des dépendances supplémentaires pour RustDesk - consolidées
    info "Installation des dépendances pour RustDesk..."
    sudo apt install -y libgtk-3-0 libxcb-randr0 libxdo3 libxfixes3 libxcb-xtest0 pulseaudio || check_error "Échec de l'installation des dépendances de RustDesk"

    # Pour Ubuntu 24, spécifier libasound2t64 explicitement au lieu de libasound2
    if [[ $(echo "$UBUNTU_VERSION >= 24.0" | bc) -eq 1 ]]; then
        info "Ubuntu 24 ou plus récent détecté, essai de libasound2t64..."
        if sudo apt-cache search libasound2t64 | grep -q libasound2t64; then
            sudo apt install -y libasound2t64 || warning "Échec de l'installation de libasound2t64"
        else
            info "libasound2t64 non trouvé, essai de libasound2..."
            sudo apt install -y libasound2 || {
                warning "Échec de l'installation de libasound2. RustDesk pourrait avoir des problèmes audio."
                warning "Vous pouvez essayer d'installer manuellement la bibliothèque audio appropriée plus tard."
            }
        fi
    else
        sudo apt install -y libasound2 || warning "Échec de l'installation de libasound2"
    fi

    # Créer un répertoire de configuration pour l'utilisateur dédié
    sudo mkdir -p /home/$GUI_USERNAME/.config/rustdesk
    sudo chown -R $GUI_USERNAME:$GUI_USERNAME /home/$GUI_USERNAME/.config

    # Générer un mot de passe aléatoire pour RustDesk
    RUSTDESK_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    info "Mot de passe aléatoire généré pour RustDesk"

    # Choisir entre service ou démarrage automatique (pas les deux)
    read -p "Voulez-vous exécuter RustDesk comme un service système (s) ou comme une application de démarrage automatique pour l'utilisateur (u) ? (s/u) : " RUSTDESK_START_METHOD_INPUT
    
    # Mettre à jour la variable globale
    if [[ "$RUSTDESK_START_METHOD_INPUT" == "u" ]]; then
        RUSTDESK_START_METHOD="u"
    else
        RUSTDESK_START_METHOD="s"
    fi
    
    if [[ "$RUSTDESK_START_METHOD" == "u" ]]; then
        # Configurer RustDesk pour démarrer automatiquement pour l'utilisateur
        sudo mkdir -p /home/$GUI_USERNAME/.config/autostart
        sudo tee /home/$GUI_USERNAME/.config/autostart/rustdesk.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=RustDesk
Exec=/usr/bin/rustdesk
Terminal=false
Type=Application
Icon=rustdesk
StartupNotify=true
Categories=Network;RemoteAccess;
EOF
        sudo chown -R $GUI_USERNAME:$GUI_USERNAME /home/$GUI_USERNAME/.config/autostart
        info "RustDesk configuré pour démarrer automatiquement avec la session utilisateur."
    else
        # Créer un service système pour RustDesk (par défaut)
        info "Création du service RustDesk..."
        sudo tee /etc/systemd/system/rustdesk.service > /dev/null << EOF
[Unit]
Description=Service RustDesk
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/rustdesk --service
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

        # Activer et démarrer le service RustDesk
        sudo systemctl daemon-reload
        sudo systemctl enable rustdesk.service
        sudo systemctl start rustdesk.service || warning "Échec du démarrage du service RustDesk, nouvelle tentative plus tard"
        info "RustDesk configuré pour fonctionner comme un service système."
    fi

    # Créer un fichier de configuration RustDesk avec des options avancées
    sudo tee /home/$GUI_USERNAME/.config/rustdesk/RustDesk.toml > /dev/null << EOF
rendezvous_server = "rustdesk.com"
nat_type = 0
serial = 0

[options]
allow-remote-config-modification = true
enable-audio = true
enable-file-transfer = true
enable-clipboard = true
stop-service = false
direct-server = true
enable-public-access = true
EOF
    sudo chown -R $GUI_USERNAME:$GUI_USERNAME /home/$GUI_USERNAME/.config/rustdesk

    # Définir le mot de passe permanent pour RustDesk
    info "Définition du mot de passe permanent pour RustDesk..."
    # Obtenir l'ID RustDesk
    RUSTDESK_ID=$(rustdesk --get-id 2>/dev/null | grep -oE '[0-9]+')
    if [[ ! -z "$RUSTDESK_ID" ]]; then
        # Définir le mot de passe permanent
        rustdesk --password "$RUSTDESK_PASSWORD" >/dev/null 2>&1
        success "Mot de passe permanent configuré pour l'ID RustDesk : $RUSTDESK_ID"
    else
        warning "Impossible d'obtenir l'ID RustDesk maintenant. Le mot de passe sera défini après le redémarrage."
        warning "Le mot de passe généré sera sauvegardé dans le fichier d'identifiants."
    fi

    # S'assurer que DISPLAY est configuré pour les applications GUI
    info "Configuration de l'environnement graphique pour RustDesk..."
    sudo tee -a /home/$GUI_USERNAME/.profile > /dev/null << 'EOF'
export DISPLAY=:0
EOF

    # S'assurer que RustDesk peut accéder à l'écran de connexion
    if [[ "$RUSTDESK_START_METHOD" == "s" ]]; then
        info "Configuration de RustDesk pour accéder à l'écran de connexion..."
        
        # Permettre à RustDesk d'accéder à l'écran X
        sudo tee /etc/X11/Xwrapper.config > /dev/null << EOF
allowed_users=anybody
needs_root_rights=yes
EOF
    
        # Configurer la politique de sécurité pour permettre l'accès à l'écran
        if [ -d /etc/polkit-1/localauthority/50-local.d ]; then
            sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla > /dev/null << EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
        fi
    fi

    success "RustDesk installé et configuré avec succès"
}

# Fonction pour installer le navigateur
install_browser() {
    section "INSTALLATION DU NAVIGATEUR"
    
    info "Installation de Google Chrome..."
    # Télécharger dans /tmp pour éviter les problèmes de permission
    cd /tmp
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || check_error "Échec du téléchargement de Chrome"
    sudo apt install ./google-chrome-stable_current_amd64.deb -y || check_error "Échec de l'installation de Chrome"
    cd -  # Retourner au répertoire précédent
    
    success "Google Chrome installé avec succès"
}

# Fonction pour installer ZeroWork
install_zerowork() {
    section "INSTALLATION DE ZEROWORK"
    
    info "Installation de ZeroWork version $ZEROWORK_VERSION..."
    # Télécharger dans /tmp pour éviter les problèmes de permission
    cd /tmp
    wget "https://zerowork-agent-releases.s3.amazonaws.com/public/linux/ZeroWork-$ZEROWORK_VERSION.deb" || check_error "Échec du téléchargement de ZeroWork"
    sudo apt install -y "./ZeroWork-$ZEROWORK_VERSION.deb" || check_error "Échec de l'installation de ZeroWork"
    cd - # Retourner au répertoire précédent
    
    success "ZeroWork installé avec succès"
}

# Fonction pour vérifier la configuration de l'auto-login
verify_autologin_config() {
    section "VÉRIFICATION DE L'AUTO-LOGIN"
    
    info "Vérification de la configuration de l'auto-login..."
    
    local autologin_configured=false
    
    # Vérifier LightDM
    if [ -f /etc/lightdm/lightdm.conf.d/50-autologin.conf ]; then
        if grep -q "autologin-user=$GUI_USERNAME" /etc/lightdm/lightdm.conf.d/50-autologin.conf; then
            success "Auto-login configuré correctement dans LightDM"
            autologin_configured=true
        else
            warning "Configuration LightDM trouvée mais l'utilisateur ne correspond pas"
        fi
    fi
    
    # Vérifier GDM3
    if [ -f /etc/gdm3/custom.conf ]; then
        if grep -q "AutomaticLoginEnable=true" /etc/gdm3/custom.conf && 
           grep -q "AutomaticLogin=$GUI_USERNAME" /etc/gdm3/custom.conf; then
            success "Auto-login configuré correctement dans GDM3"
            autologin_configured=true
        else
            warning "Configuration GDM3 trouvée mais les paramètres d'auto-login sont incorrects"
        fi
    fi
    
    if [ "$autologin_configured" = false ]; then
        warning "Aucune configuration d'auto-login valide n'a été trouvée"
        warning "Après le redémarrage, vous devrez peut-être vous connecter manuellement"
        warning "Utilisez les identifiants sauvegardés dans $HOME/zerowork/credentials.txt"
    fi
}

# Fonction pour obtenir l'ID RustDesk
get_rustdesk_id() {
    section "CONFIGURATION DE RUSTDESK"
    
    info "Récupération de l'ID RustDesk..."

    # Vérifier si le service RustDesk existe avant d'essayer de le redémarrer/démarrer
    if [[ "$RUSTDESK_START_METHOD" == "s" ]] && systemctl list-unit-files | grep -q rustdesk.service; then
        if systemctl is-active --quiet rustdesk.service; then
            info "Redémarrage du service RustDesk..."
            sudo systemctl restart rustdesk || warning "Impossible de redémarrer le service RustDesk, mais ce n'est pas critique."
        else
            info "Démarrage du service RustDesk pour la première fois..."
            sudo systemctl start rustdesk.service || warning "Impossible de démarrer le service RustDesk, mais ce n'est pas critique."
        fi
    else
        info "Le service RustDesk n'est pas configuré ou pas encore correctement installé."
        info "Tentative de récupération de l'ID RustDesk via une commande directe..."
    fi
    
    # Attendre un peu que RustDesk démarre complètement
    sleep 5
    RUSTDESK_ID=$(rustdesk --get-id 2>/dev/null | grep -oE '[0-9]+')

    # Si l'ID n'est pas trouvé, essayer une autre méthode
    if [[ -z "$RUSTDESK_ID" ]]; then
        info "Tentative alternative pour obtenir l'ID RustDesk..."
        RUSTDESK_ID=$(sudo -u $GUI_USERNAME DISPLAY=:0 rustdesk --get-id 2>/dev/null | grep -oE '[0-9]+')
        
        # Si toujours pas d'ID, informer l'utilisateur
        if [[ -z "$RUSTDESK_ID" ]]; then
            warning "Impossible d'obtenir automatiquement l'ID RustDesk."
            warning "Après le redémarrage, vous pourrez l'obtenir avec la commande 'rustdesk --get-id'"
            return 1
        fi
    fi
    
    info "ID RustDesk : $RUSTDESK_ID"
    return 0
}

# Fonction pour afficher le résumé de l'installation
display_summary() {
    section "RÉSUMÉ DE L'INSTALLATION"
    
    echo -e "${CYAN}INSTALLATION TERMINÉE AVEC SUCCÈS${NC}"
    echo ""
    
    # Tableau récapitulatif des services installés
    echo -e "${CYAN}                   === RÉSUMÉ DU DÉPLOIEMENT ZEROWORK ===${NC}"
    echo -e "  Service          |  Version               |  Statut         "
    echo -e "-------------------|------------------------|-----------------"
    echo -e "  ZeroWork         |  ${ZEROWORK_VERSION}           |  Installé       "
    echo -e "  RustDesk         |  ${RUSTDESK_VERSION}           |  Installé       "
    echo -e "  XFCE             |  (dernière version)    |  Installé       "
    echo -e "  Google Chrome    |  (dernière version)    |  Installé       "
    echo ""
    
    # Essayer d'obtenir l'ID RustDesk
    get_rustdesk_id
    
    # Définir le mot de passe permanent pour RustDesk si nous avons l'ID maintenant
    if [[ ! -z "$RUSTDESK_ID" ]] && [[ ! -z "$RUSTDESK_PASSWORD" ]]; then
        info "Définition du mot de passe permanent pour l'ID RustDesk : $RUSTDESK_ID"
        rustdesk --password "$RUSTDESK_PASSWORD" >/dev/null 2>&1
    fi
    
    echo -e "\n${PURPLE}Instructions pour se connecter avec RustDesk :${NC}"
    echo "1. Installez le client RustDesk sur votre machine locale depuis https://rustdesk.com"
    echo "2. Démarrez RustDesk sur votre machine locale"
    echo "3. Entrez l'ID RustDesk indiqué ci-dessus"
    echo "4. Utilisez le mot de passe enregistré dans le fichier d'identifiants"
    echo ""
    
    echo -e "${GREEN}INFORMATIONS DE SÉCURITÉ :${NC}"
    echo "✅ Fail2ban installé pour protéger contre les attaques par force brute"
    echo "✅ Mises à jour de sécurité automatiques configurées"
    echo "✅ Pare-feu (UFW) configuré avec un minimum de ports ouverts"
    echo ""
    
    echo -e "${YELLOW}⚠️ Pour maintenir la sécurité, surveillez régulièrement les journaux et les mises à jour.${NC}"
    echo -e "${YELLOW}⚠️ Commande utile : sudo fail2ban-client status${NC}"
    
 # Créer le dossier zerowork s'il n'existe pas
    mkdir -p ~/zerowork
    CREDENTIALS_FILE="$HOME/zerowork/credentials.txt"
    
    CREDENTIALS_CONTENT="==== IDENTIFIANTS DE L'ENVIRONNEMENT ZEROWORK ====
Date d'installation: $(date)

UTILISATEUR GUI:
- Nom d'utilisateur: ${GUI_USERNAME}
- Mot de passe: ${GUI_PASSWORD}

RUSTDESK:
- ID: ${RUSTDESK_ID:-"ID sera disponible après redémarrage"}
- Mot de passe permanent: ${RUSTDESK_PASSWORD}

INFORMATIONS SYSTÈME:
- Version Ubuntu: ${UBUNTU_VERSION}
- Version RustDesk: ${RUSTDESK_VERSION}
- Version ZeroWork: ${ZEROWORK_VERSION}

SÉCURITÉ:
- Fail2ban: Installé et configuré
- UFW (Pare-feu): Activé avec les ports nécessaires ouverts
- Mises à jour automatiques: Configurées

INSTRUCTIONS:
1. Pour vous connecter avec RustDesk, utilisez l'ID et le mot de passe ci-dessus
2. Pour vous connecter au système GUI, utilisez les identifiants de l'utilisateur GUI
3. Conservez ce fichier en lieu sûr et supprimez-le une fois les informations notées ailleurs

Support: https://discord.gg/4Nuvxxu5GF"
    
    save_credentials_securely "$CREDENTIALS_FILE" "$CREDENTIALS_CONTENT"
    
    echo ""
    echo -e "${YELLOW}************************************************************${NC}"
    echo -e "${YELLOW}*                  INFORMATION IMPORTANTE                   *${NC}"
    echo -e "${YELLOW}************************************************************${NC}"
    echo -e "${YELLOW}*                                                          *${NC}"
    echo -e "${YELLOW}* Tous les identifiants ont été sauvegardés dans :          *${NC}"
    echo -e "${YELLOW}* $CREDENTIALS_FILE                                *${NC}"
    echo -e "${YELLOW}*                                                          *${NC}"
    echo -e "${YELLOW}* CONSERVEZ CE FICHIER EN LIEU SÛR ET SUPPRIMEZ-LE APRÈS UTILISATION ! *${NC}"
    echo -e "${YELLOW}*                                                          *${NC}"
    echo -e "${YELLOW}************************************************************${NC}"
}

# Fonction pour détecter la version d'Ubuntu
detect_ubuntu_version() {
    section "DÉTECTION DU SYSTÈME"
    
    info "Détection de la version d'Ubuntu..."
    # UBUNTU_VERSION est déjà défini au début du script
    success "Version d'Ubuntu détectée : $UBUNTU_VERSION"

    # Vérifier la compatibilité des versions logicielles avec Ubuntu
    if [[ $(echo "$UBUNTU_VERSION >= 24.0" | bc) -eq 1 ]]; then
        info "Ubuntu 24.0+ détecté. Vérification de la compatibilité des logiciels..."
        
        # Vérifier la compatibilité de la version de RustDesk
        if [[ $(echo "$RUSTDESK_VERSION < 1.2.0" | bc) -eq 1 ]]; then
            warning "La version $RUSTDESK_VERSION de RustDesk pourrait ne pas être totalement compatible avec Ubuntu 24."
            warning "Envisagez d'utiliser une version plus récente de RustDesk si vous rencontrez des problèmes."
            echo "   Les dernières versions peuvent être trouvées sur : https://github.com/rustdesk/rustdesk/releases"
            read -p "Continuer avec la version actuelle ? (o/n) : " CONTINUE_RUSTDESK
            if [[ "$CONTINUE_RUSTDESK" != "o" ]]; then
                echo "Veuillez redémarrer le script avec un paramètre de version RustDesk plus récent."
                echo "Exemple : ./gui-setup.sh 1.1.60 1.4.0"
                exit 1
            fi
        fi
        
        # Vérifier la compatibilité de ZeroWork
        info "REMARQUE : La version $ZEROWORK_VERSION de ZeroWork n'a pas été explicitement testée avec Ubuntu 24."
        info "L'installation va se poursuivre, mais veuillez signaler tout problème rencontré."
    fi
}

# ====================== EXÉCUTION PRINCIPALE ======================

main() {
    # Afficher la bannière
    echo -e "${CYAN}"
    echo "███████╗███████╗██████╗░░█████╗░░██╗░░░░░░░██╗░█████╗░██████╗░██╗░░██╗"
    echo "╚════██║██╔════╝██╔══██╗██╔══██╗░██║░░██╗░░██║██╔══██╗██╔══██╗██║░██╔╝"
    echo "░░███╔═╝█████╗░░██████╔╝██║░░██║░╚██╗████╗██╔╝██║░░██║██████╔╝█████═╝░"
    echo "██╔══╝░░██╔══╝░░██╔══██╗██║░░██║░░████╔═████║░██║░░██║██╔══██╗██╔═██╗░"
    echo "███████╗███████╗██║░░██║╚█████╔╝░░╚██╔╝░╚██╔╝░╚█████╔╝██║░░██║██║░╚██╗"
    echo "╚══════╝╚══════╝╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝"
    echo -e "${NC}"
    echo "Créé par Romain Jolly Martoia"
    echo "Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF"
    echo "======================================================================================="
    echo ""
    
    # Avertissement
    echo -e "${YELLOW}AVERTISSEMENT :${NC}"
    echo "Ce script installe un environnement GUI avec RustDesk et ZeroWork pour l'accès et la gestion à distance."
    echo "Il configurera un environnement de bureau graphique (XFCE) et les outils de sécurité nécessaires."
    echo ""
    echo "L'installation comprend :"
    echo "- Environnement de bureau XFCE"
    echo "- RustDesk pour l'accès à distance (version $RUSTDESK_VERSION)"
    echo "- Agent ZeroWork (version $ZEROWORK_VERSION)"
    echo "- Google Chrome pour la navigation web"
    echo "- Outils de sécurité (UFW, Fail2ban, mises à jour automatiques)"
    echo ""
    
    # Demander à l'utilisateur d'accepter l'avertissement
    read -p "Acceptez-vous de continuer ? (o/n) : " AGREEMENT
    
    # Vérifier la réponse de l'utilisateur
    if [[ "$AGREEMENT" != "o" ]]; then
        echo "Vous avez refusé l'accord. Sortie du script."
        echo "Installation abandonnée. Vous pouvez exécuter le script à nouveau à tout moment pour continuer."
        
        # Demander de supprimer le fichier script
        read -p "Voulez-vous supprimer le fichier script téléchargé ? (o/n) : " DELETE_FILE
        cleanup_script "$DELETE_FILE"
        
        exit 1
    fi
    
    # Vérifier l'espace disque avant de continuer
    check_disk_space
    
    # Vérifier les dépendances au début
    check_dependencies
    
    # Détecter la version d'Ubuntu
    detect_ubuntu_version
    
    # Préparation du système
    section "PRÉPARATION DU SYSTÈME"
    info "Mise à jour des paquets système..."
    system_update
    
    # Installer les outils de sécurité
    install_security_tools
    
    # Configurer l'environnement GUI
    setup_gui_environment
    
    # Installer RustDesk
    install_rustdesk
    
    # Installer le navigateur Chrome
    install_browser
    
    # Installer ZeroWork
    install_zerowork

    # Dans la fonction main(), avant display_summary()
    verify_autologin_config
    
    # Afficher le résumé de l'installation
    display_summary
    
    # Demander si le système doit être redémarré
    section "FINALISATION"
    
    echo "REMARQUE : Certains changements nécessitent un redémarrage du système pour prendre pleinement effet, notamment :"
    echo "- Configuration du gestionnaire d'affichage pour l'interface graphique"
    echo "- Modifications des services réseau"
    read -p "Souhaitez-vous redémarrer le système maintenant ? (o/n) : " REBOOT_SYSTEM
    if [[ "$REBOOT_SYSTEM" == "o" ]]; then
        # Demander de supprimer le fichier script avant le redémarrage
        read -p "Voulez-vous supprimer le fichier script téléchargé avant le redémarrage ? (o/n) : " DELETE_FILE
        cleanup_script "$DELETE_FILE"
        
        info "Le système va redémarrer dans 10 secondes. Appuyez sur Ctrl+C pour annuler."
        sleep 10
        sudo reboot
    else
        # Demander de supprimer le fichier script sans redémarrage
        read -p "Voulez-vous supprimer le fichier script téléchargé ? (o/n) : " DELETE_FILE
        cleanup_script "$DELETE_FILE"
        
        warning "N'oubliez pas de redémarrer votre système bientôt pour appliquer complètement tous les changements."
    fi
    
    echo -e "${CYAN}Merci d'avoir utilisé ce script d'installation !${NC}"
    echo -e "Pour le support et les mises à jour, rejoignez les solopreneurs 3.0 :"
    echo -e "Discord : https://discord.gg/4Nuvxxu5GF"
}

# Exécuter la fonction principale
main
