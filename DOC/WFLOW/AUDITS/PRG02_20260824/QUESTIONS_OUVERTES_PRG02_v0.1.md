# ❓ Questions ouvertes — Revue PRG_02 (Acquisition + HMI/Troubleshooting)

📅 2026-08-24 · Consolidées à partir de [REVUE_PRG02_ACQUISITION_v0.1.md](REVUE_PRG02_ACQUISITION_v0.1.md)
et [REVUE_PRG02_HMI_TROUBLESHOOTING_v0.1.md](REVUE_PRG02_HMI_TROUBLESHOOTING_v0.1.md).
Aucune de ces questions n'a bloqué le travail — elles sont listées ici pour arbitrage humain,
comme demandé.

## 🔴 Priorité 1 — Sécurité machine réelle (bloquant avant toute clôture de lot)

| # | Question | Fichier | Impact si non tranché |
|---|---|---|---|
| Q1 | `ArmingPermit` du joystick est câblé en dur à `TRUE` (`PRG_02_Acquisition.st:303`) — le désarmement homme-mort automatique sur changement de mode / fin de cycle benne (AF08 v2.0) n'existe plus dans le FB. **Faut-il réimplémenter la chaîne de permission, ou est-ce un choix assumé (et alors sur quelle base) ?** | `FB_Joystick.st`, `PRG_02_Acquisition.st:303` | Homme-mort ne se désarme plus automatiquement |
| Q2 | `FB_Encoder_Homing.st` déclare `FwdRevSpeedFeedbackOff`/`BrakeFeedback` en entrée mais ne les lit jamais ; le bit2 `ErrorId` (« arrêt non confirmé ») n'est jamais positionné. ⚠️ **Confirmé par le challenge indépendant : le trou est sur 2 niveaux, pas 1** — la façade `FB_Encoder.st` (appelée par `PRG_02`) **n'expose même pas ces 2 ports** en `VAR_INPUT` ; un correctif doit donc étendre l'interface de `FB_Encoder.st` ET le câblage `PRG_02_Acquisition.st`, pas seulement coder la logique interne de `FB_Encoder_Homing.st`. Recherche de mécanisme compensatoire : `AscentPermit`/Meca A-E (`FB_Safety_Winch.st`) exclut explicitement `NOT InReferencingMode` → **aucune protection active pendant le homing**. **Faut-il implémenter le gate (2 fichiers), ou retirer ces ports de l'interface partout (et corriger la fiche) ?** | `FB_Encoder_Homing.st`, `FB_Encoder.st` | Homing possible sans garantie contacteurs/frein au repos — aucun filet de sécurité alternatif trouvé |

## 🟠 Priorité 2 — Architecture / doctrine (à trancher avant refactor du domaine)

| # | Question | Fichier | Impact |
|---|---|---|---|
| Q3 | `FB_Encoder_Safety.st` : `Reset` calculé mais jamais lu ; le bit0 (bornage) s'auto-efface sans acquittement alors que la fiche documente un comportement Fault. **Le bit0 doit-il devenir un vrai latch Cause/Ack, ou la fiche doit-elle être corrigée pour documenter l'auto-clear actuel ?** | `FB_Encoder_Safety.st` | Dépassement de bornage transitoire invisible sans trace |
| Q4 | `PRG_07_Supervision` calcule `LimitLegalReached` inline (comparaison de seuil), alors que sa doctrine documentée est « lecture seule stricte : n'écrit ni commande, ni configuration, ni interlock ». **Ce calcul est-il un « état public agrégé » toléré, ou doit-il migrer vers un domaine métier producteur ?** | `PRG_07_Supervision.st:333-335` | Ambiguïté doctrine PRG_07, précédent pour futurs calculs inline |
| Q5 | La doc `AF_Partie-09 §4.2/§6` affirme que le homing a migré vers `PRG_04_Treuils_Benne` (« décidé »), mais le code l'instancie toujours dans `FB_Encoder` (facade) appelée depuis `PRG_02`. **Décision non appliquée, ou doc en avance sur un choix révisé depuis (facade unifiée) ?** | `AF_Partie-09_Fonction_Encoder_v2.1.md` vs `FB_Encoder.st` | Doc et code divergents sur l'architecture cible |
| Q6 | `GVL_Troubleshooting` est structurellement un **snapshot instantané** (aucun horodatage/historique dans les ~14 structures `ST_Chain*`/`ST_*Checklist`, tous domaines confondus) — pas seulement le trou M3 déjà connu (T129). **Veut-on un chantier dédié « historique/chronologie troubleshooting » (buffer circulaire horodaté), et à quelle priorité ?** | `GVL_Troubleshooting.st` + toutes les `ST_Chain*` | Dépannage terrain reste « état figé », pas « dans quel ordre ça a lâché » |

