# 🔔 AUDIT T356 — Chaîne alarmes : recensement exhaustif process + safety

> **Lot** : T356 (parent T278) · **Criticité** C2 · **Nature** : AUDIT PUR — **zéro ligne de `CODE/` modifiée**
> **Agent** : `DSH21` (verrou `TASK_LOCKS.json`) · **Date** : 2026-09-21 · **Ancrage** : `HEAD = c9e1fbfe`
> **Préambule** : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` **APPLIQUÉ** — le brief a été exécuté par
> le porteur lui-même, pas retransmis (condition écrite en tête du brief, même patron que T352/DSH17).
> **Preuve périmètre** : `git status --short -- CODE/` → **vide** (aucun fichier de `CODE/` touché).

```text
============================================================
🧾 AUDIT T356 — CHAINE ALARMES / LECTURE SEULE
============================================================
CODE/ modifié        : AUCUN (git status --short -- CODE/ = vide)
Gates / bundle       : NON APPLICABLES (aucune ligne de code) — déclaré, pas simulé
Script d'inventaire  : TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py
Candidats scannés    : 572 déclarations · 82 causes · 30 bits ad hoc · 116 libellés
Lignes qualifiées    : 119 (défauts tracés fichier:ligne)
Défauts MUETS        : 25 dont 16 safety (15 safety hors slots inertes documentés) ← chiffre critique
============================================================
```

---

## 1. Synthèse chiffrée (à lire en premier)

| Indicateur | Valeur | Preuve / artefact |
|---|---|---|
| Fichiers `.st` scannés | **262** | `T356_synthese_scan.json` |
| Candidats bruts extraits par pattern (univers de départ) | **572** | `T356_candidats_declarations.csv` |
| ↳ tier 1 (vocabulaire du brief) / tier 2 (élargissement) | 492 / 80 | idem |
| Causes élémentaires réelles (`instCauses[i]`) | **82** | `T356_causes_producteurs.csv` |
| Bits de `ErrorId` écrits **hors** `FB_FaultCore` (chemin ad hoc) | **30** | `T356_errorid_bits_ad_hoc.csv` |
| Libellés du carrousel (`AlarmArray[n] :=`) | **116** (80 actifs + 34 `[HISTO]` + 2 remises à zéro) | `T356_bandeau_libelles.csv` |
| Sources agrégées dans `AnyFaultActive` | **11 termes** (`PRG_07_Supervision.st:587-597`) | `T356_aggregation_anyfault.csv` |
| **Lignes de défauts qualifiées (traçées fichier:ligne)** | **119** | `T356_qualification_defauts.csv` |
| Défauts **muets au carrousel** (ni actif, ni `[HISTO]`) | **54** | idem, colonne `Remonte_en_banniere` |
| Défauts **sans aucun message utilisateur** | **35** | idem, colonne `Message_utilisateur` |
| Défauts **totalement silencieux** (ni bannière, ni voyant, ni IHM) | **25** | idem, colonne `Silencieuse` |
| ↳ **dont SAFETY** | **16** | idem |
| ↳ dont slots **volontairement inertes** et documentés (retirés du décompte réel) | 4 (`FB_Winch` bit 1, `CYCLE` bits 6/10, `AU` bit 2) | `FB_Winch.st:117-120`, `FB_CycleSemiAuto.st:488-492`, `:523-525`, `FB_Safety_EmergencyManagement.st:494-495` |
| 🔴 **Défauts réellement muets (décompte net)** | **21** | — |
| 🔴 **Défauts SAFETY réellement muets (le chiffre le plus critique)** | **15** | — |
| Défauts à visibilité **partielle** (texte générique d'étape, cause jamais nommée) | **15** dont **14 safety** | 7 causes de homing machine + 8 lignes encodeur |
| Entrées de carrousel **fantômes** (ne peuvent jamais s'allumer) | **11** (7 `[DIVE]` + 4 `[EXTRACTION]`) | `FB_Hmi_BannerFormatter.st:1022-1052` vs `PRG_07:772-773` |

### Taux de couverture du script (question explicite du brief)

| Mesure | Valeur |
|---|---|
| Candidats trouvés par le script au 1er passage | 572 déclarations **et 75 causes** (au lieu de 82) |
| **Cas atypiques ratés par le 1er passage, récupérés par lecture humaine puis mécanisés** | **7 causes de `FB_CycleMachineHoming`** |
| Cause du raté | index de cause **symbolique** (`instCauses[CST_CauseClimbTimeout]`) et non littéral → le script a été corrigé (résolution des `VAR CONSTANT` + colonne `index_symbolique`) ; le trou est **prouvé**, pas supposé |
| Autres chemins de production invisibles au pattern de nommage, ajoutés au script | **30 écritures ad hoc de bits** `ErrorId := … OR 16#…` (`FB_Acquisition_Preflight.st:68-83`, `FB_Diag_Ethercat.st:129/139/149`, `FB_Diag_CanOpen.st:97/105`) |
| Autres cas trouvés **par lecture seule** (non mécanisables par pattern de nom) | 3 : `FB_Diag_IhmHeartbeat` (aucun bit de défaut, seulement `HeartbeatIhmTimeout`), `FB_SpeedStep.ConfigError` (relayé en bit 2 de `FB_Winch`), entrées fantômes `[DIVE]`/`[EXTRACTION]` |
| Couverture finale annoncée | **100 % des 3 chemins de production identifiés** (cause → `FB_FaultCore`, bit ad hoc, booléen nommé) sur les 262 fichiers |

