#!/bin/bash

# Chemin vers le fichier contenant les informations des utilisateurs
fichier_utilisateurs="accounts.csv"

# Vérification si le fichier existe
if [ ! -f "$fichier_utilisateurs" ]; then
    echo "Le fichier $fichier_utilisateurs n'existe pas."
    exit 1
fi

# Lecture du fichier utilisateur ligne par ligne
while IFS=',' read -r nom prenom mail mot_de_passe _; do
    # Création du nom d'utilisateur en utilisant la première lettre du prénom et le nom complet
    utilisateur="${prenom:0:1}${nom}"

    # Création de l'utilisateur avec le mot de passe spécifié
    sudo useradd -m -d "/home/$utilisateur" -p "$(openssl passwd -1 "$mot_de_passe")" -s /bin/bash "$utilisateur"
    
    # Désactivation du compte utilisateur pour qu'il soit obligé de changer son mot de passe à la première connexion
    sudo chage -d 0 "$utilisateur"
    
done < "$fichier_utilisateurs"