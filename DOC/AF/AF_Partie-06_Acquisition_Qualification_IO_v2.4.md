# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.4)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.
> Statut : décision documentaire préalable au retrait de `PRG_01_Inputs_LD` et `FB_Input`.
> 🗺️ Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md` §3 et §5.

## 🎯 Rôle et périmètre

- **Rôle** : définir la frontière unique d'acquisition de `PRG_02_Acquisition` (ST).
- **Périmètre** : `HwReal`/`HwSim`/`HwIn`, diagnostics bus/device, TOR d'entrée, préflight machine
  arrêtée. Les décisions de mouvement restent hors de ce document.
- **Type de composant** : `PRG_02_Acquisition` (programme d'orchestration) + `FB_Acquisition_Preflight`
  (contrat AF03 `standard`, sous-fiche dédiée) — Transverse.
- **Décision v2.2** : `PRG_02_Acquisition` devient l'unique producteur de `HwReal`, `HwSim`,
  `HwIn` et des diagnostics d'acquisition. Le filtrage TOR applicatif non requis a été retiré.

## 📑 Sommaire

1. [🧪 Points de validation](#1--points-de-validation)
2. [🎯 Rôle (détail)](#2--rôle-détail)
3. [🏗️ Chaîne d'acquisition](#3--chaîne-dacquisition)
   - [3bis. 🧩 Intégration programme — cible `PRG_02_Acquisition`](#3bis--integration-programme--cible-prg_02_acquisition)
   - [3ter. 🧾 Contrats DUT — image d'acquisition](#3ter--contrats-dut--image-dacquisition)
4. [📡 Diagnostics bus](#4--diagnostics-bus)
   - [4bis. 🩺 Diagnostic carte des modules DI (22 TOR réelles)](#4bis--diagnostic-carte-des-modules-di-22-tor-reelles)
5. [🔌 TOR d'entrée — liste exhaustive de `HwIn`](#5--tor-dentrée--liste-exhaustive-de-hwin)
6. [⚡ Sorties physiques & Barrières de sécurité](#6--sorties-physiques--barrières-de-sécurité)
7. [🩺 Preflight (qualification machine arrêtée)](#7--preflight-qualification-machine-arrêtée)
8. [📜 Suivi historique](#8--suivi-historique)
9. [❓ TBD](#9--tbd)
10. [📚 Documents liés](#10--documents-liés)

## 🧪 1 · Points de validation

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Intention | Preuve | Type | Réf | Etat |
|---|---|---|---|---|---|
| <nobr><code>TC-P06-001</code></nobr> | Aucune lecture d'E/S brute dans les FB métier | Consommateurs lisent des faits qualifiés | `💻 AUTO` | <small>§3</small> | `NV` |
| <nobr><code>TC-P06-002</code></nobr> | Polarité normalisée une seule fois à l'acquisition | Zéro ré-inversion dans les FB métier | `💻 AUTO` | <small>§3</small> | `NV` |
| <nobr><code>TC-P06-003</code></nobr> | Bascule réel/simulation centralisée | `HwIn` source unique par domaine | `💻 AUTO` | <small>§3</small> | `NV` |
| <nobr><code>TC-P06-004</code></nobr> | Diag CANopen/EtherCAT publié en ligne | Statuts dispos pour Modes/Safety/IHM | `💻 AUTO` | <small>§4</small> | `NV` |
| <nobr><code>TC-P06-005</code></nobr> | Noms des signaux de puissance validés | `PowerKeepAlive_A/B_RQ`, `EmergencyChainClosed_DI` | `🟢 SITE` | <small>§5</small> | `NV` |
| <nobr><code>TC-P06-006</code></nobr> | Écriture des sorties physiques centralisée | `PRG_06_Outputs` seul producteur final | `💻 AUTO` | <small>§6</small> | `NV` |
| <nobr><code>TC-P06-007</code></nobr> | Preflight passif machine arrêtée | Sur front `Execute` (demande IHM) uniquement — aucun verdict automatique au démarrage automate — verdict 16 bits après immobilité ; publication IHM sans action machine | `💻 AUTO_PLC` | <small>§7 / FB_Acquisition_Preflight</small> | `NV-I` |

---

## 🎯 2 · Rôle (détail)

`PRG_02_Acquisition` acquiert les entrées réelles, construit les images `HwReal`/`HwSim`/`HwIn`,
normalise les faits d'entrée et publie les diagnostics device. Il ne décide ni `SafeStop`, ni mode,
ni commande actionneur.

L'acquisition publie des **faits qualifiés** :
- E/S TOR, PDO et mesures réelles brutes dans `HwReal` ;
- image simulée dans `HwSim` ;
- image effectivement consommée dans `HwIn` ;
- disponibilité des devices, dont les trois modules DI (`Local_Digital_IO`, `VH_0800END`,
  `VH_0808ETP`) ;
- mesures codeurs, joystick et position M3 traitées par leurs FB dédiés.

Le nom métier des entrées porte la polarité attendue (`EmergencyChainClosed_DI = TRUE` signifie
chaîne fermée, par exemple). Toute inversion nécessaire doit être prouvée par le mapping réel et
centralisée dans cette frontière ; aucun consommateur ne ré-inverse un signal.

`GetDeviceState()` reste un diagnostic de carte, pas un filtre de voie.

---

## 🏗️ 3 · Chaîne d'acquisition

```text
E/S TOR + PDO + devices réels ──► PRG_02_Acquisition ──► HwReal brut ──┐
                                      │                                 │
                                      ├──► FB_SimBench ──► HwSim        ├──► sélection par domaine ──► HwIn
                                      │                                 │
                                      └─────────────────────────────────┘
                                                                        │
