#!/bin/bash

# ===================================================================
# ░█████╗░██╗  ░██████╗████████╗░█████╗░░█████╗░██╗░░██╗
# ██╔══██╗██║  ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║░██╔╝
# ███████║██║  ╚█████╗░░░░██║░░░███████║██║░░╚═╝█████═╝░
# ██╔══██║██║  ░╚═══██╗░░░██║░░░██╔══██║██║░░██╗██╔═██╗░
# ██║░░██║██║  ██████╔╝░░░██║░░░██║░░██║╚█████╔╝██║░╚██╗
# ╚═╝░░╚═╝╚═╝  ╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝
# AI Stack Installer v1.0 | Créé par Romain Jolly Martoia
# Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF
# ===================================================================

# Activer la vérification stricte des erreurs
set -e

# Sauvegarder le chemin absolu pour la suppression du script à la fin
SCRIPT_ABSOLUTE_PATH="$(realpath "$0")"

# ====================== FONCTIONS UTILITAIRES ======================

# Couleurs pour améliorer la lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Pas de couleur

# Fonction pour afficher les messages d'information
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fonction pour afficher les messages de succès
success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1"
}

# Fonction pour afficher les messages d'avertissement
warning() {
    echo -e "${YELLOW}[AVERTISSEMENT]${NC} $1"
}

# Fonction pour afficher les messages d'erreur
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
        error "$error_message (code: $exit_code)"
        error "L'exécution du script a été arrêtée pour éviter d'autres problèmes."
        exit $exit_code
    fi
}

# Fonction pour réparer le système de paquets
repair_package_system() {
    section "RÉPARATION DU SYSTÈME DE PAQUETS"
    
    info "Vérification et réparation du système de paquets..."
    
    # Vérifier si le répertoire des mises à jour contient des fichiers problématiques
    if [ -d "/var/lib/dpkg/updates" ] && [ "$(ls -A /var/lib/dpkg/updates 2>/dev/null)" ]; then
        info "Nettoyage du répertoire des mises à jour dpkg..."
        sudo rm -f /var/lib/dpkg/updates/* || warning "Impossible de nettoyer le répertoire des mises à jour dpkg."
    fi
    
    # Essayer de configurer les paquets en attente
    info "Configuration des paquets en attente..."
    sudo dpkg --configure -a || warning "La configuration dpkg a rencontré des problèmes, tentative de continuer..."
    
    # Essayer de corriger les dépendances cassées
    info "Correction des dépendances cassées..."
    sudo apt-get -f install -y || warning "Impossible de corriger toutes les dépendances, tentative de continuer..."
    
    # Nettoyer les paquets qui ne sont plus nécessaires
    info "Nettoyage des paquets inutilisés..."
    sudo apt-get autoremove -y || warning "Impossible de supprimer tous les paquets inutilisés, tentative de continuer..."
    
    # Mettre à jour les listes de paquets
    info "Mise à jour des listes de paquets..."
    sudo apt-get update || warning "Impossible de mettre à jour les listes de paquets, tentative de continuer..."
    
    success "Réparation du système de paquets terminée"
}

# Vérifier l'espace disque avant de continuer
check_disk_space() {
    local MIN_SPACE=5  # GB minimum requis (augmenté à 5GB)
    local AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [ "$AVAILABLE" -lt "$MIN_SPACE" ]; then
        error "Espace disque insuffisant. Au moins ${MIN_SPACE}G requis, mais seulement ${AVAILABLE}G disponible."
        exit 1
    fi
    
    info "Vérification de l'espace disque réussie : ${AVAILABLE}G disponible"
}

# Fonction pour vérifier si un paquet est installé
is_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Fonction pour valider une adresse email
validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Fonction pour valider un nom de domaine
validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Fonction pour valider un mot de passe (min 12 caractères)
validate_password() {
    local password=$1
    if [[ ${#password} -lt 12 ]]; then
        return 1
    fi
    return 0
}

# Fonction pour valider un nom d'utilisateur
validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]{3,}$ ]]; then
        return 1
    fi
    return 0
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

# Fonction pour vérifier si les ports 80 et 443 sont accessibles
check_ports_accessibility() {
    section "VÉRIFICATION DES PORTS"
    
    info "Vérification de l'accessibilité des ports 80 et 443..."
    
    # Vérifier les ports localement avec ss (remplaçant moderne de netstat)
    info "Vérification des ports utilisés localement..."
    
    # Installer ss si nécessaire
    if ! command -v ss &> /dev/null; then
        info "Installation de iproute2 pour vérifier les ports..."
        sudo apt-get update
        sudo apt-get install -y iproute2 || warning "Impossible d'installer iproute2. La vérification des ports sera limitée."
    fi
    
    if command -v ss &> /dev/null; then
        # Vérifier le port 80
        if ss -tuln | grep -q ":80 "; then
            warning "Le port 80 est déjà utilisé localement."
            warning "Cela pourrait causer des conflits avec Traefik."
            
            # Identifier les processus avec lsof ou ss
            echo "Processus utilisant le port 80 :"
            if command -v lsof &> /dev/null; then
                sudo lsof -i :80
            elif command -v ss &> /dev/null; then
                sudo ss -lptn 'sport = :80'
            fi
            
            read -p "Voulez-vous continuer malgré ce conflit potentiel ? (o/n) : " CONTINUE_PORT_80
            if [[ "$CONTINUE_PORT_80" != "o" ]]; then
                error "Installation interrompue. Veuillez libérer le port 80 et réessayer."
                exit 1
            fi
        else
            success "Le port 80 est libre localement."
        fi
        
        # Vérifier le port 443
        if ss -tuln | grep -q ":443 "; then
            warning "Le port 443 est déjà utilisé localement."
            warning "Cela pourrait causer des conflits avec Traefik."
            
            # Identifier les processus avec lsof ou ss
            echo "Processus utilisant le port 443 :"
            if command -v lsof &> /dev/null; then
                sudo lsof -i :443
            elif command -v ss &> /dev/null; then
                sudo ss -lptn 'sport = :443'
            fi
            
            read -p "Voulez-vous continuer malgré ce conflit potentiel ? (o/n) : " CONTINUE_PORT_443
            if [[ "$CONTINUE_PORT_443" != "o" ]]; then
                error "Installation interrompue. Veuillez libérer le port 443 et réessayer."
                exit 1
            fi
        else
            success "Le port 443 est libre localement."
        fi
    else
        warning "L'outil ss n'est pas disponible. Impossible de vérifier si les ports sont déjà utilisés localement."
    fi
    
    # Vérifier la configuration du pare-feu
    info "Vérification de la configuration du pare-feu..."
    
    # Vérifier UFW (pare-feu Ubuntu)
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            info "UFW est actif. Vérification des règles pour les ports 80 et 443..."
            
            if ! sudo ufw status | grep -q "80/tcp" && ! sudo ufw status | grep -q "80 "; then
                warning "Le port 80 ne semble pas être autorisé dans UFW."
                read -p "Voulez-vous autoriser le port 80 dans UFW ? (o/n) : " ALLOW_PORT_80
                if [[ "$ALLOW_PORT_80" == "o" ]]; then
                    sudo ufw allow 80/tcp
                    success "Port 80 autorisé dans UFW."
                else
                    warning "Le port 80 reste bloqué. Let's Encrypt pourrait ne pas fonctionner correctement."
                fi
            else
                success "Le port 80 est déjà autorisé dans UFW."
            fi
            
            if ! sudo ufw status | grep -q "443/tcp" && ! sudo ufw status | grep -q "443 "; then
                warning "Le port 443 ne semble pas être autorisé dans UFW."
                read -p "Voulez-vous autoriser le port 443 dans UFW ? (o/n) : " ALLOW_PORT_443
                if [[ "$ALLOW_PORT_443" == "o" ]]; then
                    sudo ufw allow 443/tcp
                    success "Port 443 autorisé dans UFW."
                else
                    warning "Le port 443 reste bloqué. Let's Encrypt pourrait ne pas fonctionner correctement."
                fi
            else
                success "Le port 443 est déjà autorisé dans UFW."
            fi
        else
            info "UFW est installé mais n'est pas actif. Aucune règle de pare-feu à vérifier."
        fi
    fi
    
    # Vérifier firewalld (utilisé sur certaines distributions)
    if command -v firewall-cmd &> /dev/null; then
        if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
            info "firewalld est actif. Vérification des règles pour les ports 80 et 443..."
            
            if ! sudo firewall-cmd --list-ports | grep -q "80/tcp"; then
                warning "Le port 80 ne semble pas être autorisé dans firewalld."
                read -p "Voulez-vous autoriser le port 80 dans firewalld ? (o/n) : " ALLOW_PORT_80
                if [[ "$ALLOW_PORT_80" == "o" ]]; then
                    sudo firewall-cmd --permanent --add-port=80/tcp
                    sudo firewall-cmd --reload
                    success "Port 80 autorisé dans firewalld."
                else
                    warning "Le port 80 reste bloqué. Let's Encrypt pourrait ne pas fonctionner correctement."
                fi
            else
                success "Le port 80 est déjà autorisé dans firewalld."
            fi
            
            if ! sudo firewall-cmd --list-ports | grep -q "443/tcp"; then
                warning "Le port 443 ne semble pas être autorisé dans firewalld."
                read -p "Voulez-vous autoriser le port 443 dans firewalld ? (o/n) : " ALLOW_PORT_443
                if [[ "$ALLOW_PORT_443" == "o" ]]; then
                    sudo firewall-cmd --permanent --add-port=443/tcp
                    sudo firewall-cmd --reload
                    success "Port 443 autorisé dans firewalld."
                else
                    warning "Le port 443 reste bloqué. Let's Encrypt pourrait ne pas fonctionner correctement."
                fi
            else
                success "Le port 443 est déjà autorisé dans firewalld."
            fi
        fi
    fi
    
    # Information sur les ports 80 et 443 pour Let's Encrypt
    info "REMARQUE IMPORTANTE SUR LES PORTS 80 ET 443 :"
    info "Sur un serveur fraîchement installé, il est normal qu'aucun service n'écoute sur les ports 80 et 443."
    info "Traefik sera le premier service à utiliser ces ports après l'installation."
    info "Pour que Let's Encrypt fonctionne, ces ports doivent être accessibles depuis Internet."
    info "Assurez-vous que votre fournisseur d'hébergement ou votre routeur ne bloque pas ces ports."
    
    echo ""
    warning "Pour Let's Encrypt, les ports 80 et 443 doivent être accessibles depuis Internet."
    read -p "Confirmez-vous que les ports 80 et 443 ne sont pas bloqués par votre hébergeur ou pare-feu externe ? (o/n) : " PORTS_ACCESSIBLE
    
    if [[ "$PORTS_ACCESSIBLE" != "o" ]]; then
        warning "Vous avez indiqué que les ports pourraient être bloqués."
        warning "L'installation va continuer, mais Let's Encrypt pourrait ne pas fonctionner correctement."
        warning "Dans ce cas, vous devrez configurer manuellement les certificats SSL plus tard."
        read -p "Appuyez sur Entrée pour continuer..."
    else
        success "Vérification des ports terminée. L'installation va continuer."
    fi
}



# Fonction pour installer les outils de sécurité du système
install_security_tools() {
    section "CONFIGURATION DE LA SÉCURITÉ"
    
    # Fail2ban
    if ! is_package_installed "fail2ban"; then
        info "Installation de fail2ban..."
        sudo apt install -y fail2ban || check_error "Échec de l'installation de fail2ban"
    else
        info "fail2ban déjà installé"
    fi

    # Configuration avancée de Fail2ban pour tous les services
    info "Configuration de Fail2ban pour tous les services..."

    # Création des répertoires de filtres si nécessaire
    sudo mkdir -p /etc/fail2ban/filter.d

    # Vérifier si la configuration actuelle est valide
    if sudo fail2ban-client -d > /dev/null 2>&1; then
        info "Configuration Fail2ban existante valide, ajout des jails supplémentaires uniquement"
        
        # Ajouter uniquement les jails pour les nouveaux services
        cat > /tmp/additional-jails.conf << 'EOL'

# Jails pour les services de la stack AI
# Ajoutés automatiquement par le script d'installation

[traefik-auth]
enabled = true
port = 80,443
filter = traefik-auth
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=traefik, port="80,443", protocol=tcp]

[portainer]
enabled = true
port = 443
filter = portainer
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=portainer, port="443", protocol=tcp]

[n8n]
enabled = true
port = 443
filter = n8n
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=n8n, port="443", protocol=tcp]

[pgsql]
enabled = true
port = 5432
filter = pgsql
logpath = /var/lib/docker/containers/*/*.log
maxretry = 3
findtime = 300
bantime = 3600
action = iptables-multiport[name=pgsql, port="5432", protocol=tcp]

[pgadmin]
enabled = true
port = 443
filter = pgadmin
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=pgadmin, port="443", protocol=tcp]

