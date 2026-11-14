# FS25 Farm Icon Color

Mod Farming Simulator 25 : couleur et logo personnalises pour chaque ferme (menus, liste des fermes, carte, hotspots, terrains).

- Auteur : Equinox
- ModHub : https://www.farming-simulator.com/mod.php?mod_id=366058
- Version en developpement : voir `mod/modDesc.xml` et [CHANGELOG.md](CHANGELOG.md)

## Organisation du depot

```
mod/                    contenu EXACT du ZIP (modDesc.xml a la racine)
  modDesc.xml
  scripts/farmIconColor.lua      logique principale (couleurs, logos, menus, sync couleur/logo)
  scripts/customLogoSync.lua     partage des logos personnalises (catalogue serveur + transfert reseau)
  scripts/logoPicker.lua         grille de selection des logos (bouton Logos / touche L)
  xml/farmIconColor.xml  liste/ordre des logos integres
  textures/*.dds         logos integres (256x256, blanc, fond transparent, DXT5)
docs/
  ANALYSIS.md            revue du code (bugs, risques, dette technique)
  ARCHITECTURE-logos-serveur.md  plan de la synchro des logos personnalises
  HANDOFF.txt    passation d'origine (historique des tests)
tools/
  build.ps1 / build.sh   fabrique dist/FS25_farmIconColor.zip (+ dist/convertisseur-logos.html avec build.sh)
  logo-converter/        convertisseur image -> paquet logo .xml (page web hors ligne)
.github/                 CI (verif syntaxe + ZIP telechargeable), modeles d'issue/PR
```

## Construire le ZIP

Windows (PowerShell, a la racine du depot) :

```powershell
./tools/build.ps1            # -> dist/FS25_farmIconColor.zip
./tools/build.ps1 -Install   # + copie dans Documents/My Games/FarmingSimulator2025/mods
```

Chaque push sur GitHub construit aussi le ZIP automatiquement (onglet **Actions** -> artefact `FS25_farmIconColor`).

## Workflow de developpement

1. Une branche par fonctionnalite (`feature/...`, `fix/...`).
2. Commits petits et testables ; tester en jeu (solo + multi) avant de fusionner.
3. `FarmIconColor.DEBUG = false` et aucun `print()` dans une version publiee (exigence GIANTS ModHub, verifiee par la CI).
4. Pour une publication : monter `<version>` dans `modDesc.xml`, completer `CHANGELOG.md`, creer un tag `v1.x.x.x` et une Release GitHub avec le ZIP.

## Logos personnalises (version 1.1)

1. Ouvrir le convertisseur en ligne : **https://fantazzzdev.github.io/FS25_farmIconColor/** (ou hors ligne : `dist/convertisseur-logos.html` apres un build), y deposer une image (PNG, JPG, SVG, DDS) et telecharger le `.xml`.
2. Placer le `.xml` dans `Documents/My Games/FarmingSimulator2025/modSettings/FS25_farmIconColor/customLogos/`.
3. En jeu, en tant qu'admin, dans la fenetre de modification de ferme : **Logos** (L), puis **Importer** (INSER). Un logo qui ne convient pas se retire avec **Supprimer** (SUPPR, deux appuis).

Le logo est envoye au serveur, enregistre dans la sauvegarde et transmis a tous les joueurs. Un simple `.dds` depose dans le meme dossier reste utilisable, mais uniquement sur ton PC.
Details techniques : `docs/ARCHITECTURE-logos-serveur.md`.
