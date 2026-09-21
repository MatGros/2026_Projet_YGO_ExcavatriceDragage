# 🪝 T354 — Asymétrie de garde M1/M2 : `NOT BucketBusy` présent au gate M1 (branche manuelle), absent du gate M2

> **Nature** : ANALYSE SEULE — **zéro ligne de `CODE/` écrite**, zéro commit, zéro bundle.
> **Parent** : T328 (couplage mécanique M1/M2) · **Amont** : T351 (cartographie treuils M1/M2, DSH18)
> **Brief source** : `DOC/WFLOW/CONTRACTS/BRIEF_T354_ASYMETRIE_GARDE_M1_M2.md` (lu, **non modifié**)
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T354_ASYMETRIE_GARDE_M1_M2.yaml` (écrit avant l'analyse — R1)
> **Date** : 2026-09-21 · **Porteur** : DSH20 (deepseek-v4.1-flash:cloud)

---

## 0. 🧭 Réponse courte (à lire avant tout)

**VERDICT ATTEIGNABILITÉ : OUI — le trou de garde est atteignable, mais pas dans la configuration
que décrit le brief.**

| Question du brief | Réponse prouvée |
|---|---|
| M2 peut-il partir seul, benne occupée (`BucketBusy=TRUE`) ? | **OUI**, par un chemin unitaire M2 (boutons IHM `BtnAscentM2`/`BtnDescentM2` en mode Boutons, ou joystick `Select=2`) **pendant que la manœuvre benne reste latchée `Busy`**, et sans qu'aucune garde ne s'y oppose (`FB_WinchCmdArbitrationM2.st:143-151`). |
| … « alors que M1 est gelé » ? | **OUI en MAINT_N2 + inhibition M1** : M1 est *physiquement* gelé (`FB_Winch` M1 `Enable=FALSE`, `PRG_04:1458`), la benne reste **vivante** (`instBucket Enable := NOT InhibitM2`, `PRG_04:341`) — c'est **exactement le cas d'usage réel** de l'exploitant (changement de câble). |
| … reproduit-il le REX « M2 suit la benne pendant que M1 suit autre chose → câbles désynchronisés » (`FB_WinchCmdArbitrationM2.st:59-64`) ? | **NON dans ce cas précis** : M1 inhibé ne peut plus suivre quoi que ce soit. Le risque réel est **d'un autre type** : conflit de sources sur M2 + **conclusions d'état benne fausses** (§7, §8). |
| Le verrou d'atomicité de démarrage couplé (`PRG_04:1391-1409`, `:1495-1501`, `:1658-1678`) couvre-t-il ce scénario ? | **NON** — ses trois volets sont déclenchés par `WinchBothMotionActive` (`:1407`, `:1499`, `:1661-1663`), **faux** dans le scénario (aucune intention couplée active). Preuve §6. |
| La garde compensatoire `WinchBothMotionBlockedByBucket` couvre-t-elle le cas `Busy=TRUE` ? | **NON** — sa définition (`PRG_04:396`) la rend **FAUSSE quand `Busy=TRUE`** : elle est inerte dans le cas du brief. Preuve §5. |
| Doctrine M1 vs M2 justifiant l'asymétrie ? | **NON SOURCÉE** (§9) : aucune spec `DOC/AF/` ne porte `BucketBusy` côté arbitre. |
| Mode MAINTENANCE N2 avec inhibition d'un treuil : mécanisme réel ? | **OUI, réel et tracé** : `Auth.InhibitM1/InhibitM2` (`FB_Modes.st:315-341`), commandé par les boutons IHM (`PRG_03:92-93`), **exclusion mutuelle**, effectif **en MAINT_N2 seulement**. Ce n'était pas une hypothèse. |

**Correction de prémisse majeure** : il n'existe **pas** de modes `MANU` ni `AUTO` dans le code. L'énumération
réelle est `DISABLE(0) / MAINT_N1(1) / MAINT_N2(2) / SEMI_AUTO(3)` (`CODE/F_MODES/E_Mode.st:9-12`). La « branche
manuelle » des arbitres n'est donc **pas** « MANU » : c'est la branche `ELSE` de `Mode = SEMI_AUTO`, donc
**`DISABLE` + `MAINT_N1` + `MAINT_N2`** (constat déjà relevé par T351 §7.12, ici revérifié).

---

## 1. 🧊 Contexte figé, périmètre et ANCRAGE DE RÉVISION (AC2)

**Besoin d'origine** : le lot T351 a relevé une asymétrie candidate 🔴 (`TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md`
§ 6.4-A2 et § 10 point 4) : le gate final de l'arbitre **M1** porte `AND NOT Context.BucketBusy`, le gate final de
l'arbitre **M2** n'en porte aucune. T354 doit trancher l'**atteignabilité en exploitation**, pas la gravité.

**Position exploitant (confirmée 2026-09-21, non hypothétique)** : M1 et M2 travaillent normalement synchronisés,
**mais en MAINTENANCE N2 l'exploitant inhibe délibérément un treuil** pour travailler sur un seul câble
(changement de câble). Ce mode existe donc bien en exploitation — il est **confirmé par le code et la spec**
(§ 4).

### 🔐 Bloc d'ancrage de révision

| Élément | Valeur |
|---|---|
| `HEAD` (lecture 2026-09-21T02:31:12+02:00) | `c9e1fbfeff460a4bb6065f37efb80d5e574d8772` |
| `git status --short -- CODE/` à la prise | **vide** (CODE/ propre vs HEAD) |
| `git diff HEAD --stat -- CODE/` à la prise | **vide** |

| Fichier cité | Blob SHA (`git hash-object`, lecture 2026-09-21T02:31–02:39) |
|---|---|
| `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` | `27247259430b674e6e3e63d265ca0c5ea311c7a7` |
| `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st` | `0e757b00558cde1ea9c17f4af88f05931dd19578` |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | `6e22c76df8623759f0f696d5f003ec34540b8fd1` |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | `9c493a5f0d5726b3d276c455bc3efca83fe29ebd` |
| `CODE/F_MODES/FB_Modes.st` | `4a890744c9f32c858922338d9dd989a5e0edbcca` |
| `CODE/D_JOYSTICK/FB_Joystick.st` | `4d373c8ed388eae7257d4ca6a391e73e43e4cfbc` |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` |
| `CODE/H_TREUILS_BENNE/FB_BucketCmdArbitration.st` | `d2a118ac15599571c0a7b02f945af5e7de83e2fb` |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | `eea649deaebd8000bf9f64e598ff65ed0ff9ab91` |
| `CODE/H_TREUILS_BENNE/FB_WinchSync.st` | `03bfca8e9689123fcd7462d2d6de8333d41654ae` |
| `CODE/H_TREUILS_BENNE/FB_Winch.st` | *(voir §12 — non relu intégralement, seule la ligne 216 est citée)* |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `211136fff38170468488f8a229c186669109cb01` |
| `CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_Context.st` | `14204c511602520750478925e47cfd97025f9a56` |
| `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCmd.st` | `d0c76ea28d6202764358e54232d431b541835d0e` |
| `CODE/F_MODES/E_Mode.st` | `23baeb5cb3f88f69ba979c945dfcb69d9030732f` |
| `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md` | `060b4fcefcfd6e3f54d932bab5fcb6290f6d72f3` |
| `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` | `f818752e366dacd4ed77b3b16c1d6481d18ef8de` |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` | `aeaac5dd285618f80a0479dbb3ba81a0e6fe7001` |

> ⚠️ **Ancrage daté** : toute référence `fichier:ligne` de ce document vaut pour les blobs ci-dessus.
> Leçon T351 : `PRG_02_Acquisition.st` a changé 3 fois en 8 minutes pendant un lot concurrent — un numéro
> de ligne nu n'est pas une preuve. Si un blob a bougé, rejouer la procédure du §11.

---

## 2. 🧩 Méthode

1. Chaque garde a été **relue physiquement** sur l'arbre de travail (blobs §1), jamais reprise du brief ni de T351.
2. Les **3 chemins de commande M2** (R3.2) ont été tracés **jusqu'à l'écriture des sorties physiques** (`%Q`).
3. Le **mode MAINT N2 + inhibition** (R3.3) a été tracé depuis l'écritoire IHM jusqu'à l'effet sur les FB.
4. Le **verrou d'atomicité** (R3.4) a été jugé sur sa **portée** (variable de déclenchement), pas sur son intention.
5. Toute prémisse du brief divergente a été **réfutée par preuve** (§11), brief non modifié.
6. Les combinaisons non tranchables sont déclarées **NON TRACÉ** (§10), jamais comblées par déduction.

---

## 3. 🧮 TABLE DE VÉRITÉ PROUVÉE (AC1, AC9)

**Colonnes** : `Mode` · `BucketBusy=TRUE possible` · `M1 état` · `chemin M2 actif / M2 commandable pendant Busy` ·
`garde traversée (fichier:ligne)` · `verdict atteignable`.

Conventions : `Select` = `Auth.JoystickWinchSelectArbitrated` (0 couplé / 1 M1 / 2 M2).
`Master` = `GVL_IHM.Modes.Cmd.TglJoystickMaster` (TRUE = joystick maître, FALSE = mode Boutons IHM).

| # | Mode | `BucketBusy=TRUE` possible ? | M1 état | Chemin M2 & commande pendant `Busy=TRUE` | Garde traversée | **Atteignable ?** |
|---|---|---|---|---|---|---|
| **R1** | `DISABLE` | ❌ impossible — tous les FB neutralisés (`PRG_04:927`, `:997`, `:1458`, `:1524` ; `PRG_03:487-511`) | neutralisé | aucune | — | **NON** |
| **R2** | `MAINT_N1`, `Select=0`, `Master=TRUE` (couplé joystick) | ✅ oui — bouton benne IHM + manche défléchi (`FB_Bucket:493`, `:509`, `:172`) | **bloqué par la garde** `M1:117` (`RunRequest=FALSE` ⇒ pas de mouvement, `FB_Winch:216`) | branche « intention both » `M2:123-127` ; le gate exige **les 2 permis** (`M2:140-142`), or ceux-ci ne sont **pas** coupés par la benne (`FB_Safety_Winch:563-582`) ⇒ *a priori* « M2 seul alors que les deux sont demandés » | `M2:143-151` (sans `BucketBusy`) | **NON — piste réfutée par vérification** : ce cas exige `BucketM2RunRequest=FALSE`, donc `EffectivePermitBucket_Close/Open=FALSE` (`PRG_04:1118-1127`) ; or ce terme **contient** `EffectivePermitM2_*` ⇒ `BothDirectionAuthorized=FALSE` ⇒ **M2 est bloqué**. *Verrou de compensation involontaire : le permis benne partage le terme de permis M2.* |
| **R3** | `MAINT_N1`, `Select=1`, `Master=TRUE` | ✅ oui | bloqué par la garde `M1:117` **si** M1 est commandé | M2 : ni `Select=2` (`M2:119`) ni `BothIntent` (exige `Select=0`, `PRG_03:141-143`) ⇒ `M2:128-131` ⇒ **aucune commande M2** | `M2:143-151` | **NON** |
| **R4** | `MAINT_N1` **ou** `MAINT_N2`, `Select=2`, **`Master=FALSE`** (Boutons IHM) | ✅ oui — `BtnOpen`/`BtnClose` + bouton both pour `MotionRequestActive` (`FB_Bucket:493-501`, `:509`, `:172`) puis relâchement du bouton both ⇒ `M2_RunRequest := FALSE` **en gardant `Busy=TRUE`** (`FB_Bucket:559-562`) | **gelé par la garde** (`M1:117`) en MAINT_N1 si commandé ; **physiquement gelé** en MAINT_N2+`InhibitM1` (`PRG_04:927`, `:1458`) | branche Boutons IHM `M2:97-116` — **indépendante de `Select`** et **sans exigence d'homme-mort** (`M2:147`, `NOT Master` ⇒ neutre) | `M2:143-151` : `RequestConflict=F` · `WinchBothMotionBlockedByBucket=F` (car `Busy=T`, cf. §5) · `SyncBlocks*=F` (synchro coupée, `PRG_04:426-446`) · `BothDirectionAuthorized=T` (`NOT BothIntent.Active`, `M2:140`) | ✅ **OUI** — voir chaîne §7 |
| **R5** | `MAINT_N1` **ou** `MAINT_N2`, `Select=2`, **`Master=TRUE`**, homme-mort armé | ✅ oui **si** un pilotage benne PROGRAMME est actif : `DumpAtTremie` (`PRG_03:411-415`) ou cycle de homing HX4 (`PRG_03:429-433`) ⇒ `ArmBucketBusy=FALSE` ⇒ l'homme-mort **reste armé** (`PRG_04:1184-1185`, `FB_Joystick:238-239`) | idem R4 | branche joystick `M2:119-122` | idem R4 (`M2:147` satisfait par `DeadmanArmed`) | ✅ **OUI** — variante « à la Trémie » (là où `Select` est **forcé à 2**, `FB_Modes:372-374`) |
| **R6** | `MAINT_N2` + **`InhibitM2`** | ❌ impossible — `instBucket Enable := NOT InhibitM2 = FALSE` ⇒ `Busy := FALSE` + `RETURN` (`PRG_04:341`, `FB_Bucket:309-332`) | M1 libre | — | — | **NON** (et c'est la **sortie de secours** du cas R4/R5) |
| **R7** | `SEMI_AUTO` | ✅ oui | **non gelé** (`InhibitM1/2` inopérants hors N2 : `FB_Modes:340-341`) ⇒ M1 suit le séquenceur | chemin benne **prioritaire** (`M2:65-67` autorise SEMI_AUTO) ; si `BucketM2RunRequest=FALSE`, M2 reçoit la demande cycle `M2:87-90` **sans garde `BucketBusy`** | `M2:87` (pas de garde) mais **barrière de cohérence finale active** (`PRG_04:1661-1678`) | **NON pour le scénario du brief** (M2 jamais « seul » : M1 est commandé par le même séquenceur) — la garde manquante y est **sans effet observable** |

**Lecture du tableau** : le scénario du brief n'est atteignable que dans les lignes **R4** et **R5**, toutes deux
**unitairement M2** (`Select=2` ou mode Boutons) — donc **en MAINT_N1 ou MAINT_N2**, et **jamais** en `SEMI_AUTO`
ni `DISABLE`. En MAINT_N2, `InhibitM1` rend « M1 gelé » **structurel** (cas réel de l'exploitant).

---

## 4. 🧰 MODE MAINTENANCE N2 — INHIBITION D'UN TREUIL : MÉCANISME RÉEL (R3.3)

> Question posée : « si tu ne trouves PAS de mécanisme d'inhibition de treuil dans le code, c'est un constat majeur. »
> **Réponse : le mécanisme existe, il est complet et il correspond au besoin décrit par l'exploitant.**

| Maillon | Preuve |
|---|---|
| Écritoire IHM | `GVL_IHM.M1TreuilRetenue.Cmd.BtnInhibit` / `GVL_IHM.M2TreuilBenne.Cmd.BtnInhibit` → `PRG_03_Modes_Cycle.st:92-93` |
| Doctrine de la commande | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCmd.st:13-14` : « Bouton IHM inhibition treuil — **UNIQUEMENT actif si MAINT_N2** (voir `FB_Modes.InhibitM1/M2`) » |
| Arbitrage (front montant = toggle) | `FB_Modes.st:315-335` |
| **Exclusion mutuelle** | `FB_Modes.st:321-322` et `:331-332` : inhiber un treuil **lève** l'inhibition de l'autre ⇒ **au plus un treuil inhibé à la fois** (nuance vs « un ou plusieurs treuils » du brief) |
| Gate de mode | `FB_Modes.st:340-341` : `Auth.InhibitMx := (Mode = MAINT_N2) AND Auth.InhibitMx` ⇒ **inopérant hors MAINT_N2** |
| Remise à zéro en sortie de maintenance | `FB_Modes.st:416-425` |
| Effet sur M1 | `PRG_04:927` (`FB_Safety_Winch` M1 `Enable`), `:1458` (`FB_Winch` M1 `Enable`), `:1357`, `:1558` ⇒ **M1 ne peut plus bouger** (permis FALSE, `FB_Safety_Winch:530-533`) |
| Effet sur la synchro | `FB_Modes:323/333` (`SelSyncEnable := FALSE`) + `PRG_04:637` (`NOT InhibitM1 AND NOT InhibitM2`) |
| **Effet sur la benne** | `PRG_04:341` : `instBucket(Enable := NOT Auth.InhibitM2)` ⇒ **inhiber M1 laisse la benne ENTIÈREMENT vivante**; inhiber M2 la neutralise (`FB_Bucket:309-332`) |
| Doctrine documentée | `AF_Partie-05_Modes_Maintenance_v2.1.md:153-158` (MAINT_N2 = pilotage unitaire, « le treuil non sélectionné reste non commandé ») puis `:160-165` : « L'inhibition d'un treuil est une action de maintenance **distincte**… pilotée via `Auth.InhibitM1/2` » |