[redis-commander]
enabled = true
port = 443
filter = redis-commander
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=redis-commander, port="443", protocol=tcp]

[redis]
enabled = true
port = 6379
filter = redis
logpath = /var/lib/docker/containers/*/*.log
maxretry = 3
findtime = 300
bantime = 3600
action = iptables-multiport[name=redis, port="6379", protocol=tcp]

EOL

        # Vérifier si ces jails existent déjà
        for jail in traefik-auth portainer n8n pgsql pgadmin redis-commander redis; do
            if grep -q "^\[$jail\]" /etc/fail2ban/jail.local; then
                info "Jail $jail déjà configuré, ignoré"
                # Supprimer ce jail du fichier temporaire
                sed -i "/^\[$jail\]/,/^$/d" /tmp/additional-jails.conf
            fi
        done
        
        # Ajouter les jails manquants à la fin du fichier
        if [ -s /tmp/additional-jails.conf ]; then
            sudo bash -c "cat /tmp/additional-jails.conf >> /etc/fail2ban/jail.local"
            info "Jails supplémentaires ajoutés à la configuration existante"
        else
            info "Tous les jails sont déjà configurés"
        fi
    else
        warning "Configuration Fail2ban existante invalide ou problématique, création d'une nouvelle configuration"
        
        # Créer une configuration complète qui remplace l'existante
        cat > /tmp/jail.local << 'EOL'
[DEFAULT]
# Ignorer les adresses IP privées
ignoreip = 127.0.0.1/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# Configuration du bannissement progressif
bantime = 3600
bantime.increment = true
bantime.factor = 1
bantime.formula = ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * bantime.factor
bantime.multipliers = 1 2 4 8 16 32 64 128 256 512 1024
bantime.maxtime = 604800  # 1 semaine en secondes

# Temps pendant lequel les tentatives sont comptées (en secondes)
findtime = 600

# Nombre de tentatives avant bannissement
maxretry = 5

# Utilisez l'action iptables-multiport par défaut
banaction = iptables-multiport

# Activer la journalisation des actions de Fail2ban
logtarget = /var/log/fail2ban.log

# Activer la journalisation des logs Docker
backend = auto

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[traefik-auth]
enabled = true
port = 80,443
filter = traefik-auth
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=traefik, port="80,443", protocol=tcp]

[portainer]
enabled = true
port = 443
filter = portainer
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=portainer, port="443", protocol=tcp]

[n8n]
enabled = true
port = 443
filter = n8n
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=n8n, port="443", protocol=tcp]

[pgsql]
enabled = true
port = 5432
filter = pgsql
logpath = /var/lib/docker/containers/*/*.log
maxretry = 3
findtime = 300
bantime = 3600
action = iptables-multiport[name=pgsql, port="5432", protocol=tcp]

[pgadmin]
enabled = true
port = 443
filter = pgadmin
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=pgadmin, port="443", protocol=tcp]

[redis-commander]
enabled = true
port = 443
filter = redis-commander
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=redis-commander, port="443", protocol=tcp]

