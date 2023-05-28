#!/bin/bash

# installation de sshpass
sudo apt-get install sshpass -y

# Chemin vers le fichier contenant les informations des utilisateurs
read -p 'Pour la lecture des informations des utilisateurs, veuillez indiquer le nom du fichier csv : ' fichier_utilisateurs

# Vérification si le fichier existe
if [ ! -f "$fichier_utilisateurs" ]; then
    echo "Le fichier $fichier_utilisateurs n'existe pas."
    exit 1
fi

# Connexion ssh puis création du dossier "saves"
    sudo sshpass -p "$mdp" ssh "$login"@"$server" "mkdir /home/saves"

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
    
done < "$fichier_utilisateurs"


# Création d'un script pour automatiser la sauvegarde que j'envoie sur le serveur ssh 
cat <<EOF > script_cron
#!/bin/bash
dossier_sauvegarde=$(ls /home/shared)
for dossier in \$dossier_sauvegarde; do
    sudo tar -czf "/home/\$(basename \$dossier)/save_\$(basename \$dossier).tgz" --directory="/home/\$(basename \$dossier)/a_sauver" .
    sudo sshpass -p "\$mdp" scp -r "/home/\$utilisateur/a_sauver" "\$login@\$server":/home/"\$login"/saves/"save_\$utilisateur".tgz
    sudo rm "/home/\$(basename \$dossier)/save_\$(basename \$dossier).tgz"
done
EOF

# j'applique une tâche cron sur le script tout les jours de la semaine à 23h
(crontab -l; echo "0 23 * * 1-5 script_cron") | crontab -

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
iptables -A INPUT -p tcp --dport 0:65535 -j DROP
iptables -A INPUT -p udp --dport 0:65535 -j DROP
