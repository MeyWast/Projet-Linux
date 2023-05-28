# Projet-Linux

L’objectif de ce projet est de mettre à profit les compétences que vous avez acquises durant
les cours-TP successifs dans un unique projet. Vous aurez aussi à utiliser des outils que vous
n’avez pas utilisé jusqu’à présent de manière autonome. Dans ce projet, vous devrez créer un
script de déploiement de comptes pour une liste d’utilisateurs.trices. qui est donné par un csv.

## Cahier des charges : 
### Installation de base 
- [] Création de compte pour chaque utilisateurs
    - [x] Les utilisateurs doivent changer leur mot de passe à la première connexion 
    - [x] chaque utilisateur doit avoir un home directory avec un fichier "a_sauver"
    - [x] Création d'un dossier "shared" appartenant à root 
    - [x] A l'intérieur du dossier shared, créer un dossier par utilisateur qui doit appartenir à ce dernier et avoir les droits d'éxécution et de lecture pour les autres et des droits en écriture pour le propriétaire
    - [] Un fois le compte crée, envoie de mail à chaque utilisateur avec son login, mot de passe

### Sauvegarde
- [x] Création d'un script de sauvegarde automatique de "a_sauver" sur le serveur distant tout les jours de la semaine à 23h
- [x] Création d'un script "retablir_sauvegarde" qui permet de restaurer la sauvegarde
- [x] Connexion avec clé ssh pour chacun des utilisateurs

### Eclipse
- [x] Installation d'eclipse en local pour chaque utilisateur

### Pare-feu
- [x] Installation d'un pare feu qui bloque toutes les connexion FTP et du protocole UDP

### Nextcloud
- [x] Installation de nextcloud sur le serveur distant avec compte administrateur

### Monitoring
- [] Installation d'outil de monitoring sur le serveur distant


