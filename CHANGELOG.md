# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions = `<version>` de `modDesc.xml`.

## [Non publie] - 1.1.0.0
### Ajoute
- Import de logos personnalises (DDS) depuis `modSettings/FS25_farmIconColor/customLogos/` (touche INSERT ou bouton Importer, admin uniquement).

### Corrige
- Securite multijoueur : le serveur n'accepte un changement de couleur/logo que de l'admin ou d'un membre de la ferme concernee ; sinon il renvoie les vraies valeurs au joueur.
- Les couleurs/logos sont de nouveau enregistres DANS la sauvegarde (`savegameX/farmIconColor.xml`, comme en 1.0), au moment ou le jeu sauvegarde. Une nouvelle partie n'herite plus des reglages d'une ancienne partie du meme emplacement. Les donnees des builds 1.1 de developpement (modSettings) sont migrees automatiquement.
- Pave numerique 4/6 et INSER ne changent plus le logo / ne lancent plus l'import pendant la saisie du nom ou du mot de passe de la ferme.

### Retire
- Diagnostic experimental `DDS-ROUNDTRIP` (corrompait l'affichage du premier logo personnalise et ecrivait dans log.txt).

## 1.0.x - Version ModHub
- Version publiee : https://www.farming-simulator.com/mod.php?mod_id=366058
