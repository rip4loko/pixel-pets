# Pixel Pets — installation gratuite (sans Mac)

## 1. Compiler l'app avec GitHub (une seule fois, ~10 min)
1. Crée un compte sur github.com.
2. Clique **New repository**, nomme-le `pixel-pets`, laisse-le **Public** (les Mac de GitHub sont gratuits pour les projets publics), puis **Create repository**.
3. Clique **uploading an existing file** et glisse **tout le contenu** de ce dossier. Le dossier `.github` doit être inclus. S'il n'apparaît pas dans l'Explorateur Windows : Affichage › Afficher › Éléments masqués.
4. Clique **Commit changes**.
5. Va dans l'onglet **Actions**. La compilation « Build IPA » démarre toute seule et dure environ 5 à 10 min.
6. Quand c'est vert ✅, clique dessus. En bas, sous **Artifacts**, télécharge **PixelPets-ipa**. Dézippe-le pour obtenir **PixelPets.ipa**.
   Si c'est rouge ❌, copie-colle l'erreur à Claude pour qu'il la corrige.

## 2. Installer sur l'iPhone avec Sideloadly (Windows)
1. Installe **iTunes** et **iCloud** depuis le site d'Apple, pas depuis le Microsoft Store (Sideloadly en a besoin).
2. Installe **Sideloadly** (sideloadly.io).
3. Branche ton iPhone en USB, puis déverrouille-le et appuie sur « Faire confiance ».
4. Dans Sideloadly, glisse **PixelPets.ipa**, entre ton Apple ID (un compte gratuit suffit) et clique **Start**.
5. Sur l'iPhone :
   - Réglages › Confidentialité et sécurité › **Mode développeur** › activer (l'iPhone redémarre).
   - Réglages › Général › **VPN et gestion de l'appareil** › ton Apple ID › **Faire confiance**.

## 3. Utiliser
- Ouvre Pixel Pets : le défilé démarre tout seul, à un endroit au hasard.
- Île compacte : les persos passent d'un côté à l'autre, derrière la caméra.
- Appui long sur l'île ou écran verrouillé : une bande où toute la troupe défile.
- iOS retire le défilé après environ 8 h. Rouvrir l'app le relance.

## Comment ça marche (pour Claude)
Une Live Activity ne peut pas s'animer librement. Le seul élément qui bouge tout seul est un minuteur système. `tools/make_fonts.py` fabrique des polices où chaque texte « mm:ss » est remplacé par une image du défilé : le minuteur devient un film d'1 h à 1 image/seconde. Après un changement de persos dans `Shared/PetData.swift`, relancer `python3 tools/make_fonts.py` (il faut `pip install fonttools pillow`).

## Chaque semaine
Avec un compte gratuit, l'app expire après **7 jours**. Rebranche l'iPhone et refais « Start » dans Sideloadly. Tu peux aussi activer le rafraîchissement automatique de Sideloadly.
