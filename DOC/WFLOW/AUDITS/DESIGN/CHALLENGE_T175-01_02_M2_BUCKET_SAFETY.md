# 🪓 CHALLENGE T175-01 + T175-02 — Glissement M2 & Anti-traversée / Boot contradictoire benne

> **Type** : Challenge contradictoire (anti-yes-man) · **Lecture seule** `CODE/` · Criticité **C0**
> **Cible challenge** : `CADRAGE_T175-01_M2_SLIP_SAFETY.md` (Agent A) + Rapport Agent B (texte, aucun fichier)
> **Contrats** : `TASK_CONTRACT_T175-01` & `TASK_CONTRACT_T175-02`
> **Toutes références** : `fichier:ligne` code réel lu. ⛔ Aucun seuil/PLr inventé : toute valeur neuve marquée « exige visa humain ».
> ⛔ Aucune écriture hors du présent livrable ; aucun commit/push ; `CODE/`, `TASKS.yaml`, contrats intacts.

---

## 0. ⚡ Verdict global (sans complaisance)

| Livrable | Verdict | Justification (1 ligne) |
|---|---|---|
| **Agent A** (T175-01) | 🟠 **PARTIEL — diagnostic bon, solution non implémentable telle quelle** | Le trou « M2 bouge sans consigne pendant benne » (**FB_Bucket.st:141** surveille M1 seul ; Méca A/B exigent joystick au neutre **FB_Safety_Winch.st:235/247** ; Méca E masquée `BenneBusy` **PRG_04:657,717**) est bien identifié. MAIS : le bit proposé n'a **pas de bit libre** dans `ErrorId` (WORD 16 bits, tous consomment), et la classe **PowerCutOff** sur un discriminateur vitess/commande est **fortement faussement positive** (inertie au lâcher de consigne) → risque de coupure AU intempestive et de dégradation d'exploitation. |
| **Agent B** (T175-02) | 🟢 **SOLIDE — diagnostic exact + correctifs cohérents**, 2 limites | Les 2 points sont exacts : boot `IsOpen=TRUE/IsClosed=TRUE` non détecté (**FB_Bucket.st:198**), `ActiveOffsetValid` **jamais consommé pour gater le mouvement** (seul **PRG_04:1080** le publie ; rien ne le gate). Fix XOR non-régressif OK. Réserves : « ActiveOffsetValid vraie interlock » est mal ciblé (couvrirait tous défauts benne, pas que l'incohérence), et boot **physique** vs drapeau RETAIN toujours indétectable. |

**Verdict phase de patch : ❌ PAS ENCORE.** Les 2 livrables, en l'état, ne doivent **pas** passer en phase de code. Raisons exactes en §7. Les correctifs d'Agent B sont presque prêts (1 visa bloquant + 1 rework léger) ; la solution d'Agent A doit être **refaite** (bit budget + classe d'arrêt).

---

## 1. 🔍 Faits vérifiés (recroisement code réel)

