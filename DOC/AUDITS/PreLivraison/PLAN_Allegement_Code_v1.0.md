# ⚖️ PLAN — Allègement, lisibilité & dette technique avant livraison (v1.0)

> 🎯 **Rôle** : cadrer ce qui doit être retiré, corrigé, **et surtout ce qu'il ne faut PAS toucher**
> avant la livraison client. Document maître de phasage des 3 plans.
> 📅 2026-07-26 · **Aucune modification code réalisée** — document de préparation.
> 🔗 [PLAN_Rationalisation_Simulation_v1.0](PLAN_Rationalisation_Simulation_v1.0.md) ·
> [PLAN_Ergonomie_MiseEnService_v1.0](PLAN_Ergonomie_MiseEnService_v1.0.md) ·
> [AUDIT_Revue_Technique_v1.0](../RevueTechnique/AUDIT_Revue_Technique_v1.0.md) · [PLAN_TASK §3](../../PLAN_TASK_v1.0.md)

---

## 1. 📏 Où est réellement le poids

**9 982 lignes ST · 114 fichiers** (dont ~17 % de commentaires purs).

| Dossier | Lignes | % | Nature | Compressible ? |
|---|---|---|---|---|
| `MAIN` (PRG_00→10) | 2 642 | 26 % | Orchestration + **570 l. de mapping IHM** | 🟠 partiellement |
| `TREUILS` | 2 148 | 22 % | Métier + safety M1/M2/benne | 🔴 non — cœur sécurité |
| `SUPERVISION` (40 fichiers) | 868 | 9 % | Structs `ST_*HMI`/`Cfg`/`Bypass` | 🟠 marginal |
| `CODEURS` | 674 | 7 % | Chaîne codeur/homing | 🔴 non |
| `TRANSLATION` | 577 | 6 % | M3 + safety | 🔴 non |
| `COMMUN` | 564 | 6 % | Briques réutilisables | 🔴 non |
| **`SIMULATION`** | **532** | **5 %** | Simulation + `GVL_PLC_Tests` | ✅ **−210 l.** |
| `CYCLE` | 492 | 5 % | Séquenceur | 🔴 non |
| `DIAG` | 484 | 5 % | Bus terrain | 🟠 refactor T77 |
| `JOYSTICK` | 389 | 4 % | — | 🔴 non |
| `AU` | 304 | 3 % | Chaîne AU / redondance | 🔴 non |
| `MODES` | 201 | 2 % | — | 🔴 non |

### 🎯 Verdict à assumer

Le retrait de `PLC_TESTS` (7 300 lignes, `v0.5.1`) a **déjà fait l'essentiel du travail** : il
représentait 43 % du projet. Ce qui reste est du code métier et sécurité, dense et nécessaire.

➡️ **Le gain de poids restant est de l'ordre de 2 %.** Il ne justifie pas, à lui seul, de toucher au
code avant livraison. **Ce qui le justifie, c'est la suppression de mécanismes trompeurs** — voir
[plan Simulation §2](PLAN_Rationalisation_Simulation_v1.0.md).

⚠️ **Ne pas rogner sur les commentaires.** 17 % de commentaires FR + emoji, avec les `REX aaaa-mm-jj`
qui expliquent *pourquoi* chaque choix a été fait : c'est l'actif de maintenance le plus précieux du
projet, et il ne coûte **rien** dans l'automate (retiré à la compilation).

---

## 2. ✅ Suppressions sûres — orphelins confirmés

Vérifiés par recherche exhaustive sur `CODE/**/*.st` : aucun consommateur.

| Élément | Lignes | Consommateurs |
|---|---|---|
| `FB_Sim_DigitalMirror` | 46 | ☠️ **aucun** (spec Partie 13 le dit utilisé pour M3 — faux) |
| `GVL_PLC_Tests` (16 des 20 `Override*`) | 64 | ☠️ vue instance uniquement |
| Points d'injection `PRG_00:311-356`, `PRG_01:42-45,91-95`, `PRG_09:63-74` | 63 | — |
| `ST_TestTranslation` + `ST_TestCycle` | 22 | ⚠️ **`GVL_IHM` → visu possible** |
| `PRG_09:253-257` `BypassRestoreDone` | 5 | ☠️ « 100 % orphelin » écrit dans le code lui-même |

