# Scripts d'Automatisation pour Serveurs Ubuntu

![Automatisation Serveur](https://img.shields.io/badge/Serveur-Automatisation-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange)
![Bash](https://img.shields.io/badge/Bash-Scripts-green)
![Licence](https://img.shields.io/badge/Licence-MIT-yellow)

Une collection de scripts bash puissants pour automatiser la configuration de serveurs Ubuntu, le déploiement de stacks IA, et la mise en place d'environnements de travail à distance.
Rejoignez notre communauté de solopreneurs pour obtenir du support, des mises à jour et faire passer votre business au niveau supérieur :

[![Discord](https://img.shields.io/badge/Discord-Rejoindre_la_Communauté-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/4Nuvxxu5GF)
## 📋 Vue d'ensemble

Ce dépôt contient trois scripts principaux pour différents besoins d'automatisation de serveurs :

1. **`config-ubuntu.sh`** - Configuration de base et renforcement de la sécurité d'un serveur Ubuntu
2. **`AI Stack/ai-stack-ubuntu.sh`** - Stack complète de développement IA avec n8n, PostgreSQL, Redis, et plus
3. **`ZeroWork Stack/zerowork-ubuntu.sh`** - Environnement de travail à distance avec interface graphique, RustDesk et agent ZeroWork

Chaque script est conçu pour fonctionner indépendamment et peut être exécuté sur une installation Ubuntu fraîche (20.04 LTS ou plus récente).

## 🚀 Fonctionnalités

### Configuration de Base (`config-ubuntu.sh`)
- Mises à jour système et gestion des paquets
- Outils de sécurité essentiels (fail2ban, UFW)
- Optimisation des performances
- Mises à jour de sécurité automatiques
- Outils de surveillance système

### Stack IA (`ai-stack-ubuntu.sh`)
- Environnement de développement complet avec :
  - Proxy inverse Traefik avec SSL automatique
  - Automatisation de flux de travail n8n
  - Base de données PostgreSQL
  - Cache Redis
  - Portainer pour la gestion des conteneurs
  - pgAdmin pour l'administration de la base de données
- Configuration sécurisée avec protection fail2ban
- Scripts de sauvegarde et de maintenance automatiques

### Stack ZeroWork (`zerowork-ubuntu.sh`)
- Environnement de bureau à distance avec :
  - Environnement de bureau XFCE
  - RustDesk pour l'accès à distance
  - Agent ZeroWork pour la gestion du travail à distance
  - Navigateur Google Chrome
- Connexion automatique et configuration de sécurité
- Protection fail2ban et pare-feu

## 📥 Installation

### Prérequis
- Serveur Ubuntu 20.04 LTS ou plus récent
- Accès root ou sudo
- Connexion Internet

Il vous faudra également un nom de domaine et faire pointer ces sous-somaines vers l'ip de votre VPS :
- traefik.votredomaine.com
- portainer.votredomaine.com
- n8n.votredomaine.com
- pgadmin.votredomaine.com
- redis.votredomaine.com


### Configuration de Base du Serveur

```bash
# Télécharger le script
wget https://raw.githubusercontent.com/RomainJM/ai-agency-stack/main/config-ubuntu.sh

# Le rendre exécutable
chmod +x config-ubuntu.sh

# Exécuter le script
sudo ./config-ubuntu.sh
```
### Stack de Développement IA

```bash
# Télécharger le script
wget https://raw.githubusercontent.com/RomainJM/ai-agency-stack/main/AI-Stack/ai-stack-ubuntu.sh

# Le rendre exécutable
chmod +x "AI Stack/ai-stack-ubuntu.sh"

# Exécuter le script
sudo ./ai-stack-ubuntu.sh
```

### Environnement à Distance ZeroWork
```bash
# Télécharger le script
wget https://raw.githubusercontent.com/RomainJM/ai-agency-stack/main/ZeroWork-Stack/zerowork-ubuntu.sh

# Le rendre exécutable
chmod +x "ZeroWork Stack/zerowork-ubuntu.sh"

# Exécuter le script
sudo ./zerowork-ubuntu.sh
```
## ⚙️ Options de Configuration
Chaque script vous demandera les options de configuration nécessaires pendant l'exécution. Les scripts sont conçus pour être interactifs et vous guideront tout au long du processus d'installation.
### Configuration de la Stack IA
- Nom de domaine pour les services
- Email pour les certificats Let's Encrypt
- Identifiants de base de données
- Noms d'utilisateur administrateur
### Configuration ZeroWork
- Nom d'utilisateur et mot de passe pour l'interface graphique
- Configuration de RustDesk
- Configuration de l'agent ZeroWork
## 🔒 Sécurité
Ces scripts mettent en œuvre plusieurs bonnes pratiques de sécurité :
- Fail2ban pour la protection contre les attaques par force brute
- Configuration du pare-feu UFW
- Génération de mots de passe sécurisés
- Mises à jour de sécurité automatiques
- Exposition limitée des services
## 📚 Documentation
Chaque script inclut des commentaires détaillés expliquant les fonctionnalités. De plus, les scripts génèrent des journaux complets et des fichiers d'identifiants qui fournissent des informations sur les composants installés.
Après l'installation, vous pouvez trouver :
- Les identifiants de la Stack IA dans `⁠~/ai-stack/credentials.txt`
- Les identifiants ZeroWork dans `⁠~/zerowork/credentials.txt`
## 🛠️ Maintenance
### Maintenance de la Stack IA
```bash
# Mettre à jour tous les conteneurs
cd ~/ai-stack && ./scripts/update.sh

# Sauvegarder la configuration et les données
cd ~/ai-stack && ./scripts/backup.sh

# Vérifier le statut de fail2ban
cd ~/ai-stack && ./fail2ban-manage.sh status
```
### Surveillance du Système
```bash
# Exécuter le script de surveillance
sudo /usr/local/bin/server-status.sh
```
## 🤝 Communauté et Support

Rejoignez notre communauté de solopreneurs pour obtenir du support, des mises à jour et participer aux discussions :

[![Discord](https://img.shields.io/badge/Discord-Rejoindre_la_Communauté-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/4Nuvxxu5GF)

⭐ Si vous trouvez ces scripts utiles, n'hésitez pas à mettre une étoile au dépôt !



