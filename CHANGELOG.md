# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions = `<version>` de `modDesc.xml`.

## [Non publie] - 1.1.0.0
### Ajoute
- Import de logos personnalises (DDS) depuis `modSettings/FS25_farmIconColor/customLogos/` (touche INSERT ou bouton Importer, admin uniquement).
- Logos partages par le serveur : l'admin importe un paquet `.xml` (cree avec le convertisseur `tools/logo-converter`), le serveur le verifie, l'enregistre dans la sauvegarde (`savegameX/farmIconColorLogos.xml`) et l'envoie automatiquement a tous les joueurs, y compris ceux qui se connectent plus tard. Fonctionne en solo, en multi auto-heberge et sur serveur dedie.
- Grille de selection des logos : vrai dialogue FS25 (profils natifs du jeu, `gui/logoPickerDialog.xml`), ouvert par le bouton **Logos** (touche L) ou un clic sur le logo dans la fenetre de ferme. 4 logos par ligne (SmoothList native), defilement molette + curseur, clic pour choisir, double-clic / Entree (Valider) pour appliquer, Echap (Retour) pour fermer. Logos integres et personnalises dans la meme liste. Les fleches gauche/droite restent disponibles.
- Noms des logos integres traduits (FR/EN/DE) dans la grille et le selecteur.
- Convertisseur en ligne : https://fantazzzdev.github.io/FS25_farmIconColor/
- Convertisseur de logos (page web hors ligne) : PNG/JPG/WEBP/SVG/DDS -> paquet `.xml` (DDS 256x256 DXT5 avec mipmaps), option "rendre le logo blanc".

### Corrige
- Securite multijoueur : le serveur n'accepte un changement de couleur/logo que de l'admin ou d'un membre de la ferme concernee ; sinon il renvoie les vraies valeurs au joueur.
- Les couleurs/logos sont de nouveau enregistres DANS la sauvegarde (`savegameX/farmIconColor.xml`, comme en 1.0), au moment ou le jeu sauvegarde. Une nouvelle partie n'herite plus des reglages d'une ancienne partie du meme emplacement. Les donnees des builds 1.1 de developpement (modSettings) sont migrees automatiquement.
- Pave numerique 4/6 et INSER ne changent plus le logo / ne lancent plus l'import pendant la saisie du nom ou du mot de passe de la ferme.

### Retire
- Diagnostic experimental `DDS-ROUNDTRIP` (corrompait l'affichage du premier logo personnalise et ecrivait dans log.txt).

## 1.0.x - Version ModHub
- Version publiee : https://www.farming-simulator.com/mod.php?mod_id=366058