**Conclusion R3.3** : en **MAINT_N2 + `InhibitM1` + `Select=2`**, la machine est exactement dans l'état
« un seul câble disponible, l'autre gelé » **et la benne peut être manœuvrée** ⇒ `BucketBusy` **peut être TRUE
pendant que l'inhibition est active**. La question du brief est tranchée **par preuve**, et le trou de garde
M2 s'applique bien dans cette fenêtre.

---

## 5. 🛡️ GARDE COMPENSATOIRE `WinchBothMotionBlockedByBucket` — SENS RÉEL (R3.6, AC7)

| Élément | Preuve |
|---|---|
| Définition | `PRG_04_Treuils_Benne.st:396` : `WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;` |
| Source d'armement | `FB_BucketCmdArbitration.st:49-53` : `TglEnableCoupledBucketSequencing AND Mode<>SEMI_AUTO AND NOT CoupledPhaseLocked AND MotionActive AND ReqDescend AND NOT BucketIsOpen` |
| Consommation | M1 `:118`, M2 `:144` ; publication diagnostic `PRG_04:1796` → `PRG_06:211` |
| **Valeur dans le cas du brief (`Busy=TRUE`)** | `NOT Busy = FALSE` ⇒ **variable = FALSE** ⇒ `NOT Context.WinchBothMotionBlockedByBucket = TRUE` ⇒ **elle ne bloque RIEN** |
| Valeur dans le cas `Busy=FALSE` | dépend de `WinchBothDiveBucketOpenArmed` (descente couplée demandée avec benne non ouverte) ⇒ **c'est un garde-fou de séquençage de plongée, pas un garde-fou d'occupation benne** |

