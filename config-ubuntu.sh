#!/bin/bash

# ===================================================================
# ░██████╗███████╗██████╗░██╗░░░██╗███████╗██████╗░
# ██╔════╝██╔════╝██╔══██╗██║░░░██║██╔════╝██╔══██╗
# ╚█████╗░█████╗░░██████╔╝██║░░░██║█████╗░░██████╔╝
# ░╚═══██╗██╔══╝░░██╔══██╗╚██╗░██╔╝██╔══╝░░██╔══██╗
# ██████╔╝███████╗██║░░██║░╚████╔╝░███████╗██║░░██║
# ╚═════╝░╚══════╝╚═╝░░╚═╝░░╚═══╝░░╚══════╝╚═╝░░╚═╝
# Server Setup v1.0 | Créé par Romain Jolly Martoia
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

# Fonction pour afficher l'avertissement initial et demander confirmation
show_initial_warning() {
    clear
    echo -e "${YELLOW}"
    echo "⚠️  AVERTISSEMENT IMPORTANT ⚠️"
    echo -e "===============================================================${NC}"
    echo ""
    echo -e "Ce script est conçu pour configurer un ${CYAN}serveur Ubuntu fraîchement installé${NC}."
    echo "Il va effectuer les opérations suivantes :"
    echo ""
    echo -e " ${GREEN}✓${NC} Mise à jour complète du système"
    echo -e " ${GREEN}✓${NC} Installation des outils essentiels (fail2ban, ufw, etc.)"
    echo -e " ${GREEN}✓${NC} Configuration du pare-feu et de la sécurité"
    echo -e " ${GREEN}✓${NC} Optimisation des performances système"
    echo -e " ${GREEN}✓${NC} Configuration des mises à jour automatiques"
    echo -e " ${GREEN}✓${NC} Mise en place d'outils de surveillance"
    echo ""
    echo -e "${RED}ATTENTION :${NC} Ce script peut modifier considérablement la configuration"
    echo "de votre serveur. Il est fortement recommandé de l'exécuter uniquement sur"
    echo "un serveur fraîchement installé pour éviter des conflits avec des"
    echo "configurations existantes."
    echo ""
    echo -e "${YELLOW}Si vous avez déjà configuré manuellement certains aspects du serveur"
    echo -e "(pare-feu, services, etc.), ce script pourrait écraser ces configurations.${NC}"
    echo ""
    read -p "Êtes-vous sûr de vouloir continuer ? (o/n) : " confirm
    if [[ ! "$confirm" =~ ^[Oo]$ ]]; then
        echo ""
        echo -e "${RED}Installation annulée.${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}Confirmation reçue. L'installation va commencer...${NC}"
    echo ""
    sleep 2
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

# Fonction pour vérifier si un paquet est installé
is_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# ====================== FONCTIONS PRINCIPALES ======================

# Fonction pour vérifier les droits d'administration
check_root() {
    section "VÉRIFICATION DES DROITS"
    
    if [ "$(id -u)" -ne 0 ]; then
        error "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
    
    success "Droits d'administration vérifiés"
}

# Fonction pour réparer les installations interrompues
repair_packages() {
    section "RÉPARATION DES PAQUETS"
    
    info "Réparation des installations interrompues..."
    dpkg --configure -a
    
    success "Réparation terminée"
}

# Fonction pour mettre à jour le système
update_system() {
    section "MISE À JOUR DU SYSTÈME"
    
    info "Mise à jour des listes de paquets..."
    apt-get update
    
    info "Mise à niveau des paquets installés..."
    apt-get upgrade -y
    
    info "Mise à niveau de la distribution..."
    apt-get dist-upgrade -y
    
    info "Suppression des paquets obsolètes..."
    apt-get autoremove -y
    
    info "Nettoyage du cache apt..."
    apt-get autoclean
    
    success "Système mis à jour avec succès"
}

# Fonction pour installer les outils essentiels
install_essential_tools() {
    section "INSTALLATION DES OUTILS ESSENTIELS"
    
    info "Installation des outils essentiels..."
    apt-get install -y \
        unattended-upgrades \
        apt-listchanges \
        fail2ban \
        ufw \
        htop \
        iotop \
        ncdu \
        tmux \
        net-tools \
        vim \
        curl \
        wget \
        git \
        logrotate \
        rsync \
        netcat-openbsd
    
    success "Outils essentiels installés"
}

# Fonction pour configurer les mises à jour automatiques
configure_auto_updates() {
    section "CONFIGURATION DES MISES À JOUR AUTOMATIQUES"
    
    info "Configuration des mises à jour automatiques..."
    dpkg-reconfigure --priority=low unattended-upgrades
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    success "Mises à jour automatiques configurées"
}

# Fonction pour configurer le DNS
configure_dns() {
    section "CONFIGURATION DNS"
    
    info "Configuration des serveurs DNS Google..."
    # Retirer l'attribut immutable s'il existe déjà
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
    # Rendre le fichier immuable pour éviter les modifications par le système
    chattr +i /etc/resolv.conf
    if [ $? -ne 0 ]; then
        error "Erreur lors du verrouillage du fichier /etc/resolv.conf"
        exit 1
    fi
    
    success "DNS configuré sur les serveurs Google et fichier verrouillé"
}

# Fonction pour configurer le pare-feu
configure_firewall() {
    section "CONFIGURATION DU PARE-FEU"
    
    info "Configuration du pare-feu..."
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw --force enable
    
    success "Pare-feu configuré et activé"
}

# Fonction pour configurer fail2ban
configure_fail2ban() {
    section "CONFIGURATION DE FAIL2BAN"
    
    info "Configuration de fail2ban..."
    systemctl enable fail2ban
    systemctl start fail2ban
    
    success "Fail2ban configuré et activé"
}

# Fonction pour optimiser les performances système
optimize_system() {
    section "OPTIMISATION DES PERFORMANCES"
    
    info "Optimisation des performances système..."
    cat > /etc/sysctl.d/99-sysctl.conf << EOF
# Optimisation mémoire
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Optimisation réseau
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
EOF
    sysctl -p /etc/sysctl.d/99-sysctl.conf
    
    info "Configuration des limites système..."
    cat > /etc/security/limits.d/99-limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF
    
    success "Performances système optimisées"
}

# Fonction pour configurer la rotation des logs
configure_logrotate() {
    section "CONFIGURATION DE LOGROTATE"
    
    info "Configuration de logrotate..."
    cat > /etc/logrotate.d/custom-logs << EOF
/var/log/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
EOF
    
    success "Logrotate configuré"
}

# Fonction pour créer un script de surveillance
create_monitoring_script() {
    section "CRÉATION DU SCRIPT DE SURVEILLANCE"
    
    info "Création d'un script de surveillance avancé..."
    cat > /usr/local/bin/server-status.sh << 'EOF'
#!/bin/bash

# ===================================================================
# ░██████╗███████╗██████╗░██╗░░░██╗███████╗██████╗░
# ██╔════╝██╔════╝██╔══██╗██║░░░██║██╔════╝██╔══██╗
# ╚█████╗░█████╗░░██████╔╝██║░░░██║█████╗░░██████╔╝
# ░╚═══██╗██╔══╝░░██╔══██╗╚██╗░██╔╝██╔══╝░░██╔══██╗
# ██████╔╝███████╗██║░░██║░╚████╔╝░███████╗██║░░██║
# ╚═════╝░╚══════╝╚═╝░░╚═╝░░╚═══╝░░╚══════╝╚═╝░░╚═╝
# Surveillance v1.0 | Créé par Romain Jolly Martoia
# Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF
# ===================================================================

# Couleurs pour améliorer la lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Pas de couleur

# Fonction pour afficher les en-têtes de section
print_header() {
    echo -e "\n${CYAN}===== $1 =====${NC}\n"
}

# Date et heure actuelles
echo -e "${PURPLE}RAPPORT DE SURVEILLANCE SERVEUR - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo "=============================================================="

# Vérification de l'uptime
print_header "UPTIME SYSTÈME"
uptime

# Vérification de la charge CPU
print_header "UTILISATION CPU"
echo -e "${BLUE}Charge moyenne:${NC}"
cat /proc/loadavg
echo

echo -e "${BLUE}Top 5 des processus par utilisation CPU:${NC}"
ps aux --sort=-%cpu | head -6

# Vérification de la mémoire
print_header "UTILISATION MÉMOIRE"
free -h

echo -e "\n${BLUE}Top 5 des processus par utilisation mémoire:${NC}"
ps aux --sort=-%mem | head -6

# Vérification de l'espace disque
print_header "UTILISATION DISQUE"
echo -e "${BLUE}Vue d'ensemble de l'espace disque:${NC}"
df -h | grep -v "tmpfs\|udev"

# Vérification des partitions critiques
ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$ROOT_USAGE" -gt 90 ]; then
    echo -e "${RED}ALERTE: Partition racine à $ROOT_USAGE% d'utilisation!${NC}"
elif [ "$ROOT_USAGE" -gt 80 ]; then
    echo -e "${YELLOW}ATTENTION: Partition racine à $ROOT_USAGE% d'utilisation.${NC}"
else
    echo -e "${GREEN}Partition racine à $ROOT_USAGE% d'utilisation.${NC}"
fi

# Vérification des inodes (souvent négligés)
echo -e "\n${BLUE}Utilisation des inodes:${NC}"
df -i | grep -v "tmpfs\|udev"

# Trouver les plus gros répertoires
echo -e "\n${BLUE}Les 5 plus gros répertoires dans /var:${NC}"
du -h /var --max-depth=1 2>/dev/null | sort -hr | head -5

# Vérification des connexions réseau
print_header "CONNEXIONS RÉSEAU"
echo -e "${BLUE}Ports en écoute:${NC}"
netstat -tulpn | grep LISTEN

echo -e "\n${BLUE}Nombre de connexions par état:${NC}"
netstat -an | awk '/tcp/ {print $6}' | sort | uniq -c

# Vérification des services critiques
print_header "SERVICES CRITIQUES"
for service in sshd fail2ban ufw nginx apache2 mysql postgresql docker; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "$service: ${GREEN}Actif${NC}"
    elif systemctl is-enabled --quiet $service 2>/dev/null; then
        echo -e "$service: ${YELLOW}Installé mais inactif${NC}"
    else
        echo -e "$service: ${RED}Non installé${NC}"
    fi
done

# Vérification des dernières connexions
print_header "DERNIÈRES CONNEXIONS"
last | head -5

# Vérification des tentatives d'accès échouées
print_header "TENTATIVES D'ACCÈS ÉCHOUÉES"
if [ -f /var/log/auth.log ]; then
    echo -e "${BLUE}Dernières tentatives de connexion échouées:${NC}"
    grep "Failed password" /var/log/auth.log | tail -5
fi

# Vérification des mises à jour disponibles
print_header "MISES À JOUR DISPONIBLES"
if [ -x "$(command -v apt)" ]; then
    echo -e "${BLUE}Nombre de mises à jour disponibles:${NC}"
    apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l
fi

# Résumé final
print_header "RÉSUMÉ DE SANTÉ DU SYSTÈME"
ISSUES=0

# Vérifier la charge CPU
LOAD=$(cat /proc/loadavg | awk '{print $1}')
CORES=$(nproc)
if (( $(echo "$LOAD > $CORES" | bc -l) )); then
    echo -e "${RED}[PROBLÈME] Charge CPU élevée: $LOAD (Nombre de cœurs: $CORES)${NC}"
    ISSUES=$((ISSUES+1))
fi

# Vérifier la mémoire
MEM_AVAIL=$(free | grep Mem | awk '{print $7}')
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_PERCENT=$((100 - MEM_AVAIL * 100 / MEM_TOTAL))
if [ "$MEM_PERCENT" -gt 90 ]; then
    echo -e "${RED}[PROBLÈME] Utilisation mémoire élevée: $MEM_PERCENT%${NC}"
    ISSUES=$((ISSUES+1))
fi

# Vérifier l'espace disque
if [ "$ROOT_USAGE" -gt 90 ]; then
    echo -e "${RED}[PROBLÈME] Espace disque faible sur /: $ROOT_USAGE%${NC}"
    ISSUES=$((ISSUES+1))
fi

# Afficher le statut global
if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}Aucun problème majeur détecté. Le système semble en bonne santé.${NC}"
else
    echo -e "${YELLOW}$ISSUES problème(s) détecté(s). Vérifiez les alertes ci-dessus.${NC}"
fi

echo -e "\n${PURPLE}Fin du rapport - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo "=============================================================="
EOF
    chmod +x /usr/local/bin/server-status.sh
    
    # Créer un alias pour faciliter l'exécution
    echo "alias status='sudo /usr/local/bin/server-status.sh'" >> /etc/bash.bashrc
    
    # S'assurer que bc est installé (nécessaire pour les calculs)
    if ! command -v bc &> /dev/null; then
        apt-get install -y bc
    fi
    
    success "Script de surveillance avancé créé"
    info "Vous pouvez l'exécuter avec la commande 'status' après redémarrage ou en tapant '/usr/local/bin/server-status.sh'"
}