## 🟡 Priorité 3 — Nettoyage documentaire/style (aucun risque fonctionnel, exécutable directement si accord)

| # | Sujet | Fichiers |
|---|---|---|
| Q7 | `AF_Partie-08_Fonction_Joystick_v2.0.md` périmée vis-à-vis du `FB_Joystick.st` réel (interface entière disparue) — mise à jour à planifier, distincte de Q1. | `AF_Partie-08...md` |
| Q8 | `FB_Encoder_Homing_v1.0.md §2/§3ter` documente une interface qui n'existe plus (`Mode`/`UnitaryMode`/`WinchSelected`). | fiche AF-09 |
| Q14 | `Reset` quasi/totalement inerte dans `FB_Diag_CanOpen.st` et `FB_Diag_Ethercat.st` (auto-clear déjà en place, port redondant) — clarifier ou retirer. | `FB_Diag_CanOpen.st`, `FB_Diag_Ethercat.st` |
| Q15 | `FB_Encoder_SpeedMonitor.st` : `PowerContactorEngaged` en entrée alors que ce FB ne pilote aucun organe (anti-pattern déjà cité pour Joystick dans `CODE_QUALITY_STANDARDS.md`), et `Mode` jamais lu. | `FB_Encoder_SpeedMonitor.st` |

✅ **Traitées et closes (T152, 2026-08-25)** : Q9 (commentaires-journal), Q10 (condition 5 termes),
Q11 (duplication ×10 bypass), Q12 (vocabulaire abandonné), Q13 (régions sans `§N`), Q16
(commentaire cassé) — voir `DOC/WFLOW/TASKS.yaml` T152/T152-A..D et
[REVUE_PRG02_ACQUISITION_v0.1.md](REVUE_PRG02_ACQUISITION_v0.1.md) /
[REVUE_PRG02_HMI_TROUBLESHOOTING_v0.1.md](REVUE_PRG02_HMI_TROUBLESHOOTING_v0.1.md) pour le détail
d'origine.

---

## 🕵️ Challenge indépendant — verdict (2026-08-24)

