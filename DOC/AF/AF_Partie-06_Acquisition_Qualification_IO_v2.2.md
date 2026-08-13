# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.2)

> Role : definir la frontiere unique d'acquisition de `PRG_02_Acquisition` (ST).
> Statut : décision documentaire préalable au retrait de `PRG_01_Inputs_LD` et `FB_Input`.
> Les décisions de mouvement restent hors de ce document.
> 🗺️ Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.

**Décision v2.2 :** `PRG_02_Acquisition` devient l'unique producteur de `HwReal`,
`HwSim`, `HwIn` et des diagnostics d'acquisition. Le filtrage TOR applicatif non requis a été retiré.


## 🧭 Sommaire

1. Role
2. Chaine d'acquisition
3. Diagnostics bus
4. Polarites et noms
5. Sorties physiques
6. Preflight (qualification machine arrêtée)
7. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P06-001</code></nobr> | Aucune lecture d'E/S brute dans les FB métier | Consommateurs lisent des faits qualifiés | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P06-002</code></nobr> | Polarité normalisée une seule fois à l'acquisition | Zéro ré-inversion dans les FB métier | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P06-003</code></nobr> | Bascule réel/simulation centralisée | `HwIn` source unique par domaine | `💻 AUTO` | <small>§2</small> |
| <nobr><code>TC-P06-004</code></nobr> | Diag CANopen/EtherCAT publié en ligne | Statuts dispos pour Modes/Safety/IHM | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P06-005</code></nobr> | Noms des signaux de puissance validés | `PowerKeepAlive_A/B_RQ`, `EmergencyChainClosed_DI` | `🟢 SITE` | <small>§4</small> |
| <nobr><code>TC-P06-006</code></nobr> | Écriture des sorties physiques centralisée | `PRG_OUTPUTS_LD` seul producteur final | `💻 AUTO` | <small>§5</small> |

---

## 🎯 1. Role

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

## 🏗️ 2. Chaine d'acquisition

```text
E/S TOR + PDO + devices réels ──► PRG_02_Acquisition ──► HwReal brut ──┐
                                      │                                 │
                                      ├──► FB_SimBench ──► HwSim        ├──► sélection par domaine ──► HwIn
                                      │                                 │
                                      └─────────────────────────────────┘
                                                                        │
Modes/Cycle → procédés avec leur safety → PRG_06_Outputs_LD → Supervision
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
| Barrière finale des sorties physiques | `PRG_06_Outputs_LD` | Ladder | Interlocks finaux et coils de sortie |
| Ancienne qualification TOR | `PRG_01_Inputs_LD` | Ladder | En retrait ; aucun nouveau câblage |

> 📌 La frontière cible est donc unique dans `PRG_02_Acquisition`. Le Ladder reste justifié pour
> la barrière finale des sorties ; il n'est pas requis pour afficher ou conditionner les entrées.
> Le retrait de l'ancien POU est un lot de code ultérieur, après remappage et validation.

---

## 🧩 2bis. Integration programme — cible `PRG_02_Acquisition`

**Principe :** acquerir une mesure physique, la mettre a l'echelle, en deduire une vitesse et juger
sa validite est **une seule responsabilite**. La cible reunit donc dans une page unique ce que le
code actuel eclate en quatre POU — ce qui supprime les instances codeurs et joystick dupliquees.

| Ce qui est absorbe par `PRG_02_Acquisition` | POU actuel | Contenu concerne |
|---|---|---|
| Frontiere E/S, selection reel/simule, joystick | `PRG_ACQUISITION_CFC` | `HwReal` / `FB_SimBench` / `HwIn`, `instJoystick` |
| Chaine de mesure codeurs M1/M2/M3 | `PRG_02_Encoders` | acquisition brute, echelle, position, vitesse, validite et disponibilite |
| Diagnostics devices et bus | `PRG_01_Diagnostics` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` |
| Retours auxiliaires qualifies | `PRG_AUXILIARY_CFC` | retour thermique centrale hydraulique |
| **Etat AU qualifie** | chaine AU | ⚠️ **acquisition de l'etat seulement** |

### 🛑 Etat AU : acquis ici, agissant en sortie

L'etat de la chaine d'arret d'urgence est un **fait d'entree qualifie**, acquis avec les autres
entrees pour etre visible des l'acquisition par la maintenance.

⚠️ **Cela ne change rien a son action.** Le FB de gestion AU agit sur les sorties via la barriere
finale `PRG_06_Outputs_LD`. **Acquisition de l'etat ≠ lieu d'action.** La chaine materielle AU, sa
polarite fail-safe, son auto-test et son rearmement restent proprietaires de la **Partie 01** : le
PLC ne remplace jamais cette chaine.