[redis]
enabled = true
port = 6379
filter = redis
logpath = /var/lib/docker/containers/*/*.log
maxretry = 3
findtime = 300
bantime = 3600
action = iptables-multiport[name=redis, port="6379", protocol=tcp]
EOL

        # Remplacer complètement le fichier jail.local
        sudo cp /tmp/jail.local /etc/fail2ban/jail.local
        sudo chmod 644 /etc/fail2ban/jail.local
        info "Nouvelle configuration Fail2ban créée"
    fi

    # Nettoyer les fichiers temporaires
    rm -f /tmp/additional-jails.conf /tmp/jail.local

    # Créer les filtres personnalisés (toujours nécessaire)
    info "Création des filtres Fail2ban pour les services de la stack..."

    # Filtre pour Traefik
    cat > /tmp/traefik-auth.conf << 'EOL'
[Definition]
failregex = ^.*\"auth login attempt.*remote_ip=\"<HOST>\".*user=\".*\".*\"status\":401.*$
ignoreregex =
EOL
    sudo cp /tmp/traefik-auth.conf /etc/fail2ban/filter.d/traefik-auth.conf

    # Filtre pour Portainer
    cat > /tmp/portainer.conf << 'EOL'
[Definition]
failregex = ^.*\"level\":\"error\".*\"msg\":\"Authentication failure, invalid credentials\".*\"ClientIP\":\"<HOST>\".*$
ignoreregex =
EOL
    sudo cp /tmp/portainer.conf /etc/fail2ban/filter.d/portainer.conf

    # Filtre pour n8n
    cat > /tmp/n8n.conf << 'EOL'
[Definition]
failregex = ^.*\"message\":\"Wrong credentials\".*\"ip\":\"<HOST>\".*$
ignoreregex =
EOL
    sudo cp /tmp/n8n.conf /etc/fail2ban/filter.d/n8n.conf

    # Filtre pour PostgreSQL
    cat > /tmp/pgsql.conf << 'EOL'
[Definition]
failregex = ^.*FATAL:  password authentication failed for user.*\[client: <HOST>\]$
ignoreregex =
EOL
    sudo cp /tmp/pgsql.conf /etc/fail2ban/filter.d/pgsql.conf

    # Filtre pour pgAdmin
    cat > /tmp/pgadmin.conf << 'EOL'
[Definition]
failregex = ^.*\"POST /login\" 401.*client_address\":\"<HOST>\".*$
ignoreregex =
EOL
    sudo cp /tmp/pgadmin.conf /etc/fail2ban/filter.d/pgadmin.conf

    # Filtre pour Redis Commander
    cat > /tmp/redis-commander.conf << 'EOL'
[Definition]
failregex = ^.*Authentication error for user.*ip: <HOST>.*$
ignoreregex =
EOL
    sudo cp /tmp/redis-commander.conf /etc/fail2ban/filter.d/redis-commander.conf

    # Filtre pour Redis
    cat > /tmp/redis.conf << 'EOL'
[Definition]
failregex = ^.*Client <HOST>.*AUTH.*invalid password.*$
ignoreregex =
EOL
    sudo cp /tmp/redis.conf /etc/fail2ban/filter.d/redis.conf

    # Nettoyer les fichiers temporaires
    rm -f /tmp/pgadmin.conf /tmp/redis-commander.conf /tmp/redis.conf
    rm -f /tmp/traefik-auth.conf /tmp/portainer.conf /tmp/n8n.conf /tmp/pgsql.conf

    # Redémarrer Fail2ban pour appliquer les modifications
    info "Redémarrage de Fail2ban pour appliquer les modifications..."
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban

    # Créer un script de rapport pour Fail2ban
    info "Création d'un script de rapport pour Fail2ban..."
    cat > /tmp/fail2ban-report.sh << EOL
#!/bin/bash
echo "=== Fail2ban Status Report ==="
echo "Date: \$(date)"
echo ""
echo "=== Active Jails ==="
fail2ban-client status | grep "Jail list" | sed 's/^.*://g' | sed 's/,//g' | xargs -n1 | sort | xargs -I{} bash -c 'echo -n "{}: "; fail2ban-client status {} | grep "Currently banned" | sed "s/.*: //g"'
echo ""
echo "=== Recent Bans ==="
grep "Ban " /var/log/fail2ban.log | tail -n 20
EOL
    
    sudo cp /tmp/fail2ban-report.sh /usr/local/bin/fail2ban-report.sh
    sudo chmod +x /usr/local/bin/fail2ban-report.sh
    rm -f /tmp/fail2ban-report.sh
    
    # Configuration de la rotation des logs Docker
    info "Configuration de la rotation des logs Docker pour Fail2ban..."
    if [ ! -d /etc/docker ]; then
        sudo mkdir -p /etc/docker
    fi
    
    if [ ! -f /etc/docker/daemon.json ]; then
        # Créer un nouveau fichier daemon.json
        cat > /tmp/daemon.json << EOL
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOL
        sudo cp /tmp/daemon.json /etc/docker/daemon.json
        rm -f /tmp/daemon.json
    else
        # Vérifier si le fichier existe déjà et le modifier
        if command -v jq &> /dev/null; then
            # Utiliser jq si disponible
            TEMP_JSON=$(mktemp)
            sudo cat /etc/docker/daemon.json | jq '. + {"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' > "$TEMP_JSON"
            sudo cp "$TEMP_JSON" /etc/docker/daemon.json
            rm -f "$TEMP_JSON"
        else
            # Sinon, avertir l'utilisateur
            warning "jq n'est pas installé. La rotation des logs Docker n'a pas été configurée automatiquement."
            warning "Vous devriez éditer manuellement /etc/docker/daemon.json après l'installation."
        fi
    fi
    
    # Ajouter un script de fail2ban dans le répertoire scripts
    info "Ajout d'un script de gestion Fail2ban dans le répertoire scripts..."
    cat > scripts/fail2ban-manage.sh << 'EOL'
#!/bin/bash

# Couleurs pour améliorer la lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# Fonction pour afficher les messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVERTISSEMENT]${NC} $1"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# Fonction d'aide
show_help() {
    echo "Utilisation: $0 [option] [paramètres]"
    echo ""
    echo "Options:"
    echo "  status               Affiche l'état de tous les jails"
    echo "  status [jail]        Affiche l'état d'un jail spécifique"
    echo "  unban [ip]           Débloque une adresse IP"
    echo "  ban [ip] [jail]      Bloque une adresse IP dans un jail spécifique"
    echo "  logs [n]             Affiche les n dernières lignes du log (10 par défaut)"
    echo "  report               Génère un rapport complet"
    echo "  restart              Redémarre Fail2ban"
    echo "  help                 Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 status"
    echo "  $0 status sshd"
    echo "  $0 unban 192.168.1.100"
    echo "  $0 ban 192.168.1.100 sshd"
    echo "  $0 logs 20"
}

# Vérifier si Fail2ban est installé
if ! command -v fail2ban-client &> /dev/null; then
    error "Fail2ban n'est pas installé. Veuillez l'installer d'abord."
    exit 1
fi

# Traiter les arguments
case "$1" in
    status)
        if [ -z "$2" ]; then
            info "État de tous les jails Fail2ban:"
            sudo fail2ban-client status
        else
            info "État du jail $2:"
            sudo fail2ban-client status "$2"
        fi
        ;;
    unban)
        if [ -z "$2" ]; then
            error "Veuillez spécifier une adresse IP à débloquer."
            show_help
            exit 1
        fi
        info "Déblocage de l'adresse IP $2..."
        sudo fail2ban-client unban "$2"
        success "Adresse IP $2 débloquée."
        ;;
    ban)
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Veuillez spécifier une adresse IP et un jail."
            show_help
            exit 1
        fi
        info "Blocage de l'adresse IP $2 dans le jail $3..."
        sudo fail2ban-client set "$3" banip "$2"
        success "Adresse IP $2 bloquée dans le jail $3."
        ;;
    logs)
        LINES=10
        if [ ! -z "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
            LINES="$2"
        fi
        info "Affichage des $LINES dernières lignes du log Fail2ban:"
        sudo tail -n "$LINES" /var/log/fail2ban.log
        ;;
    report)
        info "Génération d'un rapport Fail2ban complet:"
        
        # Date et heure du rapport
        echo "=== RAPPORT FAIL2BAN ==="
        echo "Date: $(date)"
        echo "Serveur: $(hostname)"
        echo ""
        
        # Vérifier si Fail2ban est en cours d'exécution
        echo "=== STATUT DU SERVICE ==="
        if systemctl is-active --quiet fail2ban; then
            echo "Fail2ban est actif et en cours d'exécution"
            echo "Version: $(fail2ban-client --version)"
            echo "Temps d'exécution: $(systemctl status fail2ban | grep "Active:" | sed 's/.*; \(.*\)ago/\1/')"
        else
            echo "AVERTISSEMENT: Fail2ban n'est pas en cours d'exécution!"
        fi
        echo ""
        
        # Liste des jails actifs
        echo "=== JAILS ACTIFS ==="
        JAILS=$(fail2ban-client status | grep "Jail list" | sed 's/^.*://g' | sed 's/,//g')
        if [ -z "$JAILS" ]; then
            echo "Aucun jail actif trouvé"
        else
            echo "Nombre total de jails: $(echo $JAILS | wc -w)"
            
            # Tableau des jails
            printf "%-20s %-15s %-15s %-15s\n" "JAIL" "BANNISSEMENTS" "ÉCHECS" "FICHIERS LOG"
            printf "%-20s %-15s %-15s %-15s\n" "--------------------" "---------------" "---------------" "---------------"
            
            for jail in $JAILS; do
                # Obtenir les statistiques du jail
                JAIL_INFO=$(fail2ban-client status $jail)
                BANNED=$(echo "$JAIL_INFO" | grep "Currently banned:" | sed 's/.*: \(.*\)/\1/')
                TOTAL=$(echo "$JAIL_INFO" | grep "Total banned:" | sed 's/.*: \(.*\)/\1/')
                FAILED=$(echo "$JAIL_INFO" | grep "Currently failed:" | sed 's/.*: \(.*\)/\1/')
                LOGPATH=$(echo "$JAIL_INFO" | grep "File list:" | sed 's/.*: \(.*\)/\1/' | cut -c 1-15)
                
                printf "%-20s %-15s %-15s %-15s\n" "$jail" "$BANNED ($TOTAL total)" "$FAILED" "$LOGPATH..."
            done
        fi
        echo ""
        
        # Bannissements récents
        echo "=== BANNISSEMENTS RÉCENTS ==="
        RECENT_BANS=$(grep "Ban " /var/log/fail2ban.log | tail -n 20)
        if [ -z "$RECENT_BANS" ]; then
            echo "Aucun bannissement récent trouvé"
        else
            echo "$RECENT_BANS"
        fi
        ;;
    restart)
        info "Redémarrage de Fail2ban..."
        sudo systemctl restart fail2ban
        success "Fail2ban redémarré."
        ;;
    help|*)
        show_help
        ;;
esac
EOL

    chmod +x scripts/fail2ban-manage.sh
    ln -sf scripts/fail2ban-manage.sh fail2ban-manage.sh

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
    
    # Vérifier et ajouter les règles nécessaires
    if ! sudo ufw status | grep -q "22/tcp"; then
        sudo ufw allow ssh
        info "Règle SSH ajoutée à UFW."
    fi
    
    if ! sudo ufw status | grep -q "80/tcp"; then
        sudo ufw allow 80/tcp
        info "Règle HTTP (port 80) ajoutée à UFW."
    fi
    
    if ! sudo ufw status | grep -q "443/tcp"; then
        sudo ufw allow 443/tcp
        info "Règle HTTPS (port 443) ajoutée à UFW."
    fi
    
    # Activer uniquement si ce n'est pas déjà activé pour éviter de perturber les connexions existantes
    if ! sudo ufw status | grep -q "Status: active"; then
        info "Activation de UFW..."
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

# Fonction de mise à jour système pour consolider toutes les mises à jour apt
system_update() {
    info "Mise à jour du système..."
    
    # Mettre à jour les listes de paquets
    sudo apt-get update || warning "Impossible de mettre à jour les listes de paquets, tentative de continuer..."
    
    # Mettre à niveau les paquets
    sudo apt-get upgrade -y || warning "Impossible de mettre à niveau tous les paquets, tentative de continuer..."
    
    success "Mise à jour du système terminée"
}

# Fonction pour sauvegarder les identifiants de manière sécurisée
save_credentials_securely() {
    local filename="$1"
    local content="$2"
    
    # Créer le répertoire s'il n'existe pas
    mkdir -p "$(dirname "$filename")"
    
    # Sauvegarder le contenu dans un fichier avec des permissions restreintes
    echo -e "$content" > "$filename"
    chmod 600 "$filename"
    
    success "Identifiants sauvegardés de manière sécurisée dans $filename"
}

# Fonction pour générer un mot de passe sécurisé compatible avec tous les services
generate_secure_password() {
    local length=${1:-16}
    # Assurer une longueur minimale de 12 caractères
    if [ "$length" -lt 12 ]; then
        length=12
    fi
    local password=""
    
    # Utiliser uniquement des caractères alphanumériques (majuscules, minuscules, chiffres)
    local upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lower="abcdefghijklmnopqrstuvwxyz"
    local numbers="0123456789"
    
    # S'assurer que le mot de passe contient au moins un caractère de chaque catégorie
    password="${password}${upper:$((RANDOM % ${#upper})):1}"
    password="${password}${lower:$((RANDOM % ${#lower})):1}"
    password="${password}${numbers:$((RANDOM % ${#numbers})):1}"
    
    # Compléter le reste du mot de passe avec des caractères alphanumériques
    local chars="${upper}${lower}${numbers}"
    while [[ ${#password} -lt $length ]]; do
        password="${password}${chars:$((RANDOM % ${#chars})):1}"
    done
    
    # Mélanger les caractères du mot de passe
    password=$(echo "$password" | fold -w1 | shuf | tr -d '\n')
    
    echo "$password"
}

# Fonction pour générer un hash de mot de passe pour l'authentification basique
generate_password_hash() {
    local user="$1"
    local password="$2"
    local hash
    
    if [[ -z "$user" ]] || [[ -z "$password" ]]; then
        error "Utilisateur ou mot de passe manquant pour la génération du hash"
        return 1
    fi
    
    # Génère le hash avec htpasswd
    hash=$(htpasswd -nb "$user" "$password" | cut -d':' -f2)
    
    # Échappe les caractères $ pour docker-compose
    echo "$hash" | sed -e 's/\$/\$\$/g'
}

# Fonction pour vérifier la résolution DNS
check_dns_resolution() {
    section "VÉRIFICATION DNS"
    
    info "Vérification de la résolution DNS pour vos domaines..."
    
    # Installer dnsutils si nécessaire (pour dig)
    if ! command -v dig &> /dev/null; then
        info "Installation de dnsutils pour les tests DNS..."
        sudo apt-get install -y dnsutils || warning "Impossible d'installer dnsutils. Les tests DNS seront limités."
    fi
    
    # Vérifier la résolution DNS pour le domaine principal
    if command -v dig &> /dev/null; then
        info "Test de résolution DNS pour $BASE_DOMAIN..."
        DOMAIN_IP=$(dig +short $BASE_DOMAIN A)
        
        if [ -z "$DOMAIN_IP" ]; then
            warning "Aucune entrée DNS trouvée pour $BASE_DOMAIN."
            warning "Assurez-vous que votre domaine est correctement configuré pour pointer vers ce serveur."
            
            read -p "Voulez-vous continuer malgré l'absence d'entrée DNS pour le domaine principal ? (o/n) : " CONTINUE_DNS_MISSING
            if [[ "$CONTINUE_DNS_MISSING" != "o" ]]; then
                error "Installation interrompue. Veuillez configurer votre DNS et réessayer."
                exit 1
            fi
        else
            info "Le domaine $BASE_DOMAIN pointe vers : $DOMAIN_IP"
            
            # Obtenir l'IP publique du serveur
            PUBLIC_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)
            
            if [ -n "$PUBLIC_IP" ]; then
                info "IP publique de ce serveur : $PUBLIC_IP"
                
                # Informer sur la configuration des sous-domaines
                if [ "$DOMAIN_IP" != "$PUBLIC_IP" ]; then
                    info "L'IP du domaine principal ($DOMAIN_IP) diffère de l'IP de ce serveur ($PUBLIC_IP)."
                    info "Cela peut être normal si vous utilisez un service de proxy comme Cloudflare ou si vous configurez des sous-domaines pour pointer vers un autre serveur."
                else
                    success "L'IP du domaine principal correspond à l'IP de ce serveur."
                fi
            fi
        fi
        
        # Vérifier les sous-domaines
        info "Test de résolution DNS pour les sous-domaines..."
        
        local subdomains=("traefik" "portainer" "n8n" "pgadmin" "redis")
        local unresolved_subdomains=()
        
        for subdomain in "${subdomains[@]}"; do
            local fqdn="${subdomain}.${BASE_DOMAIN}"
            local subdomain_ip=$(dig +short $fqdn A)
            
            if [ -z "$subdomain_ip" ]; then
                info "Aucune entrée DNS trouvée pour $fqdn"
                unresolved_subdomains+=("$fqdn")
            else
                success "Le sous-domaine $fqdn pointe vers : $subdomain_ip"
            fi
        done
        
        if [ ${#unresolved_subdomains[@]} -gt 0 ]; then
            warning "Certains sous-domaines n'ont pas d'entrées DNS :"
            for domain in "${unresolved_subdomains[@]}"; do
                echo "  - $domain"
            done
            
            info "Pour que Let's Encrypt fonctionne, vous devez configurer des entrées DNS pour tous les sous-domaines."
            info "Vous pouvez utiliser :"
            info "  - Des enregistrements A individuels pour chaque sous-domaine"
            info "  - Un enregistrement A wildcard (*.${BASE_DOMAIN})"
            info "  - Des enregistrements CNAME pointant vers votre domaine principal"
            
            read -p "Voulez-vous continuer malgré les problèmes DNS des sous-domaines ? (o/n) : " CONTINUE_DNS_ISSUES
            if [[ "$CONTINUE_DNS_ISSUES" != "o" ]]; then
                error "Installation interrompue. Veuillez configurer vos sous-domaines et réessayer."
                exit 1
            fi
            
            warning "Vous avez choisi de continuer malgré les problèmes DNS. Let's Encrypt pourrait ne pas générer de certificats pour tous les domaines."
        else
            success "Tous les sous-domaines ont des entrées DNS configurées."
        fi
    else
        warning "La commande dig n'est pas disponible. Impossible de vérifier la résolution DNS."
        warning "Assurez-vous manuellement que votre domaine et tous les sous-domaines pointent vers ce serveur."
        
        read -p "Voulez-vous continuer sans vérification DNS ? (o/n) : " CONTINUE_NO_DNS_CHECK
        if [[ "$CONTINUE_NO_DNS_CHECK" != "o" ]]; then
            error "Installation interrompue. Veuillez installer dnsutils et réessayer."
            exit 1
        fi
    fi
}


# ====================== FONCTIONS PRINCIPALES ======================

# Fonction pour collecter les informations de l'utilisateur
collect_info() {
    section "CONFIGURATION DE LA STACK"
    
    # Collecter les informations de domaine
    while true; do
        read -p "Entrez votre nom de domaine (exemple: exemple.com): " BASE_DOMAIN
        if validate_domain "$BASE_DOMAIN"; then
            break
        else
            error "Le domaine n'est pas valide. Veuillez réessayer."
        fi
    done

    # Configurer les sous-domaines
    TRAEFIK_DOMAIN="traefik.$BASE_DOMAIN"
    PORTAINER_DOMAIN="portainer.$BASE_DOMAIN"
    N8N_DOMAIN="n8n.$BASE_DOMAIN"
    PGADMIN_DOMAIN="pgadmin.$BASE_DOMAIN"
    REDIS_COMMANDER_DOMAIN="redis.$BASE_DOMAIN"

    # Collecter l'email pour Let's Encrypt et pgAdmin
    while true; do
        read -p "Entrez votre email pour Let's Encrypt et pgAdmin: " EMAIL
        if validate_email "$EMAIL"; then
            PGADMIN_EMAIL="$EMAIL"  # Utiliser le même email pour pgAdmin
            break
        else
            error "L'email n'est pas valide. Veuillez réessayer."
        fi
    done

    # Collecter les noms d'utilisateur pour les services
    while true; do
        read -p "Entrez un nom d'utilisateur pour Traefik [admin]: " TRAEFIK_USER
        TRAEFIK_USER=${TRAEFIK_USER:-admin}
        if validate_username "$TRAEFIK_USER"; then
            break
        else
            error "Le nom d'utilisateur n'est pas valide. Il doit contenir au moins 3 caractères (lettres, chiffres, tirets ou underscores)."
        fi
    done

    while true; do
        read -p "Entrez un nom d'utilisateur pour Redis Commander [admin]: " REDIS_COMMANDER_USER
        REDIS_COMMANDER_USER=${REDIS_COMMANDER_USER:-admin}
        if validate_username "$REDIS_COMMANDER_USER"; then
            break
        else
            error "Le nom d'utilisateur n'est pas valide. Il doit contenir au moins 3 caractères (lettres, chiffres, tirets ou underscores)."
        fi
    done

    # Générer un nom d'utilisateur aléatoire pour PostgreSQL
    POSTGRES_USER="dbuser_$(openssl rand -hex 4)"
    
    # Nom de la base de données avec valeur par défaut
    read -p "Entrez le nom de la base de données PostgreSQL [aidb]: " POSTGRES_DB
    POSTGRES_DB=${POSTGRES_DB:-aidb}
    
    success "Configuration terminée. L'installation va maintenant commencer."
    
    # Informer l'utilisateur sur la génération de mot de passe
    info "Des mots de passe sécurisés seront automatiquement générés pour tous les services."
    info "Ils seront sauvegardés dans ~/ai-stack/credentials.txt après l'installation."
    
    # Résumé des noms d'utilisateur configurés
    info "Noms d'utilisateur configurés:"
    echo "- Traefik: ${TRAEFIK_USER}"
    echo "- Redis Commander: ${REDIS_COMMANDER_USER}"
    echo "- PostgreSQL: ${POSTGRES_USER}"
}

# Fonction pour installer les prérequis
install_prereqs() {
    section "PRÉPARATION DU SYSTÈME"
    
    # Vérifier l'espace disque
    check_disk_space
    
    info "Mise à jour des paquets système..."
    system_update
    
    info "Vérification et installation des dépendances..."
    
    # Liste des dépendances requises
    local dependencies=("apt-transport-https" "ca-certificates" "curl" "software-properties-common" "git" "jq" "netcat-openbsd")
    local db_tools=("postgresql-client" "redis-tools")
    
    # Vérifier et installer les dépendances de base
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! is_package_installed "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        info "Installation des dépendances manquantes : ${missing_deps[*]}"
        sudo apt install -y "${missing_deps[@]}" || check_error "Échec de l'installation des dépendances"
    else
        info "Toutes les dépendances de base sont déjà installées."
    fi
    
    # Vérifier et installer les outils de base de données
    local missing_db_tools=()
    for tool in "${db_tools[@]}"; do
        if ! is_package_installed "$tool"; then
            missing_db_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_db_tools[@]} -ne 0 ]; then
        info "Installation des outils de base de données manquants : ${missing_db_tools[*]}"
        sudo apt install -y "${missing_db_tools[@]}" || check_error "Échec de l'installation des outils de base de données"
    else
        info "Tous les outils de base de données sont déjà installés."
    fi

    # Installer apache2-utils pour htpasswd si non disponible
    if ! command -v htpasswd &> /dev/null; then
        info "Installation de apache2-utils pour htpasswd..."
        sudo apt install -y apache2-utils || check_error "Échec de l'installation de apache2-utils"
    else
        info "htpasswd est déjà installé."
    fi

    # Installer Docker s'il n'est pas présent ou le mettre à jour
    if ! command -v docker &> /dev/null; then
        info "Installation de la dernière version de Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        
        warning "Votre utilisateur a été ajouté au groupe 'docker'."
        warning "Pour que les changements prennent effet, vous devrez vous déconnecter et vous reconnecter après l'installation."
        warning "Le script continuera à fonctionner, mais vous pourriez avoir besoin d'utiliser 'sudo' pour les commandes Docker."
    else
        info "Docker est déjà installé. Vérification de la version..."
        CURRENT_DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        info "Version actuelle de Docker: $CURRENT_DOCKER_VERSION"
        
        # Mise à jour de Docker à la dernière version
        info "Mise à jour de Docker à la dernière version..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        
        NEW_DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        success "Docker mis à jour à la version: $NEW_DOCKER_VERSION"
        
        # Vérifier si l'utilisateur est dans le groupe docker
        if ! groups $USER | grep -q '\bdocker\b'; then
            warning "Votre utilisateur n'est pas dans le groupe 'docker'."
            warning "Cela peut nécessiter l'utilisation de 'sudo' pour les commandes Docker."
            read -p "Voulez-vous ajouter votre utilisateur au groupe 'docker'? (o/n) : " ADD_TO_DOCKER
            if [[ "$ADD_TO_DOCKER" == "o" ]]; then
                sudo usermod -aG docker $USER
                warning "Votre utilisateur a été ajouté au groupe 'docker'."
                warning "Pour que les changements prennent effet, vous devrez vous déconnecter et vous reconnecter après l'installation."
            fi
        else
            info "Votre utilisateur est déjà dans le groupe 'docker'."
        fi
    fi

    # Installer Docker Compose v2 (via plugin Docker)
    info "Installation de Docker Compose v2 (plugin)..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    
    # Télécharger la dernière version de Docker Compose
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    info "Dernière version de Docker Compose: $LATEST_COMPOSE_VERSION"
    
    COMPOSE_URL="https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    sudo curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Créer également un lien symbolique pour le plugin
    sudo curl -L "$COMPOSE_URL" -o $DOCKER_CONFIG/cli-plugins/docker-compose
    sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    
    # Vérifier l'installation
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose version --short)
        success "Docker Compose installé avec succès: $COMPOSE_VERSION"
    else
        warning "Docker Compose n'a pas pu être installé correctement. Tentative d'utiliser la version intégrée de Docker..."
        if docker compose version &> /dev/null; then
            COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "version intégrée")
            success "Docker Compose intégré disponible: $COMPOSE_VERSION"
        else
            error "Docker Compose n'est pas disponible. L'installation ne peut pas continuer."
            exit 1
        fi
    fi
}

# Fonction pour configurer les paramètres système pour Redis
configure_system_settings() {
    section "OPTIMISATION DU SYSTÈME"
    
    info "Configuration des paramètres système pour l'optimisation de Redis..."
    
    # Vérifier et configurer vm.overcommit_memory
    if grep -q "vm.overcommit_memory" /etc/sysctl.conf; then
        sudo sed -i 's/vm.overcommit_memory.*/vm.overcommit_memory = 1/' /etc/sysctl.conf
    else
        echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    
    # Appliquer le paramètre immédiatement
    sudo sysctl vm.overcommit_memory=1
    
    # Désactiver les Transparent Huge Pages (recommandé pour Redis)
    echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    
    # Faire persister le paramètre THP après redémarrage
    if ! grep -q "transparent_hugepage" /etc/rc.local; then
        if [ ! -f /etc/rc.local ]; then
            echo '#!/bin/bash' | sudo tee /etc/rc.local > /dev/null
            sudo chmod +x /etc/rc.local
        fi
        
        sudo sed -i '/exit 0/d' /etc/rc.local
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" | sudo tee -a /etc/rc.local > /dev/null
        echo "exit 0" | sudo tee -a /etc/rc.local > /dev/null
    fi
    
    # Configurer les limites système pour les conteneurs
    info "Configuration des limites système pour les conteneurs..."
    
    # Augmenter la limite de fichiers ouverts
    if ! grep -q "fs.file-max" /etc/sysctl.conf; then
        echo "fs.file-max = 1000000" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    
    # Augmenter les limites de mémoire pour les conteneurs
    if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
        echo "vm.max_map_count = 262144" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    
    # Appliquer les paramètres immédiatement
    sudo sysctl -p
    
    success "Paramètres système configurés pour des performances optimales"
}