Un 3ᵉ sous-agent (n'ayant pas produit les revues) a vérifié **dans le code source réel** chaque
finding BLOCK/MAJOR des 2 revues, et cherché spécifiquement un mécanisme compensatoire pour Q1,
Q2, Q3 dans `PRG_04_Treuils_Benne.st`, `PRG_05_Translation.st`, `FB_Safety_Winch.st`,
`FB_Cycle.st`.

| Point vérifié | Verdict challenge |
|---|---|
| Q1 (ArmingPermit figé) | ✅ Confirmé — `grep ArmingPermit` = 2 fichiers seulement, aucune chaîne alternative |
| Q2 (Homing arrêt confirmé) | ✅ Confirmé, **et pire que rapporté** — trou sur 2 fichiers, pas 1 (voir Q2 corrigée ci-dessus) |
| Q3 (FB_Encoder_Safety Reset inerte) | ✅ Confirmé — aucun consommateur externe n'ajoute de latch |
| Autres MAJOR (PowerContactorEngaged/Mode SpeedMonitor, condition 5 termes, commentaires-journal, LimitLegalReached inline, duplication ×10) | ✅ Tous exacts fichier:ligne, sévérité correcte |
| Findings à corriger / exagérés / faux / doublons | **Aucun** |
| Angles morts ratés par les 2 revues initiales | **Aucun** hors l'enrichissement de Q2 déjà intégré |

**Verdict final : documents fiables, une seule correction appliquée (Q2 enrichie).** Aucun
mécanisme compensatoire trouvé pour les 3 points de sécurité — Q1/Q2/Q3 restent des trous réels
à trancher par l'utilisateur, sans filet de rattrapage ailleurs dans le programme.

---

## 🕵️ 3ᵉ challenge indépendant — exhaustif, y compris les tâches T152 (2026-08-25)

Un 4ᵉ sous-agent a relu intégralement les 4 documents + les tâches T152/T152-A..D + leurs
contrats, et surtout **élargi la couverture `_TYPES/` de 14/77 à 77/77 fichiers** (18%→100%) —
la revue d'origine et le 2ᵉ challenge n'avaient ouvert qu'une fraction de ce dossier.

### ✅ Tout ce qui avait été confirmé reste confirmé
Aucun finding BLOCK/MAJOR/MINOR des 2 revues n'est faux, exagéré ou doublonné. Un seul point
nuancé (formulation, pas le fond) : `PowerContactorEngaged` dans `FB_Encoder_SpeedMonitor.st`
n'est pas mort (il gate bien la ligne 56) — le vrai problème est l'anti-pattern (diagnostic pur
gaté comme un FB de mouvement), pas une variable inutilisée.

### 🕳️ 3 angles morts trouvés en allant plus loin

1. **`ArretConfirme` (`FB_Encoder_Homing.st:77`) — variable locale totalement morte**, jamais
   assignée ni lue. Preuve supplémentaire que la logique d'arrêt confirmé (Q2) a été retirée du
   corps du FB sans nettoyer sa déclaration. N'ouvre pas de nouvelle question — vient enrichir Q2.
2. **4 fichiers `_TYPES/` supplémentaires** portent un résidu abrégé `_LD` du vocabulaire abandonné
   (`ST_Chain_Winch_Control.st:7`, `ST_WinchState.st:37`, `ST_Chain_Translation_Control.st:6`,
   `ST_TranslationState.st:25`) — non couverts par la revue d'origine (échantillon 14/77) ni par
   T152-C dans sa version initiale. **Corrigé** : scope T152-C étendu (voir ci-dessous).
3. **5 commentaires cassés supplémentaires** du même motif que `ST_TranslationHMI.st:16` (deux-points
   orphelin en tête, reliquat d'un search-replace) : `ST_CommunHMI.st:18,21,57`,
   `ST_Chain_Winch_Control.st:14,15`. **Corrigé** : scope T152-C étendu.

### 🛠️ Corrections appliquées aux tâches (justifiées, appliquées immédiatement)

- **T152-C** : scope étendu de 5 à 9 fichiers (les 4 fichiers `_LD` + les 5 commentaires cassés
  supplémentaires), critère de grep élargi (`_LD\b` en plus des 5 noms complets — l'ancien critère
  AC6 aurait pu passer au vert sans purge réelle, fausse confiance de complétude).
- **T152-D** : scope **restreint à §2c seul** (lignes 227-295, les 10 blocs `Prev*` réellement
  identiques). §2b (lignes 174-223, 6 blocs) s'est révélé être un **algorithme différent**
  (restauration boot one-shot conditionnée par `Initialized`, pas une synchro bidirectionnelle
  continue) — le fusionner aurait cassé la sémantique boot-only. Explicitement listé en
  `forbidden` désormais. Précédent de conception noté pour info (`FB_CfgPersistBridge_*`,
  7 instances dans `_BRIDGES/`) — algorithme différent (Hmi-gagne-toujours), à ne pas copier tel
  quel mais utile comme référence de forme.
- **T152-A / T152-B** : aucune correction nécessaire, confirmées lançables telles quelles.

### Verdict final
Documents 1-4 fiables. Tâches T152-A/B/C/D toutes lançables après corrections (C et D corrigées
ci-dessus, contrats re-validés `check_task_contract.py` = PASS 0 erreur).

---
*Ce document + les 2 revues + les 4 tâches T152 ont été soumis à 3 rounds de challenge
indépendant successifs. Clôture de la phase de revue read-only.*
