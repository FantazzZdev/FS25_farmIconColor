# Mise à jour ModHub – version 1.1.0.0

## 1. Fichier à envoyer

`FS25_farmIconColor.zip`, avec `modDesc.xml` à la racine et la version `1.1.0.0`.
La description du `modDesc.xml` (FR/EN/DE) est à jour : c'est elle qu'affiche ModHub.

## 2. Changelog (champ « Changelog » du formulaire d'upload)

### Français
```
Version 1.1.0.0
- Nouvelle fenêtre des logos : grille de logos ouverte avec le bouton Logos (L) ou un clic sur le logo.
- Logos personnalisés : importez vos propres logos (admin). Ils sont enregistrés dans la sauvegarde et envoyés automatiquement à tous les joueurs, serveurs dédiés compris.
- Les logos en couleurs gardent leurs couleurs ; les logos blancs prennent la couleur de la ferme.
- Suppression d'un logo personnalisé pour tous les joueurs (admin).
- Les couleurs et logos sont de nouveau enregistrés dans la sauvegarde.
- Multijoueur : seuls l'admin et les membres d'une ferme peuvent modifier sa couleur et son logo.
- Les raccourcis ne se déclenchent plus pendant la saisie du nom ou du mot de passe de la ferme.
- L'ancienne ligne de sélection du logo a été remplacée par la fenêtre des logos.
```

### English
```
Version 1.1.0.0
- New logo window: a grid of logos opened with the Logos button (L) or by clicking the logo.
- Custom logos: import your own logos (admin). They are saved in the savegame and sent automatically to every player, dedicated servers included.
- Coloured logos keep their own colours; white logos take the farm colour.
- Delete a custom logo for every player (admin).
- Colours and logos are saved in the savegame again.
- Multiplayer: only the admin and the farm members can change a farm's colour and logo.
- Shortcuts no longer trigger while typing the farm name or password.
- The old logo selector row has been replaced by the logo window.
```

## 3. Captures d'écran à refaire (16:9, 1920×1080, sans HUD de debug)

| # | Capture | Ce qu'elle montre |
|---|---------|-------------------|
| 1 | Aperçu multijoueur avec 3–4 fermes aux logos et couleurs différents | Le résultat final, en image principale |
| 2 | Fenêtre des logos (grille), avec logos intégrés et personnalisés | La nouvelle fenêtre |
| 3 | Fenêtre de modification de ferme : logo en couleurs, boutons Logos / Couleur / Retour / Confirmer | Le bouton Logos dans la rangée native |
| 4 | Même ferme avec un logo blanc teinté dans la couleur de la ferme | Différence entre logo blanc et logo en couleurs |
| 5 | Carte avec les champs et repères aux couleurs des fermes | La couleur appliquée sur la carte |
| 6 | Sélecteur de couleur (Couleur / F9) | La personnalisation de la couleur |

Conseils : une partie propre (argent normal, pas de mods qui se voient à l'écran), des noms de ferme lisibles et des couleurs bien différentes.

## 4. Vérifications avant envoi

- [ ] Version `1.1.0.0` dans `modDesc.xml` (déjà fait).
- [ ] Aucun `print` ni log de debug (vérifié par le CI du dépôt).
- [ ] Test rapide en solo : choisir un logo intégré, changer la couleur, sauvegarder, recharger.
- [ ] Test multijoueur / serveur dédié : import, partage, logo en couleurs, suppression.
- [ ] Ancienne sauvegarde 1.0 chargée sans erreur (les couleurs et logos sont conservés).
- [ ] `log.txt` sans erreur `FS25_farmIconColor`.

## 5. Point ouvert : où trouver le convertisseur ?

La description parle du « convertisseur de logos Farm Icon Color », mais ModHub n'accepte en général
pas de lien externe dans la description. Options :
1. Publier le convertisseur sur GitHub Pages et le citer par son nom (les joueurs le trouvent en le cherchant).
2. Donner le lien sur une page à part (forum, Discord, page GitHub du mod).
