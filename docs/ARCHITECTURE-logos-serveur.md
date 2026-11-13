# Logos personnalisés partagés par le serveur - architecture proposée

## Constat (tests de la passation)

| Capacité | Résultat |
|---|---|
| Lire les octets d'un `.dds` en Lua (`io.open`, `createFile READ`, BitVectorMap) | ❌ impossible |
| **Écrire** un fichier binaire (`createFile WRITE` + `fileWrite`) | ✅ déjà constaté : FS25 a chargé un DDS de 65 664 octets écrit par le mod |
| Lire du texte dans un XML (`loadXMLFile` / `getXMLString`) | ✅ utilisé partout dans le mod |
| Transmettre des chaînes sur le réseau (`streamWriteString`) | ✅ utilisé par `FarmIconColorSyncEvent` |

Un fichier binaire ne peut pas être lu. En revanche, un XML se lit, un fichier binaire s'écrit et une chaîne se transmet.
**Il suffit donc que le logo arrive au mod sous forme de texte (Base64 dans un XML).** Tout le reste devient possible avec des API déjà vérifiées.

Je déconseille de poursuivre les essais sur BitVectorMap : ce n'est pas un lecteur d'image,
et une erreur dans cette voie peut faire planter le jeu entier (cas de `readBitVectorMapFromStream`).

## Format « paquet de logo »

`customLogos/TerraPro.xml` :

```xml
<farmIconColorLogo version="1">
    <logo id="terrapro" name="TerraPro" width="256" height="256"
          format="dds" bytes="87536" checksum="adler32:1a2b3c4d" tintable="true">
        <data>RERTIHwAAAAH...  (DDS original encodé en Base64)</data>
    </logo>
</farmIconColorLogo>
```

- `data` contient **le DDS original, sans aucune modification**, encodé en Base64 (environ 117 Ko pour un logo 256×256 en DXT5).
- `tintable` indique si le logo est blanc (recolorable) ou en couleurs. Le convertisseur le calcule, ce qui prépare l'évolution n°15.

## Convertisseur (hors jeu, une seule étape pour l'admin)

Une page web statique, hébergée gratuitement sur GitHub Pages, dans `tools/logo-converter/` :
1. l'admin glisse son fichier `MonLogo.dds` (ou un `.png`, converti en DDS par la page) ;
2. la page télécharge `MonLogo.xml` ;
3. l'admin dépose ce `.xml` dans `customLogos/` puis clique **Importer**, comme aujourd'hui.

Le parcours actuel « je dépose, je clique Importer » est conservé. Le `.dds` brut reste accepté pour un usage local, sans partage.

## Flux réseau

```
ADMIN (client ou hôte)                       SERVEUR                              CLIENTS
customLogos/X.xml --Importer-->
  lit Base64 + vérifie checksum
  UploadBegin/Chunk*/End  ─────────────►  vérifie : master user, taille ≤ 256 Ko,
  (8 Ko par chunk)                         nb logos ≤ 64, ordre des chunks, checksum
                                           enregistre dans le catalogue
                                           écrit savegameN/farmIconColorLogos.xml
                                           Manifest(id, nom, ordre, checksum) ─────►  compare avec son cache
                                                                    ◄───── Request(ids manquants)
                                           Begin/Chunk*/End  ──────────────────────►  décode Base64, vérifie checksum
                                                                                     écrit modSettings/.../cache/<checksum>.dds
                                                                                     self.logos[id] = ce fichier
NOUVEAU JOUEUR : FSBaseMission.sendInitialClientState → Manifest → même chemin.
```

- **Persistance :** le catalogue est stocké dans `farmIconColorLogos.xml` à la racine de la sauvegarde
  (VeryGames conserve ces fichiers). Il est réécrit au moment de la sauvegarde du jeu (`FSCareerMissionInfo.saveToXMLFile`).
  L'ordre définitif est celui du catalogue, et non plus celui du tri des noms de fichiers.
- **Cache client :** les fichiers sont nommés selon leur checksum, donc un logo déjà reçu n'est jamais retéléchargé.
- **Synchronisation existante :** `FarmIconColorSyncEvent` (farmId, couleur, nom du logo) reste **inchangé**.
  Un logo reçu porte simplement le même ID chez tout le monde.
- **Isolation :** tout le nouveau code va dans un fichier séparé, `scripts/customLogoSync.lua`.
  Les fonctions d'interface et d'import validées ne sont pas modifiées.

## Tests préalables (courts, sans risque de plantage)

Avant d'écrire la synchronisation, deux tests de 5 minutes permettent de valider les deux hypothèses restantes :

- **Test A - écriture binaire.** Le mod génère en Lua un DDS 256×256 non compressé à 4 quadrants de couleur
  (rouge, vert, bleu, transparent) et l'affiche comme logo. Si les 4 quadrants s'affichent correctement,
  `fileWrite` écrit fidèlement les octets, y compris les octets nuls.
- **Test B - lecture XML volumineuse.** Le mod lit un `<data>` Base64 de ~120 Ko avec `getXMLString`,
  le décode, compare le checksum et écrit le résultat en `.dds`. Si le logo s'affiche, toute la chaîne est validée.

Chaque test écrit une seule ligne `[FS25_farmIconColor][TEST-A]` ou `[TEST-B] OK/FAIL` dans log.txt, puis il est retiré du code.

## Alternatives écartées

- Lire le DDS directement : toutes les API testées échouent (voir la passation, §7).
- Mod « pack de logos » distribué par le serveur : en général, les clients ne peuvent télécharger automatiquement depuis un serveur que les mods ModHub.
- FTP : non disponible pour l'utilisateur sur VeryGames.