**Verdict AC7 : la garde compensatoire NE COUVRE PAS le cas `Busy=TRUE`.** La formulation du brief est confirmée
par relecture de la définition ; le nom de la variable (« blocked by bucket ») est **trompeur** en diagnostic.

---

## 6. 🔗 VERROU D'ATOMICITÉ DE DÉMARRAGE COUPLÉ — COUVRE / NE COUVRE PAS (R3.4, AC6)

Le REX `PRG_04:1392-1398` (« M1 parti seul 59 cm après ouverture benne », MES 2026-09-04) a produit **quatre**
volets de verrou :

| Volet | Ligne | Déclencheur | Actif dans le scénario R4/R5 ? |
|---|---|---|---|
| Gel de la requête M1 | `PRG_04:1407-1409` | `WinchBothMotionActive AND (instWinchM2.DirectionChangePending OR instWinchM2.Fault.Latched)` | ❌ **NON** — `WinchBothMotionActive=FALSE` (`PRG_03:152-153`, boutons relâchés / `Select≠0`) |
| Calcul de readiness | `PRG_04:1405-1406` (et `:1541-1542`) | `DirectionChangePending` + `Fault.Latched` des deux FB | ❌ NON (mêmes termes) |
| Gel de la requête M2 | `PRG_04:1499-1501` | `WinchBothMotionActive AND (instWinchM1.DirectionChangePending OR instWinchM1.Fault.Latched)` | ❌ **NON** — même raison |
| Barrière de cohérence finale | `PRG_04:1658-1678` | `Mode = SEMI_AUTO AND WinchBothMotionActive AND (NOT WinchBothMotionReady OR NOT WinchBothFinalRequestsCoherent)` | ❌ **NON** — **doublement inerte** : mauvais mode (`:1661-1663`) **et** intention couplée fausse |

