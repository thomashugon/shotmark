# ShotMark

Outil de capture d'écran et d'annotation pour macOS, inspiré des fonctionnalités de Greenshot.
« ShotMark » est un nom provisoire : « Greenshot » est une marque, l'app doit avoir son propre nom et sa propre icône.

## Fonctionnalités (v0.1)

- App de barre des menus (pas d'icône dans le Dock)
- Raccourcis globaux : **⌥⇧4** zone ou fenêtre, **⌥⇧3** écran entier, **⌥⇧2** copier le texte d'une zone (OCR), **⌥⇧5** répéter la dernière zone
- OCR hors ligne avec Apple Vision (français, anglais, allemand, espagnol, italien) : depuis ⌥⇧2 ou le bouton « Texte (OCR) » de l'éditeur
- Sélection sur image figée, sur tous les écrans : glisser pour une zone, survoler + cliquer pour une fenêtre, Espace/Entrée pour l'écran entier, Échap pour annuler
- Éditeur : rectangle, ellipse, ligne, flèche, main levée, texte, surligneur, floutage (pixellisation), numéros, recadrage ; couleur, épaisseur, annuler/rétablir
- Raccourcis de l'éditeur : R E L A F T H O I C pour les outils, ⌘C copier, ⌘S enregistrer, ⇧⌘S enregistrer sous
- Après capture (réglable) : ouvrir l'éditeur, copier, ou enregistrer directement (PNG/JPEG) dans un dossier

## Installer le .dmg (sans Xcode)

Chaque push sur `main` compile un `ShotMark.dmg` (onglet *Actions* du dépôt, artefact `ShotMark-dmg`).
L'app est signée ad hoc mais pas notarisée par Apple, donc macOS bloque le premier lancement (« Élément non ouvert ») :

1. Glisser ShotMark dans Applications, essayer de l'ouvrir une fois, puis cliquer sur *Terminé*.
2. Réglages Système › Confidentialité et sécurité, descendre jusqu'à « ShotMark a été bloqué », cliquer sur **Ouvrir quand même** et confirmer.
   Ou, dans le Terminal : `xattr -cr /Applications/ShotMark.app`
3. Autoriser ShotMark dans Confidentialité et sécurité › Enregistrement de l'écran, puis relancer l'app.

Pour supprimer cet avertissement, il faut signer avec un certificat Developer ID et notariser l'app (compte Apple Developer, 99 $/an).

## Prérequis

- macOS 14 Sonoma ou plus récent (utilise ScreenCaptureKit / `SCScreenshotManager`)
- Xcode 16 ou plus récent
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) pour générer le projet Xcode : `brew install xcodegen`

## Compiler et lancer

```sh
cd ShotMark
xcodegen generate
open ShotMark.xcodeproj
```

Dans Xcode : choisir votre équipe dans *Signing & Capabilities*, puis ⌘R.
Au premier lancement, macOS demande l'autorisation **Enregistrement de l'écran** (Réglages Système › Confidentialité et sécurité). Après l'avoir accordée, il faut relancer l'app.

## Structure

```
ShotMark/
  App/        point d'entrée, menu, raccourcis globaux (Carbon)
  Capture/    captures ScreenCaptureKit, overlay de sélection, orchestration
  Editor/     modèle d'annotations, rendu, éditeur SwiftUI
  Export/     presse-papiers, PNG/JPEG, enregistrement
  Settings/   préférences
```

## Pistes pour la suite

- Raccourcis personnalisables dans les réglages
- Sélection/déplacement/suppression des annotations existantes
- Loupe pendant la sélection, capture d'une fenêtre avec son ombre
- Destinations d'export (Imprimer, Partager, Mail, upload)
- Lancement au démarrage (`SMAppService`)
- Mac App Store : activer l'App Sandbox et vérifier l'accès au dossier d'enregistrement (security-scoped bookmarks)

## Licence

Code écrit de zéro, sans reprise du code de Greenshot (GPL). Si du code Greenshot était réutilisé un jour, l'app entière devrait être distribuée sous GPL.