**≈ 200 lignes**, risque fonctionnel nul hors le point ⚠️ IHM.

### 🔍 À vérifier avant de trancher (non conclu ici)

| Élément | Question |
|---|---|
| `GVL_Modes_Stub` / `GVL_Translation_M3_Stub` | Vestiges de stubs : `PosPV_DI` et `StubTranslationPositionSelect_IHM` **sont consommés** (PLAN_TASK §2) — GVL à conserver, contenu à réduire |
| `PRG_IP` | Programme réel, **appelé dans aucune tâche** (T2) — supprimer ou documenter |
| `FB_Input`/`FB_Output` (COMMUN) | Existent mais non intégrés dans Winch/Translation (logique contacteur dupliquée) — dette assumée, **pas avant livraison** |

---

## 3. 🩹 Dette technique — ce qui doit être corrigé avant livraison

Issu de l'audit du 2026-07-26. Classement **par risque machine**, pas par effort.

| # | Constat | Risque réel | Priorité |
|---|---|---|---|
| **C5** | Méca A : seuil `0,02 m/s` sur dérivée **brute**, sans filtre ni tempo → `PowerCutOff` immédiat. Les contrôles voisins (bits 14/15) ont tous une `TON`. | 🔴 **Coupure de puissance intempestive sur 1 glitch codeur.** Aggravé par C1 : Méca A est désormais la **seule** protection contre le patinage de frein | 🔴 **Avant essais dynamiques** |
| **C2** | `ForbidAscent` non initialisé dans le gate `Enable=FALSE` (`FB_Safety_Winch:242-265`) | 🟠 Sortie de bloc sécurité non déterministe. Impact masqué par `SafeStop`, mais c'est un oubli, pas un choix | 🟠 prochain lot |
| **C4** | `DelayMotorDecel` : paramètre **sans effet**, réglable depuis `FB_Winch` | 🟠 Un technicien peut croire régler la séquence de frein. Faux réglage = fausse confiance | 🟠 prochain lot |
| **C3** | `check_code_style.py` : **36/36 faux positifs** depuis la refonte `GVL_IHM` | 🟠 Garde-fou aveugle = pas de garde-fou (T75) | 🟠 outillage |
| **C6** | `FB_CycleTime` : débordement `TIME()` à 49,7 j. non géré | 🔵 À-coup de rampe sur machine en marche continue. **Une dragueuse tourne longtemps** | 🔵 opportuniste |
| **C7** | Commentaire masque `SafeStop` incomplet (bits 14/15) | 🔵 Doc seule, code correct | 🔵 opportuniste |

### 🔴 Reliquats sécurité ouverts (PLAN_TASK §3) à statuer avant réception