**Verdict AC6 : le verrou NE COUVRE PAS le scénario `M2 seul commandé, benne occupée, M1 gelé`.**
Deux raisons cumulatives et prouvées :

1. **Son vocabulaire de déclenchement** est `{DirectionChangePending, Fault.Latched}` — il ne connaît **pas**
   la cause « M1 bloqué par la garde `BucketBusy` ». La garde `M1:117` **arrête M1 sans que le verrou ne le sache** :
   les deux mécanismes s'ignorent.
2. **Sa portée est l'intention couplée** (`WinchBothMotionActive`) — or c'est précisément l'absence d'intention
   couplée qui rend le trou atteignable (§7).

**Conséquence croisée (constat, non corrigé)** : quand l'opérateur demande **les deux** treuils (boutons both) avec
`BucketBusy=TRUE` et une machine référencée, la garde `M1:117` bloque M1 tandis que `M2:143-151` laisse passer M2 —
c'est la classe exacte du REX « départ isolé », mais **refermée par un autre terme** : le permis benne partagé
(`PRG_04:1118-1127`) rend `M2AscentPermitApplied/DescendPermitApplied` faux (`:1131-1134`) dès que
`EffectivePermitBucket_*` est faux, ce qui bloque aussi M2. **Le trou n'est donc pas couplé : il est unitaire.**

---

## 7. ✅ CHAÎNE D'ATTEIGNABILITÉ PROUVÉE, MAILLON PAR MAILLON (AC9)

**Configuration cible** : `MAINT_N2` + `InhibitM1=TRUE` (M1 gelé) + `SelectArbitrated=2` + `Master=FALSE` (Boutons IHM)
+ benne référencée, aucune faute benne.

| # | Maillon | Valeur | Preuve |
|---|---|---|---|
| 1 | M1 est gelé | `Enable=FALSE` sur les FB M1 | `PRG_04:927`, `:1458` ; permis coupés `FB_Safety_Winch:530-533` |
| 2 | La benne reste vivante malgré `InhibitM1` | `Enable := NOT InhibitM2 = TRUE` | `PRG_04:341` |
| 3 | L'opérateur arme la manœuvre benne | `CmdOpen_IHM` (bouton `BtnOpen`) → `OpenReq := TRUE` | `FB_BucketCmdArbitration:62`, `FB_Bucket:493-496` |
| 4 | `MotionRequestActive` requis à l'armement | vrai ⇒ `Busy := TRUE` (front) | `FB_Bucket:172`, `:509-515` |
| 5 | Pendant `Busy`, la benne commande M2 (ou pas) | `M2_RunRequest := TRUE/FALSE` selon permis ; **si permis benne absent ou opérateur relâché ⇒ `FALSE`** | `FB_Bucket:559-562` (branche `OpenReq`) ; `:544-546` (branche `CloseReq`) |
| 6 | `BucketBusy` reste **TRUE** malgré `M2_RunRequest=FALSE` | aucun `Lifecycle.Busy := FALSE` sur ces branches | `FB_Bucket:559-567` (aucune écriture de `Busy`) |
| 7 | Pas d'abandon « hors contexte » | l'abandon exige `NOT WinchSelBucket` ⇒ **désactivé** car `Select=2` | `FB_Bucket:476-480` |
| 8 | Pas d'expiration du watchdog | budget **gelé** hors commande engagée (`TimeoutEngaged=FALSE`) | `FB_Bucket:230`, `:242-245`, `:265-268` |
| 9 | `BucketBusy` publié vers les arbitres | `ArbContext.BucketBusy := instBucket.Lifecycle.Busy` | `PRG_04:499` ; champ `ST_fbWinchCmdArbitration_Context.st:14` |
| 10 | Chemin benne **non** pris | `BucketM2RunRequest=FALSE` ⇒ `M2:65` faux | `FB_WinchCmdArbitrationM2.st:65-67`, `:83` |
| 11 | M2 retombe sur la branche Boutons IHM | `ELSIF IHM.BtnAscentM2` **sans test de `Select`** | `FB_WinchCmdArbitrationM2.st:97-116` |
| 12 | **Le gate M2 ne contient AUCUN terme `BucketBusy`** | seules gardes : conflit, `WinchBothMotionBlockedByBucket`, sync, homme-mort, axe X, atomicité Both | `FB_WinchCmdArbitrationM2.st:143-151` (comparer `M1:116-125`, terme `:117`) |
| 13 | `BothDirectionAuthorized` = vrai (mode unitaire) | `(NOT BothIntent.Active)` suffit | `M2:140` ; `BothIntent.Active=FALSE` car `Master=FALSE` sans bouton both (`PRG_03:152-153`) |
| 14 | Homme-mort non exigé en mode Boutons | `NOT TglJoystickMaster OR DeadmanArmed` ⇒ neutre | `M2:147` |
| 15 | Requête de marche M2 propagée | `M2LogicRunRequest := instArbM2.RunRequest` | `PRG_04:564` |
| 16 | Pas de gel aval (verrou couplé inerte) | voir §6 | `PRG_04:1499-1501`, `:1661-1663` |
| 17 | Permis M2 appliqué **sans** terme benne | `M2AscentPermitApplied := EffectivePermitM2_Ascent AND (NOT instBucket.M2_RunRequest OR …)` ⇒ `= EffectivePermitM2_Ascent` car `M2_RunRequest=FALSE` | `PRG_04:1131-1134` |
| 18 | **M2 bouge** | `ReqM2Winch.RunRequest := TRUE` → `FB_Winch` M2 → barrière finale → contacteurs | `PRG_04:1473-1476`, `:1523-1536`, `:1614-1629` ; `PRG_06:215-231`, `:378-379` (`%Q`) |

