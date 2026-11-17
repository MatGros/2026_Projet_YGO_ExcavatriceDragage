# T377-B — Défauts parasites au démarrage (perte codeur M1/M2, autotest AU) · spécification v0.1

> Rédigée par TORC-CC10 le 2026-11-17 (23:5x), sur demande de l'exploitant. **Proposition**, rien n'est inscrit au catalogue. Dossier de tâche : non créé, à décider par T377-CC03 (intégrer au dossier T377 ou le séparer). Remplace et précise `BRIEF_SOUS-TACHE_T377_DEMARRAGE_VERROU_CODEUR_AUTOTEST_AU_20261117_v0.1.md`.

## Fiche catalogue proposée
- **id** : `T377-B` · **parent_id** : `T377` · **statut** : ⬜ · **criticité** : **C4** (modification de la condition d'armement d'un latch de sécurité) · **agent** : `—` (T377-CC03 décide : prend la tâche, ou la rend).
- **domaine** : SECURITE_ET_AU / DEMARRAGE / DIAGNOSTIC
- **titre** : Défauts parasites au démarrage : ne pas armer la perte codeur avant le 1er OP du bus, reporter l'autotest AU après rebouclage
- **tâches liées (à rattacher ou fusionner par le responsable du catalogue)** : T367, T363, T278, T357, T359, T397.

## Contexte (faits)
Au démarrage après arrêt, 3 défauts apparaissent : `[M1] ErrorID:02` et `[M2] ErrorID:02` (perte codeur), `[AU] ErrorID:04` (échec autotest au démarrage). Aucun défaut réel : la machine fonctionne après un Reset. Des messages restent affichés pendant des heures.
- `FB_Safety_Winch.st:277-279` : la cause 1 est armée **à chaque scan** tant que `NOT EncoderAvailable` ; elle n'est purgée que par `ResetEdge` ou au 1er scan (`:181-216`). Un Reset fait **avant** le 1er OP du bus se ré-arme donc au scan suivant (lu par TORC-CC10).
- `EncoderAvailable = FALSE` pendant toute l'initialisation EtherCAT (`FB_Diag_Ethercat.st:72`, étude T377-CC03).
- Autotest AU : évalué **une fois** au 1er `EnableRising`, alors que la boucle AU est physiquement ouverte (étude T377-CC03 `:171-186, 496-497`).
- `FB_AutoResetTransientDiag` n'atteint que les diagnostics réseau (en-tête) ; son impulsion est un no-op prouvé (T359).

## Résultat du challenge A/B (Ollama, 2026-11-17 ; vérifié à la source par TORC-CC10)
- **A (innovation)** : aucun mécanisme existant n'efface les 3 défauts ; **variante B étendue** (armement du latch codeur conditionné à « OP atteint une fois » ou à une fenêtre X ; autotest AU déclenché au 1er `EnableRising` **ET** boucle AU fermée). **Pas d'impulsion, pas de purge** de latch. Fusionner l'utile de T278, abandonner l'émission d'impulsion, T363 à requalifier, T397 à suspendre.
- **B (red team)** : verdict **BLOCK** pour toute impulsion de reset qui peut atteindre un latch de sécurité. Risques majeurs : « AU actif » non défini par un signal unique, reset sur retour de bus en marche, X non mesuré, flag « OP une fois » = seconde source de vérité, double reset.
- **Convergence** : ne pas implémenter de reset automatique des latches de sécurité ; retarder **l'armement** de la cause, pas purger une cause posée. La demande « impulsion à chaque bus opérationnel » est **refusée** pour les latches ; elle ne vaut que pour les diagnostics réseau (déjà couverts, sans effet).
- Réponses brutes : `$CLAUDE_JOB_DIR/tmp/reponse_A_t377b.md` et `reponse_B_t377b.md` (non versionnées ; à copier dans le dossier de tâche si l'exploitant le souhaite).

## Mécanismes retenus et repli (décision exploitant, 2026-11-18)
1. **Prévention d'abord** : ne pas armer la perte codeur avant le 1er OP du bus (délai maximal X mesuré) ; ne déclencher l'autotest AU qu'après le 1er rebouclage de la chaîne. Éviter le défaut plutôt que l'effacer.
2. **Repli prévu** si un cas est oublié ou ajouté en cours de route : **une seule impulsion d'acquittement après la fin du boot + 5 s**, **limitée à la perte codeur** (cause réévaluée à chaque scan : un défaut réel se ré-arme immédiatement, l'impulsion ne peut pas le masquer). Jamais en marche, jamais sur un retour de bus.
3. **Limite AU** : l'impulsion ne s'applique **pas** à l'autotest AU (évalué une seule fois : l'effacer sans nouveau test laisse la fonction AU non prouvée).
4. **Bit d'activation** : chaque mécanisme (prévention codeur, report de l'autotest AU, impulsion de repli) a son bit `Tgl` dédié, **défaut = comportement actuel**, pour pouvoir revenir en arrière sans réimport.
5. Tout acquittement automatique d'un défaut de sécurité exige un **GO C4 explicite** de l'exploitant.

