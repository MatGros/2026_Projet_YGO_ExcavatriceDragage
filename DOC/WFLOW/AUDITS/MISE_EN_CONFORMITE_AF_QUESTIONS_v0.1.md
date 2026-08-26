# Mise en conformité AF-01 → AF-14 — Questions & Décisions en attente

> 📌 Journal de bord de la mise en conformité `GUIDE_EDITION_AF_v1.0.md` sur l'ensemble des
> parties AF (chantier autonome démarré 2026-08-26). Une entrée par question/décision qui ne
> peut pas être tranchée seul (ambiguïté normative, sécurité, choix d'architecture). Ne bloque
> pas le travail — trace la question, continue sur le reste, l'humain tranche plus tard.

## Statut d'avancement

| AF | Statut | Commit | Review sous-agent |
|---|---|---|---|
| AF-01 | ✅ Fait | `b599d031` | 2 tours, tous défauts corrigés |
| AF-02 | ✅ Fait | `777cb424` | 1 tour, 4 gaps ingénierie corrigés |
| AF-03 | ✅ Fait | `3ed051bd` | 1 tour, 5 gaps ingénierie corrigés |
| AF-04 | ✅ Fait | `0e7e54f2` | 1 tour, bug version titre + réécriture §5 synchro (fausse phase de rattrapage) |
| AF-05 | ✅ Fait | `98cf96ee` | 1 tour, nom de variable inexistant corrigé (`TglMaintenanceZoneAccess`→`SelMaintenanceZoneAccess`) |
| AF-06 | ✅ Fait | `18ba121b` | 1 tour, ⛔ P0 sécurité trouvé (EncoderIncoherent non consommé par Modes/Safety) |
| AF-07 | ✅ Fait | `6a8cec2b` | 2 tours (1er a échoué sur limite API), section §6 manquante depuis toujours écrite from scratch |
| AF-10 | ✅ Fait (chapô seul, 9 fiches FB non retouchées) | `951db663` | 1 tour, 4 liens morts + §5.1 fausse + refs tâches inexistantes |
| AF-11 | ✅ Fait | `d757f6f1` | 1 tour, ⛔ catalogue TC inventé + anti-télescopage mal attribué (F_Safety_Translation au lieu de PRG_05 direct) |
| AF-12 | ✅ Fait (chapô seul, 3 fiches FB non retouchées) | (à suivre) | 1 tour, chemin source faux + zéro TC-P12 signalé + bug de code trouvé (ErrorId M2) |
| AF-07 | ⬜ | — | — |
| AF-08 | ✅ Déjà fait (session précédente) | `a045b40c` | — |
| AF-09 | ✅ Déjà fait (session précédente) | `a045b40c` | — |
| AF-10 | ⬜ | — | — |
| AF-11 | ⬜ | — | — |
| AF-12 | ⬜ | — | — |
| AF-13 | ⬜ | — | — |
| AF-14 | ⬜ | — | — |

## Questions ouvertes (à trancher par l'humain)

### Q1 — AF-08 v2.2 vs v2.3 : quelle version garder ?
**Contexte** : v2.3 applique les diagrammes/chronogrammes standardisés ; v2.2 était gardée
exprès pour comparaison. v2.2 a depuis été archivée (commit `a045b40c`/`b599d031` l'a confirmé
comme périmée). **Statut** : résolu implicitement — v2.3 est la version active, v2.2 archivée.
Signalé ici pour mémoire, aucune action requise sauf objection.

### Q2 — ArmingPermit non câblé + asymétrie homme-mort Treuils/Translation (T157)
Déjà tracké dans `TASKS.yaml` (T157, ⏸️, C4). Pas ré-ouvert ici, juste référencé : toute AF
touchant Treuils/Translation (AF-10/AF-11) devra composer avec cette zone grise sans la trancher.

## Décisions prises en autonomie (à valider a posteriori, pas bloquantes)

### D1 — AF-01 sort de la colonne "Fondations" du guide §5
AF-01 (chaîne AU/réarmement) a un comportement réel/testable propre, contrairement à AF-02
(architecture) et AF-03 (contrats) qui restent méta. Table des fonctions F01.01-F01.08 ajoutée.
Voir `GUIDE_EDITION_AF_v1.0.md §5` et `AF_Partie-01_Analyse_Fonctionnelle_v2.1.md §1`.

### D2 — Table macro "Points de validation" du chapô = synthèse condensée, jamais duplication verbatim
Règle appliquée : quand un chapô référence des `TC-Pxx-*` déjà détaillés dans une fiche FB, il
regroupe par intention (3-6 groupes) avec une phrase de synthèse — il ne recopie jamais le texte
détaillé de la fiche FB ligne à ligne. Écart trouvé et corrigé sur AF-01 (retour utilisateur
2026-08-26), à vérifier systématiquement sur toutes les AF suivantes qui ont une fiche FB dédiée.

### Q3 — `G200_check_linkage.py` L10 (producteur unique) : faux positifs intra-POU
Le checker compte deux écritures à la même variable **dans le même POU** (branchement normal)
comme "producteur multiple" — indistinguable d'un vrai second POU écrivain (1019 WARN actuels
non triés). Trouvé lors de la review AF-02 (sous-agent expert automatisme, 2026-08-26).
**Impact** : `TC-P02-001` n'est pas fiable tel quel. **Correctif proposé** (pas fait — hors
périmètre doc, nécessite modifier le script Python) : scoper la détection par POU, pas par ligne.
Documenté en TBD dans `AF_Partie-02_Architecture_Programme_v3.2.md §8`.