Modes/Cycle → procédés avec leur safety → PRG_06_Outputs → Supervision
```

| Règle | Exigence |
|---|---|
| 🧱 Frontière unique | Aucun FB métier ne lit une E/S brute device ; il lit `HwIn`. |
| 🧪 Simulation | La bascule réel/simulé se fait une seule fois, par domaine, dans `PRG_02_Acquisition`. |
| 🔒 Polarité | Chaque champ `HwIn` expose l'état métier attendu ; aucune ré-inversion aval. |
| ✍️ Producteur unique | `PRG_02_Acquisition` est l'unique producteur de `HwReal`, `HwSim`, `HwIn` et diagnostics acquisition. |
| 🪜 Entrées | `PRG_01_Inputs_LD` est une couche historique en retrait ; aucun nouveau consommateur ne doit y être ajouté. |

Le detail homing/vitesse codeur reste proprietaire de la Partie 09. AF06 porte seulement leur acquisition et leur publication.

### Repartition ST / Ladder — cible v2.1

| Type de signal | Programme propriétaire | Langage | Bloc / DUT |
|---|---|---|---|
| E/S TOR, PDO, diagnostics device, simulation et image sélectionnée | `PRG_02_Acquisition` | ST | `ST_HardwareImage`, FB d'acquisition et `GetDeviceState()` |
| Barrière finale des sorties physiques | `PRG_06_Outputs` | Ladder | Interlocks finaux et coils de sortie |
| Ancienne qualification TOR | `PRG_01_Inputs_LD` | Ladder | En retrait ; aucun nouveau câblage |

> 📌 La frontière cible est donc unique dans `PRG_02_Acquisition`. Le Ladder reste justifié pour
> la barrière finale des sorties ; il n'est pas requis pour afficher ou conditionner les entrées.
> Le retrait de l'ancien POU est un lot de code ultérieur, après remappage et validation.

---

## 🧩 3bis · Integration programme — cible `PRG_02_Acquisition`

**Principe :** acquerir une mesure physique, la mettre a l'echelle, en deduire une vitesse et juger
sa validite est **une seule responsabilite**. La cible reunit donc dans une page unique ce que le
code actuel eclate en quatre POU — ce qui supprime les instances codeurs et joystick dupliquees.

| Ce qui est absorbe par `PRG_02_Acquisition` | Ancien POU | Contenu concerne |
|---|---|---|
| Frontiere E/S, selection reel/simule, joystick | `PRG_Acquisition` | `HwReal` / `FB_SimBench` / `HwIn`, `instJoystick` |
| Chaine de mesure codeurs M1/M2/M3 | `PRG_02_Encoders` | acquisition brute, echelle, position, vitesse, validite et disponibilite |
| Diagnostics devices et bus | `PRG_01_Diagnostics` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` |
| Retours auxiliaires qualifies | `PRG_Auxiliary` | retour thermique centrale hydraulique |
| **Etat AU qualifie** | chaine AU | ⚠️ **acquisition de l'etat seulement** |

### 🛑 Etat AU : acquis ici, agissant en sortie

L'etat de la chaine d'arret d'urgence est un **fait d'entree qualifie**, acquis avec les autres
entrees pour etre visible des l'acquisition par la maintenance.

⚠️ **Cela ne change rien a son action.** Le FB de gestion AU agit sur les sorties via la barriere
finale `PRG_06_Outputs`. **Acquisition de l'etat ≠ lieu d'action.** La chaine materielle AU, sa
polarite fail-safe, son auto-test et son rearmement restent proprietaires de la **Partie 01** : le
PLC ne remplace jamais cette chaine.

### ⚠️ Ce que l'acquisition n'absorbe pas

- Aucune decision `SafeStop`, mode, interdiction ou commande actionneur. La safety de chaque
  procede vit **dans son programme dédié** (`PRG_04_Treuils_Benne`, `PRG_05_Translation`),
  pas ici et pas dans un POU safety global — qui n'existe pas dans la cible.
- Aucune sortie physique : elles restent produites uniquement par `PRG_06_Outputs`.

📌 Lot de migration : **M1** (C4, rebuild) — migration 7 POU soldée, historique archivé (`ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`).
Le référencement (`FB_Encoder_Homing`) n'appartient pas à cette frontière de mesure : il rejoint
`PRG_04_Treuils_Benne`, où les autorisations de maintenance et la visibilité opérateur sont
disponibles. Il consomme les faits publiés par l'acquisition (`RawPos`, `EncoderAvailable`, retours
d'arrêt) et publie sa calibration/requête de preset vers la chaîne EtherCAT.