# Fonction pour créer les fichiers de configuration
create_config_files() {
    section "CRÉATION DES FICHIERS DE CONFIGURATION"
    
    # Vérifier que le hash du mot de passe Traefik est défini
    if [[ -z "$TRAEFIK_PASSWORD_HASH" ]]; then
        error "Le hash du mot de passe Traefik n'est pas défini. Impossible de continuer."
        exit 1
    fi
    
    info "Mise en place de la structure des répertoires..."
    mkdir -p ~/ai-stack
    cd ~/ai-stack
    
    # Créer la structure de répertoires modernisée
    mkdir -p traefik/config/dynamic
    mkdir -p traefik/acme
    mkdir -p services/n8n
    mkdir -p services/postgres
    mkdir -p services/redis
    mkdir -p scripts

    info "Création du fichier .env..."
    cat > .env << EOL
# Domaines
BASE_DOMAIN=${BASE_DOMAIN}
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN}
N8N_DOMAIN=${N8N_DOMAIN}
PGADMIN_DOMAIN=${PGADMIN_DOMAIN}
REDIS_COMMANDER_DOMAIN=${REDIS_COMMANDER_DOMAIN}

# Identifiants PostgreSQL
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# Identifiants pgAdmin
PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}

# Identifiants Redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_COMMANDER_USER=${REDIS_COMMANDER_USER}
REDIS_COMMANDER_PASSWORD=${REDIS_COMMANDER_PASSWORD}

