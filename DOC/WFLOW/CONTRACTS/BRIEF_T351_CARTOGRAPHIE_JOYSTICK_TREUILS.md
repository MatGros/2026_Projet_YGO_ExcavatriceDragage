=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== LECTURE SEULE — AUCUN CODE/ TOUCHÉ ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Besoin utilisateur récurrent
(2026-09-20/21) : pouvoir comprendre exhaustivement, à tout moment, le chemin
complet d'une commande depuis le geste joystick (ou la séquence auto) jusqu'au
contacteur physique — en MANU/MAINTENANCE ET en AUTO/SEMI_AUTO — pour anticiper
et diagnostiquer les bugs/blocages sans devoir relire tout le code à chaque
fois.

Un travail de ce type existe déjà pour la **translation M3 uniquement** :
`DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`,
section 3-4 : chaîne MANUELLE 66 lignes (codes M01-M66) et chaîne CYCLE AUTO
35 lignes (codes C01-C35), chacune tracée fichier:ligne. **Rien d'équivalent
n'existe pour les treuils M1/M2.**

Phase 2 envisagée par l'utilisateur (HORS PÉRIMÈTRE de ce lot, à ne pas
commencer) : outil web interactif — sélection d'un geste joystick, affichage
en temps réel/graphique du chemin exact parcouru dans le code (PRG, FB,
variables), chronologiquement.

## 2. Objectif de la tâche (T351)

Produire pour les **treuils M1 et M2** le même niveau de cartographie déjà
fait pour M3 : 2 chaînes complètes (MANU/MAINTENANCE et AUTO/SEMI_AUTO)
tracées fichier:ligne, du geste joystick au contacteur physique.

## 3. Méthode (calquer sur T334, ne pas réinventer)

Reprendre le format de `TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`
section 3-4 :
- Un tableau par variable : nom exact, où elle est déclarée (fichier:ligne),
  où elle est écrite (fichier:ligne), où elle est consommée (fichier:ligne),
  rôle en une phrase.
- Code court (`M01`, `M02`...) pour la chaîne manuelle, code court (`C01`,
  `C02`...) pour la chaîne cycle auto — permet de citer une variable
  précisément ailleurs.
- Un schéma texte du chemin complet, comme celui produit pour M3
  (`instCycleSemiAuto → TranslationCmd → PRG_03 → PRG_05 → FB_Translation...`),
  adapté aux treuils (`FB_CycleSemiAuto/PRG_03 → WinchM1Cmd/WinchM2Cmd →
  PRG_04 → FB_Winch → FB_WinchOutputInterlock → PRG_06 → relais`).
- Section dédiée aux **points de convergence/divergence** entre les 2 chaînes
  (comme fait pour M3 : "l'axe possède-t-il un seul contrat d'ordre ou deux ?").

## 4. Périmètre exact

### Chaîne MANU/MAINTENANCE (M1 et M2)
Point de départ : `PRG_02_Acquisition.st` (lecture joystick brut, `FB_Joystick`).
Point d'arrivée : relais physiques (`PRG_06_Outputs.st`).
Fichiers à parcourir a minima : `FB_Joystick.st`, `PRG_02_Acquisition.st`,
`PRG_04_Treuils_Benne.st` (arbitrage manuel), `FB_Winch.st`,
`FB_WinchDirectionInterlock.st` (D18), `FB_WinchOutputInterlock.st`,
`FB_Safety_Winch.st`, `PRG_06_Outputs.st`.

### Chaîne AUTO/SEMI_AUTO (M1 et M2)
Point de départ : `FB_CycleSemiAuto.st` (génération `WinchM1Cmd`/`WinchM2Cmd`).
Point d'arrivée : mêmes relais physiques (convergence attendue, à vérifier
comme pour M3 — "un seul point de sélection de source").
Fichiers à parcourir a minima : `FB_CycleSemiAuto.st`, `PRG_03_Modes_Cycle.st`,
`PRG_04_Treuils_Benne.st` (arbitrage cycle), puis même aval que la chaîne
manuelle (`FB_Winch.st` → ... → `PRG_06_Outputs.st`).

### Points spécifiques à documenter (déjà connus comme sensibles cette session)
- D18 (`FB_WinchDirectionInterlock.st`) : mécanisme de crédit du temps d'arrêt
  réel (corrigé récemment, T325 clos) — expliquer comment il s'intercale dans
  les 2 chaînes.
- Garde croisée M1/M2 (`PRG_04_Treuils_Benne.st:1360-1361`/`1452-1453` —
  numéros à revérifier, le fichier a bougé) : un treuil peut geler l'autre.
- Sécurité géométrique (limite haute logicielle `CfgCableLimitAscent_M`,
  `FB_Safety_Winch.st`) : comment elle coupe le permis dans les 2 modes.

## 5. Ce qu'il faut vérifier en plus (pas juste recopier T334)

- La chaîne M3 déjà produite dans T334 doit être relue et complétée si des
  trous apparaissent par comparaison avec le niveau de détail attendu ici
  (même gabarit, même exhaustivité).
- Ne pas supposer que les 2 chaînes (manuel/auto) convergent avant l'axe comme
  c'est le cas pour M3 — le vérifier explicitement pour M1/M2, avec preuve
  fichier:ligne, pas par analogie.

## 6. Devoir de challenge

- Toute variable citée doit être vérifiée par grep/lecture réelle, jamais
  recopiée d'une mémoire ou d'une hypothèse.
- Si une chaîne s'avère incomplète ou qu'un point reste ambigu après lecture,
  le signaler explicitement plutôt que de combler par une supposition.

## 7. Livrables attendus

- Document Markdown livré dans `DOC/WFLOW/TROUBLESHOOTING/FICHES/`, nommé
  `TROUBLESHOOTING_TREUILS_JoystickContacteur_2026-09-21.md` (ou équivalent),
  réutilisable comme référence permanente — pas un jetable de session.
- Aucune modification de `CODE/` — travail 100% lecture/documentation.
- Mise à jour `TASKS.yaml` (T351), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 8. Contraintes non négociables

- Zéro `CODE/` modifié — mission read-only stricte.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Ne pas démarrer la phase 2 (outil web interactif) — hors périmètre, capturée
  séparément pour plus tard si besoin.