### Q4 — Aucun gate ne vérifie l'ordre inter-programmes (`MainTask`)
`G200_check_linkage.py` ne valide pas qu'un programme ne lit pas une donnée produite par un
programme exécuté plus tard dans le même cycle (règle §7 d'AF-02). Repose sur revue manuelle.
Trouvé lors de la review AF-02. Documenté en TBD `AF_Partie-02_Architecture_Programme_v3.2.md §8`.
**Correctif proposé** (pas fait) : nouveau gate d'analyse statique des dépendances de lecture/
écriture entre POU dans l'ordre `MainTask`.

### Q5 — Test `light`/`standard` ne dérive pas le critère sémantique
`test_fb_interface_guard.py` vérifie l'interface d'un FB déjà classé, mais ne dérive pas
lui-même « ce FB remonte-t-il un défaut ? » à partir de son corps. Un FB `light` mal classé
(qui écrirait quand même un défaut) passerait sans alerte. Trouvé lors de la review AF-03,
documenté en note dans `AF_Partie-03_Contrats_Composants_v2.2.md §3`. **Correctif proposé**
(pas fait, hors périmètre doc) : renforcer le test pour détecter l'écriture d'un champ
défaut-like dans un FB classé `light`.

### Q6 — Timeout séquence Kobold (`FB_DiveSearch`) : attente indéfinie voulue ou oubli ?
`FB_DiveSearch.st` ne porte aucun `TON`/timer — si le front d'immersion n'arrive jamais, le FB
attend indéfiniment (défaut uniquement par violation de séquence). Trouvé lors de la review AF-04.
Documenté en TBD `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.2.md §8`. **Non tranché** : ajouter un
timeout explicite, ou l'attente indéfinie est-elle réellement voulue (couverte par le tempo max
d'étape générique si `CycleMotionPermit=TRUE`) ?

### Note — `VERSION_HISTORY.md` : historique AF-04 incohérent (non bloquant)
`VERSION_HISTORY.md:129` mentionne "AF_Partie-04 v1.5 · v1.4 archivée" mais aucun fichier v1.5
n'existe (archive saute v1.4→v2.0 directement). Trouvé lors de la review AF-04, sans lien avec le
bug de titre "v3.0" corrigé cette session. À nettoyer un jour, pas bloquant.

### Q7 — ⛔ P0 SÉCURITÉ : `EncoderIncoherent` n'atteint ni Modes ni Safety (trouvé 2026-08-26)
**Contexte** : `AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §3ter` affirmait (avant cette
révision) que le trou P0 historique (AF09 §6 alerte 8 : perte bus → position gelée → dans la
plage → incohérence jamais vue → `SEMI_AUTO` reste autorisé) était "corrigé par conception" via
`ST_EncoderMeasurements`/`EncoderFault := NOT EncoderAvailable OR EncoderIncoherent`. **Faux en
pratique** : `PRG_03_Modes_Cycle.st:43` câble `FB_Modes.EncoderFaultPresent` sur
`COD1/COD2_DeviceState <> RUNNING` uniquement — `EncoderIncoherent` n'atteint jamais cette porte.
`FB_Safety_Winch` ne consomme que `EncoderAvailable`, pas `EncoderIncoherent` non plus.
**Conséquence** : une incohérence codeur SANS perte de bus (`EncoderIncoherent=TRUE`,
`EncoderAvailable=TRUE`) n'est bloquée nulle part — ni Modes ni Safety. Le doc a été corrigé pour
refléter l'état réel (marqué ⛔ non résolu), mais **le code lui-même n'a pas été touché** (hors
périmètre de ce chantier documentaire).
**Décision requise** : câbler `FB_Modes`/`FB_Safety_Winch` sur l'agrégat `EncoderFault` (formule
déjà correcte dans `FB_EncoderReliability`, juste jamais consommée en aval), ou documenter
explicitement pourquoi une incohérence seule ne doit pas bloquer `SEMI_AUTO`/déclencher `SafeStop`
si c'est volontaire. **Criticité C4 proposée** (sécurité, comportement machine). Documenté en TBD
`AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §9`.