---

## 🧾 3ter · Contrats DUT — image d'acquisition

> 📌 Règles de fiche : `AF_Partie-03 §4`. **Producteur unique** : chaque champ a exactement un
> écrivain. Quatre images du même type `ST_HardwareImage` (brute / qualifiée / simulée / sélectionnée).
> Aucun FB métier ne lit une E/S brute device : tout passe par `HwIn`.

### 🧱 `ST_HardwareImage` — trois images d'acquisition

| | Instance | Contenu | Producteur | Lecteurs |
|---|---|---|---|---|
| Brute | `HwReal` | Image device réelle brute | `PRG_02_Acquisition` (lectures E/S/PDO, `GetDeviceState`) | `FB_SimBench`, sélection, dépannage |
| Simulée | `HwSim` | Image simulée normalisée | `FB_SimBench` | `PRG_02_Acquisition` uniquement |
| Sélectionnée | `HwIn` | Image résultante par domaine (réel brut ou simulé) | `PRG_02_Acquisition` | **Tout le programme métier** (Modes, Treuils/Benne, Translation, Outputs, Supervision) |

**Structure** (4 sous-domaines, identiques entre les 3 images) :

| Champ | Type | Contenu | Unités | Polarité |
|---|---|---|---|---|
| `Winch` | `ST_HwWinch` | TOR réelles treuils M1/M2 + codeurs COD1/COD2 | — | `_DI` : `TRUE` = état vrai (normalisé) |
| `Translation` | `ST_HwTranslation` | TOR réelles M3 + status word/fréquence AC600 | `Hz` (x100), `WORD` | idem |
| `Operator` | `ST_HwOperator` | Joystick analogique `INT` + état bus CAN | — | — |
| `Machine` | `ST_HwMachine` | Sécurités/commun machine (AU, phases, thermiques, Kobold) | — | `TRUE` = état sûr/OK |

**Sélection par domaine** (une seule bascule, visible dans `PRG_02_Acquisition`) :

```text
HwIn.<Domaine> := SEL(SimActive.<Domaine>, HwReal.<Domaine>, HwSim.<Domaine>)
```

- Domaine réel → source = `HwReal`.
- Domaine simulé → source = `HwSim` **sans filtrage supplémentaire** (valeurs simulées normalisées, AF13 §4).
- 🧪 Tous les domaines ont la même logique visible : pas de bascule cachée.

**Invalidité** : un sous-domaine simulé n'a pas de notion d'erreur physique propre ; les faits de
disponibilité (device, communication) restent évalués sur la source réelle par `PRG_02` (voir §4).

**Cadence** : tâche `MainTask` (cycle rapide, AF02 §4), lecture seule, aucun effet de bord.

**Tests de contrat** :
- Sans simulation : `HwIn.<domaine> == HwReal.<domaine>`.
- Simulation active sur un domaine : `HwIn.<Domaine> == HwSim.<Domaine>` quel que soit le réel.
- Aucun `_DI` de `HwIn` n'a une polarité physique : tout `TRUE` = état logique normalisé.

### 🔢 `ST_InputsQualified` — statut de retrait

`ST_InputsQualified` et ses sous-DUT sont **hérités de l'ancienne architecture**. Ils ne doivent plus
recevoir de nouveau lecteur ni de nouvelle donnée. Leur retrait sera autorisé uniquement lorsque la
recherche active prouvera l'absence de consommateur CODESYS et lorsque chaque champ requis sera
consommé depuis `PRG_02_Acquisition.HwIn`.

| Point de contrôle | Exigence avant suppression |
|---|---|
| Producteur | Aucun nouveau producteur ; `PRG_02_Acquisition` publie `HwIn` |
| Lecteurs | `grep` CODE + inspection CODESYS : zéro lecteur réel restant |
| Polarité | Chaque champ `HwIn` conserve le nom et l'état métier attendus |
| Filtrage | Filtre matériel prouvé ou filtrage équivalent intégré à `PRG_02` |
| Simulation | La sélection `HwReal`/`HwSim` reste centralisée dans `PRG_02` |
| Diagnostic | `InputModuleFault` et les trois états module restent publiés |

Aucune suppression de type n'est effectuée dans cette phase documentaire.

### 📏 `ST_EncoderMeasurements` — mesures codeur M1/M2 (à créer)

Facts de la chaîne de mesure pure (Abs → Scale → Safety → SpeedMeasure), un sous-DUT par treuil.

| Attr. | Valeur |
|---|---|
| Propriétaire / producteur | `PRG_02_Acquisition` (chaîne de mesure pure, rang 02) |
| Écrivain unique | `PRG_02_Acquisition` |
| Lecteurs | `PRG_04_Treuils_Benne` (conduite + `FB_Safety_Winch`), `PRG_03_Modes_Cycle` (`EncoderIncoherent` → blocage SEMI_AUTO), Supervision/IHM |
| Cadence | tâche `T01_Acquisition`, cycle rapide |