| Txx | Sujet | Décision attendue |
|---|---|---|
| **T52** | 🔴 Chaîne `PowerCutOff` physique jamais validée : câblage A/B, contacteur, retour, temps de coupure réel | **Bloquant réception** |
| **T72** | Interverrouillage sens/frein : interdire `RelayFwd/Rev` tant que `BrakeCmd = FALSE` — constat terrain M2 (moteur sous frein serré, MES-004) | 🔴 échauffement/usure |
| **T64** | Plafond de palier vitesse laissé à `0` (réglage d'essai) | Restaurer la valeur d'exploitation |
| **T73** | Limite basse câble (bit6) : `Forbid` seul, **aucune escalade** vs bit5 haut qui a Méca D | Harmoniser |
| **T74** | Translation : `LimitSwitch` escalade `PowerCutOff` **sans délai** de confirmation | Harmoniser |
| **T43** | `SpeedMismatchThreshold/Timeout` à `0` = surveillance **inactive** | Définir ou afficher « inactif » |
| **T11** | `EmergencyStopOk` : pas de confirmation temporisée post-réarmement | Statuer |

---

## 4. 🚫 Ce qu'il ne faut PAS faire avant la livraison

Recommandation explicite — la tentation existe, l'échéance l'interdit.

| Chantier | Pourquoi s'abstenir maintenant |
|---|---|
| 🔴 **Refactor du nommage global** (`Req`/`Cmd`/`Sensor`, cap long terme PLAN_TASK) | Blast radius maximal, touche des variables sécurité (`TopPositionSensor` a **déjà** causé un bug de polarité). À faire après réception, jamais dans le rush |
| 🔴 **Refonte du mapping `PRG_09` (570 l.)** | Chaque nom est **mappé dans la visu physique**. Le gain est cosmétique, le coût est un reparamétrage IHM complet + risque de trou silencieux |
| 🟠 **T77 — refonte POO des FB de diagnostic** | Justifiée sur le fond (MES-005, fausse alarme `CANbusOnline`). Mais elle réécrit la chaîne de diagnostic bus **entière**. À traiter comme un lot dédié, avec essais bus réels — **pas mélangé** aux plans Simulation/Ergonomie |
| 🟠 **`FB_Input`/`FB_Output` généralisés à Winch/Translation** | Dette réelle, refactor de la logique contacteur = cœur sécurité. Après réception |
| 🟠 **Fusion/découpage des `PRG_xx`** | L'ordre d'exécution porte de la sémantique (latences d'1 cycle assumées et documentées partout). Y toucher casse des raisonnements validés |
| 🟡 **Historique d'alarmes en PLC** | Coûteux en RAM/CPU pour un service que l'IHM rend mieux |

🎯 **Règle de gel** : à partir de la livraison, **aucune modification du cœur sécurité**
(`FB_Safety_*`, `FB_Winch`, `FB_Brake`, `PRG_03`, `PRG_10`) hors correctif de défaut avéré et tracé
`MES-xxx`.

---

## 5. 🗺️ Phasage consolidé des 3 plans

> 🔄 **Révisé 2026-07-27** — décisions utilisateur : **simulation d'abord, informations MES ensuite**
> (D7), et **débrancher avant de rebrancher** (D8). Détail dans
> [PLAN_Rationalisation_Simulation §5](PLAN_Rationalisation_Simulation_v1.0.md).

| Vague | Contenu | Touche `CODE/` | RETAIN | Risque |
|---|---|---|---|---|
| **0 — Baseline** | Tag git + export CODESYS + bundle + **relevé des bypass RETAIN actifs** + valeurs `PERSISTENT` | non | — | nul |
| **1 — Sécurité isolée** 🔴 | **C5** (tempo/filtre Méca A) · **C2** (`ForbidAscent`) | oui, ciblé | non | 🟠 à valider **seule** |
| **2 — P1a · Forçages & orphelins** | Retrait `GVL_PLC_Tests` (64 l. + 31 pts) · `ST_Test*` · `FB_Sim_DigitalMirror` · `BypassRestoreDone` · **C4** · **C7** | oui | non ✅ | 🟢 |
| **3 — P1b · Débranchement sim** | Retrait instances `FB_Sim_*` + `OR`/`SEL` sim dans 8 PRG · `DeadmanRearmTimeout` figé `T#10S` | oui, large | non ✅ | 🟠 **essai machine réelle** |
| **4 — P2 · Frontière unique** | `ST_HardwareImage` · `FB_SimBench` · `PRG_00` §0 · `GVL_Simulation` 25→5 flags | oui, large | non ✅ | 🟠 le lot technique |
| **5 — P3 · Verrou & spec** | **C3** (gate style, T75) + règle `GVL_Simulation.` confinée · `AF_Partie-13 v2.0` | non | — | 🟢 |
| **6 — Livraison IHM #1** 🔄 | `FB_MotionInhibit` · `FB_FirstFault` · bandeau bypass · paramètres fantômes exposés | oui | ⚠️ **invalidé** | 🟠 |
| **7 — Livraison IHM #2** 🔄 | `FB_CommissioningMeter` · `FB_Preflight` | oui | ⚠️ **invalidé** | 🟢 |
| **8 — Opportuniste** | **C6** (`FB_CycleTime`) · Trace CODESYS (T79) · `IHM_VARIABLES_MIGRATION` | non/ciblé | — | 🟢 |

### ⛓️ Règles d'enchaînement — non négociables

1. **Vague 1 seule et validée avant tout le reste.** Un correctif de sécurité ne se noie pas dans un lot de nettoyage.
2. **Débrancher (2-3) avant de rebrancher (4).** On ne remplace pas une architecture pendant qu'on en démonte une autre. La vague 3 laisse un programme **complet, propre et validable sur machine réelle** — c'est le point de contrôle qui rend la vague 4 sûre.
3. 🎁 **Aucune vague ne casse une structure IHM mappée.** Le seul champ retiré (`.Test`) n'est mappé nulle part → **tout le chantier simulation se fait sans reparamétrage visu**, ce qui permet de le passer en premier. La perte des valeurs `RETAIN`/`PERSISTENT` au download est **acceptée (D10)** : relire la config restaurée avant tout mouvement.
4. **Vagues 6 et 7 = les seules à toucher des noms mappés dans la visu.** Elles ajoutent des champs consommés par l'IHM → à grouper pour ne faire qu'un reparamétrage par vague.
5. **La Trace CODESYS peut être faite immédiatement** — coût automate nul, débloque MES-008 tout de suite. Seule exception au séquencement.

⚠️ **Entre les vagues 3 et 4, aucun banc de simulation n'est disponible.** Acceptable avec M1/M2/M3
câblés ; sinon enchaîner sans pause.

### 🚪 Porte de sortie à chaque vague

| Contrôle | Attendu |
|---|---|
| Compilation CODESYS | 0 erreur / 0 warning |
| `run_all_gates.py` | PASS (⚠️ **C3 à corriger d'abord**, sinon la Gate style ne prouve rien) |
| Bundle PLCopenXML | régénéré |
| Bypass RETAIN après download | relevés et **remis à FALSE** si non voulus |
| `ConfigRestoredFromPersistent` | acquitté **après vérification** des valeurs, pas par réflexe |
| Registre MES | 1 entrée `MES-xxx` par vague |

---

## 6. 📊 Bilan net des 3 plans

| | Lignes ST |
|---|---|
| Retrait simulation / `GVL_PLC_Tests` / orphelins | **−210** |
| Correctifs dette (C2/C4/C5/C6/C7) | ≈ **+20** |
| Ergonomie MES (A/B/C/D/E/G) | **+370** |
| **Net** | **≈ +180 l. (+1,8 %)** |

🎯 **Message à retenir** : le projet ne peut plus maigrir de façon significative — le gros a été
retiré avec `PLC_TESTS`. Ce qui reste à gagner est ailleurs :

- **−3 mécanismes qui peuvent mentir** sur l'état de la machine (overrides, masquages de simulation, paramètres fantômes) ;
- **+1 machine qui explique elle-même pourquoi elle ne bouge pas** ;
- **6 constats d'audit** soldés avant que le client ne les découvre.

C'est un plan de **fiabilisation et de maintenabilité**, pas d'optimisation mémoire. L'annoncer
comme tel évite de juger le résultat au mauvais critère.

---

## 7. 🧷 Limites de ce plan

- Analyse **statique** : aucune exécution, aucun essai. Les priorités C5/T72 supposent le
  comportement décrit par l'audit et le registre MES, pas une mesure.
- **65 % du code n'a jamais été audité ligne à ligne** (`FB_Cycle`, `FB_Bucket`, chaîne codeur,
  `FB_Joystick`, `FB_Translation`) — l'absence de constat n'y vaut pas quitus.
- Les chiffrages de lignes des livrables Ergonomie sont des **estimations**, à ±30 %.
- L'impact IHM du retrait de `ST_Test*` dépend du mapping **réel** de la visu, non consultable ici :
  à vérifier avec le collègue en charge de la supervision avant la vague 3.
- ⚠️ Rappel : `ST_IHM_MANU` est figée (table transmise) — aucun champ n'y est ajouté par ces plans.