### ⚠️ Ce que l'acquisition n'absorbe pas

- Aucune decision `SafeStop`, mode, interdiction ou commande actionneur. La safety de chaque
  procede vit **dans la page de son procede** (`PRG_04_Treuils_Benne_CFC`, `PRG_05_Translation_CFC`),
  pas ici et pas dans un POU safety global — qui n'existe pas dans la cible.
- Aucune sortie physique : elles restent produites uniquement par `PRG_06_Outputs_LD`.

📌 Lot de migration : **M1** de `DOC/WFLOW/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).
Le référencement (`FB_Encoder_Homing`) n'appartient pas à cette frontière de mesure : il rejoint
`PRG_04_Treuils_Benne_CFC`, où les autorisations de maintenance et la visibilité opérateur sont
disponibles. Il consomme les faits publiés par l'acquisition (`RawPos`, `EncoderAvailable`, retours
d'arrêt) et publie sa calibration/requête de preset vers la chaîne EtherCAT.

---

## 🧾 2ter. Contrats DUT — image d'acquisition

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

**Sélection par domaine** (une seule bascule, visible dans le CFC Acquisition) :

```text
HwIn.<Domaine> := SEL(SimActive.<Domaine>, HwReal.<Domaine>, HwSim.<Domaine>)
```

- Domaine réel → source = `HwReal`.
- Domaine simulé → source = `HwSim` **sans filtrage supplémentaire** (valeurs simulées normalisées, AF13 §4).
- 🧪 Tous les domaines ont la même logique visible : pas de bascule cachée dans un Ladder.

**Invalidité** : un sous-domaine simulé n'a pas de notion d'erreur physique propre ; les faits de
disponibilité (device, communication) restent évalués sur la source réelle par `PRG_02` (voir §3).

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
| Lecteurs | `PRG_04_Treuils_Benne_CFC` (conduite + `FB_Safety_Winch`), `PRG_03_Modes_Cycle_CFC` (`EncoderIncoherent` → blocage SEMI_AUTO), Supervision/IHM |
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
| Cadence | tâche `MainTask`, cycle rapide |

**Polarité** : tout `BOOL` = `TRUE` état normalisé. Aucun champ brut EtherCAT (alarmes/warnings,
`DEVICE_STATE`) dans ce DUT : ils restent exposés via `ST_EncoderHMI` (Supervision) pour l'IHM.

**Tests de contrat** :
- Perte bus (simuler `AlarmsIn≠0` ou esclave non opérationnel) : `EncoderAvailable=FALSE`,
  `RawPos` inchangé (gelé), `SpeedValid=FALSE`, `Speed_Mps=0.0`.
- Redémarrage incohérent (`HomingSuspect`) : `EncoderIncoherent=TRUE` → Modes refuse `SEMI_AUTO`.
- Sans simulation : M1 reflète COD1, M2 reflète COD2 — jamais croisés.

> ✅ **Point de vigilance ordonnancement — TRANCHÉ (décision 2026-08-03)** : `FB_Encoder_Scale`
> (rang 02) consomme `HomingRefRaw` produit par `FB_Encoder_Homing` (**rang 04**, Treuils).
> **Retard d'un scan bénin assumé** : `HomingRefRaw` est RETAIN quasi-statique, ne change que sur
> référencement abouti (procédure terrain AF09 §5) suivi d'une confirmation visuelle — jamais de
> conséquence sur une commande, un interlock ou une sortie. Pas de relais dédié, pas de déplacement
> du homing (réintroduirait la violation grave Homing→Modes). Documenté AF09 §4.2 « Note A-01 bis ».

### 🔥 Flux perte codeur → Modes / Safety / Supervision / IHM (trou P0 AF09 §6 alert. 8)

> ✅ **Corrigé par conception** — la chaîne `ST_EncoderMeasurements` propage la **disponibilité**
> (`EncoderAvailable`), pas seulement la **cohérence** (`EncoderIncoherent`). L'ancien agrégat
> `EncoderFaultPresent := EncoderIncoherent M1 OR M2` laissait une position figée autoriser
> `SEMI_AUTO` (perte bus ⇒ `RawPos` gelé ⇒ position dans la plage ⇒ incohérence fausse).

**Un seul fait par treuil définit le défaut codeur consommé partout** (formule déjà portée par
`Supervision` côté IHM) :

```text
EncoderFault.<Treuil> := NOT EncoderAvailable OR EncoderIncoherent
```

| Consommateur | Action sur `EncoderFault` | Bypass |
|---|---|---|
| `PRG_03_Modes_Cycle_CFC` (`FB_Modes`) | Refuse `SEMI_AUTO` (repli `MAINT_N1`, `Auth.ErrorId` bit0) — **agrégat M1 OR M2** | aucun (SEMI_AUTO ne tolère aucun codeur faux) |
| `PRG_04_Treuils_Benne_CFC` (`FB_Safety_Winch`) | `SafeStop` du treuil concerné (bit2 `ErrorId`) | individuel `EncoderFaultBypass`, **MAINT_N2 uniquement** |
| `PRG_03_Modes_Cycle_CFC` (`Auth.SyncEnable` / `Sync`) | Synchro refusée si l'un des 2 codeurs faux | — |
| `PRG_06_Outputs_LD` / `PRG_04` (commande) | Interdit toute commande reposant sur la position tant que `EncoderFault` | via Modes/Safety uniquement |
| `PRG_07_Supervision_CFC` (IHM) | `EncoderFault` par treuil → alarme/animation | — |

**Producteur unique de l'agrégat** : `PRG_02_Acquisition` produit `ST_EncoderMeasurements`
(avec `EncoderAvailable` par treuil) ; l'agrégat `EncoderFaultPresent` (M1 OR M2, incluant la
disponibilité) est **calculé par `FB_Modes`** à partir de ce DUT — pas de POU d'agrégation
intermédiaire (supprime le cycle `PRG_02_Encoders` legacy).

**Test de contrat (non-régression)** : perte bus COD1 simulée ⇒ `M1.EncoderAvailable=FALSE`,
`M1.EncoderFault=TRUE` ⇒ Modes refuse `SEMI_AUTO`, `FB_Safety_Winch` M1 passe `SafeStop`, M2
inchangé, IHM affiche l'alarme M1 — **alors même que `CablePosMSafe` reste gelée dans la plage**.

---

## 📡 3. Diagnostics bus

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

### 🩺 3bis. Diagnostic carte des modules DI (22 TOR reelles)

> ✅ Tranche 2026-08-04 (utilisateur, confirme sur les 3 modules) : les 22 TOR d'entree (§4) sont
> portees par 3 supports materiels distincts, chacun exposant `GetDeviceState()` :

| Module | TOR portees (§4) | Domaine |
|---|---|---|
| `Local_Digital_IO` | #8-15 (8 TOR) | Winch, Machine (Kobold) |
| `VH_0800END` | #1-7 (7 TOR) | Machine (AU, phases, thermiques), freins M1/M2/M3 |
| `VH_0808ETP` | #16-22 (7 TOR) | Translation (positions M3), Machine (hydraulique, crible) |

**Granularite MODULE, pas canal.** `GetDeviceState()` renseigne la sante d'une carte, pas d'une
voie individuelle : un module en defaut ne dit pas *quelle* TOR ment, seulement qu'aucune de ses
TOR n'est fiable. `FB_Input.ChannelOk` (§1 rappel) n'a donc **pas** de source par canal disponible
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
avec le traitement `EncoderFault` deja en place (§2ter). Aucun bypass simulation sur ce diagnostic :
un module DI absent en simulation banc reste un fait materiel reel, jamais un choix modelise.

---

## 🔌 4. TOR d'entrée — liste exhaustive de `HwIn`

> 📌 **Source de vérité matérielle** : `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260806.csv`
> (export CODESYS → CSV, référence T100). **22 TOR d'entrée réelles** sont recensées ici.
> La structure `ST_HardwareImage` porte les champs ; aucun nouveau champ ne doit être créé dans
> `ST_InputsQualified` ou dans un POU `PRG_01` en retrait.

Le nom d'une E/S dit ce que signifie `TRUE` (`<Domaine>_<ÉtatQuandTRUE>_DI`). La polarité est
normalisée une seule fois dans le mapping d'acquisition `PRG_02_Acquisition` ou garantie par la
configuration matérielle ; aucun `InvertLogic` aval ne doit être ajouté.

| # | TOR (`_DI`) | Device · Bit | Domaine (`HwIn`) | Polarité | `TRUE` = |
|---|---|---|---|---|---|
| 1 | `PowerContactorEngaged_DI` | VH_0800END · 6 | Machine | NO | Contacteur de puissance engagé / portail maître OK |
| 2 | `EmergencyChainClosed_DI` | VH_0800END · 7 | Machine | NC | Boucle AU fermée (coup-de-poing + contact PLC) |
| 3 | `PhaseRotationOk_DI` | VH_0800END · 4 | Machine | NC | Rotation des phases électriques correcte |
| 4 | `BrakeThermalOk_DI` | VH_0800END · 3 | Machine | NC | Thermique freins M1/M2/M3 commun OK |
| 5 | `M1_BrakeIsOpen_DI` | VH_0800END · 0 | Winch | inversée* | Frein M1 **ouvert** (desserré) — normalisée TRUE=serré |
| 6 | `M2_BrakeIsOpen_DI` | VH_0800END · 1 | Winch | inversée* | Frein M2 **ouvert** — normalisée TRUE=serré |
| 7 | `M3_BrakeIsOpen_DI` | VH_0800END · 2 | Translation | inversée* | Frein M3 **ouvert** — normalisée TRUE=serré |
| 8 | `M1_ContactorsReleased_DI` | Local_Digital_IO · 0 | Winch | NO | Contacteurs sens M1 relâchés |
| 9 | `M1_ThermalOk_DI` | Local_Digital_IO · 1 | Winch | NC | Thermique M1 OK |
| 10 | `M2_ContactorsReleased_DI` | Local_Digital_IO · 2 | Winch | NO | Contacteurs sens M2 relâchés |
| 11 | `M2_ThermalOk_DI` | Local_Digital_IO · 3 | Winch | NC | Thermique M2 OK |
| 12 | `M2_TensionedCable_DI` | Local_Digital_IO · 4 | Winch | NC | Câble M2 tendu (capteur mou non déclenché) |
| 13 | `M1_M2_KoboldContactFond_DI` | Local_Digital_IO · 5 | Machine | NO | Kobold fond détecté (info=0 et benne immergée) |
| 14 | `M3_ThermalFeedback_DI` | Local_Digital_IO · 6 | Winch | NC | Thermique M3 OK *(nouveau vs legacy 19)* |
| 15 | `M1M2_TopPositionFree_DI` | Local_Digital_IO · 7 | Winch | NC | Position extrême haut libre — référencement, déclenche AU |
| 16 | `M3_PosTremie_DI` | VH_0808ETP · 0 | Translation | NO | Chariot position Trémie |
| 17 | `M3_PosPV_DI` | VH_0808ETP · 1 | Translation | NO | Chariot position PV (ralentissement Trémie) |
| 18 | `M3_PosP2_DI` | VH_0808ETP · 2 | Translation | NO | Chariot position P2 |
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

## ⚡ 5. Sorties physiques

Les sorties finales restent dans `PRG_OUTPUTS_LD` en Ladder (cible `PRG_06_Outputs_LD`).

| Regle | Exigence |
|---|---|
| 🧱 Barrieres finales | Uniques productrices des commandes physiques autorisees. |
| 🛡️ SafeStop | Laisse la deceleration metier se terminer. |
| 🔴 Coupure finale | `Enable=FALSE`, perte contacteur, timeout ou defaut final. |
| 🧨 PowerCutOff | Demande safety agregee puis canaux A/B fail-safe. |

Le detail de la chaine AU/rearmement est proprietaire de la Partie 01.

---

## 🩺 6. Preflight (qualification machine arrêtée)

| Fiche | FB | Contenu |
|---|---|---|
| [`FB_Acquisition_Preflight`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.0.md) | `FB_Acquisition_Preflight` | Verdict passif : 16 contrôles de cohérence E/S machine arrêtée |

`FB_Acquisition_Preflight` vérifie 16 conditions mécaniques/électriques quand la machine est
arrêtée. Observateur pur : aucune écriture de commande, sécurité ou mouvement.

Instance : `PRG_TROUBLESHOOTING_CFC.instPreflight` (ST actuel).
Cible : `PRG_07_Supervision_CFC`, qui absorbe le troubleshooting en lecture seule stricte.

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

## ❓ 7. TBD

- Durees de filtrage par signal apres qualification terrain.
- Statut definitif de `FB_Output` non instancie.
- Diagnostic par canal (`FB_Input.ChannelOk`) : non disponible avec le materiel actuel
  (`GetDeviceState()` = etat carte, pas etat voie) — a revisiter si un module diagnostiquant
  chaque canal individuellement est installe.
- ~~Contrat exact des structures de publication internes vers les pages CFC.~~ ✅ **Résolu** — §2ter : `ST_HardwareImage` (HwReal/HwSim/HwIn), diagnostic modules et `ST_EncoderMeasurements` (M1/M2, lecteurs Treuils/Modes/Supervision).

## 📚 Documents lies

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : architecture cible 7 POU — `PRG_02_Acquisition` et `PRG_06_Outputs_LD`.
- Partie 08 : traitement joystick.
- Partie 09 : homing et vitesse codeur.
- Partie 13 : simulation.