| Affirmation agent | Vérif | Réf |
|---|---|---|
| M1 slip → `M1SlipDetected` + coupe M2 | ✅ | `FB_Bucket.st:141-148`, consommé `PRG_04:491` |
| `M1RefPosM` capturé à l'entrée Busy | ✅ | `FB_Bucket.st:245` |
| Méca A/B exigent `JoystickYNeutral AND NOT BenneHoldStillActive` | ✅ | `FB_Safety_Winch.st:235` (A), `247` (B) |
| `UncommandedSpeedThresholdMps` déclaré non câblé | ✅ | `FB_Safety_Winch.st:45` — jamais lu ailleurs |
| Méca E masquée par `BenneBusy := instBucket.Busy` | ✅ | `PRG_04:657` (M1), `717` (M2) → arm `FB_Safety_Winch.st:291` |
| Busy ne relit pas `M1_Busy/M2_Busy` | ✅ | `FB_Bucket.st:254-335` ; gate ne lit qu'entrée READY `234-240`, `BusyEdge` `242` |
| Boot `NOT IsOpen AND NOT IsClosed` seul testé | ✅ | `FB_Bucket.st:198-200` ; cas both-TRUE absent |
| `ActiveOffsetM=15.0` via `IsClosed` prioritaire | ✅ | `FB_Bucket.st:354` (`ELSIF CloseReq OR BucketState.IsClosed`) ; `GVL_PERSISTENT.st:67` `OffsetCloseM:=15.0` |
| Synchro consomme `instBucket.ActiveOffsetM` sans condition | ✅ | `PRG_04:425` (FB_WinchSync) ; Méca E M1 `PRG_04:656` / M2 `716` |
| `ActiveOffsetValid` jamais consommé pour gater | ✅ | grep CODE → seul `PRG_04:1080` publie vers IHM ; écrit en `FB_Bucket.st:364-367,178` ; jamais en entrée de gate |
| `CoherenceLimitM` mort (déclaré, jamais lu) | ✅ | `ST_fbBucket_Config.st:11`, init `GVL_PERSISTENT.st:70`=1.0, **0 occurrence de lecture** dans `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (grep) |
| 3 valeurs discordantes `CoherenceLimitM` | ✅ | AF `FB_Bucket_v1.0.md:281`=0.05 · GVL `GVL_PERSISTENT.st:70`=1.0 · tests `test_fb_bucket.st:7`=5.0 |
| `_BucketState` PERSISTENT RETAIN sans init flags | ✅ | `GVL_PERSISTENT.st:74` ; `ST_fbBucket_State.st` (IsOpen/IsClosed défaut FALSE) |

---

## 2. 🧱 Tableau des failles & effets de bord (F01..Fn)

| ID | Fichier:ligne | Description | Gravité | Impact | Recommandation |
|---|---|---|---|---|---|
| **F01** | `ST_Fault.st:20`, `FB_FaultCore.st:53`, `FB_Safety_Winch.st:114-131` | **AUCUN bit libre** dans `ErrorId` (WORD 16 bits, bits 0-15 tous consommés : socle 0-6, A-G 7-15). La « nouvelle Méca M2 » d'Agent A a besoin d'un bit qui n'existe pas. | 🔴 MAJEURE (bloquante pour A) | Ajouter un bit = **élargir `ErrorId` à DWORD** (casse toute l'interface `ST_Fault`, tous les masques `16#xxxx`, tous les consommateurs IHM/diag) OU créer une sortie dédiée hors masque. Agent A dit « câbler bit dans 16#2F84 » (**CADRAGE:197**) : infaisable en l'état. | **Rebuild de la solution A** : nouvelle sortie booléenne `M2SlipDetected` (hors `ErrorId`), OU widen `ErrorId`. Visa humain sur l'impact interface avant tout code. |
| **F02** | `FB_Safety_Winch.st:45`, `312`, `FB_Bucket.st:258-267` | **Inertie / lâcher de consigne → faux positif** : lâcher le joystick en plein close (`M2_StartStop:=FALSE`, `FB_Bucket.st:265`) → `MovementCommanded` retombe (`PRG_04:708` = `RelayFwd OR RelayRev`) alors que M2 **coaste encore** (vitesse>seuil) → la Méca vitesse/commande d'Agent A déclencherait **PowerCutOff (coupure AU)** sur un arrêt nominal. | 🔴 MAJEURE | Coupure AU intempestive sur une manœuvre normale → indisponibilité → **risque de bypass opérateur** (plus dangereux). Agent A justifie PowerCutOff par « câble libre non rattrapable » mais le discriminateur vitesse ne distingue pas slip réel d'inertie. | Ne PAS partir sur PowerCutOff instantané. **SafeStop d'abord + escalade si persistance** (miroir Méca E bit12→13, `FB_Safety_Winch.st:290-306`), fenêtre de décélération + confirmation (délai) avant déclenchement. Visa humain sur la classe. |
| **F03** | `FB_Safety_Winch.st:308-311`, `319-322` (Méca F/G existantes) | La nouvelle Méca M2 **n'est pas gagée sur `NOT InReferencingMode` ni `HomingSuspect`** dans la formulation d'Agent A (armement « ne pas exiger joystick neutre, ne pas masquer BenneBusy »). Pendant homing/proche homing, vitesse/commande transitoire → faux déclenchement. | 🟠 ÉLEVÉE | Faux défaut pendant mise en référence. | Gater l'armement sur `NOT InReferencingMode AND NOT HomingSuspect` (comme Méca D, `FB_Safety_Winch.st:216`). |
| **F04** | `FB_Safety_Winch.st:52-54` → `PRG_04:719-721` | **Timing multi-tâche non vérifié** : la vitesse `MeasuredSpeedMps` vient des Encodeurs (PRG_02, tâche acquisition) ; le bucket/FB_Safety tournent dans PRG_04. Si acquisitions 4ms/10ms/20ms désalignées, la fenêtre de « mouvement sans commande » doit tolérer ≥ 1 scan/lag et l'arrêt M2 (`PRG_04:321-324` note lag 1 scan assumé). | 🟠 ÉLEVÉE | Faux positifs/négatifs selon l'alignement de tâches. | Préciser la tâche d'exécution et le délai de confirmation **avant** de câbler. Visa humain plan tâches. |
| **F05** | `FB_Bucket.st:234-242` | **Refus du re-read BusyEdge (fix B) laisse `CloseReq/OpenReq` latches** : si `M1_Busy` devient actif après latch puis `MotionRequestActive` monte → BusyEdge bloqué, mais `CloseReq` reste armé → engagement « surprise » sur un ordre ultérieur sans re-passage par le gate `L234`. | 🟠 ÉLEVÉE | Fermeture imprévue plus tard, hors fenêtre d'intention opérateur. | Sur refus (Mx_Busy) : **désarmer la requête** (`CloseReq:=FALSE/OpenReq:=FALSE`) ; l'opérateur doit re-presser consciemment. |
| **F06** | `FB_Bucket.st:254-344` | **Relâchement joystick à mi-close = Timeout 60 s (pas de sortie propre)** : `M2_StartStop:=FALSE` (`L265`) mais `CloseReq`+`Busy` persistent, cible jamais atteinte → `TonTimeout` (`L132`) → défaut après 60 s. Aucun des 2 agents ne couvre ce « cancel manquant ». | 🟠 ÉLEVÉE (préexistant, aggravé par les patches) | Exploitant « bloqué » 60 s sur une simple pause ; défaut benne gèle aussi synchro. | Définir une condition de sortie sur relâchement (annuler et restaurer état, façon recul `L303-311`) — hors scope T175 mais à tracer/devoir-d'alerte. |
| **F07** | `FB_Bucket.st:364-366` | **Recommandation B « ActiveOffsetValid vraie interlock » mal ciblée** : `ActiveOffsetValid` inclut `Fault.ErrorId=0` (**L366**) → toute faute benne (timeout, homing, glissement) couperait la synchro, pas seulement l'incohérence. | 🟠 ÉLEVÉE (régression) | Après un défaut benne acquittable, synchro bloquée → empêche la reprise. | Créer une sortie **dédiée `BucketStateCoherent := NOT StateIncoherent`** pour l'interlock, et laisser `ActiveOffsetValid` pour le diagnostic/sélecteur d'offset. |
| **F08** | `GVL_PERSISTENT.st:70`, `ST_fbBucket_Config.st:11`, ancien code (backup `..._20260822.../FB_Bucket.st:131-137`) | **Régression non vue par B** : l'ancien code consommait `CoherenceLimitM` pour un contrôle **au boot de la position réelle** vs `LastPosM2Open/LastPosM2Close`. Le refactor actuel a **supprimé** cette cohérence position→flag : un boot « benne physiquement ouverte mais `IsClosed=TRUE` » (RETAIN périmée) est indétectable. Le fix XOR de B ne traite QUE l'incohérence logique des 2 flags, pas la divergence physique. | 🔴 MAJEURE (manque sécurité) | RETAIN périmée + position réelle discordante → offset de 15 m appliqué à la synchro sans détection. | **Restaurer** le contrôle position→flag au boot (avec `CoherenceLimitM` **re-validé**, AC6), ET le XOR. Visa humain sur la valeur de `CoherenceLimitM` (3 sources discordantes). |
| **F09** | `PRG_04:321-324`, `FB_Bucket.st:221-230` | **Coordination A↔B pendant slip M1** : lors d'un slip M1 en cours de close, `M1SlipDetected` (position 1 m, `FB_Bucket.st:141`) coupe M2 (`L224`) ; Agent B coupe M2 sur `M1_Busy` ; si la coupure M2 fait coaster M2, la Méca « M2 sans commande » d'Agent A **re-déclenche** → double/escalade AU. | 🟠 ÉLEVÉE | Escalade intempestive et messages défauts multiples/masqués. | **Arbiter une seule source** : si la coupure vient d'un défaut, masquer la nouvelle Méca M2 le temps de la décélération. Unifier les causes. |
| **F10** | `TASK_CONTRACT_T175-02:16-21` | **AC2 vs AC3 internes T175-02** : AC2 « si M2_Busy devient actif → quitte », AC3 « M2_Busy légitime → pas d'avortement ». **Insatisfaisables ensemble sur M2.** Agent B le relève et tranche « M1 abortif seul ». Bonne résolution, reste **à entériner**. | 🟡 MOYENNE (ambiguïté) | Ambiguïté résiduelle → implémentation litigieuse. | Visa humain : acte « M2_Busy jamais abortif, M1_Busy abortif » (couvre AC3 + conservation « M2_Busy effet normal » `TASK_CONTRACT_T175-02:51`). |
| **F11** | `test_fb_bucket.st:173-212` | **TC-P10-025.2** injecte `M2_Busy=TRUE` en cours de Busy et **asserte Busy+M2_StartStop conservés** (commentaire `L174-176` « bloc Busy L254+ ne relit pas »). Le fix de B (M1 abortif seul) NE brise PAS ce test (M2_Busy non abortif). B **surestime** « tout correctif de relecture invalide le test ». | ℹ️ INFO (correction factuelle) | Blocage test à tort / retard. | Seul un fix « M2_Busy abortif » invaliderait ce test. Avec M1-only, ajouter un TC miroir `M1_Busy → avortement`. |
| **F12** | `FB_Bucket.st:234,237` | Ordre simultané Ouvrir+Refermer : `IF CmdOpen ... ELSIF CmdClose ...` → **Open gagne.** Bénin mais non testé, comportement silencieux. | ℹ️ INFO | Priorité non documentée. | Ajouter un TC « boutons simultanés » et documenter la priorité. |