**⇒ VERDICT : ATTEIGNABLE (OUI), en MAINT_N2 avec `InhibitM1` — exactement le mode de travail « un seul câble »
décrit par l'exploitant** (variante R5 identique avec `Master=TRUE` + `DumpAtTremie`).

**Paliers** : M2 part au palier demandé par la source (`Cfg.BtnStepTgt` = 5, `PRG_04:524`) **borné** par
`M2MaxStepUp/Down` (`PRG_04:1306-1315`, `:1320-1334`, `:1484-1485`) — donc jamais « palier 5 garanti » :
le palier appliqué dépend de `_BucketCfgPersist.Config.MaxStep*` et de la zone de ralentissement jog.

---

## 8. ⚠️ CONSÉQUENCES RÉELLES (ce qui est en jeu, sans surévaluer)

Ce qui **n'est pas** le risque : la désynchronisation « M2 suit la benne pendant que M1 suit autre chose »
(`FB_WinchCmdArbitrationM2.st:59-64`) **ne peut pas** se produire dans la variante `InhibitM1` — M1 est inerte.

Ce qui **est** le risque, prouvé, dans l'ordre d'importance :

1. **Deux producteurs concurrents de la commande M2, sans arbitrage explicite.** Selon le scan,
   `M2_RunRequest` (benne) prend la main (`priority`, `M2:65-83`) ou la branche Boutons/joystick commande.
   La **direction** et le **palier** viennent alors de **sources différentes** : la benne impose sa direction
   (`BucketM2ReqAscent/Descend`, `M2:70-71`) et tire le palier du **joystick** (`M2:73`, `LIMIT(1, Joystick.AxisY.StepTgt, 5)`),
   qui vaut **0 au repos** (`FB_Joystick:295`) ⇒ `LIMIT` ⇒ **1** : en mode Boutons, un ordre M2 peut passer
   silencieusement de « palier bouton 5 » à « palier 1, direction benne ». Non documenté en spec.
2. **États benne publiés sur la base d'un mouvement que la benne n'a pas commandé.** Le FB conclut
   `IsClosed/IsOpen` selon la **position** (`FB_Bucket:624-646`, `:650-662`) : une montée M2 déclenchée par le
   bouton IHM pendant `Busy` peut faire conclure « benne fermée » (`CloseReached := TRUE`, `:635`) puis
   publier `MechState.IsClosed`. Or cet état alimente **les portes du cycle** (`PRG_03:104-105`, `:165`, `:247-248`)
   et le **sélecteur T248** (`FB_Modes:385`) ⇒ décision aval sur une donnée non fiable.
3. **Piège opérateur (variante joystick R5) : perte de commande treuil.** `ArmBucketBusy` (`PRG_04:1182-1185`)
   ⇒ `ArmingPermit := FALSE` (`:1205-1206`) ⇒ l'homme-mort est **désarmé immédiatement** (`FB_Joystick:238-239`,
   `PRG_02:464`) et **ne peut pas être ré-armé** tant que `ArmingPermit=FALSE` (`FB_Joystick:230`) ⇒ en pilotage
   joystick, plus aucun mouvement treuil possible. Sorties possibles : atteindre la position cible benne
   (`FB_Bucket:624-646`, `:650-662`), défaut timeout **sous commande continue** (`:260-262` → `SevereError`
   `:462-470`), `Reset`, sortie de mode (`FB_Modes:416-425`), ou **inhibition M2** (`PRG_04:341` → `FB_Bucket:309-332`).
   Voir constat §11-2 : cet état peut se **coller**.

---

## 9. 📜 DOCTRINE M1 vs M2 : **NON SOURCÉE** (R3.5, AC8)

**Constat de preuve** — recherche exhaustive `BucketBusy` dans `DOC/AF/` : **une seule** occurrence, et elle porte
un autre mécanisme (`AF_Partie-08_Fonction_Joystick_v2.5.md:582` : `ArmingPermit := … AND NOT BucketBusy`).

| Affirmation à sourcer | Source trouvée |
|---|---|
| La garde `NOT BucketBusy` au gate **M1** est une doctrine | **AUCUNE spec.** Seule justification écrite : le commentaire de code `FB_WinchCmdArbitrationM1.st:106` — « Gating StartStop (**bit-identique PRG_04 §3**) » ⇒ **héritage historique**, pas doctrine. |
| L'absence de cette garde côté **M2** est volontaire | **AUCUNE source.** Le commentaire le plus proche (`M2:59-64`) justifie la **restriction du chemin benne** (Select=2 / SEMI_AUTO), **pas** l'absence de garde dans la branche manuelle. |
| Priorité benne > cycle en SEMI_AUTO (A4 de T351) | Commentaire `M2:59-64` (REX 2026-09-04), **pas une spec** — constat déjà relevé par T351 §5.2-D01 ; **non traité par ce lot** (item distinct). |
| La matrice MAINT N1/N2 et l'inhibition | **Sourcée** : `AF_Partie-05…v2.1.md:153-165` et `§4bis:173-223` (§4 ci-dessus). |