## Périmètre
**Dans** : condition d'armement de `EncoderFaultLatched` (M1/M2) dans `FB_Safety_Winch.st`, source du flag « OP atteint une fois » (`FB_Diag_Ethercat.st`), déclencheur de l'autotest AU dans `FB_Safety_EmergencyManagement.st`, messages de bandeau associés, mesure du temps de montée du bus.
**Hors** : tout reset automatique de latch de sécurité ; chaîne AU matérielle ; homing sans contact TOP (T377) ; correctif T363/T397 tant que non arbitré.

## Critères testables (AC)
1. **AC1** Reboot PLC sous puissance, bus sain : 0 latch codeur M1/M2, `ArmingErrorId = 0` (preuve : snapshot, sortie brute).
2. **AC2** Codeur réellement mort au boot : latch armé après `X` s au plus ; mouvement impossible avant (preuve : essai ou simulation + trace).
3. **AC3** Perte codeur **en marche** (OP déjà atteint) : latch **immédiat**, inchangé (non-régression).
4. **AC4** AU puis rebouclage : perte codeur latchée immédiatement (le flag « OP une fois » ne s'efface pas).
5. **AC5** Cold boot, boucle AU ouverte : pas d'échec d'autotest tant que la boucle n'a jamais été fermée ; après 1er rebouclage, autotest évalué ; AU réellement en panne ⇒ latch.
6. **AC6** Aucun reset automatique d'un latch de sécurité (revue de code + test déterministe).
7. **AC7** `X` mesuré sur la machine (froid et après retour contacteur), pas supposé ; `G200 --report`, `run_all_gates.py --palier C` verts.

## Points d'arrêt humain
1. Avant code : GO C4 de l'exploitant sur la variante B étendue et sur X.
2. Après mesure de X : validation de la valeur.
3. Après revue indépendante du diff, avant import dans CODESYS.

## Preuves attendues
Sorties brutes avec code retour, diff réel, snapshots avant/après redémarrage (variables `Phase`, `AttemptCount`, `Lockout`, `EncoderFaultLatched`, `ArmingErrorId`), bundle complet + diff bundle, G200, gates.

## Chantiers concurrents
T377 (CC03, homing sans contact TOP, mêmes FB) ; T417-C (AGY02, `PRG_03`, `CODE_DiffBundle.xml`) ; T427-CC02 (garde d'écriture) ; T386, T387, T395 (selon brief T377).

## Points ouverts (non tranchés)
- Définition de « AU actif » si une variante avec reset est un jour reconsidérée (signal unique à nommer).
- Position de la chaîne AU et affectation 24 V des codeurs au démarrage (schéma `DOC/WFLOW/ELEC`, à confirmer).
- Effet exact d'un Reset sur le flag d'autotest AU et ordre rebouclage / engagement du contacteur (à lire avant de coder).
- Autres consommateurs de `EncoderAvailable` (non vus).
