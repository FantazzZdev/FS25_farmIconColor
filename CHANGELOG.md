# Changelog

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions = `<version>` de `modDesc.xml`.

## [Non publie] - 1.1.0.0
### Ajoute
- Import de logos personnalises (DDS) depuis `modSettings/FS25_farmIconColor/customLogos/` (touche INSERT ou bouton Importer, admin uniquement).
- Logos partages par le serveur : l'admin importe un paquet `.xml` (cree avec le convertisseur `tools/logo-converter`), le serveur le verifie, l'enregistre dans la sauvegarde (`savegameX/farmIconColorLogos.xml`) et l'envoie automatiquement a tous les joueurs, y compris ceux qui se connectent plus tard. Fonctionne en solo, en multi auto-heberge et sur serveur dedie.
- Grille de selection des logos : vrai dialogue FS25 (profils natifs du jeu, `gui/logoPickerDialog.xml`), ouvert par le bouton **Logos** (touche L, insere dans la rangee native des boutons, a gauche de Couleur, alignement a droite comme le jeu) ou un clic sur le logo dans la fenetre de ferme. 4 logos par ligne (SmoothList native), defilement molette + curseur, logos sans nom (image seule), clic pour choisir, double-clic / Entree (Valider) pour appliquer, Echap (Retour) pour fermer. Boutons de gauche a droite : Importer, Supprimer, Retour, Valider. Logos integres et personnalises dans la meme liste. La ligne "Logo de la ferme" (fleches gauche/droite) de la fenetre de ferme est retiree, remplacee par la grille ; le pave numerique 4/6 reste disponible.
- Fenetre des logos (admin) : boutons **Importer** (INSER) et **Supprimer** (SUPPR, confirmation en deux appuis). Supprimer retire un logo partage pour tous les joueurs (les fermes qui l'utilisaient reprennent un autre logo) ; le fichier reste ignore tant que d'autres logos sont importes ; un Import qui ne trouve rien de nouveau restaure les logos supprimes encore presents dans le dossier. Le bouton Importer a ete retire de la fenetre de ferme : le bouton **Logos** prend sa place.
- Noms des logos integres traduits (FR/EN/DE) dans la grille et le selecteur.
- Convertisseur de logos : un seul fichier `converter/FarmIconColor-LogoConverter.html` a telecharger depuis GitHub (pas d'hebergement), en francais, anglais et allemand (langue du navigateur, choix FR/EN/DE memorise), fonctionne hors ligne. PNG/JPG/WEBP/SVG/DDS -> paquet `.xml` (DDS 256x256 DXT5 avec mipmaps), option "rendre le logo blanc".
- Description du mod : lien vers le GitHub (remarques, suggestions, bugs, telechargement du convertisseur).

- Logos en couleurs : un logo converti sans l'option "Rendre le logo blanc" garde ses propres couleurs (grille, fenetre de ferme, menus). La couleur de ferme continue de s'appliquer au reste (carte, marqueurs) et aux logos blancs/integres. L'information voyage avec le logo partage (serveur, sauvegarde, tous les joueurs).

### Corrige
- Barre de separation entre Logos et Couleur : elle etait masquee (ainsi que, par moments, le bouton Logos) par le code qui cache les controles de couleur d'origine, car son image est `gui.colorPreset` et le nom du bouton contient "Color".
- Import : des logos supprimes puis remis dans `customLogos/` etaient ignores sans message visible. Ils sont maintenant restaures par un Import qui ne trouve rien de nouveau ; message "Aucun nouveau logo" quand il n'y a vraiment rien.
- Conformite TestRunner GIANTS 0.9.24 : plus aucun `pcall` (les erreurs ne sont plus cachees du log). Les appels proteges ont ete remplaces par des verifications explicites ; signatures FS25 respectees (`setImageColor(state, r, g, b, a)`, `MapHotspot:setColor(r, g, b)`), suppression des appels a des methodes inexistantes en FS25. `descVersion` 116, changelog dans la description.
- Multijoueur (serveur dedie) : un logo que le serveur ne connait pas (fichier `.dds` brut, ou envoi non confirme) n'est plus proposable dans la grille d'un client, car le choisir etait refuse et la ferme reprenait son ancien logo. L'admin est prevenu : `.dds` non partage (a convertir en `.xml`), confirmation "Logo partage" quand le serveur l'a recu, ou alerte si le serveur ne l'a pas accepte apres 20 s.
- Securite multijoueur : le serveur n'accepte un changement de couleur/logo que de l'admin ou d'un membre de la ferme concernee ; sinon il renvoie les vraies valeurs au joueur.
- Les couleurs/logos sont de nouveau enregistres DANS la sauvegarde (`savegameX/farmIconColor.xml`, comme en 1.0), au moment ou le jeu sauvegarde. Une nouvelle partie n'herite plus des reglages d'une ancienne partie du meme emplacement. Les donnees des builds 1.1 de developpement (modSettings) sont migrees automatiquement.
- Pave numerique 4/6 et INSER ne changent plus le logo / ne lancent plus l'import pendant la saisie du nom ou du mot de passe de la ferme.

### Retire
- Diagnostic experimental `DDS-ROUNDTRIP` (corrompait l'affichage du premier logo personnalise et ecrivait dans log.txt).

## 1.0.x - Version ModHub
- Version publiee : https://www.farming-simulator.com/mod.php?mod_id=366058