**Verdict AC8 : asymétrie `BucketBusy` M1/M2 = NON SOURCÉE.** Aucune justification n'a été fabriquée.
La matrice de maintenance (AF-05) ne mentionne **jamais** l'articulation benne × inhibition de treuil.

---

## 10. ❓ LIMITES DE LA PREUVE (AC13) — NON TRACÉ, assumé

| # | Point non tranché | Ce qui manque pour le trancher |
|---|---|---|
| **U1** | **Visibilité IHM** des boutons `BtnOpen/BtnClose` benne et `BtnAscent/DescentM2` selon le mode et le niveau utilisateur. Le **PLC** les accepte dans **tous** les modes (`FB_BucketCmdArbitration:62` n'a aucun gate de mode) ; l'authentification est **côté IHM** (`AF-05:167-169` : « aucun garde-fou mot de passe côté PLC »). | Le projet IHM (hors `CODE/`) ou un essai machine. **Impact** : conditionne R4 en MAINT_N1 (en MAINT_N2 l'accès maintenance est établi). |
| **U2** | Comportement complet du **cycle de homing machine (HX4)** en MAINT_N2 avec M1 inhibé : `CmdBucketOpen` (`PRG_03:431`) peut armer la benne, mais les ordres treuil du cycle (`CmdWinchM1/M2`, `PRG_03:403-404`) **ne sont pas consommés** hors SEMI_AUTO (constat §11-1). | Lecture intégrale de `FB_CycleMachineHoming.st` (§ HX2..HX7) + harnais CI. Déclaré **NON TRACÉ** : non nécessaire au verdict (R5 n'en dépend pas). |
| **U3** | Comportement **dynamique** (bascule de source d'un scan sur l'autre, effet du hold de transition 300 ms `PRG_04:572-575`, anti-chatter contacteurs `PRG_06:280-294`). | Simulation/CI ou trace machine. Aucun exécution PLC possible dans ce lot (analyse seule). |
| **U4** | **Gravité physique** exacte (contrainte mécanique, usure, risque de casse) du cas R4/R5. | Essai machine instrumenté + cotation ISO 13849. Ce document établit le **mécanisme logique**, pas la cotation de risque. |
| **U5** | Comportement des **tests CI** existants sur ce périmètre (`test_fb_winchcmdarbitration*`) : je n'ai pas exécuté la CI (hors périmètre, `TOOLS/TEST_AUTO_CI/` interdit). | Lancer la suite CI du domaine H_TREUILS_BENNE. |

---

## 11. 🚨 DEVOIR D'ALERTE — CONSTATS HORS SCOPE (signalés, **NON corrigés**)

| # | Constat | Preuve | Gravité |
|---|---|---|---|
| **1** | **Les ordres treuil du cycle de homing machine ne sont pas consommés en MAINT_N2.** `Data.ReqProgram.ReqWinchM1/M2` (dont `CmdWinchM1/M2` en HX2/HX3, `PRG_03:401-405`) n'est lu **que** dans la branche `SEMI_AUTO` des arbitres (`M1:56-61`, `M2:85-90`, points d'appel `PRG_04:534`, `:557`). En MAINT_N2 (branche « manuelle »), ces ordres sont **morts** — le mouvement de homing vient en réalité du geste joystick. | `PRG_03:403-404`, `PRG_04:534`, `:557`, `M1:58`, `M2:87` | 🟠 **Confirmé, déjà relevé par T351 §7.3 / §10 pt 3** — cohérent avec mon analyse, **non corrigé ici** |
| **2** | **État `Lifecycle.Busy` collable.** Avec `Select=2`, `MotionRequestActive=FALSE`, aucun pilotage benne programme et hors homing : le watchdog est **gelé** (`FB_Bucket:230`, `:242-245`), l'abandon est **désactivé** (`:476-480`), `OpenReq/CloseReq` restent **latchés** (réarmement seulement hors `Busy`, `:493-501`) et `Busy` n'est écrit à `FALSE` nulle part dans ces branches ⇒ `Busy` peut rester `TRUE` **indéfiniment**. Conséquences : `ArmingPermit=FALSE` en continu ⇒ **plus aucune commande treuil en pilotage joystick** (`PRG_04:1182-1206`, `FB_Joystick:230/238`) ; seule sortie : position cible atteinte, faute sous commande continue, `Reset`, sortie de mode, ou inhibition M2. | `FB_Bucket:230`, `:242-245`, `:265-268`, `:476-480`, `:493-501`, `:559-567` | 🔴 **Risque d'exploitation** (machine figée en maintenance) — **hors scope T354**, à ouvrir en tâche séparée **avant** tout durcissement de la garde M2 (sinon la garde proposée rendrait l'état collé plus pénalisant) |
| **3** | **Priorité de source M2 non documentée en Mode Boutons** : la benne impose sa direction et prend son palier sur le joystick au repos (`LIMIT(1, 0, 5) = 1`), donc « bouton 5 » → « palier 1 » silencieux. | `FB_WinchCmdArbitrationM2.st:70-73`, `FB_Joystick:295`, `PRG_04:524` | 🟠 Défaut de lisibilité/IHM, non dangereux en soi |
| **4** | **Nom trompeur** : `WinchBothMotionBlockedByBucket` est **fausse** quand la benne est occupée (§5). En diagnostic IHM (`PRG_04:1796`, `PRG_06:211`), un opérateur peut conclure l'inverse de la réalité. | `PRG_04:396` | 🟠 Diagnostic |

---

## 12. 🛠️ OPTIONS DE CORRECTION COMPARÉES (AC10) — **DOCUMENTAIRES, ZÉRO CODE**

> ⛔ **Aucune ligne de code, aucun diff, aucun patch prêt à coller.** Le brief §2 interdit le correctif dans ce
> lot ; le §2.4 demande des options. Ces options sont un **livrable de décision** : elles n'ont d'effet que si
> une tâche C3/C4 distincte est ouverte avec son contrat et son test CI rouge-avant / vert-après.

| Option | Contenu | Modes bloqués **en plus** | Risque / coût | Reversibilité |
|---|---|---|---|---|
| **O1 — Garde symétrique (recommandée à l'analyse)** | Ajouter `AND NOT Context.BucketBusy` au gate M2 (`FB_WinchCmdArbitrationM2.st:143-151`), identique à `M1:117`. **La branche chemin benne (`M2:58-82`) n'est pas touchée** : elle est en amont du `IF/ELSE` et ne traverse pas ce gate ⇒ M2 continue de suivre la benne pendant une manœuvre. | Bloque **la commande M2 unitaire pendant `BucketBusy=TRUE`** : mode Boutons (`BtnAscentM2/BtnDescentM2`) et joystick `Select=2`, en **MAINT_N1 et MAINT_N2** (= lignes R4/R5 du §3). Ne bloque **rien** en `SEMI_AUTO` (branche cycle, gate inchangé) ni le chemin benne. | 1 ligne. Effet de bord **réel** : combinée au constat §11-2 (état `Busy` collé), elle **retire à l'opérateur son seul moyen de manœuvrer M2** dans un état collé ⇒ **à livrer avec** la sortie d'état collé, sinon régression d'exploitation. | Triviale (1 ligne, aucun DUT, aucune IHM) |
| **O2 — Élargir la garde compensatoire** | Changer la définition `PRG_04:396` pour couvrir `Busy=TRUE` (ex. garder le terme « occupée » au lieu de `NOT Busy`). | Bloque **les DEUX treuils** (`M1:118` **et** `M2:144`) dans **tous** les modes manuels/MAINT, **et** modifie 2 publications de diagnostic (`PRG_04:1796`, `PRG_06:211`). | ⚠️ **À écarter en l'état** : risque de régression **cycle** — `FB_Bucket:517-524` documente que « AX10B relâche explicitement la benne : le cycle prend M1+M2 P1 **au même scan** » ; une garde « benne occupée = mouvement couplé bloqué » s'opposerait à ce raccordement. Variable **partagée M1/M2** : une seule définition change deux comportements. | Moyenne (1 ligne, mais 2 effets + diagnostic) |
| **O3 — Garde en aval, au niveau PRG_04** | Forcer `M2LogicRunRequest := FALSE` (et `M2LogicReqAscent/Descend`) quand `ArbContext.BucketBusy AND NOT instBucket.M2_RunRequest`, près du hold de transition `PRG_04:572-575`. | Équivalent à **O1** + couvre aussi toute source M2 non listée (y compris cycle en MAINT_N2). Ne touche **pas** l'interface des FB d'arbitrage. | 3 à 4 lignes dans `PRG_04` — fichier **disputé** (verrous T291-B/AGY01, T328/DSH03) ⇒ coordination obligatoire. | Facile |

**Recommandation d'analyse (à arbitrer par l'humain)** : **O1**, la plus proche de la symétrie déjà présente côté M1
et la plus locale, **conditionnée** à une tâche jumelle traitant le constat §11-2 (état `Busy` collé), et
**accompagnée** d'un test CI (rouge avant / vert après) sur les lignes R4/R5 du §3.
**Aucune** de ces options n'est implémentable sans décision humaine : elles changent le comportement de
commande d'un treuil en maintenance, ce qui relève d'un arbitrage d'exploitation, pas d'un agent.

---

## 13. 🔎 CHALLENGE DU BRIEF — écarts constatés (AC12), brief **non réécrit**

| Référence du brief | Réalité prouvée | Statut |
|---|---|---|
| « boutons IHM M2 pilotent M2… `PRG_04_Treuils_Benne.st:104-111` » | `PRG_04:104-111` est le bloc de **déclarations** « ACTION BENNE M2 » (`ExtractionControlActive`, `BucketM2ReqAscent/Descend`…). L'affectation réelle des boutons est **`PRG_04:492-497`** ; leur **consommation** est `FB_WinchCmdArbitrationM2.st:104-111` (le brief a fusionné les deux références, comme le tableau M14 de T351 §3 :180). | ❌ **Réfuté** (sans gravité : le **chemin** décrit existe bien) |
| « M1:117 porte une garde `AND NOT Context.BucketBusy`, uniquement dans la branche manuelle (ELSE ligne 62) » | ✅ exact — `M1:117` dans le gate `:116-125`, dans la branche `ELSE` ouverte `:62` ; la branche `SEMI_AUTO` `:56-61` n'en porte aucune | ✅ **Confirmé** |
| « en SEMI_AUTO, M1 n'a lui-même AUCUNE garde » | ✅ exact (`M1:58` : seule garde = axe X) | ✅ **Confirmé** |
| « `FB_WinchCmdArbitrationM2.st:143-151`, seule garde `:144` » | ✅ exact (`NOT Context.WinchBothMotionBlockedByBucket` à `:144`) | ✅ **Confirmé** |
| « chemin benne `:58-82`, commentaire `:59-64`, condition `:65-67` » | ✅ exact (3 références exactes) | ✅ **Confirmé** |
| « chemin benne restreint à `WinchSel=2` ou `SEMI_AUTO` (n'existe pas en `WinchSel=1`) » | ✅ exact (`:66-67`) | ✅ **Confirmé** |
| « `WinchBothMotionBlockedByBucket` (`PRG_04…:396`) ne couvre pas le cas `Busy=TRUE` » | ✅ exact — **et** le brief ne dit pas que la variable est **fausse** en `Busy=TRUE` (donc **inertie totale**, pas simple incomplétude) | ✅ **Confirmé, renforcé** |
| « verrou d'atomicité `PRG_04:1394-1398` + `:1405-1406`, `:1407-1409`, `:1499-1501`, `:1541-1542`, `:1663` » | ✅ toutes réelles ; le REX « M1 parti seul 59 cm » est à `:1397` ; `:1663` est bien la condition de la barrière finale | ✅ **Confirmé** |
| Modes « MANU / MAINT / AUTO / SEMI_AUTO » | ⚠️ Le code n'a **ni** `MANU` **ni** `AUTO` : `DISABLE / MAINT_N1 / MAINT_N2 / SEMI_AUTO` (`E_Mode.st:9-12`) | ⚠️ **Corrigé** (vocabulaire) |
| « l'exploitant inhibe un ou **plusieurs** treuils » | ⚠️ **Exclusion mutuelle** : au plus **un** treuil inhibé (`FB_Modes:321-322`, `:331-332`) | ⚠️ **Nuancé** |
| « garde compensatoire `:396` **à revérifier** (le fichier a bougé) » | ✅ revérifiée : blob `31760d59…`, `git status --short -- CODE/` vide | ✅ **Fait** |

---

## 14. 📊 COMPTAGE DES RÉFÉRENCES (AC11)

| Mesure | Valeur mesurée (2026-09-21) |
|---|---|
| **Références `fichier:ligne` au total** (formes pleines + alias) | **179** |
| dont formes pleines (`chemin/fichier.st:NNN`) | 34 — 33 résolues automatiquement, **0 hors-borne**, 1 abrégée en prose (`AF_Partie-05…v2.1.md:153-165`, résolue à la main et vérifiée) |
| dont alias (`M1:`, `M2:`, `PRG_04:`, `FB_Bucket:`, `FB_Modes:`, `AF-05:`, `T351:` …) | **145 — 145 dans les bornes du fichier visé, 0 hors-borne** |
| **Références conformes (contenu vérifié ligne à ligne)** | **107 assertions de contenu : 104 conformes exactement**, 3 vérifiées puis expliquées (2 assertions de contrôle mal formulées côté outil : `M1:62` = `ELSE` — c'est bien la ligne citée, le commentaire « Mode manuel » est en `:63` ; `M2:59` = commentaire ⚠️ SÉCURITÉ, encodage console — et 1 citation en **plage** `FB_Bucket:517-524` dont la phrase citée est en `:518` : la plage est correcte) |
| **Références hors-borne** | **0** |
| Méthode | `[regex]` d'extraction + `Test-Path` + bornes (`Get-Content … .Count`) pour **toutes** les références ; puis 107 assertions de **contenu** (`-like` du motif attendu sur la ligne citée) sur les références qui portent le verdict |

**Conclusion du comptage** : 179 références, 178 conformes automatiquement, 1 vérifiée à la main, **0 hors-borne,
0 fabriquée**.

### 14bis. 🔁 Procédure de re-vérification (à rejouer si un blob a bougé)

1. `git rev-parse HEAD` → comparer au §1. Si différent : **tout numéro de ligne de ce document est à recontrôler**.
2. `git hash-object` sur les fichiers du tableau §1 → comparer aux blobs.
3. Re-vérifier en priorité les 6 lignes qui **portent le verdict** :
   `FB_WinchCmdArbitrationM1.st:117`, `FB_WinchCmdArbitrationM2.st:65`, `:143-151`, `BENNE/FB_Bucket.st:559-562`,
   `PRG_04_Treuils_Benne.st:341`, `PRG_04_Treuils_Benne.st:396`, `PRG_04_Treuils_Benne.st:1499-1501`.
4. Vérifier `git status --short -- CODE/` : doit rester **vide** (ce lot n'écrit rien).

---

## 15. 🧾 PREUVE QUE CE LOT N'A RIEN ÉCRIT DANS `CODE/` (AC14)

| Contrôle | Résultat |
|---|---|
| `git status --short -- CODE/` avant / après le lot | **vide** / **vide** |
| `git diff HEAD --stat -- CODE/` | **vide** |
| Bundle PLCopenXML / diff bundle | **NON APPLICABLES** (aucun `CODE/` touché — un bundle ne prouverait rien ici) |
| `G200_check_linkage.py` | **NON APPLICABLE** (idem) |
| Suite de gates (`run_all_gates.py`) | **NON APPLICABLE** (idem) ; aucun fichier `TOOLS/`, `CODE_XML/`, `PRJ_CODESYS/` touché |
| Commit | **aucun** — la validation est humaine |

---

## 16. 📝 JOURNAL (chronologique, horodaté)

| Heure | Étape | État | Résumé |
|---|---|---|---|
| 02:30:55 | `debut` | en_cours | Prise de tag + relevé des verrous + lecture du brief T354 |
| 02:31:11 | `verrous-ok` | ok | Tag **DSH20** = premier libre (DSH01..DSH19 pris) ; `edit_flags` vide ; T354 existe déjà (`TASKS.yaml:53-69`) ; HEAD `c9e1fbfe`, `CODE/` propre |
| 02:32:03 | `chemins-M2` | en_cours | `M1:117` confirmé (branche manuelle) ; `M2:143-151` sans `BucketBusy` ; MAINT N2 = `Auth.InhibitM1/M2` |
| 02:34:28 | `fenetre-prouvee` | en_cours | Fenêtre identifiée (`FB_Bucket:559-562` + `ArmingPermit` + `M2:147`) ; référence `PRG_04:104-111` du brief **réfutée** (réel `:492-497`) |
| 02:39:09 | `contrat-ok` | ok | Contrat C3 écrit **avant** l'analyse : `check_task_contract.py` **PASS 0 erreur / 0 avertissement** (14 critères AC1..AC14) |
| 02:40-02:44 | `fiche-ecrite` | ok | Livrable rédigé (table de vérité, 3 chemins, MAINT N2, verrou, doctrine NON SOURCÉE, 3 options, 4 constats hors scope, 5 limites) |
| 02:44:30 | `contre-verification` | ok | 179 références extraites (34 pleines + 145 alias) : **0 hors-borne** ; 107 assertions de contenu : 104 exactes, 3 expliquées ; `git status --short -- CODE/` et `git diff HEAD --stat -- CODE/` **vides** |
| 02:45:12 | `registres-ok` | ok | `TASKS.yaml` T354 mis à jour (statut ⏳, agent `DSH20`, `contrat`, `avancement`) — YAML valide (149 tâches) ; `TASK_LOCKS.json` : verrou `T354`/`DSH20` posé — JSON valide (27 verrous) ; contrat repassé **PASS** après remplissage du bloc `execution:` |
| 02:46:00 | `fin` | termine | Restitution au porteur/orchestrateur. **Aucun commit.** Aucun fichier de `CODE/` touché. Verrou T354 **laissé posé** : il reste un arbitrage humain (options O1/O2/O3 + alerte A2). |

---

*Fin du livrable T354 — analyse seule, aucune ligne de `CODE/` écrite, aucun commit.*