---

## 3. ⚔️ Contradictions A ↔ B (explicites)

| # | Contradiction | Détail | Résolution |
|---|---|---|---|
| **C1** | **Budget de bits asymétrique** | FB_Bucket garde des slots causes libres (0-4 utilisés, 5-15 libres) → le correctif B (M1_Busy → cause 5) est **implémentable**. FB_Safety_Winch `ErrorId` **plein** (16/16 bits) → la nouvelle Méca A **ne l'est pas** tel quel (F01). | A doit être **refaite** (sortie dédiée ou widen). B peut passer. |
| **C2** | **Coupe M2 pendant slip M1 : 2 producteurs** | B coupe M2 sur `M1_Busy` (interlock benne) ; A coupe M2/PowerCutOff sur « M2 sans commande ». Pendant un slip M1 qui arrête M2 en commanded-stop, **les deux s'enclenchent** et se re-déclenchent → AU double/escalade (F09). | Masquer la Méca A pendant la fenêtre de décélération post-défaut. Un seul décisionnaire de coupure. |
| **C3** | **ActiveOffsetValid interlock (B) vs nouvelle Méca consommant la synchro (A)** | Si on gâte la synchro sur `ActiveOffsetValid` (recommandation B), elle se coupe sur **tout défaut benne** ; or la Méca A repose sur la continuité de la synchro/contexte M2. Les deux correctifs s'empêchent mutuellement si câblés naïvement. | Interlock B scoper sur `BucketStateCoherent` seul (F07), découplé de Méca A. |
| **C4** | **M2_Busy abortif ?** | A considère M2_Busy comme effet légitime pendant benne (cohérent AC3). B pose la question AC2. Pas de contradiction factuelle mais **décision commune** requise : M2 jamais abortif (sinon TC-P10-025.2 meurt et la manœuvre s'auto-torpedo). | Visa humain unique couvrant les 2 contrats. |

**Bilan** : A et B **ne se contredisent pas** sur le fond (complémentaires : A = slip M2 vitesse/commande, B = interlock M1_Busy + boot XOR) mais **interfèrent** sur : budget de bits (C1), double-coupure slip (C2), interlock sync (C3), sémantique M2_Busy (C4). À coordonner dans un seul patch cohérent.

---

## 4. 🧪 Cas de test manquants (impératifs pour le safety case)

> En plus de S1-S11 (A) et TC-P10-023..048.1, TC-P10-047.2 rouge (B). **Obligatoires :**

| # | Test | Cible | Pourquoi (faille couverte) |
|---|---|---|---|
| T1 | **Lâcher joystick à mi-close → AUCUN slip M2, AUCUN PowerCutOff, arrêt propre** | Méca A / FB_Safety | F02 : inertie = faux positif le plus probable. C'est LE test anti-faux-défaut qui valide/invalide la classe A. |
| T2 | **Boot IsOpen=TRUE ET IsClosed=TRUE + 1er mouvement synchro → pas de consigne 15 m, motion bloquée** | FB_Bucket + PRG_04 | F08 : prouve que l'interlock gâte réellement (pas seulement le flag IHM). |
| T3 | **Boot divergence position→flag (RETAIN périmée)** : `CablePosM2` ↔ `IsClosed` discordants | FB_Bucket boot | F08 : couvre le trou physique que le XOR ne couvre pas. |
| T4 | **Reset pendant défaut (slip M1_Busy en cours)** → pas de redémarrage auto, re-latch si cause présente | FB_Bucket socle | No-auto-restart ISO 13849 §5.2.5. |
| T5 | **M1_Busy devient actif pendant BUSY → avortement + coupe M2 + latch** (miroir de TC-P10-025.2 mais M1) | FB_Bucket | F11 complet : le pendant M1 du test B. |
| T6 | **M2_Busy devient actif pendant BUSY → PAS d'avortement** (non-régression TC-P10-025.2) | FB_Bucket | C4 : verrouille la doctrine « M2 jamais abortif ». |
| T7 | **Refus BusyEdge puis re-requête** → aucune fermeture « surprise » résiduelle (CloseReq désarmée) | FB_Bucket | F05. |
| T8 | **Slip M1 + coupure M2 → aucun AU double** (la Méca A est masquée pendant décélération) | FB_Safety + PRG_04 | F09 / C2. |
| T9 | **Relâchement joystick à mi-close → pas de Timeout 60 s bloquant** (sortie propre ou comportement documenté) | FB_Bucket | F06. |
| T10 | **Homing en cours → La Méca M2 ne déclenche pas** (`NOT InReferencingMode`) | FB_Safety | F03. |
| T11 | **Simulation/multitâche (alignement 4/10/20ms)** : vitesse M2 + commande déphasées → pas de faux positif/négatif | PRG_04 | F04. |
| T12 | **Boutons Ouvrir+Refermer simultanés → priorité documentée** | FB_Bucket | F12. |

Les TC **T1, T8, T11 sont bloquants** pour accepter la solution d'Agent A. T2, T3, T5 sont bloquants pour B.

---

## 5. 🛑 Non-conformités safety (ISO 13849 / IEC 61508)

| # | Non-conformité | Norme | Correction exigée |
|---|---|---|---|
| NC1 | **Absence d'interlock sur `ActiveOffsetValid`** : une valeur d'offset incohérente (15 m) est **appliquée** à la synchro (`PRG_04:425,716`) sans aucun blocage — le signal n'est que diagnostic (`PRG_04:1080`). | ISO 13849 (safety function non réalisée ; erreur systématique) | Faire de la cohérence un **vrai interlock** (F07) gâtant le mouvement synchro ET la consigne benne. |
| NC2 | **Défaut « no auto-restart » non démontré** sur les nouveaux latches (A et B) : le re-latch immédiat si cause persistante doit être prouvé par TC (T4), et `Reset` doit rester un **front conscient** (`FB_Bucket.st:102-110`). | ISO 13849 §5.2.5 | TC dédié + revue de la chaîne Reset. |
| NC3 | **Classe d'arrêt non justifiée / disproportionnée** (Agent A) : PowerCutOff (coupure AU) proposée pour un détecteur vitesse instable → risque de nuisance élevé → risque de **bypass opérateur**. | ISO 13849 (availability vs safety ; common-cause) | **SafeStop + escalade** (miroir Méca E), pas PowerCutOff immédiat. Visa humain PLr/type de stop. |
| NC4 | **Détection mono-canal du slip M2** (vitesse codeur seule, `PRG_04:719-721`), alors qu'elle alimenterait une fonction `PowerCutOff`. | IEC 61508 / Cat.2-3 (redondance, diagnostic) | Assumer mono-canal explicitement (déjà doc `FB_Safety_Winch_v1.0.md §3` TC-P10-001) ET au moins croiser position+vitesse, ou documenter le PLr résultant. |
| NC5 | **Aucun capteur/calcul safety distance** pour « croisement/torsion de câbles » : les seuils (1 m slip, 2 m, 2,5 m, 0,02 m/s) sont présents mais une **justification géométrique / cinématique** du risque croisement n'est pas formalisée. | Distance/calcul safety non justifié (§ mission) | Note de calcul cinématique M1/M2 (offset, désynchronisation) validée au **visa terrain**. |
| NC6 | **`CoherenceLimitM` mort + 3 valeurs discordantes** (0.05 / 1.0 / 5.0) : config silencieuse active. | ISO 13849 (config invalide) | AC6 : soit re-consommé par la cohérence boot (F08) avec **une** valeur visée, soit retiré + maj AF-10 (`FB_Bucket_v1.0.md:281`). |
| NC7 | **Boot physique non validé** : persistance RETAIN (`GVL_PERSISTENT.st:74`) ne peut distinguer « benne physiquement vraie » de « RETAIN périmée » sans capteur de position benne dédié. | Common-cause / diagnostic | **Vérification terrain** obligatoire + contrôle position→flag au boot (F08). |

---

## 6. 🕹️ Ergonomie / exploitant (challengé)

| Point | Constat | Action |
|---|---|---|
| Réarmement après coupure M2 (B) | Pas de sortie propre définie : restauration `IsOpen/IsClosed` (`FB_Bucket.st:306,329`), refonctionnement OK en général, mais « Busy bloqué → timeout 60 s » possible (F06). | Message défaut clair + rearmement front Reset. |
| Faux PowerCutOff (A) | Risque fort de coupure AU sur lâcher de consigne → exploitant qui voit la machine couper « sans raison » → tendance au bypass. | **C'est le point d'ergonomie #1 à traiter avant tout patch A.** |
| IHM cohérence boot | `ActiveOffsetValid`/`StateIncoherent` publiés (`PRG_04:1080`), mais l'exploitant n'a aucun **moyen d'agir** (le flag ne bloque rien). | Ajouter un état/gating actionnable + procédure de réarmement (confirm ouvert/fermé `FB_Bucket.st:204-217` déjà présent, à exposer). |
| Reprise après coupure AU | `_BucketState` RETAIN survit ; sans contrôle boot robuste, reprise en discordance. | Contrôle boot + re-confirmation MAINT avant reprise synchro. |

---

## 7. 🗂️ Priorisation & Visas humains bloquants (ordonnés)

### Ordre d'implémentation le plus sûr

| Ordre | Lot | Contenu | Blocage |
|---|---|---|---|
| **1 (déjà possible)** | **Correctif B — Boot** | XOR boot (`FB_Bucket.st:198-200`), **restauration cohérence position→flag** (F08), **consommation `CoherenceLimitM` ou retrait (AC6)**, sortie `BucketStateCoherent` dédiée + **interlock synchro via PRG_04/`instWinchSync`** (NC1/F07), `ActiveOffsetValid` restée diagnostic. | Visa V1 (sémantique), V2 (CoherenceLimitM), + T2/T3 |
| **2** | **Correctif B — Anti-traversée** | Re-read `M1_Busy/M2_Busy` dans BusyEdge + **désarmement requête sur refus** (F05) ; « M1_Busy en BUSY → coupe M2 + latch » (M1 seul, jamais M2, C4) ; **doctrine d'arrêt** (catégorie/rampe ou non). | Visa V4 (doctrine d'arrêt), T5/T6 |
| **3 (rework A)** | **Slip M2** | **REFADRE** : sortie dédiée (pas de bit ErrorId), SafeStop + escalade (pas PowerCutOff immédiat), gait `NOT InReferencingMode/HomingSuspect`, masqué pendant décélération post-défaut (F09), délai/fenêtre multi-tâche (F04). | Visa V3 (classe/PLr), V5 (sémantique stop), T1/T8/T11 |
| **4** | **UX / devoir-d'alerte préexistant** | Sortie propre sur relâchement joystick à mi-benne (F06), priorités documentées (F12). | Visa exploitation |

