# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.0)

> Role : definir la frontiere d'acquisition de `PRG_ACQUISITION_CFC` (ST actuel).
> Cible : `PRG_02_Acquisition_CFC`, rang 02 de la `MainTask` — voir §2bis.
> Les decisions de mouvement restent hors de ce document.
> 🗺️ Architecture cible faisant foi : `DOC/AF_Partie-02_Architecture_Programme_v3.0.md` §2 et §4.

La page `PRG_01_Inputs_LD` (Ladder) est associee a cette frontiere : elle affiche les 21 entrees TOR
qualifiees via `FB_Input`, sans logique metier et sans decision.

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
| TC-P06-001 | Aucune lecture d'E/S brute dans les FB métier | Consommateurs lisent des faits qualifiés | `💻 AUTO` | §2 |
| TC-P06-002 | Polarité normalisée une seule fois à l'acquisition | Zéro ré-inversion dans les FB métier | `💻 AUTO` | §2 |
| TC-P06-003 | Bascule réel/simulation centralisée | `HwIn` source unique par domaine | `💻 AUTO` | §2 |
| TC-P06-004 | Diag CANopen/EtherCAT publié en ligne | Statuts dispos pour Modes/Safety/IHM | `💻 AUTO` | §3 |
| TC-P06-005 | Noms des signaux de puissance validés | `PowerKeepAlive_A/B_RQ`, `EmergencyChainClosed_DI` | `🟢 SITE` | §4 |
| TC-P06-006 | Écriture des sorties physiques centralisée | `PRG_OUTPUTS_LD` seul producteur final | `💻 AUTO` | §5 |

---

## 🎯 1. Role

`PRG_01_Inputs_LD` acquiert les entrees TOR **reelles**, normalise leur polarite et applique leur filtrage avant tout usage metier. `PRG_02_Acquisition_CFC` selectionne ensuite, par domaine, l'image reelle qualifiee ou l'image simulee.

L'acquisition publie des **faits qualifies** :
- E/S TOR et PDO conditionnes via la chaine `HwReal` → `FB_SimBench` → `HwIn` ;
- disponibilite des devices (diagnostics CANopen/EtherCAT) ;
- image reelle ou simulee selectionnee par domaine ;
- mesures codeurs brutes/qualifiees selon frontiere validee ;
- joystick, homme-mort et codeurs traites par des FB dedies (`FB_Joystick`, `FB_Encoder_*`, `FB_Translation_PositionDecoder`).

`PRG_01_Inputs_LD` affiche en Ladder les 21 entrees TOR apres qualification (`FB_Input`) :
- polarite normalisee (`TRUE` = etat vrai) ;
- mots de force/test rejetes en dehors de cette page ;
- aucune decision `SafeStop`, mode ou commande actionneur n'y est prise.

L'acquisition ne decide ni `SafeStop`, ni mode, ni commande actionneur.

---

## 🏗️ 2. Chaine d'acquisition

```text
E/S TOR reelles ──► PRG_01_Inputs_LD ──► ST_InputsQualified (reel qualifie)
PDO / mesures reelles ────────────────────────────────────────────┐
FB_SimBench ──────────────────────────────────────────────────────┤
                                                                    ↓
                              PRG_02_Acquisition_CFC : selection reel/simule par domaine
                                                                    ↓
              HwIn + Joystick + Codeurs + PositionDecoder M3 + diagnostics devices
                                                                    ↓
Modes/Cycle → procedes (Treuils/Benne, Translation) avec leur safety → Outputs → Supervision
```

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | Aucun FB metier ne lit une E/S brute device. |
| 🧪 Simulation | La bascule reel/simule se fait une seule fois, par domaine, dans `FB_SimBench`. |
| 🔒 Polarite | Normalisee une seule fois dans `PRG_01_Inputs_LD` (`FB_Input` / DUT de normalisation). |
| ✍️ Producteur unique | `PRG_01_Inputs_LD` produit les TOR reels qualifies; `PRG_02_Acquisition_CFC` produit l'image selectionnee reel/simule et les mesures acquises. |
| 🪜 Inputs LD | `PRG_01_Inputs_LD` acquiert et expose les E/S TOR reelles via `FB_Input`, sans decision metier. |

Le detail homing/vitesse codeur reste proprietaire de la Partie 09. AF06 porte seulement leur acquisition et leur publication.

### Repartition CFC / Ladder (resolution du TBD §6)