**Structure** (1 sous-DUT par treuil, M1 et M2) :

```text
ST_EncoderMeasurements
├── M1 : ST_EncoderMeasurement
└── M2 : ST_EncoderMeasurement
```

| Champ | Type | Source FB | Unités | Invalidité |
|---|---|---|---|---|
| `RawPos` | UDINT | `FB_Encoder_Abs.RawPos` | points bruts | **gelée** sur dernière valeur valide si `EncoderAvailable=FALSE` |
| `EncoderAvailable` | BOOL | `FB_Encoder_Abs.EncoderAvailable` | — | `FALSE` = perte bus/esclave → warning IHM + vue Modes |
| `CablePosM` | REAL | `FB_Encoder_Scale.CablePosM` | m (signée, + enroulé) | gelée via `CablePosMSafe` |
| `CablePosMSafe` | REAL | `FB_Encoder_Safety.CablePosMSafe` | m | gelée sur dernière valeur **plausible** si hors plage ±99 m |
| `EncoderIncoherent` | BOOL | `FB_Encoder_Safety.EncoderIncoherent` | — | `TRUE` = incohérence redémarrage → **refuse SEMI_AUTO** (Modes) |
| `Speed_Mps` | REAL | `FB_Encoder_SpeedMeasure.Speed_Mps` | m/s | 0.0 si `Valid=FALSE` |
| `SignedSpeed_Mps` | REAL | `FB_Encoder_SpeedMeasure.SignedSpeed_Mps` | m/s (signée, + montée) | 0.0 si `Valid=FALSE` |
| `SpeedValid` | BOOL | `FB_Encoder_SpeedMeasure.Valid` | — | `FALSE` < 6 éch. couvrant 50 ms |

> ⏱️ **Cadence** : tâche `MainTask`, cycle rapide.

**Polarité** : tout `BOOL` = `TRUE` état normalisé. Aucun champ brut EtherCAT (alarmes/warnings,
`DEVICE_STATE`) dans ce DUT : ils restent exposés via `ST_EncoderHMI` (Supervision) pour l'IHM.

**Tests de contrat** :
- Perte bus (simuler `AlarmsIn≠0` ou esclave non opérationnel) : `EncoderAvailable=FALSE`,
  `RawPos` inchangé (gelé), `SpeedValid=FALSE`, `Speed_Mps=0.0`.
- Redémarrage incohérent (`HomingSuspect`) : `EncoderIncoherent=TRUE` → Modes refuse `SEMI_AUTO`.
- Sans simulation : M1 reflète COD1, M2 reflète COD2 — jamais croisés.