> ❗ **Règle** : viser **avant** chaque lot (contrats T175 AC5/AC2/AC3 + `alert_duty` `TASK_CONTRACT_T175-01:59-62`, `T175-02:61-63`). Jamais de code avant.

### Visas humains bloquants (liste ordonnée)

| Visa | Question à trancher | Lot concerné |
|---|---|---|
| **V1** | Sémantique « M2_Busy jamais abortif / M1_Busy abortif » (AC2 vs AC3, C4) — doit couvrir LES 2 contrats. | 2, 3 |
| **V2** | `CoherenceLimitM` : une **seule** valeur (0.05 / 1.0 / 5.0) + qui la consomme (cohérence boot) — ou retrait + maj AF-10. | 1 |
| **V3** | **Classe d'arrêt du slip M2** : SafeStop+escalade vs PowerCutOff. Recommandation challenge : **SafeStop d'abord** (F02). | 3 |
| **V4** | **Doctrine d'arrêt M1_Busy en BUSY** : catégorie safety / temps de rampe / SafeStop vs PowerCutOff (alert_duty T175-02). | 2 |
| **V5** | **Impact interface** : widen `ErrorId` DWORD OU sortie dédiée `M2SlipDetected` (F01). | 3 |
| **V6** | **Justification cinématique/distance** croisement-torsion câbles (NC5) — note de calcul + validation terrain. | 1-4 |
| **V7** | **Vérification terrain** : RETAIN vs position réelle benne au boot, capteur position benne (NC7, TC-P10-034). | 1, 2 |