# Identifiants Traefik
TRAEFIK_USER=${TRAEFIK_USER}
TRAEFIK_PASSWORD_HASH=${TRAEFIK_PASSWORD_HASH}

# Configuration Let's Encrypt
ACME_EMAIL=${EMAIL}
EOL

    info "Création de docker-compose.yml..."
    cat > docker-compose.yml << EOL
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/config:/etc/traefik
      - ./traefik/acme:/acme
    networks:
      - ai-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik-dashboard.rule=Host(\`\${TRAEFIK_DOMAIN}\`)"
      - "traefik.http.routers.traefik-dashboard.entrypoints=websecure"
      - "traefik.http.routers.traefik-dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik-dashboard.service=api@internal"
      - "traefik.http.routers.traefik-dashboard.middlewares=traefik-auth,secure-headers@file"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=\${TRAEFIK_USER}:\${TRAEFIK_PASSWORD_HASH}"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    environment:
      - TZ=Europe/Paris
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer-data:/data
    networks:
      - ai-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`\${PORTAINER_DOMAIN}\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      - "traefik.http.routers.portainer.middlewares=secure-headers@file"
    depends_on:
      traefik:
        condition: service_healthy

  postgres:
    image: postgres:latest
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_DB=\${POSTGRES_DB}
      - TZ=Europe/Paris
      - LANG=C.UTF-8
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - ai-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      start_period: 30s
      interval: 10s
      timeout: 10s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      - PGADMIN_DEFAULT_EMAIL=\${PGADMIN_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=\${PGADMIN_PASSWORD}
      - PGADMIN_CONFIG_SERVER_MODE=True
      - TZ=Europe/Paris
    volumes:
      - pgadmin-data:/var/lib/pgadmin
    depends_on:
      postgres:
        condition: service_healthy
      traefik:
        condition: service_healthy
    networks:
      - ai-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pgadmin.rule=Host(\`\${PGADMIN_DOMAIN}\`)"
      - "traefik.http.routers.pgadmin.entrypoints=websecure"
      - "traefik.http.routers.pgadmin.tls.certresolver=letsencrypt"
      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
      - "traefik.http.routers.pgadmin.middlewares=secure-headers@file"

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_PORT=5678
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - N8N_PROTOCOL=https
      - N8N_HOST=\${N8N_DOMAIN}
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${N8N_DOMAIN}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_RUNNERS_ENABLED=true
      - N8N_COMMUNITY_NODES_ENABLED=true
      - GENERIC_TIMEZONE=Europe/Paris
    volumes:
      - n8n-data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
      traefik:
        condition: service_healthy
    networks:
      - ai-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`\${N8N_DOMAIN}\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
      - "traefik.http.routers.n8n.middlewares=secure-headers@file"

  redis:
    image: redis:latest
    container_name: redis
    restart: unless-stopped
    command: >-
      redis-server 
      --requirepass "\${REDIS_PASSWORD}" 
      --appendonly yes 
      --maxmemory 256mb 
      --maxmemory-policy allkeys-lru
    sysctls:
      net.core.somaxconn: 1024
    volumes:
      - redis-data:/data
    networks:
      - ai-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "\${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: redis-commander
    restart: unless-stopped
    environment:
      - REDIS_HOSTS=local:redis:6379:0:\${REDIS_PASSWORD}
      - HTTP_USER=\${REDIS_COMMANDER_USER}
      - HTTP_PASSWORD=\${REDIS_COMMANDER_PASSWORD}
    networks:
      - ai-network
    depends_on:
      redis:
        condition: service_healthy
      traefik:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.redis-commander.rule=Host(\`\${REDIS_COMMANDER_DOMAIN}\`)"
      - "traefik.http.routers.redis-commander.entrypoints=websecure"
      - "traefik.http.routers.redis-commander.tls.certresolver=letsencrypt"
      - "traefik.http.services.redis-commander.loadbalancer.server.port=8081"
      - "traefik.http.routers.redis-commander.middlewares=secure-headers@file"

networks:
  ai-network:
    name: ai-network
    driver: bridge

volumes:
  postgres-data:
  pgadmin-data:
  n8n-data:
  redis-data:
  portainer-data:
EOL

    info "Création de la configuration Traefik..."
    
    # Création du fichier acme.json avec les permissions appropriées
    touch traefik/acme/acme.json
    chmod 600 traefik/acme/acme.json

    cat > traefik/config/traefik.yml << EOL
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: /acme/acme.json
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: ai-network
  file:
    directory: /etc/traefik/dynamic
    watch: true

log:
  level: INFO
  format: json

accessLog:
  format: json

ping:
  entryPoint: traefik
EOL

    # Création des middlewares Traefik
    cat > traefik/config/dynamic/middlewares.yml << EOL
http:
  middlewares:
    secure-headers:
      headers:
        frameDeny: true
        sslRedirect: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
        customResponseHeaders:
          X-Robots-Tag: "none,noarchive,nosnippet,notranslate,noimageindex"
          Server: ""
EOL

    info "Création des scripts utilitaires..."
    cat > scripts/pg-connect.sh << EOL
#!/bin/bash
echo -e "${BLUE}[INFO]${NC} Connexion à PostgreSQL..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h localhost -p 5432 -U ${POSTGRES_USER} -d ${POSTGRES_DB}
EOL
    chmod +x scripts/pg-connect.sh

    cat > scripts/redis-connect.sh << EOL
#!/bin/bash
echo -e "${BLUE}[INFO]${NC} Connexion à Redis..."
redis-cli -h localhost -p 6379 -a "${REDIS_PASSWORD}"
EOL
    chmod +x scripts/redis-connect.sh

    # Script de sauvegarde
    cat > scripts/backup.sh << EOL
#!/bin/bash

# Script de sauvegarde pour AI Stack
# Sauvegarde les volumes Docker et les configurations

# Configuration
BACKUP_DIR=~/ai-stack-backups
DATE=\$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE=\${BACKUP_DIR}/ai-stack-backup-\${DATE}.tar.gz

# Créer le répertoire de sauvegarde s'il n'existe pas
mkdir -p \${BACKUP_DIR}

# Sauvegarde des configurations
echo "Sauvegarde des fichiers de configuration..."
cd ~/ai-stack
tar -czf \${BACKUP_FILE} .env docker-compose.yml traefik/config scripts

# Sauvegarde de la base de données PostgreSQL
echo "Sauvegarde de la base de données PostgreSQL..."
docker exec postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > \${BACKUP_DIR}/db_backup_\${DATE}.sql

# Compression de la sauvegarde SQL
gzip \${BACKUP_DIR}/db_backup_\${DATE}.sql

echo "Sauvegarde terminée : \${BACKUP_FILE}"
echo "Sauvegarde de la base de données : \${BACKUP_DIR}/db_backup_\${DATE}.sql.gz"
EOL
    chmod +x scripts/backup.sh

    # Script de mise à jour
    cat > scripts/update.sh << EOL
#!/bin/bash

# Script de mise à jour pour AI Stack
# Met à jour tous les conteneurs vers les dernières versions

cd ~/ai-stack

echo "Arrêt des conteneurs..."
docker compose down

echo "Suppression des images obsolètes..."
docker image prune -f

echo "Téléchargement des dernières images..."
docker compose pull

echo "Démarrage des conteneurs mis à jour..."
docker compose up -d

echo "Mise à jour terminée. Vérification des conteneurs..."
docker compose ps
EOL
    chmod +x scripts/update.sh

    # Créer des liens symboliques dans le répertoire principal
    ln -sf scripts/pg-connect.sh pg-connect.sh
    ln -sf scripts/redis-connect.sh redis-connect.sh

    success "Fichiers de configuration créés avec succès"
}

# Fonction pour démarrer la stack
start_stack() {
    section "LANCEMENT DES SERVICES"
    
    info "Démarrage de la stack AI..."
    cd ~/ai-stack
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        success "Stack AI déployée avec succès !"
        echo ""
        info "Vos services sont disponibles aux adresses suivantes :"
        echo "- Tableau de bord Traefik : https://${TRAEFIK_DOMAIN}"
        echo "- Portainer : https://${PORTAINER_DOMAIN}"
        echo "- n8n : https://${N8N_DOMAIN}"
        echo "- pgAdmin : https://${PGADMIN_DOMAIN}"
        echo "- Redis Commander : https://${REDIS_COMMANDER_DOMAIN}"
        echo ""
        info "Pour la connexion en ligne de commande sur le serveur :"
        echo "- PostgreSQL : ./pg-connect.sh"
        echo "- Redis : ./redis-connect.sh"
        echo ""
        warning "IMPORTANT : Lors de votre première connexion à Portainer, vous devrez créer un compte administrateur."
        echo ""
        info "Commandes de gestion de la stack :"
        echo "- Mettre à jour la stack : cd ~/ai-stack && ./scripts/update.sh"
        echo "- Sauvegarder la stack : cd ~/ai-stack && ./scripts/backup.sh"
        echo "- Redémarrer la stack : cd ~/ai-stack && docker compose restart"
        echo "- Arrêter la stack : cd ~/ai-stack && docker compose down"
    else
        error "Une erreur s'est produite lors du démarrage de la stack."
        exit 1
    fi
}

# Fonction pour vérifier l'état des services
check_services_status() {
    section "VÉRIFICATION DE L'ÉTAT DES SERVICES"
    
    info "Vérification de l'état des conteneurs..."
    cd ~/ai-stack
    docker compose ps
    
    info "Vérification des logs Traefik pour les erreurs de certificats..."
    docker logs traefik 2>&1 | grep -i "error\|warn\|certif" | tail -n 20
    
    info "Vérification de l'accessibilité des services..."
    
    # Vérifier si curl est disponible
    if command -v curl &> /dev/null; then
        # Attendre quelques secondes pour que les services démarrent
        info "Attente que les services soient prêts..."
        for service in traefik n8n postgres redis; do
            info "Attente que $service soit prêt..."
            timeout=60  # Temps maximum d'attente en secondes
            counter=0
            while [ $counter -lt $timeout ]; do
                if docker inspect --format='{{.State.Health.Status}}' $service 2>/dev/null | grep -q "healthy"; then
                    success "$service est prêt!"
                    break
                fi
                sleep 2
                counter=$((counter+2))
                if [ $counter -ge $timeout ]; then
                    warning "$service n'est pas devenu prêt dans le délai imparti. Continuation..."
                fi
            done
        done
        
        # Tester l'accès à Traefik
        info "Test d'accès à Traefik..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k https://${TRAEFIK_DOMAIN})
        if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
            success "Traefik est accessible (code HTTP: $HTTP_CODE)"
        else
            warning "Traefik n'est pas accessible correctement (code HTTP: $HTTP_CODE)"
        fi
        
        # Tester l'accès à n8n
        info "Test d'accès à n8n..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k https://${N8N_DOMAIN})
        if [ "$HTTP_CODE" = "200" ]; then
            success "n8n est accessible (code HTTP: $HTTP_CODE)"
        else
            warning "n8n n'est pas accessible correctement (code HTTP: $HTTP_CODE)"
        fi
    else
        warning "curl n'est pas disponible. Impossible de tester l'accessibilité des services."
    fi
    
    info "Vérification de l'état des certificats Let's Encrypt..."
    if [ -f ~/ai-stack/traefik/acme/acme.json ]; then
        if [ -s ~/ai-stack/traefik/acme/acme.json ]; then
            if command -v jq &> /dev/null; then
                # Utiliser set +e pour éviter que le script ne s'arrête si jq échoue
                set +e
                CERT_DOMAINS=$(cat ~/ai-stack/traefik/acme/acme.json | jq -r '.letsencrypt.Certificates[].domain.main' 2>/dev/null || echo "")
                set -e
                
                if [ -n "$CERT_DOMAINS" ]; then
                    success "Certificats Let's Encrypt obtenus pour les domaines :"
                    echo "$CERT_DOMAINS"
                else
                    warning "Aucun certificat Let's Encrypt n'a encore été obtenu."
                    warning "Cela peut prendre quelques minutes. Vérifiez les logs Traefik pour plus d'informations."
                fi
            else
                warning "jq n'est pas disponible. Impossible d'analyser les certificats."
                ls -la ~/ai-stack/traefik/acme/acme.json
            fi
        else
            warning "Le fichier acme.json existe mais est vide."
            warning "Let's Encrypt n'a pas encore généré de certificats."
        fi
    else
        warning "Le fichier acme.json n'existe pas."
        warning "Let's Encrypt n'a pas encore généré de certificats."
    fi

}

# ====================== EXÉCUTION PRINCIPALE ======================

main() {
    # Afficher la bannière
    echo -e "${CYAN}"
    echo "░█████╗░██╗  ░██████╗████████╗░█████╗░░█████╗░██╗░░██╗"
    echo "██╔══██╗██║  ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║░██╔╝"
    echo "███████║██║  ╚█████╗░░░░██║░░░███████║██║░░╚═╝█████═╝░"
    echo "██╔══██║██║  ░╚═══██╗░░░██║░░░██╔══██║██║░░██╗██╔═██╗░"
    echo "██║░░██║██║  ██████╔╝░░░██║░░░██║░░██║╚█████╔╝██║░╚██╗"
    echo "╚═╝░░╚═╝╚═╝  ╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝"
    echo -e "${NC}"
    echo "Créé par Romain Jolly Martoia"
    echo "Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF"
    echo "=============================================================="
    echo ""
    
    # Avertissement
    echo -e "${YELLOW}AVERTISSEMENT :${NC}"
    echo "Ce script installe une stack complète d'IA et d'automatisation utilisant Docker."
    echo "Il inclut Traefik, Portainer, PostgreSQL, pgAdmin, n8n, Redis et Redis Commander."
    echo "L'installation configurera un accès sécurisé avec des certificats SSL via Let's Encrypt."
    echo ""
    echo "Prérequis :"
    echo "- Un serveur exécutant Ubuntu (20.04+ recommandé)"
    echo "- Un nom de domaine avec DNS correctement configuré pour pointer vers ce serveur"
    echo "- Ports 80 et 443 accessibles depuis Internet (pour les certificats SSL)"
    echo ""
    
    # Demander à l'utilisateur d'accepter l'avertissement
    read -p "Êtes-vous d'accord pour continuer ? (o/n) : " AGREEMENT
    
    # Vérifier la réponse de l'utilisateur
    if [[ "$AGREEMENT" != "o" ]]; then
        echo "Vous avez refusé l'accord. Sortie du script."
        echo "Installation annulée. Vous pouvez exécuter le script à nouveau à tout moment pour continuer."
        
        # Demander de supprimer le fichier script
        read -p "Voulez-vous supprimer le fichier script téléchargé ? (o/n) : " DELETE_FILE
        cleanup_script "$DELETE_FILE"
        
        exit 1
    fi
    
    # Réparer le système de paquets avant toute installation
    repair_package_system
    
    # Collecter les informations de l'utilisateur
    collect_info
    
    # Vérifier la résolution DNS
    check_dns_resolution
    
    # S'assurer que htpasswd est installé avant de générer les mots de passe
    if ! command -v htpasswd &> /dev/null; then
        info "Installation de apache2-utils pour htpasswd..."
        # Réparation supplémentaire du système de paquets si nécessaire
        sudo dpkg --configure -a
        sudo apt-get -f install -y
        sudo apt-get update
        sudo apt-get install -y apache2-utils || {
            error "Échec de l'installation de apache2-utils."
            error "Essayez d'exécuter manuellement : sudo apt install -y apache2-utils"
            error "Puis relancez ce script."
            exit 1
        }
        
        # Vérifier que htpasswd est maintenant disponible
        if ! command -v htpasswd &> /dev/null; then
            error "Impossible d'installer htpasswd. Cet outil est nécessaire pour continuer."
            exit 1
        fi
    fi
    
    # Générer des mots de passe sécurisés pour tous les services
    section "GÉNÉRATION DES IDENTIFIANTS SÉCURISÉS"
    info "Création de mots de passe forts pour tous les services..."

    # Générer les mots de passe
    TRAEFIK_PASSWORD=$(generate_secure_password 16)
    POSTGRES_PASSWORD=$(generate_secure_password 16)
    PGADMIN_PASSWORD=$(generate_secure_password 16)
    REDIS_PASSWORD=$(generate_secure_password 16)
    REDIS_COMMANDER_PASSWORD=$(generate_secure_password 16)

    # Générer le hash pour Traefik avec gestion d'erreur
    TRAEFIK_PASSWORD_HASH=$(generate_password_hash "$TRAEFIK_USER" "$TRAEFIK_PASSWORD")
    if [[ -z "$TRAEFIK_PASSWORD_HASH" ]] || ! echo "$TRAEFIK_PASSWORD_HASH" | grep -q '\$'; then
        error "Échec de la génération du hash de mot de passe pour Traefik"
        error "Hash généré : $TRAEFIK_PASSWORD_HASH"
        exit 1
    fi

    success "Identifiants sécurisés générés avec succès"
    
    # Vérifier l'accessibilité des ports 80 et 443
    check_ports_accessibility
    
    # Installer les prérequis
    install_prereqs
    
    # Installer et configurer les outils de sécurité
    install_security_tools
    
    # Configurer les paramètres système pour Redis
    configure_system_settings
    
    # Créer les fichiers de configuration
    create_config_files
    
    # Démarrer la stack
    start_stack
    
    # Vérifier l'état des services
    check_services_status
    
    # Sauvegarder les identifiants
    section "SAUVEGARDE DES IDENTIFIANTS"
    
    CREDENTIALS_FILE=~/ai-stack/credentials.txt
    CREDENTIALS_CONTENT="==== IDENTIFIANTS DE LA STACK AI ====
Générés le : $(date)

CONFIGURATION DES DOMAINES :
- Traefik : https://${TRAEFIK_DOMAIN}
- Portainer : https://${PORTAINER_DOMAIN} (créer un compte admin lors de la première connexion)
- n8n : https://${N8N_DOMAIN} (créer un compte lors de la première connexion)
- pgAdmin : https://${PGADMIN_DOMAIN}
- Redis Commander : https://${REDIS_COMMANDER_DOMAIN}

TABLEAU DE BORD TRAEFIK :
- Nom d'utilisateur : ${TRAEFIK_USER}
- Mot de passe : ${TRAEFIK_PASSWORD}

BASE DE DONNÉES POSTGRESQL :
- Hôte : postgres
- Port : 5432
- Base de données : ${POSTGRES_DB}
- Nom d'utilisateur : ${POSTGRES_USER}
- Mot de passe : ${POSTGRES_PASSWORD}

INTERFACE PGADMIN :
- Email : ${PGADMIN_EMAIL}
- Mot de passe : ${PGADMIN_PASSWORD}

REDIS :
- Hôte : redis
- Port : 6379
- Mot de passe : ${REDIS_PASSWORD}

REDIS COMMANDER :
- Nom d'utilisateur : ${REDIS_COMMANDER_USER}
- Mot de passe : ${REDIS_COMMANDER_PASSWORD}

PORTAINER & N8N :
- Créez des comptes administrateur lors de votre première connexion

Pour l'accès en ligne de commande :
- PostgreSQL : Utilisez le script pg-connect.sh dans le répertoire ai-stack
- Redis : Utilisez le script redis-connect.sh dans le répertoire ai-stack

Pour la maintenance :
- Mise à jour : ./scripts/update.sh
- Sauvegarde : ./scripts/backup.sh"

    save_credentials_securely "$CREDENTIALS_FILE" "$CREDENTIALS_CONTENT"
    
    # Message final
    section "INSTALLATION TERMINÉE"
    
    success "Installation de la stack AI terminée avec succès !"
    warning "Vos identifiants ont été sauvegardés dans ${CREDENTIALS_FILE}"
    warning "GARDEZ CE FICHIER EN SÉCURITÉ et supprimez-le après avoir sauvegardé les informations ailleurs."
    echo ""
    
    echo -e "${CYAN}                   === RÉSUMÉ DU DÉPLOIEMENT DE LA STACK ===${NC}"
    echo -e "  Service          |  URL d'accès                           "
    echo -e "-------------------|----------------------------------------"
    echo -e "  Traefik          |  https://${TRAEFIK_DOMAIN}            "
    echo -e "  Portainer        |  https://${PORTAINER_DOMAIN}          "
    echo -e "  n8n              |  https://${N8N_DOMAIN}                "
    echo -e "  pgAdmin          |  https://${PGADMIN_DOMAIN}            "
    echo -e "  Redis Commander  |  https://${REDIS_COMMANDER_DOMAIN}    "
    echo ""
    
    echo -e "${PURPLE}Détails de connexion PostgreSQL (pour vos applications) :${NC}"
    echo -e "  Nom d'utilisateur : ${POSTGRES_USER}"
    echo -e "  Mot de passe : (stocké dans credentials.txt)"
    echo -e "  Base de données : ${POSTGRES_DB}"
    echo ""
    
    # Avertissement sur les droits Docker
    if ! groups $USER | grep -q '\bdocker\b'; then
        warning "RAPPEL : Votre utilisateur a été ajouté au groupe 'docker'."
        warning "Pour utiliser Docker sans sudo, vous devrez vous déconnecter et vous reconnecter."
    fi

    echo -e "${CYAN}Sécurité renforcée :${NC}"
    echo -e "- Fail2ban est configuré pour protéger tous vos services (SSH, Traefik, Portainer, n8n, PostgreSQL)"
    echo -e "- Utilisez le script ./fail2ban-manage.sh pour gérer Fail2ban"
    echo -e "- Exemple : ./fail2ban-manage.sh status"
    
    echo -e "${CYAN}Conseils de dépannage :${NC}"
    echo -e "1. Si vous ne pouvez pas accéder à vos services, vérifiez :"
    echo -e "   - Les logs Traefik : docker logs traefik"
    echo -e "   - La résolution DNS : dig ${N8N_DOMAIN}"
    echo -e "   - L'état des certificats : cat ~/ai-stack/traefik/acme/acme.json"
    echo -e "2. Si Let's Encrypt échoue, vérifiez que les ports 80 et 443 sont accessibles depuis Internet"
    echo -e "3. Pour redémarrer un service spécifique : docker restart [nom_du_service]"
    echo ""
    
    # Demander si le script doit être supprimé
    read -p "Voulez-vous supprimer le script d'installation ? (o/n) : " DELETE_SCRIPT
    cleanup_script "$DELETE_SCRIPT"
}

# Exécuter la fonction principale
main