> ✅ **Point de vigilance ordonnancement — TRANCHÉ, mis à jour 2026-08-26** : la décision initiale
> du 2026-08-03 (`FB_Encoder_Scale` rang 02 consommant `HomingRefRaw` produit par
> `FB_Encoder_Homing` déplacé rang 04/Treuils) a été **remplacée par l'architecture actée du
> 2026-08-25** (`AF_Partie-09_Fonction_Encoder_v2.3.md §8`) : la chaîne codeur complète
> (Abs→Homing→Scale→Safety→Reliability→Speed) est regroupée dans une **façade unique
> `FB_Encoder`, entièrement instanciée dans `PRG_02_Acquisition`** — le déplacement du homing seul
> vers `PRG_04_Treuils_Benne` n'a jamais été implémenté et n'est plus la cible. `HomingRefRaw` est
> donc produit et consommé au même rang (`PRG_02_Acquisition`), aucun retard inter-programme sur
> ce champ. Le seul retard résiduel documenté est celui de `HomingPermit` (lit `Auth.Mode` produit
> au rang `PRG_03_Modes_Cycle`, retard d'un scan bénin assumé — AF09 §8). Voir AF09 §8 pour le
> détail complet.

### 🔥 Flux perte codeur → Modes / Safety / Supervision / IHM (trou P0 AF09 §6 alert. 8)

> ⛔ **PAS corrigé en pratique — écart doc/code trouvé (review sous-agent, 2026-08-26).** La
> formule ci-dessous (`FB_EncoderReliability`, `CODE/E_CODEURS/FB_EncoderReliability.st:30`) et sa
> publication par treuil (`PRG_02_Acquisition.st:359/409`, `Data.M1/M2_EncoderFault`) existent bien
> dans le code. **Mais `PRG_03_Modes_Cycle.st:43` ne les consomme pas** : `FB_Modes.EncoderFaultPresent`
> est câblé sur `COD1/COD2_DeviceState <> RUNNING` uniquement — `EncoderIncoherent` n'atteint
> jamais la porte `SEMI_AUTO`. Le bug P0 originel (perte bus ⇒ position gelée ⇒ dans la plage ⇒
> incohérence jamais vue ⇒ `SEMI_AUTO` reste autorisé) **peut toujours se produire côté Modes**.
> Non tranché — voir TBD §9 et journal de conformité (question ouverte, pas une simple faute de
> frappe doc : câblage réel à corriger ou formule à revoir, décision humaine requise).

**Un seul fait par treuil définit le défaut codeur consommé partout** (formule déjà portée par
`Supervision` côté IHM — **mais pas encore par `PRG_03_Modes_Cycle`, voir alerte ci-dessus**) :

```text
EncoderFault.<Treuil> := NOT EncoderAvailable OR EncoderIncoherent
```

| Consommateur | Action sur `EncoderFault` | Bypass |
|---|---|---|
| `PRG_03_Modes_Cycle` (`FB_Modes`) | ⛔ **N'utilise PAS cette formule** — `EncoderFaultPresent` câblé sur `DeviceState<>RUNNING` seul (`PRG_03_Modes_Cycle.st:43`), `EncoderIncoherent` ignoré | aucun (SEMI_AUTO ne tolère aucun codeur faux — mais le tolère en fait si incohérence sans perte bus) |
| `PRG_04_Treuils_Benne` (`FB_Safety_Winch`) | `SafeStop` du treuil concerné sur `NOT EncoderAvailable` seul (bit1 `ErrorId`, "Perte codeur" — **pas bit2**, qui est surchauffe moteur) — **`EncoderIncoherent` non plus consommé ici** | individuel `EncoderFaultBypass`, **MAINT_N2 uniquement** |
| `PRG_03_Modes_Cycle` (`Auth.SyncEnable` / `Sync`) | Synchro refusée si l'un des 2 codeurs faux | — |
| `PRG_06_Outputs` / `PRG_04` (commande) | Interdit toute commande reposant sur la position tant que `EncoderFault` | via Modes/Safety uniquement |
| `PRG_07_Supervision` (IHM) | `EncoderFault` par treuil → alarme/animation | — |

**Producteur unique de l'agrégat** : `PRG_02_Acquisition` produit `ST_EncoderMeasurements`
(avec `EncoderAvailable` par treuil) ; `FB_EncoderReliability` calcule `EncoderFault` par treuil
— pas de POU d'agrégation intermédiaire (supprime le cycle `PRG_02_Encoders` legacy). **Mais** ni
`FB_Modes` ni `FB_Safety_Winch` ne lisent ce fait agrégé aujourd'hui (voir tableau ci-dessus) :
chacun recalcule sa propre condition, plus étroite qu'`EncoderFault`.

**Test de contrat (non-régression) — cible, PAS l'état actuel** : perte bus COD1 simulée ⇒
`M1.EncoderAvailable=FALSE`, `M1.EncoderFault=TRUE` ⇒ Modes refuse `SEMI_AUTO` (✅ vrai : ceci
passe par `DeviceState`), `FB_Safety_Winch` M1 passe `SafeStop` (✅ vrai : `EncoderAvailable`
directement consommé), M2 inchangé, IHM affiche l'alarme M1. **Le cas non couvert** :
incohérence sans perte bus (`EncoderIncoherent=TRUE`, `EncoderAvailable=TRUE`) — Modes ne refuse
**pas** `SEMI_AUTO` dans ce cas, contrairement à ce que ce paragraphe affirmait avant révision.

---

## 📡 4 · Diagnostics bus

Les diagnostics font partie de l'acquisition qualifiee.

| Bus | Devices a minima |
|---|---|
| 🟧 CANopen | Joystick / reseau operateur. |
| 🟦 EtherCAT | COD1, COD2, variateur AC600. |

Faits publies :
- presence / online ;
- operationalite ;
- defauts de communication pertinents ;
- synthese de disponibilite si utile.

Les consommateurs decident ensuite :
- la safety de chaque procede, **dans la page de son procede** : interlock ou `SafeStop` ;
- Modes : refus de semi-auto ou permission ;
- IHM : affichage diagnostic.

📌 Dans la cible, ces diagnostics sont produits **ici** et non plus dans un POU `PRG_01_Diagnostics`
separee : c'est ce qui supprime le cycle prouve `Acquisition ↔ Diagnostics` et la duplication de
`instJoystick`. Les FB et leurs seuils sont inchanges (Partie 12).

### 🩺 4bis · Diagnostic carte des modules DI (22 TOR reelles)

> ✅ Tranche 2026-08-04 (utilisateur, confirme sur les 3 modules) : les 22 TOR d'entree (§5) sont
> portees par 3 supports materiels distincts, chacun exposant `GetDeviceState()` :

| Module | TOR portees (§5) | Domaine |
|---|---|---|
| `Local_Digital_IO` | #8-15 (8 TOR) | Winch, Machine (Kobold) |
| `VH_0800END` | #1-7 (7 TOR) | Machine (AU, phases, thermiques), freins M1/M2/M3 |
| `VH_0808ETP` | #16-22 (7 TOR) | Translation (positions M3), Machine (hydraulique, crible) |

**Granularite MODULE, pas canal.** `GetDeviceState()` renseigne la sante d'une carte, pas d'une
voie individuelle : un module en defaut ne dit pas *quelle* TOR ment, seulement qu'aucune de ses
TOR n'est fiable. `FB_Input.ChannelOk` (§9 TBD) n'a donc **pas** de source par canal disponible
aujourd'hui — limitation materielle assumee, pas un oubli.

**Producteur** : `PRG_02_Acquisition` (3 appels `GetDeviceState()`, publies `LocalDigitalIoOk`,
`Vh0800EndOk`, `Vh0808EtpOk`, `InputModuleFault` agrege OR).

**Consommateurs** :
- `PRG_04_Treuils_Benne` : `InputModuleFault` force `SafeStop` M1 **et** M2 (VH_0800END et
  Local_Digital_IO portent les retours frein/thermique/contacteurs/fin de course des deux treuils
  — pas de discrimination possible par treuil) ;
- `PRG_05_Translation` : `InputModuleFault` force `SafeStop` M3 (VH_0808ETP/VH_0800END portent
  positions, frein et thermique M3) ;
- IHM : `GVL_IHM.Network.InputModules` (`ST_InputModuleDiagHMI`) — memes reflexes de lecture que
  `GVL_IHM.Network.Bus*`/`*Error`.

**Choix explicite** : `SafeStop` (rampe rapide, `Enable` maintenu), pas coupure seche — coherent
avec le traitement `EncoderFault` deja en place (§3ter). Aucun bypass simulation sur ce diagnostic :
un module DI absent en simulation banc reste un fait materiel reel, jamais un choix modelise.

---

## 🔌 5 · TOR d'entrée — liste exhaustive de `HwIn`

> 📌 **Source de vérité matérielle** : `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260814.csv`
> (nom de fichier corrigé 2026-08-26 — l'ancien `Device_IO_20260806.csv` n'existe plus)
> (export CODESYS → CSV, référence T100). **22 TOR d'entrée réelles** sont recensées ici.
> La structure `ST_HardwareImage` porte les champs ; aucun nouveau champ ne doit être créé dans
> `ST_InputsQualified` ou dans un POU `PRG_01` en retrait.
>
> ⚠️ **Table non exhaustive (trouvé 2026-08-26)** : `ST_HwMachine` porte un 23e champ,
> `TremieFull_OR_GateRaised_DI` (`VH_0808ETP · 5`, CSV `Device_IO_20260826.csv:456`) — déclaré
> dans le code, **pas encore câblé électriquement**, absent de la liste ci-dessous. À ajouter dès
> câblage effectif.

Le nom d'une E/S dit ce que signifie `TRUE` (`<Domaine>_<ÉtatQuandTRUE>_DI`). La polarité est
normalisée une seule fois dans le mapping d'acquisition `PRG_02_Acquisition` ou garantie par la
configuration matérielle ; aucun `InvertLogic` aval ne doit être ajouté.

| # | TOR (`_DI`) | Device · Bit | Domaine (`HwIn`) | Polarité | `TRUE` = |
|---|---|---|---|---|---|
| 1 | `PowerContactorEngaged_DI` | VH_0800END · 6 | Machine | NO | Contacteur de puissance engagé / portail maître OK |
| 2 | `EmergencyChainClosed_DI` | VH_0800END · 7 | Machine | NC | Boucle AU fermée (coup-de-poing + contact PLC) |
| 3 | `PhaseRotationOk_DI` | VH_0800END · 4 | Machine | NC | Rotation des phases électriques correcte |
| 4 | `M1_M2_M3_BrakeThermalOk_DI` | VH_0800END · 3 | Machine | NC | Thermique freins M1/M2/M3 commun OK *(corrigé 2026-08-26, ancien nom `BrakeThermalOk_DI` ne correspond plus au code)* |
| 5 | `M1_BrakeIsOpen_DI` | VH_0800END · 0 | Winch | inversée* | Frein M1 **ouvert** (desserré) — normalisée TRUE=serré |
| 6 | `M2_BrakeIsOpen_DI` | VH_0800END · 1 | Winch | inversée* | Frein M2 **ouvert** — normalisée TRUE=serré |
| 7 | `M3_BrakeIsOpen_DI` | VH_0800END · 2 | Translation | inversée* | Frein M3 **ouvert** — normalisée TRUE=serré |
| 8 | `M1_ContactorsReleased_DI` | Local_Digital_IO · 0 | Winch | NO | Contacteurs sens M1 relâchés |
| 9 | `M1_ThermalOk_DI` | Local_Digital_IO · 1 | Winch | NC | Thermique M1 OK |
| 10 | `M2_ContactorsReleased_DI` | Local_Digital_IO · 2 | Winch | NO | Contacteurs sens M2 relâchés |
| 11 | `M2_ThermalOk_DI` | Local_Digital_IO · 3 | Winch | NC | Thermique M2 OK |
| 12 | `M2_TensionedCable_DI` | Local_Digital_IO · 4 | Winch | NC | Câble M2 tendu (capteur mou non déclenché) |
| 13 | `M1_M2_KoboldBottomTouch_DI` | Local_Digital_IO · 5 | Machine | NO | Kobold fond détecté (info=0 et benne immergée) *(corrigé 2026-08-26, ancien nom `M1_M2_KoboldContactFond_DI` ne correspond plus au code)* |
| 14 | `M3_ThermalOK_DI` | Local_Digital_IO · 6 | Translation | NC | Thermique M3 OK *(corrigé 2026-08-26 : nom `M3_ThermalFeedback_DI` et domaine `Winch` étaient faux — appartient à `Translation`)* |
| 15 | `M1M2_TopPositionFree_DI` | Local_Digital_IO · 7 | Winch | NC | Position extrême haut libre — référencement, déclenche AU |
| 16 | `M3_PosTremie_DI` | VH_0808ETP · 0 | Translation | NO | Chariot position Trémie |
| 17 | `M3_PosPV_DI` | VH_0808ETP · 1 | Translation | NO | Chariot position PV (ralentissement Trémie) |
| 18 | `M3_PosPVP2_DI` | VH_0808ETP · 2 | Translation | NO | Chariot position P2 / petite vitesse avant P1 |
| 19 | `M3_PosP1_DI` | VH_0808ETP · 3 | Translation | NO | Chariot position P1 |
| 20 | `M3_PosMaintenance_DI` | VH_0808ETP · 4 | Translation | NO | Chariot position Maintenance |
| 21 | `HydraulicThermalOk_DI` | VH_0808ETP · 6 | Machine | NC | Thermique moteur hydraulique OK *(nouveau vs legacy 19)* |
| 22 | `ConveyorInfeedReady_DI` | VH_0808ETP · 7 | Machine | NO | Autorisation démarrage crible (dépose gravats) *(nouveau vs legacy 19)* |

* Freins : `M*_BrakeIsOpen_DI` porte **TRUE = frein ouvert**. Cette polarité est celle du nom
métier actuel et doit rester identique dans `HwReal`/`HwIn`, sauf décision safety documentée.

### Sorties de maintien / réarmement (familles liées, Q/RQ)

| Q/RQ | Rôle |
|---|---|
| `PowerKeepAlive_A_RQ`, `PowerKeepAlive_B_RQ` | `TRUE` = maintien de la puissance voie A/B (NC, fail-safe) — sa retombée ouvre la chaîne |
| `EmergencyArming_RQ` | `TRUE` = impulsion de réarmement (1 s / 5 s) |
| `M*_BrakeRelease_RQ` | `TRUE` = desserrage de frein commandé |
| `M1_M2_KoboldMeasureEnable_DQ` | `TRUE` = mesure Kobold activée |

`PowerContactorEngaged_DI` alimente le portail `PowerContactorEngaged`. `EmergencyChainClosed_DI`
confirme la boucle AU (Partie 01).

---

## ⚡ 6 · Sorties physiques & Barrières de sécurité

Les sorties finales et barrières de commande matérielle sont gérées dans `PRG_06_Outputs` en Ladder.

| Regle | Exigence |
|---|---|
| 🧱 Barrieres finales | Uniques productrices des commandes physiques autorisees (`M1InterlockEnable`, etc.). |
| 🛡️ SafeStop | Laisse la deceleration metier se terminer (n'écrase pas `Enable`). |
| 🔴 Coupure finale | `Enable=FALSE` uniquement sur `PowerCutOff` matériel ou défaut d'interlock bloquant. |
| 🧨 PowerCutOff | Demande safety agregee puis canaux A/B fail-safe. |

### 🔍 Diagnostic graphique Ladder & Publication GVL_IHM

Pour chaque actionneur (**M1 Treuil Retenue**, **M2 Treuil Benne**, **M3 Translation**), `PRG_06_Outputs` intègre 3 blocs opérateurs `OR` de diagnostic pur (Watch/Ladder) :

1. **`*PowerCutOffSafetyInfo`** (Bloc 1) : Regroupe les mécanismes critiques provoquant une coupure de puissance amont (Méca A..E, thermiques, perte de contrôle).
2. **`*SafeStopSafetyInfo`** (Bloc 2) : Regroupe les défauts entraînant une rampe de décélération rapide contrôlée (perte comm opérateur/joystick, codeur, rotation phase, etc.).
3. **`*BlockedBySafetyInfo`** (Bloc 3) : Synthèse globale du blocage (`PowerCutOff` OU `SafeStop`), reliant graphiquement les sorties des deux premiers blocs vers l'état général.

Ces signaux sont directement projetés dans `GVL_IHM` via `ST_SafetyWinch` (`M1TreuilRetenue.Safety`, `M2TreuilBenne.Safety`) et `ST_SafetyTranslation` (`TranslationM3.Safety`) :
- `BlockedBySafety`
- `PowerCutOffSafety`
- `SafeStopSafety`

---

## 🩺 7 · Preflight (qualification machine arrêtée)

| Fiche | FB | Contenu |
|---|---|---|
| [`FB_Acquisition_Preflight`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.3.md) | `FB_Acquisition_Preflight` | Verdict passif : 16 contrôles de cohérence E/S machine arrêtée |

`FB_Acquisition_Preflight` vérifie 16 conditions mécaniques/électriques quand la machine est
arrêtée. Observateur pur : aucune écriture de commande, sécurité ou mouvement.

Instance : `PRG_07_Supervision.instPreflight` (ST pur, en lecture seule stricte).

### PreflightErrorId (16 bits)

| Bit | Contrôle |
|---|---|
| 0-2 | Frein M1/M2/M3 serré |
| 3-4 | Contacteurs M1/M2 retombés |
| 5-6 | Thermique M1/M2 OK |
| 7 | Thermique frein OK |
| 8 | Rotation phases OK |
| 9 | Câble M2 tendu |
| 10 | Capteurs M3 cohérents |
| 11 | Contacteur sans chaîne AU |
| 12-13 | Codeur M1/M2 opérationnel |
| 14-15 | Homé + position bornée M1/M2 |

---

## 📜 8 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v2.4 (fix) | 2026-08-26 | Revue de cohérence croisée AF-01→14 (sous-agent) : §3ter « point de vigilance ordonnancement » contredisait AF09 §8 sur l'emplacement de `FB_Encoder_Homing` (rang 04/Treuils vs façade unique `PRG_02_Acquisition`) — corrigé pour refléter l'architecture actée 2026-08-25 (AF09 §8), référence morte « AF09 §4.2 » retirée |
| v2.4 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lié (incluant désormais 3bis/3ter/4bis, absents), section `🎯 Rôle et périmètre` explicite, Suivi historique ajouté, renumérotation complète (chapô + réfs `§N` cascadées), lien mort corrigé vers `FB_Acquisition_Preflight_v1.3.md` (citait v1.0, inexistant), référence `FB_Input` ajoutée en Documents liés. **Correctifs de fond majeurs** (review sous-agent expert automatisme, vérifiés contre le code) : §3bis-nommé-§3ter « Corrigé par conception » **infirmé** — `PRG_03_Modes_Cycle.st:43` ne consomme pas `EncoderIncoherent` (câblé sur `DeviceState` seul), le bug P0 original reste possible côté Modes, marqué ⛔ non résolu (pas juste un souci doc) ; `FB_Safety_Winch` bit `ErrorId` corrigé bit2→bit1 et clarifié qu'il ne consomme pas non plus `EncoderIncoherent` ; §5 : nom fichier CSV corrigé (`20260806`→`20260814`), 3 noms de TOR corrigés (`BrakeThermalOk_DI`→`M1_M2_M3_BrakeThermalOk_DI`, `M1_M2_KoboldContactFond_DI`→`M1_M2_KoboldBottomTouch_DI`, `M3_ThermalFeedback_DI`→`M3_ThermalOK_DI` + domaine Winch→Translation), 23e champ `HopperFull_OR_GateRaised_DI` (non câblé) signalé absent de la liste ; réf stale `AF_Partie-11 §4` retirée de `FB_Acquisition_Preflight` (section inexistante) |
| v2.3 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 9 · TBD

- ⛔ **P0 sécurité (trouvé 2026-08-26, non tranché)** : `EncoderIncoherent` n'atteint ni
  `FB_Modes.EncoderFaultPresent` (câblé sur `DeviceState` seul, `PRG_03_Modes_Cycle.st:43`) ni
  `FB_Safety_Winch` (consomme `EncoderAvailable` seul). Une incohérence codeur sans perte de bus
  (`EncoderIncoherent=TRUE`, `EncoderAvailable=TRUE`) n'est bloquée nulle part côté Modes/Safety —
  voir §3ter détail. **Décision requise** : câbler `FB_Modes`/`FB_Safety_Winch` sur `EncoderFault`
  agrégé (formule déjà correcte, juste pas consommée), ou est-ce volontaire et faut-il alors
  documenter pourquoi l'incohérence seule ne doit pas bloquer `SEMI_AUTO` ?
- Durees de filtrage par signal apres qualification terrain.
- Statut definitif de `FB_Output` non instancie.
- Diagnostic par canal (`FB_Input.ChannelOk`) : non disponible avec le materiel actuel
  (`GetDeviceState()` = etat carte, pas etat voie) — a revisiter si un module diagnostiquant
  chaque canal individuellement est installe.
- ~~Contrat exact des structures de publication internes vers les programmes.~~ ✅ **Résolu** — §3ter : `ST_HardwareImage` (HwReal/HwSim/HwIn), diagnostic modules et `ST_EncoderMeasurements` (M1/M2, lecteurs Treuils/Modes/Supervision).

## 📚 10 · Documents liés

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : architecture cible 7 POU — `PRG_02_Acquisition` et `PRG_06_Outputs`.
- Partie 08 : traitement joystick.
- Sous-fiche [`FB_Acquisition_Preflight_v1.3.md`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.3.md) : détail des 16 contrôles préflight.
- Sous-fiche [`FB_Input_v1.2.md`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Input_v1.2.md) : statut de retrait contrôlé (déprécié, non supprimé).
- Partie 09 : homing et vitesse codeur.
- Partie 13 : simulation.