---

## 8. 🧭 Conclusion — Patch maintenant ou pas ?

> **❌ NON, pas en l'état.** Et **pas dans le même ordre** : Agent B d'abord, Agent A doit être refaite.

1. **Agent B peut être implémenté** après V1, V2, V4 + T2/T3 (lot 1 puis lot 2). Son diagnostic est exact et ses correctifs (XOR, interlock cohérence via sortie dédiée, M1-only anti-traversée) sont structurants et non-régressifs. **1 rework léger** (F07 : sortie `BucketStateCoherent` dédiée au lieu d'overloader `ActiveOffsetValid`).
2. **Agent A est bloqué** par **F01 (pas de bit libre)** et **F02 (faux PowerCutOff)** → la solution écrite est **inimplémentable telle quelle** et **dangereuse en l'état** (risque d'indisponibilité → bypass). Elle doit être **refaite** en lot 3 (sortie dédiée + SafeStop/escalade + fenêtre de décélération).
3. **Condition de sécurité** : une **seule source de coupure M2** pendant le slip (masquage croisé A↔B, C2/F09) et interlock synchro découplé (C3/F07).

**Donc** : on patch le boot + l'anti-traversée (B) avec visas, on re-cadre la détection slip M2 (A), et **on n'accepte aucun patch sans les TC bloquants T1/T2/T3/T5/T8/T11 verts**.

---

## 9. ✅ Conformité mission

- ⛔ **Aucun fichier `CODE/`, `TASKS.yaml` ni contrat modifié.**
- ⛔ **Aucun commit / push / édition de source.**
- ✅ Seule écriture : le **présent livrable** `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md`.
- 🔬 Tous constats ancrés `fichier:ligne` code réel. Seuils non validés marqués « exige visa humain ».
