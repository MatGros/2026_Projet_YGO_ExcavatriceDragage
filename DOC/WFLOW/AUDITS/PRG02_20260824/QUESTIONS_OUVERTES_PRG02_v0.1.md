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
| Q9 | Commentaires-journal interdits (§2ter) dans `FB_Hmi_BannerFormatter.st:478-540` — à purger, historique → `VERSION_HISTORY.md`. | `FB_Hmi_BannerFormatter.st` |
| Q10 | Condition composée 5 termes `CriticalActionActive` (>3, seuil §2quater) — à décomposer. | `FB_Hmi_BannerFormatter.st:341-342` |
| Q11 | Duplication ×10 du motif bypass IHM↔RETAIN dans `PRG_07_Supervision §2b/§2c` — candidate à extraction FC. | `PRG_07_Supervision.st` |
| Q12 | 4 références à du vocabulaire de POU abandonné dans des commentaires (`PRG_TREUILS_CFC`, `PRG_10_Outputs_LD`, `PRG_MODES_CFC`, `PRG_AUXILIARY_CFC`, `PRG_SUPERVISION_CFC`) — remplacement mécanique par les noms cibles. | `_TYPES/1_TREUILS_BENNE/ST_WinchFinalInterlockRequest.st`, `_TYPES/2_TRANSLATION/ST_TranslationCmd.st`, `_TYPES/3_CYCLE_ET_MODES/ST_Modes_Autorisations.st`, `_TYPES/7_COMMUN_CONFIG/ST_CommunHMI.st` |
| Q13 | Régions sans préfixe `§N` dans `FB_Encoder.st` et `FB_Joystick.st` — renumérotation. | `FB_Encoder.st`, `FB_Joystick.st` |
| Q14 | `Reset` quasi/totalement inerte dans `FB_Diag_CanOpen.st` et `FB_Diag_Ethercat.st` (auto-clear déjà en place, port redondant) — clarifier ou retirer. | `FB_Diag_CanOpen.st`, `FB_Diag_Ethercat.st` |
| Q15 | `FB_Encoder_SpeedMonitor.st` : `PowerContactorEngaged` en entrée alors que ce FB ne pilote aucun organe (anti-pattern déjà cité pour Joystick dans `CODE_QUALITY_STANDARDS.md`), et `Mode` jamais lu. | `FB_Encoder_SpeedMonitor.st` |
| Q16 | Commentaire syntaxiquement cassé (reliquat d'édition). | `ST_TranslationHMI.st:16` |

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
*Ce document + les 2 revues ont été soumis à un sous-agent challenger indépendant. Clôture de la
phase de revue read-only.*
