#!/bin/bash

# installation de sshpass
sudo apt-get install sshpass -y # je ne savais pas quel moyen utiliser pour me connecter en ssh donc j'ai utilisé sshpass qui demande le mot de passe pour que cela soit accessible à tous sans avoir de clé
# j'ai tout de même généré une clé ssh pour chaque utilisateur pour leur connexion comme demandé

# Chemin vers le fichier contenant les informations des utilisateurs
read -p 'Pour la lecture des informations des utilisateurs, veuillez indiquer le nom du fichier csv : ' fichier_utilisateurs

# Déclaration des variables
echo "Pour la connexion ssh, veuillez entrer vos informations :"
read -p "Adresse serveur ssh : " serverssh
read -p "login ssh : " loginssh
read -p "mot de passe ssh : " mdpssh

echo "Pour l'envoi du mail, veuillez entrer vos informations :"
read -p "Adresse serveur smtp : " serversmtp
read -p "login smtp : " loginsmtp
read -p "mot de passe smtp : " mdpsmtp
read -p "le port smtp :" port

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
    sudo mkdir "/home/shared/$utilisateur"

    # attribution des droits à l'utilisateur
    sudo chown $utilisateur "/home/shared/$utilisateur"
    sudo chmod 755 "/home/shared/$utilisateur"
    sudo chmod u+w "/home/shared/$utilisateur"

    # j'envoie un mail à l'utilisateur pour notifier la création de son compte
    # j'enleve le @ car ca marche pas sinon et je le remplace par %40
    mailsmtp=$(echo $loginsmtp | sed 's/@/%40/g')
    sshpass -p "$mdpssh" ssh "$loginssh"@"$serverssh" "mail --subject 
    \"
    Création de compte
    \"
     --exec 
    \"
    set sendmail=smtp://$mailsmtp:$mdpsmtp@$serversmtp:$port
    \" 
    --append \"
    From:$loginsmtp
    \" 
    $mail <<< 
    \"
    Bonjour $prenom $nom,
    je vous envoie ce mail pour vous informer que votre compte a bien été créé.
    Vous pouvez dès à présent vous connecter avec les informations suivantes :

    Nom d'utilisateur : $utilisateur
    Mot de passe : $mot_de_passe (ce dernier devra être modifié lors de la premiere connexion)
    Cordialement,
    \""

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
# je récupère la sauvegarde sur le serveur ssh
sudo scp -i /home/\$utilisateur/.ssh/id_rsa \$loginssh@\$serverssh:/home/saves/save_\$utilisateur.tgz /home/\$utilisateur/temp_save.tgz
# je supprime le dossier "a_sauver" de l'utilisateur pour le remplacer
sudo rm -rf /home/\$utilisateur/a_sauver
# je décompresse la sauvegarde dans le dossier "a_sauver" de l'utilisateur
tar -xzf /home/\$utilisateur/temp_save.tgz --directory=/home/\$utilisateur/a_sauver .
# je supprime la sauvegarde temporaire
sudo rm /home/\$utilisateur/temp_save.tgz
EOF

# Installation d'éclipse
sudo wget -P /home/ https://rhlx01.hs-esslingen.de/pub/Mirrors/eclipse/technology/epp/downloads/release/2023-03/R/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz
sudo tar -xzf /home/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz -C /usr/local/share

# je le copie dans le dossier bin pour pouvoir l'utiliser en tant que commande pour tt les utilisateurs
sudo ln -s /usr/local/share/eclipse/eclipse /usr/local/bin/eclipse
sudo rm /home/eclipse-java-2023-03-R-linux-gtk-x86_64.tar.gz

# Configuration pare feu
iptables -A INPUT -p tcp --dport 21 -j DROP
iptables -A OUTPUT -p tcp --dport 21 -j DROP
iptables -A INPUT -p udp -j DROP
iptables -A OUTPUT -p udp -j DROP

# script Déploiement nextcloud
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

    # Suppression du script de surveillance
    rm script_monitoring.sh
EOF