# ====================== EXÉCUTION PRINCIPALE ======================

main() {
    # Afficher la bannière
    echo -e "${CYAN}"
    echo "░██████╗███████╗██████╗░██╗░░░██╗███████╗██████╗░"
    echo "██╔════╝██╔════╝██╔══██╗██║░░░██║██╔════╝██╔══██╗"
    echo "╚█████╗░█████╗░░██████╔╝██║░░░██║█████╗░░██████╔╝"
    echo "░╚═══██╗██╔══╝░░██╔══██╗╚██╗░██╔╝██╔══╝░░██╔══██╗"
    echo "██████╔╝███████╗██║░░██║░╚████╔╝░███████╗██║░░██║"
    echo "╚═════╝░╚══════╝╚═╝░░╚═╝░░╚═══╝░░╚══════╝╚═╝░░╚═╝"
    echo -e "${NC}"
    echo "Créé par Romain Jolly Martoia"
    echo "Rejoignez les solopreneurs 3.0 : https://discord.gg/4Nuvxxu5GF"
    echo "=============================================================="
    echo ""
    
    # Afficher l'avertissement et demander confirmation
    show_initial_warning

    # Journalisation
    LOG_FILE="/var/log/server_setup.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Script de préparation serveur exécuté le $(date)"
    
    # Vérifier les droits d'administration
    check_root
    
    # Réparer les installations interrompues
    repair_packages
    
    # Mettre à jour le système
    update_system
    
    # Installer les outils essentiels
    install_essential_tools
    
    # Configurer les mises à jour automatiques
    configure_auto_updates
    
    # Configurer le DNS
    configure_dns
    
    # Configurer le pare-feu
    configure_firewall
    
    # Configurer fail2ban
    configure_fail2ban
    
    # Optimiser les performances système
    optimize_system
    
    # Configurer la rotation des logs
    configure_logrotate
    
    # Créer un script de surveillance
    create_monitoring_script
    
    # Message final
    section "PRÉPARATION TERMINÉE"
    
    success "Préparation du serveur terminée avec succès !"
    warning "Un redémarrage est recommandé pour appliquer toutes les modifications."
    read -p "Voulez-vous redémarrer maintenant? (o/n) " reponse
    if [[ "$reponse" =~ ^[Oo]$ ]]; then
        info "Redémarrage du serveur..."
        shutdown -r now
    else
        info "N'oubliez pas de redémarrer le serveur plus tard pour appliquer toutes les modifications."
    fi
}

# Exécuter la fonction principale
main