| Type de signal | Programme | Langage | Bloc / DUT |
|---|---|---|---|
| E/S TOR reelles qualifiees | `PRG_01_Inputs_LD` | Ladder | `FB_Input` : acquisition, polarite, filtre, `ST_InputsQualified` |
| PDO/mesures, simulation, joystick, codeurs, position M3, diagnostics | `PRG_02_Acquisition_CFC` | CFC | Instances `FB_*`, selection reel/simule, `ST_AcquisitionQualified` |

> 📌 La frontiere est donc explicite : **Ladder acquiert et qualifie les TOR reelles**, puis le **CFC selectionne reel/simule et traite les FB complexes**. Aucune logique metier n'est ecrite dans `PRG_01_Inputs_LD`.

---

## 🧩 2bis. Integration programme — cible `PRG_02_Acquisition_CFC`

**Principe :** acquerir une mesure physique, la mettre a l'echelle, en deduire une vitesse et juger
sa validite est **une seule responsabilite**. La cible reunit donc dans une page unique ce que le
code actuel eclate en quatre POU — ce qui supprime les instances codeurs et joystick dupliquees.

| Ce qui est absorbe par `PRG_02_Acquisition_CFC` | POU actuel | Contenu concerne |
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

📌 Lot de migration : **M1** de `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).
Le référencement (`FB_Encoder_Homing`) n'appartient pas à cette frontière de mesure : il rejoint
`PRG_04_Treuils_Benne_CFC`, où les autorisations de maintenance et la visibilité opérateur sont
disponibles. Il consomme les faits publiés par l'acquisition (`RawPos`, `EncoderAvailable`, retours
d'arrêt) et publie sa calibration/requête de preset vers la chaîne EtherCAT.

---

## 🧾 2ter. Contrats DUT — image d'acquisition

> 📌 Règles de fiche : `AF_Partie-03 §4`. **Producteur unique** : chaque champ a exactement un
> écrivain. Trois images du même type `ST_HardwareImage` (brute / simulée / sélectionnée) + un DUT
> TOR qualifiées. Aucun FB métier ne lit une E/S brute device : tout passe par `HwIn`.

### 🧱 `ST_HardwareImage` — image brute / simulée / sélectionnée (3 instances)

| | Instance | Contenu | Producteur | Lecteurs |
|---|---|---|---|---|
| Brute | `HwReal` | Image **device brute** (polarité physique, valeurs non mises à l'échelle) | `PRG_02_Acquisition_CFC` (lectures E/S/PDO, `GetDeviceState`) | `FB_SimBench`, observation maintenance |
| Simulée | `HwSim` | Image **simulée** (polarité normalisée au modèle) | `FB_SimBench` | `PRG_02` (sélecteur) uniquement |
| Sélectionnée | `HwIn` | Image **résultante par domaine** (réel qualifié OU simulé) | `PRG_02_Acquisition_CFC` (sélecteur `SEL` par domaine) | **Tout le programme métier** (Modes, Treuils/Benne, Translation, Outputs, Supervision) |

**Structure** (4 sous-domaines, identiques entre les 3 instances) :

| Champ | Type | Contenu | Unités | Polarité |
|---|---|---|---|---|
| `Winch` | `ST_HwWinch` | TOR réelles treuils M1/M2 + codeurs COD1/COD2 | — | `_DI` : `TRUE` = état vrai (normalisé) |
| `Translation` | `ST_HwTranslation` | TOR réelles M3 + status word/fréquence AC600 | `Hz` (x100), `WORD` | idem |
| `Operator` | `ST_HwOperator` | Joystick analogique `INT` + état bus CAN | — | — |
| `Machine` | `ST_HwMachine` | Sécurités/commun machine (AU, phases, thermiques, Kobold) | — | `TRUE` = état sûr/OK |

**Sélection par domaine** (une seule bascule, visible dans le CFC Acquisition) :

```text
HwIn.<Domaine> := SEL(SimActive.<Domaine>, HwSim.<Domaine>, <réel du domaine>)
```

- Domaine réel → source = TOR qualifiées (`ST_InputsQualified`) pour les `_DI`, mesures réelles sinon.
- Domaine simulé → source = `HwSim` **sans filtrage** (valeurs simulées normalisées, AF13 §4).
- 🧪 Tous les domaines ont la même logique visible : pas de bascule cachée dans un Ladder.

**Invalidité** : un sous-domaine simulé n'a pas de notion d'erreur physique propre ; les faits de
disponibilité (device, communication) restent évalués sur la source réelle par `PRG_02` (voir §3).

**Cadence** : tâche `T01_Acquisition` (cycle rapide), lecture seule, aucun effet de bord.

**Tests de contrat** :
- Sans simulation : `HwIn.Winch.<champ> == ST_InputsQualified.<champ>` (domaine réel).
- Simulation active sur un domaine : `HwIn.<Domaine> == HwSim.<Domaine>` quel que soit le réel.
- Aucun `_DI` de `HwIn` n'a une polarité physique : tout `TRUE` = état logique normalisé.

### 🔢 `ST_InputsQualified` — TOR réelles qualifiées (à créer)

| Attr. | Valeur |
|---|---|
| Propriétaire / producteur | `PRG_01_Inputs_LD` (Ladder, `FB_Input`) |
| Écrivain unique | `PRG_01_Inputs_LD` |
| Lecteurs | `PRG_02_Acquisition_CFC` (seul — alimente le « réel » des domaines TOR) |
| Contenu | une entrée `BOOL` par TOR réelle qualifiée : `M1/M2/M3_*_DI`, `M1M2_*`, `Machine_*`, joystick homme-mort — exhaustif selon `ST_Hw*` |
| Polarité | `TRUE` = état logique normalisé (déjà inversé/filtré par `FB_Input`) |
| Filtre | appliqué **avant** la sélection, sur le réel uniquement (décision Q1=A validée) |
| Invalidité | pas de champ d'erreur propre : un `_DI` qualifié vaut l'état TOR après `FB_Input` ; une panne de canal remonte via les diagnostics device (§3) |
| Cadence | tâche `T01_Acquisition`, cycle rapide |

**Tests de contrat** :
- Reflète la polarité normalisée : `FB_Input` seul modifie `TRUE/FALSE` du device, pas `PRG_02`.
- Le sim n'apparaît **jamais** dans `ST_InputsQualified` (réel pur) — la bascule vit dans `PRG_02`.
- Aucune décision `SafeStop`, mode ou commande actionneur lue depuis ce DUT en dehors d'`Acquisition`.

> ✅ Décisions actées : filtre `FB_Input` sur le réel uniquement (le sim passe sans filtre) ;
> sélecteur TOR réel/sim visible dans le CFC Acquisition, `PRG_01_Inputs_LD` ne porte que le réel
> qualifié. — Cette frontière invalide l'ordre « filtre après sélection » d'AF13 : alignement AF13
> prévu à l'étape 6.

### 📏 `ST_EncoderMeasurements` — mesures codeur M1/M2 (à créer)

Facts de la chaîne de mesure pure (Abs → Scale → Safety → SpeedMeasure), un sous-DUT par treuil.

| Attr. | Valeur |
|---|---|
| Propriétaire / producteur | `PRG_02_Acquisition_CFC` (chaîne de mesure pure, rang 02) |
| Écrivain unique | `PRG_02_Acquisition_CFC` |
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

**Producteur unique de l'agrégat** : `PRG_02_Acquisition_CFC` produit `ST_EncoderMeasurements`
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

---

## 🔌 4. Polarites et noms

Le nom d'une E/S dit ce que signifie `TRUE`.

| Famille | Exemples confirmes |
|---|---|
| ⚡ Puissance | `PowerContactorEngaged_DI`, `EmergencyChainClosed_DI` |
| 🔁 Maintien / rearmement | `PowerKeepAlive_A_RQ`, `PowerKeepAlive_B_RQ`, `EmergencyArming_RQ` |
| 🛑 Freins | `M*_BrakeIsOpen_DI`, `M*_BrakeRelease_RQ` |
| 🪨 Kobold | `M1_M2_KoboldContactFond_DI`, `M1_M2_KoboldMeasureEnable_DQ` |

`PowerContactorEngaged_DI` confirme le contacteur de puissance et alimente le portail `PowerContactorEngaged`.  
`EmergencyChainClosed_DI` confirme la boucle AU.  
`PowerKeepAlive_*=TRUE` maintient la puissance ; sa retombee ouvre la chaine.

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
- Contrat exact des structures de publication internes vers les pages CFC.

## 📚 Documents lies

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : architecture cible 7 POU — `PRG_02_Acquisition_CFC` et `PRG_06_Outputs_LD`.
- Partie 08 : traitement joystick.
- Partie 09 : homing et vitesse codeur.
- Partie 13 : simulation.
