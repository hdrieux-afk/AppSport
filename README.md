# App Sport : squelette SwiftUI

App iOS (iOS 17 minimum) de programmes d'entraînement : course, vélo, muscu, avec export de fichiers .fit pour montres Garmin.

## Développer depuis Windows : la voie GitHub

Xcode n'existe que sur Mac. Ici, un Mac hébergé par GitHub compile l'app à chaque dépôt de code.

1. Créez un dépôt GitHub (public ou privé), puis ajoutez-y le contenu de ce dossier (pas le zip).
2. Ouvrez l'onglet Actions : le workflow "CI" démarre tout seul à chaque ajout de fichiers.
3. Deux travaux s'exécutent :
   - "Domaine sur Linux" : compile et teste les règles métier (rapide, quelques minutes)
   - "App complète sur macOS" : génère le projet Xcode (XcodeGen), compile l'app, lance les tests,
     puis photographie l'app dans un simulateur iPhone
4. En cas d'échec, la page de résumé du run liste les erreurs : copiez-les pour les faire corriger.
5. En cas de succès, les captures d'écran sont téléchargeables en bas de la page du run (Artifacts).

## Fichiers de pilotage

- project.yml : décrit le projet Xcode (XcodeGen en fabrique le fichier .xcodeproj)
- Package.swift : permet de compiler et tester le domaine seul, sur Linux
- .github/workflows/ci.yml : la recette exécutée par GitHub

## Organisation du code

- Domain : règles métier sans interface (bibliothèque de séances, générateur de plan, encodeur FIT)
- Persistence : ce que SwiftData sauvegarde
- Store : l'état de l'app et les actions de l'utilisateur
- Design : couleurs Trail, textes en français
- Views : les écrans
- Tests : test de l'encodeur FIT (fichier identique octet pour octet à la référence validée)
- FitSamples : 4 séances .fit à copier dans GARMIN/NewFiles de la montre (USB)

## Mode démo

Lancée avec l'argument -demo, l'app crée un plan d'exemple. La CI l'utilise pour les captures d'écran.

## Installer l'app sur un iPhone depuis Windows

Quand la compilation sur macOS réussit, le run publie un fichier AppSport-ipa (un par type de Mac) (section Artifacts du run).
Il s'installe avec Sideloadly (gratuit, Windows) : iPhone en USB, Mode développeur activé
(Réglages, Confidentialité et sécurité), puis glisser le fichier .ipa dans Sideloadly.
Avec un identifiant Apple gratuit, l'app expire après 7 jours (il suffit de la réinstaller).