---

## 2. Écarts majeurs classés par gravité

### 🔴 E1 — CRITIQUE (safety, priorité 1 du brief) : bande morte de 6,0 à 7,0 m sur la synchro M1/M2
`FB_WinchSync` bit 2 = « Écart critique synchronisation treuils M1/M2 », **latché**, alimenté par
`FB_WinchSync.st:179-180` sur le seuil 2 de `FB_SyncDeviation` (`CfgSyncCriticalTolerance_M`, défaut **6,0 m**,
`ST_SyncCfg.st:7`). Le formateur ne décode que `16#0001` et `16#0002` (`FB_Hmi_BannerFormatter.st:996`, `:999`)
→ **aucun libellé ne nomme `16#0004`**. L'atténuation par Meca E (bit 12/13 des safety, lui libellé) utilise un
**autre** seuil, `_WinchCriticalSyncTolerance_M` défaut **7,0 m** (`GVL_PERSISTENT.st:59`, câblé `PRG_04:992/1058`).
**Conséquence prouvée** : tout écart réel entre 6,0 et 7,0 m pose un défaut safety latché, allume le voyant
`AnyFaultActive` (`PRG_07:594`) **sans aucun message opérateur**, et empêche l'acquittement d'être rattaché à une cause nommée.

### 🔴 E2 — MAJEUR (safety) : « dépassement bornes physiques absolues câble » bloque la machine en silence
`FB_Encoder_Safety.st:53` / `:57` → `EncoderIncoherent` (`:81`) → gate `FB_EncoderReliability.EncoderFault`
(`FB_EncoderReliability.st:30`) consommé par `PRG_03_Modes_Cycle.st:95/194` et `FB_CycleSemiAuto.st:573`.
Aucune des 80 entrées actives du carrousel ne transporte ce signal, et `ST_EncoderHMI.st:7-27` **n'a aucun champ**
pour l'exposer : ni voyant, ni texte, ni variable IHM. Deux causes safety (hors bornes + incohérence redémarrage)
× 2 treuils.

### 🔴 E3 — MAJEUR (safety) : la façade codeur `FB_Encoder.Fault` est publiée puis **jamais lue**
`PRG_02_Acquisition.st:636` / `:691` recopient `instEncoderM1/M2.Fault` dans `Data.EncoderM1/2.Fault`.
`grep` sur les 262 fichiers : **aucun consommateur**. 3 bits × 2 treuils, dont « échec confirmation transaction
preset » (latché) qui conditionne le homing. Visible nulle part.

### 🔴 E4 — MAJEUR (safety) : erreurs de homing/codeur nommées dans le code, absentes de l'IHM
`FB_Encoder_Abs` (2 bits) et `FB_Encoder_Homing` (4 bits) remontent jusqu'à `GVL_IHM.M1/M2Treuil.*.State.Encoder.ErrorId`
(`FB_WinchStateProjection.st:129-135`, `:196-202`) mais **aucun libellé du carrousel** ne les décode : l'opérateur
voit un code binaire sur un écran de dépannage. Et les 7 causes de `FB_CycleMachineHoming` (`:434-460`), toutes
latchées, **ne sont pas publiées du tout** (`PRG_02:582-595` ne recopie que `Step`/`Instruction`/`HomingLoss`) :
seule une consigne d'étape générique s'affiche (`FB_Hmi_BannerFormatter.st:302-303`).

### 🔴 E5 — MAJEUR (classe T255-D reproduite hors périmètre du gate G506) : défauts qui allument le voyant sans texte
- `FB_Winch` bit 2 « Configuration table des paliers vitesse invalide » : `Fault.Error` entre dans
  `WinchMxSafety.Error` (`FB_WinchStateProjection.st:236/264`) → `AnyFaultActive` (`PRG_07:591-592`), mais
  `WinchMxSafety.ErrorId` ne porte **que** `SafetyMx.Fault.ErrorId` → le bit n'est jamais décodé.
- `FB_WinchOutputInterlock` bit 0 « Timeout confirmation ouverture frein treuil » : bloque le démarrage du treuil,
  visible seulement comme `GVL_IHM.*.State.FinalInterlockErrorId` — le formateur n'a **aucune** entrée
  `FinalInterlockErrorId` treuil (seul M3 est câblé, `PRG_07:763`, avec libellé `:973`). Asymétrie M3/M1-M2.
- `FB_Joystick` bits 0-2 et `FB_Modes` bits 0/2/3 : agrégés au voyant, aucun texte (exemptions nominatives G506).

