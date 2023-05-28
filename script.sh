#!/bin/bash

# installation de sshpass
sudo apt-get install sshpass -y

# Chemin vers le fichier contenant les informations des utilisateurs
read -p 'Pour la lecture des informations des utilisateurs, veuillez indiquer le nom du fichier csv : ' fichier_utilisateurs

echo "Pour la connexion ssh, veuillez entrer vos informations :"
read -p "Adresse serveur ssh : " serverssh
read -p "login ssh : " loginssh
read -p "mot de passe ssh : " mdpssh

echo "Pour l'envoi du mail, veuillez entrer vos informations :"
read -p "Adresse serveur smtp : " serversmtp
read -p "login smtp : " loginsmtp
read -p "mot de passe smtp : " mdpsmtp
read -p "le port smtp :" port

read -p "Pour l'utilisation de nextcloud, veuillez entrer vos version de mysql : " versionmysql

# Vérification si le fichier existe
if [ ! -f "$fichier_utilisateurs" ]; then
    echo "Le fichier $fichier_utilisateurs n'existe pas."
    exit 1
fi

# Connexion ssh puis création du dossier "saves"
    sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" "mkdir /home/saves"

# Lecture du fichier utilisateur ligne par ligne
while IFS=',' read -r nom prenom mail mot_de_passe _; do
    # Création du nom d'utilisateur en utilisant la première lettre du prénom et le nom complet
    utilisateur="${prenom:0:1}${nom}"

    # Création de l'utilisateur avec le mot de passe spécifié
    sudo useradd -m -d "/home/$utilisateur" -p "$(openssl passwd -1 "$mot_de_passe")" -s /bin/bash "$utilisateur"
    
    # Désactivation du compte utilisateur pour qu'il soit obligé de changer son mot de passe à la première connexion
    sudo chage -d 0 "$utilisateur"

    # Création du dossier "a_sauver" dans le dossier home de l'utilisateur
    sudo mkdir "/home/$utilisateur/a_sauver"

    # Création du dossier de l'utilisateur dans le dossier "shared" en local
    dossier_utilisateur="$dossier_shared/$utilisateur"
    sudo mkdir "$dossier_utilisateur"
    sudo chown $utilisateur "$dossier_utilisateur"
    sudo chmod 755 "$dossier_utilisateur"
    sudo chmod u+w "$dossier_utilisateur"

    # insertion d'une clé ssh pour chaque utilisateur
    sudo mkdir "/home/$utilisateur/.ssh"
    sudo ssh-keygen -f "/home/$utilisateur/.ssh/id_rsa" -N ""
    sudo ssh-copy-id -i /home/$utilisateur/.ssh/id_rsa.pub "$loginssh"@"$serverssh"
   
    # création d'utilisateur nextcloud
    sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" /snap/bin/nextcloud.occ user:add --display-name="$prenom $nom" $utilisateur
    sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" /snap/bin/nextcloud.occ user:setting $utilisateur password "$mot_de_passe"

done < "$fichier_utilisateurs"


# Création d'un script pour automatiser la sauvegarde que j'envoie sur le serveur ssh 
cat <<EOF > script_cron.sh
#!/bin/bash
dossier_sauvegarde=$(ls /home/shared)
for dossier in \$dossier_sauvegarde; do
    sudo tar -czf "/home/\$(basename \$dossier)/save_\$(basename \$dossier).tgz" --directory="/home/\$(basename \$dossier)/a_sauver" .
    sudo sshpass -p "\$mdpssh" scp -r "/home/\$utilisateur/a_sauver" "\$loginssh@\$serverssh":/home/"\$login"/saves/"save_\$utilisateur".tgz
    sudo rm "/home/\$(basename \$dossier)/save_\$(basename \$dossier).tgz"
done
EOF

# j'applique une tâche cron sur le script tout les jours de la semaine à 23h
(crontab -l; echo "0 23 * * 1-5 script_cron.sh") | crontab -

# Création d'un script "retablir_sauvegarde" qui permet de restaurer la sauvegarde
cat <<EOF > /home/retablir_sauvegarde.sh
#!/bin/bash
utilisateur= \$(whoami)
sudo scp -i /home/\$utilisateur/.ssh/id_rsa \$loginssh@\$serverssh:/home/saves/save_\$utilisateur.tgz /home/\$utilisateur/temp_save.tgz
sudo rm -rf /home/\$utilisateur/a_sauver
tar -xzf /home/\$utilisateur/temp_save.tgz --directory=/home/\$utilisateur/a_sauver .
sudo rm /home/\$utilisateur/temp_save.tgz
EOF

# Installation d'éclipse
sudo wget -P /home/ https://rhlx01.hs-esslingen.de/pub/Mirrors/eclipse/technology/epp/downloads/release/2023-03/R/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz
sudo tar -xzf /home/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz -C /usr/local/share
sudo ln -s /usr/local/share/eclipse/eclipse /usr/local/bin/eclipse
sudo rm /home/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz

# Configuration pare feu
iptables -A INPUT -p tcp --dport 21 -j DROP
iptables -A OUTPUT -p tcp --dport 21 -j DROP

iptables -A INPUT -p udp --dport 0:65535 -j DROP
iptables -A OUTPUT -p udp -j DROP

# Déploiement nextcloud
touch deploiement_nextcloud.sh
cat <<EOF > deploiement_nextcloud.sh
#!/bin/bash
utilisateur= \$(whoami)
sudo ssh -i /home/\$utilisateur/.ssh/id_rsa "\$loginssh"@"\$serverssh" -N -L 4242:localhost:80
EOF

# Installation nextcloud
sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" apt-get install snapd -y
sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" snap install nextcloud
sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" /snap/bin/nextcloud.manual-install "nextcloud-admin" "N3x+_Cl0uD"

# Monitoring
sudo sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" << EOF
    # Création du script de surveillance
    cat << 'SCRIPT' > /home/\$loginssh/script_monitoring.sh
        #!/bin/bash
        date=\$(date +"%d-%m-%Y %T")
        utilisation_cpu=\$(top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}')
        utilisation_memoire=\$(free | awk '/Mem/ {printf("%.2f"), $3/$2 * 100}')
        utilisation_reseau=\$(ifstat | awk 'NR==3 {print $1}')
        echo "Jour du rapport : \$date ; Utilisation CPU: \$utilisation_cpu % ; Utilisation Memoire: \$utilisation_memoire % ; Utilisation Network: \$utilisation_reseau %" >> rapport.log
    SCRIPT

    # Configuration de la tâche cron
    (crontab -l ; echo '* * * * 1-5 /home/\$loginssh/script_monitoring.sh') | crontab -

    # Nettoyage des fichiers temporaires
    rm script_monitoring.sh
EOF
