# Revue du code - FS25_farmIconColor 1.1.0.0-dev

Fichier analysé : `mod/scripts/farmIconColor.lua` (7 722 lignes à la réception, un seul fichier, ~330 fonctions).
La syntaxe Lua est valide (contrôlée avec LuaJIT, le même moteur Lua que FS25) et les deux XML sont valides.
Il n'y a aucune erreur de syntaxe. Les problèmes listés ci-dessous sont des problèmes de **logique**, de **sécurité** ou d'**architecture**.

Légende : ✅ corrigé dans ce dépôt · 🔴 critique · 🟠 important · 🟡 mineur

---

## ✅ 1. Le diagnostic DDS-ROUNDTRIP corrompait le logo (cause de la capture d'écran)

`diagnoseCustomLogoEngineIOSupport()` était appelée à chaque import. Elle :
- écrivait `generatedLogos/<id>_roundtrip.dds` à partir de données BitVectorMap (qui ne sont pas les octets DXT5) ;
- **remplaçait** ensuite `self.logos[logoId]` par ce fichier corrompu (`self.logos[logoId] = outputPath`).

Le premier logo personnalisé (Domaine3Epis) s'affichait donc partout sous forme de bandes rouges et noires.
Elle faisait aussi des `print()` dans log.txt, ce que GIANTS refuse sur ModHub.
**Correction :** la fonction et son appel ont été supprimés, et les logos reprennent le DDS d'origine dans `customLogos/`.
Le fichier `modSettings/FS25_farmIconColor/generatedLogos/` peut être supprimé à la main, car il n'est plus utilisé.

## 🔴 2. Le serveur accepte n'importe quel changement de n'importe quel client

`FarmIconColorSyncEvent:run()` applique, sauvegarde et rediffuse l'événement **sans vérifier qui l'envoie**.
Un client modifié ou malveillant peut changer la couleur ou le logo de **toutes** les fermes.
Côté client, seul le menu vanilla limite l'accès, et le serveur ne vérifie rien.

**Correctif proposé :** côté serveur, récupérer l'utilisateur de la connexion
(`g_currentMission.userManager:getUserByConnection(connection)`). Accepter seulement s'il est
`getIsMasterUser()` ou gestionnaire de cette ferme. Ignorer aussi les `farmId` invalides et les chaînes trop longues.

## 🔴 3. Les réglages ne sont pas dans la sauvegarde

Les couleurs et logos sont enregistrés dans `modSettings/FS25_farmIconColor/savegame<N>.xml`, avec une clé basée sur le **numéro d'emplacement**. Conséquences :
- une **nouvelle partie** créée dans le même emplacement reprend les couleurs et logos de l'ancienne ;
- une sauvegarde copiée ailleurs (téléchargement VeryGames, autre PC, backup) **perd** la personnalisation ;
- sur serveur dédié, tout dépend du profil du serveur, pas de la sauvegarde.

**Correctif proposé (méthode standard des mods FS) :** greffer `FSCareerMissionInfo.saveToXMLFile`
(`Utils.appendedFunction`) pour écrire `farmIconColor.xml` **à la racine** du dossier de sauvegarde
(`missionInfo.savegameDirectory`). La passation indique que VeryGames conserve ce type de fichier.
Il faut lire ce fichier au chargement et garder l'ancien fichier modSettings uniquement pour migrer les anciennes données.

## 🟠 4. Synchronisation réseau : un nouveau joueur attend l'envoi périodique, et les clients recalculent toute l'interface toutes les 5 s

- Un joueur qui rejoint la partie reçoit les données seulement grâce à la diffusion périodique (toutes les 5 s).
- À chaque réception, `applyNetworkFarmVisual()` relance toute la mise à jour visuelle, même si rien n'a changé :
  parcours des arbres GUI, `forceApplyAllSavedFarmVisualColors`, etc.

**Correctif proposé :** envoyer l'état complet au joueur qui se connecte via `FSBaseMission.sendInitialClientState`.
Côté client, ignorer un événement identique au dernier reçu, puis supprimer l'envoi périodique ou l'espacer fortement.

## 🟠 5. Touches lues « en brut » au lieu des actions FS25

F9, INSERT et Pavé num. 4/6 sont lus avec `Input.isKeyPressed()` dans `update()`. Conséquences :
- les touches déclarées dans `modDesc.xml` ne peuvent pas être réassignées, car le code ne les utilise pas ;
- **Pavé num. 4/6 changent le logo pendant qu'on tape des chiffres** dans « Nom de la ferme » ou « Mot de passe » ;
- rien n'est prévu pour la manette.

**Correctif proposé :** utiliser `g_inputBinding:registerActionEvent` pour les actions du modDesc, et ignorer les touches quand un champ texte a le focus.

## 🟠 6. Fragilité face aux mises à jour GIANTS

Le mod dépend de nombreux noms internes de l'interface : profils `fs25_editFarmDialogFarmIcon`,
`elementFarmIdMap`, `pageFarm`, clonage du bouton Couleur, `mouseEvent` du dialogue, etc.
Tout passe par `pcall`/`safeCall`, qui **n'affiche rien** quand `DEBUG = false`.
Si un patch casse quelque chose, le mod arrête de fonctionner sans aucune trace.

**Correctif proposé :** écrire **un seul** avertissement par fonction en erreur (`Logging.warning`, une fois par session).
Cela reste conforme à ModHub, car il n'y a pas de spam, et un `log.txt` devient exploitable.

## 🟠 7. Coût par image

`update()` appelle une quinzaine de fonctions à chaque image. Plusieurs parcourent `g_gui.dialogs` et des arbres GUI
(profondeur 8, jusqu'à 300 nœuds) tant qu'un dialogue est ouvert, et la carte est rafraîchie toutes les 500 ms.
Ça passe sur un bon PC, mais il vaut mieux espacer ces appels (toutes les 100 à 250 ms) ou se brancher sur les ouvertures de dialogues.

## 🟡 8. Dette technique

- Un seul fichier de 7 400 lignes. À découper en `core`, `persistence`, `network`, `gui` et `customLogos`, via `extraSourceFiles`.
- Code mort à retirer :
  - inspecteur GUI F10 ;
  - overlays de sélecteur désactivés (`LOGO_SELECTOR_OVERLAY_ENABLED`, `NATIVE_LOGO_SELECTOR_TEXT_OVERLAY_ENABLED`, `drawFarmDialogLogoSelectorOverlay`, ...) ;
  - blocs `if ... then end` vides ;
  - `ensureTestLogos` ;
  - champs inutilisés (`customLogoPngDiagnosticDone`, `generatedCustomLogoPaths`) ;
  - entrée `cluster` dans `getLogoFallbackDisplayName`.
- Deux fichiers comme `Terra Pro.dds` et `terra_pro.dds` donnent le même ID : le second est ignoré sans message.
- Le nombre de logos personnalisés n'est pas limité.
- Si le dossier `customLogos` est inaccessible au moment du chargement, le logo personnalisé enregistré pour une ferme est perdu sans message.
- La description dans `modDesc.xml` ne mentionne pas encore l'import de logos (INSER / Importer).

---

## Ce qui est sain

- Les logos intégrés, la recoloration, le sélecteur ◀ ▶, l'import INSERT et le clic sur le bouton Importer
  sont bien isolés : rien dans les correctifs proposés n'oblige à y toucher.
- `FarmIconColor.DEBUG = false` et `debugPrint` : bonne approche pour un log propre.
- La migration depuis l'ancien emplacement de sauvegarde est déjà prévue.