### Q8 — AF-10 : 9 fiches FB non retouchées cette session (scope réduit, décision assumée)
Vu le volume (9 fiches FB dédiées, AF métier le plus dense traité jusqu'ici), seul le chapô
`AF_Partie-10_Fonction_Winch_v2.1.md` a été mis en conformité cette session. Les 9 fiches
(`FB_Winch`, `FB_Safety_Winch`, `FB_WinchSync`, `FB_WinchOutputInterlock`, `FB_Bucket`,
`FB_Winch_Symmetry`, `FB_SpeedStep`, `FB_WinchLoadEstimator`, `FB_DriftGuard`) restent en l'état
(pas de Sommaire lié, pas de bump de version, pas de vérification individuelle approfondie).
`FB_Safety_Winch` a été spot-check en review (7 mécanismes A-G vérifiés exacts contre le code,
aucun écart trouvé). **Question pour l'humain** : une passe dédiée sur les 9 fiches FB d'AF-10
est-elle prioritaire, ou le rythme actuel (chapô uniquement pour les AF les plus denses) convient-il
pour la suite (AF-11 à AF-14) ?

### Q9 — F11.05 (anti-télescopage hauteur M1/M2) : aucun TC dédié, C4, non testé formellement
Trouvé en review AF-11 (2026-08-26) : l'interlock anti-télescopage réel (`M3_HeightInterlockOk`,
`PRG_05_Translation.st` §0) n'a jamais eu de fiche ni de `TC-P11-*` dédié — le chapô l'attribuait
par erreur à `FB_Safety_Translation` (corrigé, section §1/Table des fonctions/diagramme). Fonction
C4 (risque collision benne/translation), câblage direct hors FB, zéro test formel identifié à ce
jour. **Décision requise** : créer un TC (root ID, propriétaire à désigner) et/ou une fiche
dédiée, ou documenter explicitement pourquoi ce câblage reste hors périmètre de test formel.
Documenté en TBD `AF_Partie-11_Fonction_Translation_v2.3.md §6`.

### Q10 — Bug de code : `DeviceEncoderM2.ErrorId` faux dans `FB_Diag_Ethercat.st`
Trouvé en review AF-12 (2026-08-26) : `CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st` positionne
`DeviceEncoderM2.ErrorId` sur `16#0030` (bits 4+5) au lieu de `16#0040` (bit6) attendu/documenté.
**Sans impact sur les décisions safety** (Error/Online/Operational corrects, synthèse ErrorId
globale par nibble non affectée) — impact limité à la lecture directe du bit par un technicien/
IHM. Task T159 créée (C2, DIAGNOSTIC). **Décision requise** : corriger le bit + ajouter un guard
CI (assertion ErrorId par device, absente aujourd'hui — c'est ce qui a permis au bug de passer
inaperçu). Documenté dans `AF_Partie-12_Fonction_Diagnostic_v1.1.md §6/§8`.

### Q11 — AF-12 : 3 fiches FB non retouchées (scope réduit)
Comme pour AF-10, seul le chapô a été mis en conformité — `FB_Diag_CanOpen_v1.0.md`,
`FB_Diag_Ethercat_v1.0.md`, `FB_Diag_IhmHeartbeat_v1.0.md` restent en l'état.

---

*Mis à jour à chaque AF traitée. Ne pas éditer les entrées passées — ajouter, jamais réécrire
l'historique.*