### 🟠 E6 — MAJEUR : `PreflightErrorId` — 16 bits produits, aucun consommateur, aucun texte
`FB_Acquisition_Preflight.st:68-83` (16 `OR 16#…`), publié en variable brute (`PRG_07:444`). `PreflightOk`
(`:87`) n'est lu par **aucun** code. C'est la matérialisation de l'alerte T352 : la moitié IHM/hiérarchisation de
T278 n'a jamais été implémentée.

### 🟠 E7 — MAJEUR (structurel) : **deux tables de texte non reliées**
Les 82 libellés de causes (`ST_FaultCause.Texte`, 83 écritures) ne sont **lus par aucun code** — vérifié sur les
262 fichiers : `.Texte` n'apparaît qu'en partie gauche d'affectation. Le carrousel réécrit **sa propre** table
(114 libellés, `FB_Hmi_BannerFormatter.st:812-1220`). Aucun lien, aucune garantie de cohérence, et un bit sans
libellé passe inaperçu (c'est exactement E1, E4, E5).

### 🟠 E8 — MAJEUR : entrées fantômes du carrousel
`DiveErrorId := 0` (`PRG_07:772`) et `ExtractionErrorId := 0` (`:773`) en dur, alors que le carrousel conserve
**7 entrées `[DIVE]`** (`FB_Hmi_BannerFormatter.st:1022-1040`) et **4 `[EXTRACTION]`** (`:1043-1052`) : 11 libellés
qui ne peuvent jamais s'allumer (producteurs supprimés — `PRG_03_Modes_Cycle.st:176/418`).

### 🟠 E9 — MOYEN : attribution erronée de la cause de SafeStop synchro
`PRG_04_Treuils_Benne.st:1847` et `:1893` : `(instWinchSync.Fault.ErrorId AND 16#0002)` — or `16#0002` = bit 1 =
« Discordance contacteurs » (`FB_WinchSync.st:177`), pas l'écart de synchronisation (bit 2 = `16#0004`). La trace
terrain nomme donc une mauvaise cause et ne teste jamais le bit critique.

### 🟠 E10 — MOYEN : masques `ErrorId` non documentés et collisionnés
`FB_Diag_Ethercat.st:149` pose `16#0030` pour la perte de l'encodeur M2 alors que `16#0010` est déjà la perte du
variateur M3 (`:129`) et que M1 n'utilise que `16#0020` (`:139`) ; `GVL_IHM.Network.EcatErrorId` OR-agrège les 4
esclaves (`PRG_07:640`) → un code agrégé est ambigu. Aucun registre de bits n'existe pour aucun des producteurs
(voir §6 : `NAMING_CONVENTION.md` dit « bit n = défaut n » mais ne tient pas la table).

### 🟡 Mineurs
- Bit 13 (escalade Meca E → `PowerCutOff`) : libellé actif présent, **aucune entrée `[HISTO]`** alors que le bit est latché.
- « Survitesse » (`FB_Safety_Winch.st:100`) : latch **hors bitfield** → jamais visible en `[HISTO]`.
- Bit 3 « surchauffe frein M3 » : exclu du carrousel actif sans que l'exclusion soit documentée ni couverte par G506 (contrairement aux bits treuil équivalents).
- `FB_Translation` bit 6 et `FB_Safety_Translation` bit 6 désignent la même grandeur physique (limite extrême) avec deux libellés distincts → ambiguïté d'acquittement.
- Double libellé `[BENNE]`/`[CAN]`/`[Mx]` possible pour une même cause physique (perte joystick), donc sur-comptage du carrousel.

---

## 3. Méthode (script d'inventaire d'abord, lecture humaine ensuite)

1. **Recherche d'outillage CI existant AVANT d'écrire** : `TOOLS/AGENT_WORKFLOW/scripts/` (100 scripts + 21 gates)
   contient déjà **`G506_check_anyfault_banner_labels.py`** — mécanisme **réutilisé** (lecture de
   `AnyFaultActive` + décodage des `AlarmArray[...]`). **Mais sa couverture est partielle** : il contrôle la
   complétude **par bit uniquement pour les 2 treuils** (`WINCH_BIT_MAP`) et, pour les autres domaines, une seule
   ligne par source (`ROWS_OTHER`) → E1, E4, E5, E10 passent au vert. Constat structurel à traiter en lot séparé.
2. **Étape 1 — inventaire mécanique** : `TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py`
   (262 fichiers, 7 étages : déclarations / causes / bits ad hoc / libellés carrousel / agrégation /
   références de chaque candidat / classification de 100 % de l'univers).
   - `NAMING_CONVENTION.md` **ne porte pas** de vocabulaire alarme exploitable : la ligne 69 (`DriveHasFault`),
     la ligne 496 (`ErrorId = bitfield WORD, bit n = défaut n`) et la ligne 308 (`Diag`) existent, mais **aucune
     liste fermée de préfixes/suffixes de défaut**, et **aucun registre de bits** n'est imposé. C'est un écart en
     soi → patterns **élargis** (tier 2 : `Defaut`, `Anomal`, `Incident`, `Violation`, `Invalid`, `Saturated`,
     `OutOfRange`, `Reject`, `Latched`, `BlockReason`, `Reserve`), tracé par candidat.
3. **Étape 2 — qualification** : chaque ligne du CSV brut est tracée par lecture réelle (jamais par supposition de
   câblage) : écriture du bit, agrégation, libellé actif, libellé `[HISTO]`, texte, publication IHM.
4. **Sens inverse** : les 116 affectations `AlarmArray` ont été comparées aux producteurs réels (§4).
5. **Focus** : treuils M1/M2, synchro et safety traités en priorité 1 ; translation, benne, réseau, joystick, modes,
   cycle, homing, préflight en priorité 2 — **tous** couverts (aucun domaine laissé de côté).
6. **Limite assumée** : la visualisation CODESYS n'est pas dans le dépôt. Un champ de `GVL_IHM` ou un `.Texte`
   d'instance **pourrait** être lié directement dans la visualisation : les constats « jamais lu dans `CODE/` »
   sont donc formulés comme tels (§8), jamais comme « invisible à coup sûr ».

---

## 4. Vérification inverse — entrées du carrousel sans bit réel

| Entrées | Constat | Preuve |
|---|---|---|
| `[DIVE]` ErrorID:01 → 07 (7 libellés) | Ne peuvent **jamais** s'allumer : `DiveErrorId := 0` en dur | `FB_Hmi_BannerFormatter.st:1022-1040` ; `PRG_07_Supervision.st:772` |
| `[EXTRACTION]` ErrorID:01 → 04 (4 libellés) | Idem : `ExtractionErrorId := 0` en dur, producteurs supprimés | `FB_Hmi_BannerFormatter.st:1043-1052` ; `PRG_07:773` ; `PRG_03_Modes_Cycle.st:176/418`, `FB_TroubleshootingView.st:371` |
| `[SYNC] ErrorID:02 - incoherence commande` | Le libellé existe mais **la cause « écart critique » (bit 2) n'a aucun libellé** (E1) | `FB_Hmi_BannerFormatter.st:999` |

Aucun autre libellé orphelin : les 69 autres entrées actives correspondent toutes à un producteur identifié.

---

## 5. « Message d'action utilisateur » — état réel du code

**La notion n'existe pas comme mécanisme associé à un défaut.** Il n'y a **aucune** structure liant
`(bit de défaut) → (texte de cause) → (action opérateur)`. Ce qui existe :

| Canal | Nature | Preuve |
|---|---|---|
| `Banner.OperatorActionText` | Action **générique, indexée par étape de cycle ou par direction** — pas par défaut | `FB_Hmi_BannerFormatter.st:695-789` |
| 2 actions réellement liées à un défaut | Uniquement le bit 6 « limite basse câble » (M1/M2/M1+M2) | `FB_Hmi_BannerFormatter.st:766-784` |
| `Banner.SpecialConditionText` | Dérogations/bypass + motif de refus de changement de mode | `FB_Hmi_BannerFormatter.st:368-391` |
| `MachineHomingInstruction` | Consigne d'étape de homing (jamais la cause du défaut) | `FB_CycleMachineHoming.st:473-862` → `FB_Hmi_BannerFormatter.st:302-303` |
| `GVL_Troubleshooting` (`FB_TroubleshootingView`) | **Vue de dépannage** : booléens/`IdxNNN_` par étape — **un seul champ `STRING`** (`Idx212_OperatorAction`) — aucun texte de défaut | `FB_TroubleshootingView.st` ; `ST_ChainCycleSemiAuto.st:32-39` |

Conclusion : un défaut muet (§1) n'a **aucun repli automatique** vers un message. Le forcer serait une invention —
c'est signalé ici comme un manque de conception, pas rapproché de force.

---

## 6. Tableau exhaustif qualifié (119 défauts tracés)

> Le CSV `T356_qualification_defauts.csv` porte les **9 colonnes demandées + la preuve** pour ces mêmes 119 lignes.
> Ci-dessous la vue compacte par domaine (mêmes lignes, mêmes verdicts).
> Légende `Silencieuse` : **OUI** = aucune sortie visible · **PARTIEL** = texte générique d'étape mais cause jamais nommée · **NON** = sortie visible.

### 6.1 Treuils M1 / M2 — safety (`FB_Safety_Winch`, 16 bits × 2 treuils)

| Défaut | Condition / écriture du bit | Bannière | Message | Silent. |
|---|---|---|---|---|
| ErrorID:01 perte com opérateur | `FB_Safety_Winch.st:269` → `FB_FaultCore.st:53` | OUI `:852` (M1) / `:900` (M2) | OUI « [M1] ErrorID:01 - perte com operateur » | NON |
| ErrorID:02 perte/défaut codeur | `:280`, latch `:278` | OUI `:855` / `:903` | OUI « [M1] ErrorID:02 - perte codeur » | NON |
| ErrorID:03 surchauffe moteur | `:288`, latch `:286` | `[HISTO]` `:1119` / `:1160` | OUI « [HISTO] [M1] ErrorID:03 - surchauffe moteur » | NON |
| ErrorID:04 mou de câble | `:294` (live) | `[HISTO]` `:1122` / `:1163` | OUI « [HISTO] [M1] ErrorID:04 - mou de cable » | NON |
| ErrorID:05 rotation phases | `:305`, latch `:303` | OUI `:858` / `:906` | OUI « [M1] ErrorID:05 - rotation phases » | NON |
| bit 5 fin de course haut atteint | `:311` (live) | NON (16#0020 non décodé, absent de `[HISTO]`) | générique « [TREUIL] Limite haute » `:757` | NON |
| bit 6 limite basse câble | `:320` (live) | OUI `:895` / `:934` | OUI « [M1] Limite basse cable atteinte » + action `:781` | NON |
| ErrorID:08 Meca A | `:335`, latch `:334` | OUI `:861` / `:909` | OUI « [M1] ErrorID:08 - MecaA - deplacement sans commande » | NON |
| ErrorID:09 Meca B | `:348`, latch `:343` | OUI `:864` / `:912` | OUI « [M1] ErrorID:09 - MecaB - arret non confirme apres stop » | NON |
| ErrorID:10 Meca C | `:360`, latch `:359` | OUI `:867` / `:915` | OUI « [M1] ErrorID:10 - MecaC - glissement pendant benne figee » | NON |
| ErrorID:11 surchauffe frein | `:368`, latch `:366` | `[HISTO]` `:1137` / `:1178` | OUI « [HISTO] [M1] ErrorID:11 - surchauffe frein » | NON |
| ErrorID:12 Meca D | `:385`, latch `:381` | OUI `:870` / `:918` | OUI « [M1] ErrorID:12 - MecaD - non-arret au capteur haut » | NON |
| ErrorID:13 Meca E écart critique | `:399`, latch `:397` | OUI `:873` / `:921` | OUI « [M1] ErrorID:13 - MecaE - ecart synchro M1/M2 critique » | NON |
| bit 13 escalade Meca E | `:414`, latch `:407`/`:412` | OUI (même libellé) — **aucun `[HISTO]`** | OUI « [M1] ErrorID:13 - MecaE… » | NON |
| ErrorID:15 sens opposé | `:427`, latch `:426` | OUI `:876` / `:924` | OUI « [M1] ErrorID:15 - sens oppose » | NON |
| ErrorID:16 absence mouvement | `:445`, latch `:444` | OUI `:879` / `:927` | OUI « [M1] ErrorID:16 - discordance commande/retour/mouvement » | NON |
| Survitesse (hors bitfield) | `:454` → `:485` | OUI `:882` / `:930` | OUI « [M1] Survitesse treuil detectee (SafeStop) » | NON |

### 6.2 Treuils M1/M2 — mouvement, estimation de charge, barrière finale

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| `FB_Winch` bit 1 « contacteur collé » | `FB_Winch.st:120` `Active := FALSE` en dur | NON | NON | **OUI** (inert, documenté `:117-119`) |
| `FB_Winch` bit 2 table des paliers invalide | `:124`, latch `:114` | **NON** (le formateur ne reçoit pas `State.ErrorId`) | **NON** (texte `:126` orphelin) | **OUI** (voyant allumé, zéro texte) |
| `FB_WinchLoadEstimator` bit 0 | `:65`, latch `:66` | NON | NON | **OUI** (sortie `Fault` jamais lue) |
| `FB_WinchOutputInterlock` bit 0 timeout frein | `:528`, latch `:529` | **NON** (aucune entrée treuil dans le formateur) | NON | **OUI** (bloque le mouvement) |

### 6.3 Synchronisation M1/M2 (priorité 1)

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| SYNC ErrorID:01 écart (seuil 3,0 m) | `FB_WinchSync.st:171` | OUI `:997` | OUI « [SYNC] ErrorID:01 - ecart M1/M2 » | NON |
| SYNC ErrorID:02 discordance contacteurs | `:175`, latch `:176` | OUI `:1000` | OUI « [SYNC] ErrorID:02 - incoherence commande » | NON |
| **SYNC ErrorID:03 ÉCART CRITIQUE (seuil 6,0 m)** | `:179`, latch `:180` | **NON** — aucun libellé ne décode `16#0004` | NON (texte `:181` orphelin) | **OUI (E1)** |
| Trace `SafeStopSourceSync` (attribution) | `PRG_04:1847` / `:1893` testent `16#0002` au lieu de `16#0004` | NON | NON | OUI (E9) |

### 6.4 Benne (5 causes, 100 % libellées)

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| ErrorID:01 configuration géométrie | `FB_Bucket.st:189`, latch `:190` | OUI `:980` | OUI « [BENNE] ErrorID:01 - configuration geometrie invalide » | NON |
| ErrorID:02 dépassement écart max | `:215`, latch `:216` | OUI `:983` | OUI « [BENNE] ErrorID:02 - depassement ecart max autorise » | NON |
| ErrorID:03 timeout déplacement | `:269`, latch `:270` | OUI `:986` | OUI « [BENNE] ErrorID:03 - timeout commande deplacement » | NON |
| ErrorID:04 glissement treuil M1 | `:278`, latch `:279` | OUI `:989` | OUI « [BENNE] ErrorID:04 - glissement treuil M1 » | NON |
| ErrorID:05 codeurs non référencés | `:286` (live) | OUI `:992` | OUI « [BENNE] ErrorID:05 - codeurs treuils non references » | NON |

### 6.5 Translation M3 — safety, mouvement, barrière, frein

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| M3 ErrorID:01 perte com opérateur | `FB_Safety_Translation.st:123` | OUI `:939` | OUI | NON |
| M3 ErrorID:02 perte EtherCAT variateur | `:132` | OUI `:942` | OUI | NON |
| M3 ErrorID:03 rotation phases | `:143`, latch `:144` | OUI `:945` | OUI | NON |
| M3 ErrorID:04 surchauffe frein | `:151`, latch `:152` | `[HISTO]` `:1204` | OUI « [HISTO] [M3] ErrorID:04 - surchauffe frein » | NON |
| M3 ErrorID:05 Meca B | `:175`, latch `:176` | OUI `:948` | OUI | NON |
| M3 ErrorID:06 Meca A | `:191`, latch `:192` | OUI `:951` | OUI | NON |
| M3 ErrorID:07 limite extrême | `:203` (live) | OUI `:954` | OUI | NON |
| M3 ErrorID:08 capteurs incohérents | `:215`, latch `:216` | OUI `:957` | OUI | NON |
| `FB_Translation` bit 0 défaut frein | `FB_Translation.st:106` (← `FB_Brake.Fault.Error`) | OUI `:964` | OUI « [M3] Defaut sequence / retour frein translation » | NON |
| `FB_Translation` bit 3 variateur AC600 | `:110`, latch `:111` | OUI `:967` | OUI | NON |
| `FB_Translation` bit 6 limite extrême | `:127` | OUI `:970` | OUI | NON |
| `FB_TranslationOutputInterlock` bit 0 | `FB_TranslationOutputInterlock.st:115`, latch `:116` | OUI `:973` | OUI « [M3] Barriere finale… » | NON |
| `FB_Brake` bit 0 retour contacteur frein | `FB_Brake.st:126`, latch `:127` (et `:82`) | OUI (via M3 bit 0) | OUI | NON |

### 6.6 Encodeurs M1/M2 (22 bits — zone la plus muette du projet)

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| `FB_Encoder` bit 0 perte matériel/com | `FB_Encoder.st:226` → `Data.EncoderM1/2.Fault` | NON | NON | **OUI** (E3) |
| `FB_Encoder` bit 1 incohérence mesure | `:228` | NON | NON | **OUI** |
| `FB_Encoder` bit 2 échec transaction preset | `:230` (latché) | NON | NON | **OUI** |
| `FB_Encoder_Abs` bits 0/1 | `FB_Encoder_Abs.st:75`, `:83` | NON | NON (textes `:77`, `:85` orphelins) | **PARTIEL** (`GVL_IHM…State.Encoder.ErrorId`) |
| `FB_Encoder_Homing` bits 0→3 | `FB_Encoder_Homing.st:136/140/144/148` | NON | NON (textes `:138-150` orphelins) | **PARTIEL** |
| `FB_Encoder_Safety` bits 0/1 | `FB_Encoder_Safety.st:53`, `:57` → `EncoderIncoherent` | NON | NON | **OUI (E2, critical)** |

### 6.7 Cycle semi-auto (12 causes, 10 actives toutes libellées)

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| ErrorID:01 limite légale | `FB_CycleSemiAuto.st:446`, latch `:451` | OUI `:1068` | OUI | NON |
| ErrorID:02 désynchronisme bloquant | `:458`, latch `:465` | OUI `:1071` | OUI | NON |
| ErrorID:03 écart vitesse montée | `:468`, latch `:469` | OUI `:1086` | OUI | NON |
| ErrorID:06 perte com IHM (bit 3) | `:472`, latch `:473` | OUI `:1080` | OUI | NON |
| ErrorID:07 timeout étape (bit 4) | `:476`, latch `:477` | OUI `:1083` | OUI | NON |
| ErrorID:04 écart codeurs remontée (bit 5) | `:482`, latch `:484` | OUI `:1074` | OUI | NON |
| bit 6 « Réserve » | `:490` `Active := FALSE` en dur | NON | NON | **OUI** (inert, documenté) |
| ErrorID:08 hors FDC haut P1 (bit 7) | `:497`, latch `:500` | OUI `:1089` | OUI | NON |
| ErrorID:09 palier 5 interdit (bit 8) | `:506`, latch `:511` | OUI `:1092` | OUI | NON |
| ErrorID:10 palier 4 Kobold (bit 9) | `:517`, latch `:520` | OUI `:1095` | OUI | NON |
| bit 10 « Réserve » | `:523` `Active := FALSE` en dur | NON | NON | **OUI** (inert, documenté) |
| ErrorID:12 consigne invalide (bit 11) | `:527`, latch `:530` | OUI `:1098` | OUI | NON |

### 6.8 Cycle de référencement machine (7 causes — **aucune publiée**)

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| Cause 0 perte de datum en mouvement | `FB_CycleMachineHoming.st:434`, latch `:435` | NON | PARTIEL « Reference perdue - Arret controle » `:789` | **PARTIEL** |
| Cause 1 montée capteur haut non aboutie | `:438`, latch `:439` | NON | PARTIEL « Erreur ou Echec homing - Acquitter (Reset) » `:783` | **PARTIEL** |
| Cause 2 mouvement hors phase | `:442`, latch `:443` | NON | PARTIEL | **PARTIEL** |
| Cause 3 erreur homing codeur M1 | `:446`, latch `:447` | NON | PARTIEL | **PARTIEL** |
| Cause 4 erreur homing codeur M2 | `:450`, latch `:451` | NON | PARTIEL | **PARTIEL** |
| Cause 5 homing des axes non obtenu | `:454`, latch `:455` | NON | PARTIEL | **PARTIEL** |
| Cause 6 descente interdite en HX7 | `:458`, latch `:459` | NON | PARTIEL (instruction HX7 `:794-803`) | **PARTIEL** |

### 6.9 Modes, sécurité/AU, joystick, réseaux, préflight

| Défaut | Condition / écriture | Bannière | Message | Silent. |
|---|---|---|---|---|
| Modes bit 0 cycle non prêt (codeur) | `FB_Modes.st:163` | NON | NON | **OUI** (voyant) |
| Modes bit 1 changement de mode refusé | `:179` | NON (carrousel) | OUI partiel (`ModeChangeBlockReason`, `:368-370`) | NON |
| Modes bit 2 re-homing obligatoire | `:167` | NON | NON | **OUI** |
| Modes bit 3 référencement incomplet | `:171` | NON | NON | **OUI** |
| AU ErrorID:01 redondance contacteurs | `FB_Safety_EmergencyManagement.st:490` | OUI `:1057` | OUI | NON |
| AU ErrorID:02 échec armement | `:492` | OUI `:1060` | OUI + message dédié `PRG_07:776` | NON |
| AU bit 2 réservé | `:494` (texte vide `:495`) | NON | NON | **OUI** (inert, cohérent) |
| AU ErrorID:04 échec autotest | `:496` | OUI `:1063` | OUI | NON |
| Joystick bit 0 échec calibration | `FB_Joystick.st:139` | **NON** (aucune entrée joystick au formateur) | NON (texte `:140` orphelin) | **OUI** |
| Joystick bit 1 capteur hors plage | `:141` | NON | NON | **OUI** |
| Joystick bit 2 perte bus CAN | `:143` | NON (le libellé `[CAN]` vient d'un autre producteur) | partiel via `[Mx] ErrorID:01` | **OUI** |
| ECAT maître 16#0001 | `FB_Diag_Ethercat.st:201` | OUI `:834` | OUI « [ECAT] Defaut bus EtherCAT » | NON |
| ECAT variateur 16#0010 | `:129` | OUI `:842` | OUI « [M3] Variateur AC600 non detecte (ECAT) » | NON |
| ECAT encodeur M1 16#0020 | `:139` | OUI `:836` | OUI « [M1] Codeur absolu COD1 non detecte (ECAT) » | NON |
| ECAT encodeur M2 16#0030 | `:149` | OUI `:839` | OUI « [M2] Codeur absolu COD2 non detecte (ECAT) » | NON (mais E10 : masque collisionné) |
| CAN bus 16#0001 / joystick 16#0001-0002 | `FB_Diag_CanOpen.st:97/105/135` | OUI `:828`/`:831` | OUI « [CAN] … » | NON |
| Heartbeat IHM timeout (aucun bit) | `FB_Diag_IhmHeartbeat.st:65` | NON | NON (publié `GVL_IHM.Commun`, `PRG_07:411`) | **OUI** (consommé indirectement comme cause safety) |
| Préflight 16 bits (freins, contacteurs, thermiques, phases, mou, capteurs M3, AU, codeurs, homing/position) | `FB_Acquisition_Preflight.st:68-83` | NON | NON | **OUI ×16 (E6)** |
| `FB_SpeedStep.ConfigError/ConfigErrorId` | `FB_SpeedStep.st:24-25` → `FB_Winch.st:113` | NON | NON | **OUI** (relayé dans le bit 2 silencieux) |
| `[DIVE]` ×7 et `[EXTRACTION]` ×4 (sens inverse) | aucun producteur (`PRG_07:772-773` = 0) | **entrées mortes** | textes présents `:1022-1052` | N/A (fantômes) |
| Notion « message d'action utilisateur » | absente comme mécanisme | — | — | N/A (cf. §5) |

---

## 7. Ce que le gate G506 couvre — et ce qu'il laisse passer

| Contrôle G506 | Couverture réelle | Conséquence |
|---|---|---|
| Complétude **par bit** vs producteur | **2 treuils seulement** (`WINCH_BIT_MAP`, bits 0-15) | OK pour M1/M2 ; **aucun** contrôle équivalent pour synchro, translation, benne, cycle, encodeurs, préflight |
| Sources agrégées dans `AnyFaultActive` | 11 termes cartographiés (`ROWS_OTHER` : 1 ligne par source) | E1 (bit 2 synchro), E4, E5, E10 passent au vert |
| Exemptions | 5 exemptions nominatives (bits treuil 2/3/5/10 + 3 sources entières) | Les exclusions de type « warning » pour **M3 bit 3** et pour les autres domaines **ne sont pas documentées** |

➡️ **Recommandation de lot séparé (non implémentée ici)** : étendre G506 (ou créer un G517) pour contrôler la
complétude **par bit de tout producteur** `ST_Fault` publié, et pour détecter les entrées `AlarmArray` sans
producteur (fantômes). Le script T356 est réutilisable tel quel pour la revérification après correctifs.

---

## 8. Limites de l'audit (ce qui n'est PAS prouvé)

- La visualisation CODESYS n'est pas dans le dépôt : un champ de `GVL_IHM` ou un `ST_FaultCause.Texte` **pourrait**
  être lié directement dans la visu par un écran que nous ne voyons pas. Tous les constats « aucune lecture dans
  `CODE/` » sont donc bornés à ce périmètre (formulés ainsi, jamais « invisible à coup sûr »).
- Aucun état runtime n'a été observé : l'audit est **statique**, conformément au brief (lire le code, pas l'état simulé).
- Les seuils cités (6,0 / 7,0 m) sont les **valeurs par défaut du code** ; si `GVL_PERSISTENT` a été recalé sur la
  machine, la largeur de la bande morte change — le **défaut de structure** (bit non libellé) reste identique.
- `FB_Brake` écrit sa cause 0 dans deux branches (`:82` branche désactivée, `:126` branche active) : une
  combinaison `Active=FALSE / Latching=TRUE` mérite une vérification dédiée — **hors périmètre T356**, signalée.

---

## 9. Traçabilité

| Élément | Valeur |
|---|---|
| Ancrage | `HEAD = c9e1fbfeff460a4bb6065f37efb80d5e574d8772` |
| Périmètre code | `git status --short -- CODE/` → **vide** (0 fichier modifié) |
| Script réutilisable | `TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py` (non branché dans `run_all_gates.py`, conformément au brief) |
| Reproduction | `python TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py . --out DOC/WFLOW/AUDITS/T356_ALARMES_20260921` |
| Artefacts | `T356_candidats_declarations.csv` (572) · `T356_causes_producteurs.csv` (82) · `T356_errorid_bits_ad_hoc.csv` (30) · `T356_bandeau_libelles.csv` (116) · `T356_aggregation_anyfault.csv` (11) · `T356_references.csv` (2676) · `T356_univers_complet.csv` (572) · `T356_qualification_defauts.csv` (119) · `T356_synthese_scan.json` |
| Hors scope constaté (devoir d'alerte) | `git status` montre `D TOOLS/AGENT_WORKFLOW/scripts/G499_check_t291b_top_authority.py` (suppression **non** de ce lot — aucune suppression effectuée par T356). Rien n'a été supprimé, déplacé ni réindexé. |
| Commit | **AUCUN** — accord humain explicite requis, distinct du GO |

## 10. Lots de correction proposés (NON implémentés — décision humaine requise)

| # | Objet | Criticité | Base |
|---|---|---|---|
| 1 | Libeller le bit 2 de `FB_WinchSync` + aligner les 2 seuils synchro (6,0 / 7,0 m) | C3/C4 safety | E1 |
| 2 | Router `EncoderIncoherent` (bornes physiques / incohérence redémarrage) vers un canal visible | C3 safety | E2 |
| 3 | Décider du sort de `FB_Encoder.Fault` (publié, jamais lu) : publier ou supprimer | C2 | E3 |
| 4 | Publier les 7 causes de `FB_CycleMachineHoming` + libeller les erreurs codeur | C3 safety | E4 |
| 5 | Créer le canal manquant défaut → texte (relier les 82 `Texte` ou générer les libellés) | C3 structurel | E7 |
| 6 | Retirer / traiter les 11 entrées fantômes `[DIVE]`+`[EXTRACTION]` | C1 | E8 |
| 7 | Étendre le garde-fou CI (complétude par bit tous domaines + détection de fantômes) | C2 outillage | §7 |
| 8 | Trancher le devenir du préflight orphelin (16 bits) | C2 | E6 |
