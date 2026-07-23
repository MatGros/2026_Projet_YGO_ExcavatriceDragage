# 🗂️ PLAN_TASK — Suivi Planning & Reliquats (v1.0)

> 🎯 **Rôle** : seul document de pilotage projet (jalons, tâches, TBD, questions client). Les `AF_PartieN` restent **spec fonctionnelle pure** — tout ce qui est planning/organisationnel vit ici, pas dans les specs.
> 📥 **Remplace** : `PLAN_Finalisation_v1.0.md` + `v1.1.md` + `SAT_Protocole_Essais_v1.0.md` (les 3 archivés dans `ARCHIVES/Doc/`, contenu ingéré ci-dessous).
> 🗓️ Créé 2026-07-09.

---

## 🏁 1. Jalons connus de l'affaire

| Date | Jalon |
|---|---|
| 2026-07-24 | 🎯 **Priorité Demain** — 1) Chargement API + vérification Visualisation IHM (remapping). 2) Qualification purge Bypass Global (M1, M2, M3). 3) Essai du fonctionnement **Capteur Kobold** (contact fond) & IHM. 4) Essai du **Positionneur Translation M3** ("Aller à la position" Trémie/Maintenance/Zone travail). |
| 2026-07-23 | Correctifs terrain — Purge `BypassContactorCheck` (M1, M2, M3), documentation audit `AUDIT_BypassGlobal_Homogenization_v1.0.md` et consignation `MES-004`. |
| 2026-07-22 | `v0.4.27_SupervisionConformityRename` — Renommage complet supervision GVL_IHM + ST_*HMI et conformité suffixes physiques (_M, _Pct, _Hz, _Mps) |
| 2026-07-22 | `v0.4.26_IhmCompatibilityRepair` — Restauration des noms publics IHM historiques : visualisation inchangée |
| 2026-07-15 | `v0.4.8` — IHM_MANU M1/M2 pilotés via `FB_Winch` (rampe/ralentissement natifs, retrait doctrine "Conditional Bypass"), nouvelle limite `CableLimitAscentM1/2_M`, correctifs Méca B (bit8) + benne couplé + `FB_Safety_Translation` (latch défaut) |
| 2026-07-09 | Audit complet + ce `PLAN_TASK` |
| 2026-07-09 | `PLAN_Finalisation_v1.1` (bloquants résolus + priorités actées) + `SAT_Protocole_Essais_v1.0` (protocole recette écrit) — ⚠️ pas encore commités |
| 2026-07-08/09 | `v0.4.4`/`v0.4.5` **IHM_MANU** — mise en service d'urgence (dérogation active, voir §3 ⏸️) |
| 2026-07-08 | `v0.4.0`→`v0.4.3` : simulation stable Winch/Benne + synchro critique Méca E, pré-commissioning câble réel |
| 2026-07-07/08 | Réarchitecture `PRG_00`→`PRG_10` (abandon `PLC_PRG_MAIN`), campagne doc massive, audit cohérence documentaire |
| 2026-07-04 | `PLAN_Finalisation_v1.0` — 1er état des lieux (bloquants, écarts, TBD) |
| 2026-06-30 | Bootstrap projet (init CODESYS, skill workflow, convention nommage) |

---

## 🧩 2. Tâches / Features — état

### ✅ Fait
Joystick · Winch/SpeedStep · Benne · Encoder (pipeline) · Safety_Winch (14 bits) · Modes · Diag CanOpen/EtherCAT · Brake/Ramp · GVL_Simulation

### ✅ Priorités sécurité v1.1 — réalisées
| # | Sujet |
|---|---|
| 2.A | Homme-mort joystick absent en `SEMI_AUTO` → asservir `StartStop` M1/M2/M3 à `DeadmanArmed` + déflexion |
| 2.B | `SafeStopActive` non intégré dans `FB_Cycle` → transition `ERROR_HOLD` manquante |

### 🟡 Partiel
| Brique | Manque |
|---|---|
| `FB_WinchSync` | Surveillance seule (assumé), pas de correction active |
| `FB_Translation` | ✅ Cinématique M3, cinq capteurs, décodage position et ralentissement PV intégrés ; essais terrain restant à réaliser |
| `FB_Safety_Translation` | ✅ Limites Trémie/Maintenance et incohérence capteurs intégrées ; validation banc restant à réaliser |
| `FB_Cycle` | ✅ `Error`/`ErrorId`, `ResetEdge`, `ERROR_HOLD` et stabilisation double codeur intégrés ; essais terrain restant à réaliser |
| `FB_Input`/`FB_Output` (COMMUN) | Existent mais pas intégrés dans Winch/Translation (logique contacteur dupliquée) |

> ℹ️ Cette table conserve les briques historiquement partielles pour assurer la traçabilité. Pour l'état
> courant, la section « État réel du plan » et les lignes T33 à T39 font foi.

### 🔄 État réel du plan — mise à jour 2026-07-18

| Domaine | État actuel | Suite prévue |
|---|---|---|
| Translation M3 / cinq capteurs | ✅ Implémenté et exposé dans `GVL_IHM.TranslationM3` | Essais CODESYS puis terrain |
| Translation M3 / sécurité | ✅ Limites Trémie/Maintenance + incohérence capteurs + SafeStop/PowerCutOff | Vérifier les réactions sur banc |
| Cycle semi-auto / Kobold | ✅ Contact, remontée synchronisée et reprise homme-mort raccordés | Finaliser la stabilisation et les cas d'obstacle |
| IHM cycle et Translation | ✅ GVL de commande, état, diagnostic et simulation | Étendre aux Codeurs/Homing et aux tests opérateur |
| Vitesse réelle des codeurs | ✅ Calcul m/s, surveillance et exposition IHM réalisés | Valider les seuils sur site |
| Remontée cycle / contrôle dynamique | 🟠 Comparaison vitesse M1/M2 raccordée ; seuil/tempo à 0 donc inactive | Définir puis activer les paramètres après essais terrain |
| Paliers / charge estimée | ✅ 5 plages, tableau 2D et garde-fou implémentés | Calibrer et activer progressivement sur site |
| IHM_MANU | ✅ Supprimé définitivement (2026-07-19) — pilotage manuel exclusivement MAINT_N1/N2 + joystick homme-mort | Rien — historique dans `IHM_MANU_Journal_Modifications.md` |
| Documentation architecture | ✅ Réalignée avec l'orchestration `PRG_00`→`PRG_10` | Contrôle des liens et chemins réalisé ; en-têtes historiques à traiter séparément si nécessaire |
| Visu graphique | ❌ Hors périmètre livré, GVL disponible | À traiter séparément avec l'IHM supervision |

### ⏸️ Différé assumé (pas un trou béant)
`PRG_08_AuxiliaryControl` — les commandes casque, grille et centrale hydraulique sont retirées du périmètre PLC ; seul le retour thermique de la centrale reste à remonter en diagnostic.

### ❌ Manquant
IHM visu graphique (dossier `visu/` vide, seule la couche d'échange `GVL_IHM` existe).

### 🗑️ Nettoyage dû
`GVL_BUS`/`GVL_Machine_Stub` ✅ supprimés (2026-07-15, orphelins confirmés) · `ST_IHM_MANU` ✅ supprimé (2026-07-19) ·
Anciens champs `GVL_Translation_M3_Stub` liés à `DEGRADED_IO` ✅ supprimés après confirmation
d'absence de consommateur. `PosPV_DI` et `StubTranslationPositionSelect_IHM` restent consommés :
ne pas supprimer le GVL entier.

### 🏷️ Nommage — chantier séparé (2026-07-15)
Règle `Req`/`Cmd` préfixe formalisée (`NAMING_CONVENTION.md`), initialement pilotée sur
Translation M3 uniquement (`ST_TranslationHMI.ReqFwd/ReqRev`) — ⚠️ **non retenue** (audit
2026-07-22) : le code actuel garde `BtnFwd`/`BtnRev`/`TglJoystickMaster`/`SelTarget`, la
migration Req/Cmd n'est appliquée nulle part dans le code. Reste en préfixe `CmdX`, à auditer/migrer plus tard :
`FB_Bucket`/`FB_Winch`/`ST_BucketHMI`/`ST_WinchHMI` (`CmdOpen`/`CmdClose`/`CmdReset`/`CmdHome`/
`CmdInhibit`) et `FB_Cycle` (`CmdWinchM1_*`/`CmdTranslationM3_*`/`CmdBucket_*`) — blast radius plus
large (interfaces FB largement utilisées), plan dédié à valider avant d'y toucher.

📌 **Décisions client (2026-07-15)** :
- Le dossier `treuil` est conservé.
- **M1** est officiellement le **moteur de retenue**.
- **M2** devient le **moteur Benne** (le terme "Benne" disparaît au profit de "**Benne**").
- Le "**Translation**" devient "**Translation**" (terme abrégé cible à définir : `Trans`, `Translat` ?).

📌 **Nouvelles décisions client — Translation / auxiliaires / cycle semi-auto (2026-07-17)** :
- M3 possède cinq capteurs croisés dans l'ordre `Trémie | PV | P2 | P1 | Maintenance`.
- Codes valides : `11111 → 01111 → 00111 → 00011 → 00001 → 00000` ; toute autre combinaison est incohérente.
- `Trémie` est l'extrême gauche safety ; `Maintenance` est l'extrême droite safety et reste réservée à `MAINT_N2`.
- `PV` est le point de ralentissement avant l'arrêt répétable sur Trémie.
- Le PLC ne commande plus casque, grille ni centrale hydraulique ; seul le thermique centrale remonte en diagnostic.
- Le détecteur de fond Kobold est commandé par un contacteur de puissance à définir et fournit un retour contact fond.
- Le cycle semi-auto est reprenable par homme-mort : relâchement joystick = pause sur étape ; nouvelle commande valide = reprise.

🎯 **Cap long terme** (demande explicite utilisateur 2026-07-15) : généraliser le préfixe
(rôle/type d'abord, ex. `Req`/`Cmd`/`Sensor`/`Position`) à TOUT le projet — objectif : recherche/
autocomplete efficace, taper le rôle suffit à retrouver toutes les variables du même type peu
importe le mécanisme. Concerne potentiellement `Ready`/`Busy`/`RelayFwd`/`SpeedRef`/`CablePosM`/
`TopPositionSensor`... (usage massif, tout le projet) — **chantier majeur à planifier séparément**,
jamais improvisé vu le volume et la criticité sécurité de certaines variables concernées
(ex. `TopPositionSensor`, homing/safety Winch, déjà responsable d'un vrai bug de polarité passé).

### 📄 Doc à mettre à jour
- Presque tous les `AF_PartieN` : en-tête "Dépend de Partie 2 vX.Y" obsolète → aligner sur l'architecture courante
- `AF_Partie-07` (Interface IHM) : réalignée sur `PRG_09_Supervision` et renommée v1.5
- `AF_Partie-12` : titre et version alignés v1.4 ; chemins Benne/PERSISTENT corrigés
- `CLAUDE.md` : arborescence réalignée sur `PRG_00`→`PRG_10`

---

## ❓ 3. Reliquats, TBD & questions client

| # | Sujet | Qui tranche | Source |
|---|---|---|---|
| T1 | Détail séquence `INIT` (sous-vérifications position/cohérence) | Projet | AF_Partie-04 §2, D22 |
| T2 | ✅ `PRG_IP` existe mais n'est appelé dans aucune tâche CODESYS : programme inactif | Projet | `Device.export`, AF_Partie-02 §3 |
| T3 | ✅ Nom confirmé dans le code et l'export : `FB_Filter_PT1` | Projet | `FB_Joystick`, `Device.export` |
| T4 | Protocole registre AC600 (`DriveControlWord`/`StatusWord`) | **Constructeur variateur** | Translation/Safety_Translation |
| T5 | ✅ Priorités confirmées par export : EtherCAT=1, Main=10, CAN=16 ; watchdogs 200 ms | Projet | `Device.export`, AF_Partie-02 §2 |
| T6 | Périmètre `PRG_08` Auxiliaire | **Client** (en cours, différé assumé) | v1.1 §3 |
| T7 | ✅ `IHM_MANU` retiré définitivement (2026-07-19), sans attendre de critère de qualification — décision projet | Projet | `IHM_MANU_Journal_Modifications.md` |
| T8 | Rôle de `CodeSeqTriggerCmd` (codeurs) | À vérifier terrain | AF_Partie-10 |
| T9 | Comportement frein en montée chargée | Différé après essais terrain | AF_Partie-09 §4undecies |
| T10 | ✅ `Safety_Winch` : sens réel opposé (bit14) + absence de mouvement malgré commande (bit15), temporisés et câblés M1/M2 | Projet | AF_Partie-09 v1.11 |
| T11 | `EmergencyStopOk` : pas de confirmation temporisée post-réarmement, redondance A/B logicielle seulement | Projet | AUDIT D93 |
| T12 | ✅ Safety Translation conforme au matériel : aucun contacteur puissance M3 dédié ; surveillance par état/fréquence AC600 + retour frein M3. `PowerCutOff` actif sur bits3–7 | Projet | AF_Partie-01, AF_Partie-11 v1.9 |
| T13 | ✅ Aucun identifiant Safety Mouvement A/B/C actif. Les suffixes `PowerCutOff_A/B` sont conservés : canaux physiques redondants, pas rôles métier | Projet | AF_Partie-01, CODE/AU |
| T15 | 🔎 Source logicielle clarifiée : `PRG_00_Inputs.EmergencyStopOk` vient de `EmergencyStopOk_DI` (retour contacteur de puissance) ; simulation et override tests restent explicitement séparés. Validation du câblage réel et du comportement post-réarmement à réaliser | Projet / Terrain | AF_Partie-01 §Sécurité électrique, AF_Partie-03 §1, `PRG_00_Inputs` |
| T16 | ✅ Vestige `PRG_JOY1` retiré des instructions actives ; programme réel `PRG_01_Diagnostics`, filtre `FB_Filter_PT1` | Projet | AF_Partie-08 §6bis |
| T17 | 🟠 Checklist Joystick rédigée ; exécution terrain et verdict signé restant à réaliser. Limitations de robustesse ajoutées sur `FB_AxisScale`, `FB_Ramp` et la consigne finale M3 | Projet / Terrain | `CHECKLISTS/CHECKLIST_MiseEnService_Joystick_v1.1.md`, AF_Partie-08 §8 |
| T18 | ✅ GVL d'échange IHM créée et structurée par métier (modes, Translation M3, cycle, diagnostics) | Projet | `GVL_IHM` + Partie 7 v1.5 |
| T19 | Mapping `ChannelOk` carte/voie E-S (diagnostic carte non exploité) à définir si besoin confirmé | Projet | AF_Partie-06 §4 |
| T20 | Sélecteur treuil IHM (visu/physique) — variable rapatriée dans `GVL_IHM.Modes.JoystickWinchSelect` (2026-07-19, ex-`GVL_IHM.IHM_MANU`) ; widget visu physique restant à faire. Arbitrage MAINT_N2 fait, cf. AF_Partie-05 v1.6 | Projet | AF_Partie-05 §2, AF_Partie-09 §1 |
| T21 | Checklist validation Winch v1.7 non réalisée (inhibition, HomingApproachEnable, Méca B/D, diagnostics IHM, simulation) | Terrain | AF_Partie-09 §8 |
| T22 | Tolérance de calibration `TopSensorPositionM` (contrôle visuel) à fixer sur site | Terrain | AF_Partie-10 §7bis |
| T23 | ✅ Homing nominal et unitaire MAINT_N2 raccordés : sélection M1/M2, cible libre par treuil, limite ±99 m et diagnostics bits0/1/4 | Projet | `FB_Encoder_Homing`, `PRG_02_Encoders`, `ST_WinchHMI` |
| T24 | ✅ `FB_Encoder_Safety` intégré (instances M1/M2, inhibition `SEMI_AUTO`, diagnostic IHM) | Projet | AF_Partie-10 §9bis |
| T25 | 🟠 Suite automatisée nominale Encoder/Homing renforcée : gate simulation explicite, watchdog local, rapports TC-E1/TC-E2 corrigés ; essais CODESYS et scénarios unitaire/bornage/redémarrage restant | Projet / Terrain | `SuiteEncoder = 4`, AF_Partie-10 §10 |
| T26 | 🟠 Checklist Translation AC600 rédigée ; exécution terrain et verdict signé restant à réaliser (EtherCAT, commande, fréquence, sens, arrêts, PV, 5 capteurs, Fdc, thermique, diagnostics) | Terrain | `CHECKLISTS/CHECKLIST_MiseEnService_Translation_v1.1.md`, AF_Partie-11 §8 |
| T27 | Benne : essais de mise en service non réalisés (cinématique, offsets, Méca C couches 1/2) | Terrain | AF_Partie-12 §6 |
| T28 | ✅ Plafond palier "essais progressifs" (`WinchMaxStepFwd/Rev`) retiré avec IHM_MANU (2026-07-19) — `PRG_06_WinchControl` applique désormais un plafond fixe (5/`_WinchMaxStepDescent`), identique Auto et Manuel | Projet | Session 2026-07-19 |
| T29 | ✅ Terminologie active alignée : Translation M3, M1 Retenue, M2 Benne | Projet | CODE + AF métiers |
| T30 | ✅ Translation configurée sur échelle max 60 Hz ; nominal 30 Hz à 50 % | Projet | `FB_Translation.DriveFreqScaleMaxHz` |
| T31 | ✅ Vitesse câble calculée en m/s et répartie sur 5 plages paramétrables | Projet | T41/T45 |
| T32 | ✅ Estimation charge par tableau 2D palier contacteurs × plage vitesse, réglable et informative | Projet | T46 |
| T33 | ✅ Définir et implémenter le décodage cinq capteurs M3 (`Trémie/PV/P2/P1/Maintenance`) et le diagnostic des combinaisons incohérentes | Projet | Implémenté : `FB_Translation_PositionDecoder` |
| T34 | ✅ Définir les E/S réelles du contacteur Kobold et de son retour contact fond | Projet / Électricité | `KoboldContactFond_DI`=%IX0.5 · `KoboldContactor_DQ`=%QX0.6 — aucun réemploi du capteur mou de câble |
| T35 | ✅ Définir la stratégie de descente semi-auto : limite légale, détection Kobold, remontée synchronisée au-dessus de la limite, puis fermeture benne | Projet | Implémenté et raccordé au cycle v0.4.17 |
| T36 | ✅ Finaliser la stabilisation après fermeture benne : vitesse lente, tolérance codeurs, blocage/obstacle/câble mou et reprise | Projet | Double contrôle codeurs + timeout + `ERROR_HOLD` implémentés ; essais terrain restant |
| T37 | ✅ Retirer les commandes PLC casque/grille/centrale et conserver uniquement le diagnostic thermique centrale | Projet | Implémenté selon décision client 2026-07-17 |
| T38 | ✅ Réaliser la passe documentaire architecture : remplacer les références `PLC_PRG_MAIN`/anciens chemins et vérifier les liens | Projet | AF Partie 2/5/7/8/10/14 — liens locaux validés |
| T39 | 🟠 Interfaces Homing nominale et unitaire réalisées ; essais opérateur CODESYS restant | Projet / Terrain | T23/T25, AF_Partie-10 |
| T40 | ✅ Suppression définitive d'IHM_MANU (dispositif dérogatoire mise en service urgence, v0.4.4) : plus aucune dépendance opérationnelle en code actif ; pilotage manuel exclusivement MAINT_N1/MAINT_N2 + joystick homme-mort ; nouvelle suite de tests `SUITE_MODES` (TC-M1→M6, couvrant les 10 items obligatoires de la revue) ; revue de sécurité post-mission : homme-mort ajouté sur boutons IHM Translation M3 (écart préexistant relevé, cf. AF_Partie-11 v1.9 §6bis) | Projet | AF_Partie-11 v1.9, `IHM_MANU_Journal_Modifications.md` (historique), REX 2026-07-19 |
| T41 | ✅ Exposer la vitesse linéaire réelle de chaque câble en m/s à partir de la position codeur et d'un temps de cycle fiable | Projet | AF_Partie-10/09, `FB_Encoder_Scale`, `FB_Safety_Winch` — `MeasuredSpeedMps` exposé IHM |
| T42 | ✅ Créer la surveillance générique de vitesse codeur : variation brusque paramétrable, durée de confirmation, état et `ErrorId` | Projet | `FB_Encoder_SpeedMonitor.st` — diagnostic seul, intégration cycle reportée |
| T43 | 🟠 Raccorder les vitesses M1/M2 au cycle de remontée : comparaison, désynchronisme de vitesse, temporisation, pause/défaut sans attente infinie | Projet / Client | AF_Partie-04 §3quater, `FB_Cycle` — bit4 `ErrorId` câblé ; `SpeedMismatchThresholdMps` et `SpeedMismatchTimeout` restent à `0` (contrôle inactif) tant que les valeurs métier ne sont pas définies |
| T44 | ✅ Exposer dans `GVL_IHM` les vitesses mesurées, écarts, variations, paliers commandés et états de surveillance | Projet | AF_Partie-07, `ST_WinchHMI`, `ST_CycleHMI`, `PRG_03_Safety`, `PRG_09_Supervision` |
| T45 | ✅ Définir les 5 plages de vitesse réelle à partir de `VitesseMaxMps` (valeur provisoire 2,0 m/s), avec seuils paramétrables et hystérésis | Projet / Client | `ST_WinchSpeedConfig`, AF_Partie-09 — valeurs à confirmer terrain |
| T46 | ✅ Créer le tableau 2D empirique `palier contacteurs × vitesse mesurée → charge estimée %` ; valeur informative non certifiée, réglable en mise en service | Projet / Terrain | `ST_WinchSpeedConfig`, `ST_WinchLoadEstimateTable`, `FB_WinchLoadEstimator` |
| T47 | ✅ Ajouter le garde-fou de passage de palier : vitesse minimale atteinte + stabilité temporelle + absence de désynchronisme/variation anormale | Projet / Sécurité | `FB_SpeedStep`, `FB_Winch`, `FB_Encoder_SpeedMonitor` — activation terrain restant à valider |
| T48 | 🟠 Valider les réactions et seuils par simulation puis essais terrain : démarrage en charge, treuil freiné, câble mou, effort asymétrique, perte codeur | Projet / Terrain | Matrice V1–V7 ajoutée AF_Partie-14 §7.4.4 ; exécution CODESYS/terrain restante |
| T49 | ✅ Hauteurs unifiées : 8,0 m limite exploitation ; 8,5 m capteur/homing. Références 12,0/12,5 purgées du code et des specs actives | Projet + Mécanique | WINCH-CORE-01, `GVL_PERSISTENT`, P4/P7/P9/P10 |
| T50 | ✅ `FB_SpeedStep` borné/validé ; ConfigError remonté dans `FB_Winch.ErrorId` bit2, sorties sûres. Palier 1 tout FALSE autorisé (résistances insérées) | Projet | WINCH-CORE-01, `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §2.2 |
| T52 | 🔴 Valider chaîne `PowerCutOff` physique : câblage sorties A/B, contacteur puissance, retour confirmation, temps coupure réel (P0.3 audit Winch) | Électricité + Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §2.3, `PRG_10_Outputs.st:136-156` |
| T53 | ✅ Choix implémenté : safety stricte par défaut ; bypass individuel maintenu uniquement en MAINT_N2 + Reset, sans masquer les autres défauts | Projet | WINCH-CORE-01, `FB_Safety_Winch`, P9 |
| T54 | 🟠 Documenter latence PRG_03→PRG_06→PRG_10 (~10 ms) et l'intégrer au calcul temps d'arrêt (P1.2) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.2 |
| T55 | 🟠 Définir stratégie synchronisme unique (info / mineur / majeur / critique) et aligner DOC/CODE/IHM (P1.3) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.3, `FB_WinchSync`, `PRG_06:329-338` |
| T56 | 🟠 Caractériser seuils sécurité terrain (0,02 m/s, 2 m, 3 s, 800 ms, 500 ms) avec charge/vide/frein chaud (P1.4) | Projet / Terrain | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.4, `FB_Safety_Winch:149-169` |
| T57 | 🟠 Unifier limite haute M2 selon offset benne : une seule limite active distribuée à Winch/Safety/IHM (P1.5) | Projet | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §3.5, `PRG_06:379` vs `PRG_03:53,96` |
| T58 | 🟠 Purge boot des commandes RETAIN réalisée dans PRG_00 ; séparation Config/Commands/Status/Alarms différée jusqu'à maquette IHM validée | Projet + IHM | WINCH-CORE-01, `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §5.2 |
| T59 | 🟡 IHM afficher arrêt croisé effectif (ForbidAscentM1_Active) pas seulement safety local (P5.3) | IHM | `../ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md` §5.3, `PRG_09:319,382` vs `PRG_06:393-398` |
| T60 | ✅ `E_Mode.DISABLE` neutralise explicitement FB_Winch M1/M2 et FB_Translation M3 | Projet | WINCH-CORE-01, suite TC-M7 |
| T61 | ✅ Estimateur de charge actif uniquement pour vitesse signée positive (montée) | Projet | WINCH-CORE-01, suite TC-M10 |
| T62 | ✅ Fin `ASCENDING_LOADED` alignée sur `_CableLimitM1Ascent_M` (8,0 m) | Projet | WINCH-CORE-01, suite TC-M11 |
| T63 | ⏸️ Persistance flags simulation + split `GVL_SimulationBench` reportés : bindings visualisation à maquetter avant import | Projet + IHM | REX session revertée, hors scope WINCH-CORE-01 |
| T64 | 🟠 Essais treuils du 2026-07-23 : plafond de palier vitesse réglé temporairement à `0`. Confirmer le comportement effectif, tracer les essais, puis définir/restaurer la valeur d'exploitation avant mise en service normale | Projet / Terrain | `REGISTRE_Suivi_MiseEnService_v1.0.md` MES-003 |
| T65 | 🟠 Test PLC automatique manquant pour le fix persistance config (`Cfg.Initialized`/`CfgInitialized`, `ConfigRestoredFromPersistent`) — requis avant clôture C3/safety (`AF_Partie-14` §Contrat tests). Vérification manuelle Watch/forçage possible en attendant | Projet | `CONFIG-PERSIST-01`, `PRG_09_Supervision.st` §2/§2bis/§3 |
| T66 | 🔴 `Cycle.SetDepth_M`/`SetOffset_M` (défauts -12,5 m / 1,5 m) aucune protection persistance — cible profondeur cycle semi-auto peut revenir silencieusement sans alarme. Priorité la plus élevée de l'audit général | Projet / Sécurité | AF_Partie-15 §4, `PRG_05_Cycle.st` |
| T67 | 🟠 `TranslationM3.Cmd.SetFreq_Hz` aucune protection persistance — alimente directement `FreqPct` (vitesse réelle M3), repli silencieux sur 30% par défaut | Projet | AF_Partie-15 §4, `PRG_07_TranslationControl.st:97-100` |
| T68 | 🟠 Calibration neutre joystick (`_JoystickNeutralX/Y`) jamais réécrite après `BtnCalibrate` — perdue à CHAQUE reboot, pas seulement invalidation RETAIN (bug distinct, pas un pb de sentinelle) | Projet | AF_Partie-15 §4, `FB_Joystick.st` |
| T69 | 🟡 `M2Benne.CfgTimeoutDuration` toujours réinitialisé à `T#30s` au boot, jamais lu depuis PERSISTENT — écrasement systématique d'un réglage opérateur | Projet | AF_Partie-15 §4, `PRG_09_Supervision.st` §2 |
| T70 | ❓ `Modes.SelMode`/`SelJoystickWinch`/`TglJoystickMaster` repartent en valeur restrictive (MAINT_N1) au boot — à confirmer si voulu (sécurité) ou oubli avant de traiter | Projet / Client | AF_Partie-15 §4 |
| T71 | 🟡 Gate statique Python à créer (`TOOLS/AGENT_WORKFLOW/scripts/`) : détecte automatiquement tout champ `Cfg`/`Set` de `GVL_IHM` sans variable miroir `GVL_PERSISTENT` + bloc restore — aurait détecté T66/T67 sans audit manuel | Projet | AF_Partie-15 §5 |
| T72 | 🟠 Interverrouillage de sécurité commande / frein : conditionner l'activation des contacteurs de sens (`RelayFwd`/`RelayRev`) à l'ordre effectif de desserrage du frein (`BrakeCmd = TRUE`), pour interdire physiquement toute alimentation moteur sous frein serré par l'automate. | Projet / Sécurité | `FB_Winch.st`, `FB_Translation.st`, REX 2026-07-23 |
| T73 | 🟠 Winch : asymétrie fin de course haute (bit5, a Méca D bit11 = confirmation + escalade PowerCutOff) vs limite basse câble (bit6, Forbid seul, AUCUNE escalade). Ajouter l'équivalent Méca D pour la limite basse — seuils/délais différents selon le sens (montée = tolérance faible, descente = tolérance plus grande) | Projet / Sécurité | FB_Safety_Winch.st bit6, REX 2026-07-23 — logique seulement, pas de bypass |
| T74 | 🟠 Translation : LimitSwitch (bit6) escalade en PowerCutOff immédiatement (pas de délai de confirmation) — contrairement à Winch/Méca D qui laisse une fenêtre de confirmation avant d'escalader. Harmoniser vers le pattern Méca-style (dépassement transitoire toléré, escalade seulement si mouvement encore anormal après arrêt moteur attendu) | Projet / Sécurité | FB_Safety_Translation.st bit6, REX 2026-07-23 — logique seulement, pas de bypass |
| T75 | 🟡 `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py` : `KNOWN_VAR_OUTPUT_VIOLATIONS["MAIN/PRG_09_Supervision.st"]` obsolète depuis la restructuration Winch/Translation du 2026-07-22 (regex capture `State`/`Safety` au lieu de `M1TreuilRetenue`/etc. après passage en sous-structs) — mettre à jour la liste précise (pas d'exemption globale) | Projet | REX 2026-07-23, Lot 2a M1M2Sync |


✅ **Session 2026-07-09 (agent de scan doc)** : table complétée (T12-T27) — voir §5 pour le détail des renvois ajoutés dans chaque `AF_PartieN`.

---

## 📋 4. Recette

📥 **Ingéré depuis** `SAT_Protocole_Essais_v1.0.md` (archivé dans `ARCHIVES/Doc/`, contenu ci-dessous fait foi).

⚠️ **NO-GO mouvement** (diag EtherCAT + câblage CAN joystick, AUDIT D47) à lever formellement avant de dérouler ce protocole.

**Prérequis** : Homing M1/M2 fait (8,5 m, `Homed=TRUE`) · Joystick calibré (deadband 10%) · `GVL_Simulation.SimulationModeActive = FALSE`.

| # | Test | Résultat attendu |
|---|---|---|
| 2.1 | AU physique | Coupure puissance immédiate, `EmergencyStopOk=FALSE`, freins M1/M2/M3 serrés, alarme IHM |
| 2.2 | Collage contacteur (`PowerCutOff`) | Incohérence détectée → `PowerCutOff` déclenché, réarmement interdit tant que cause présente |
| 3.1 | Mou de câble M2 | Descente coupée immédiatement, montée restant autorisée, défaut IHM |
| 3.2 | Butée haute M1 (logicielle + physique) | Arrêt sur butée virtuelle ; coupure immédiate si `TopPositionSensor` s'ouvre |
| 4.1 | Synchro mineure (>0.25m, Soft-Stop) | Ralentissement + arrêt rampe normale, sens aggravant bloqué |
| 4.2 | Synchro majeure (>2.0m, Méca E) | `SafeStop` immédiat M1+M2, freins serrés, reset + retour neutre requis |
| 5.1 | Homme-mort manuel | Armé au neutre → mouvement possible ; lâcher → arrêt, désarmement auto après 500ms |
| 6.1 | Homme-mort en SEMI_AUTO | Neutre = immobile ; armé+poussé = mouvement gated ; relâche = arrêt, reprise si réarmé |
| 6.2 | SafeStop en séquence Auto | `ERROR_HOLD` immédiat, reprise exacte après Reset+Start une fois défaut disparu |

**Fiche signature** : Date / Responsable Automatisme / Représentant Client + tableau Pass/Fail par test + commentaires.

### 🧾 Journal des séances MES / REX

Les constats, mesures et décisions issus du banc ou du terrain sont consignés dans
`REGISTRE_Suivi_MiseEnService_v1.0.md`. Toute action différée issue d'une séance doit
être créée ou mise à jour ici au §3 avec un identifiant `Txx` : ce plan reste l'unique source des
reliquats à implémenter.

---

## 🔗 5. Renvois AF_Partie → ce document

✅ **Scan complet effectué (2026-07-09)** — 12 des 13 `AF_PartieN` touchés (contenu organisationnel
extrait et/ou harmonisation titre/nom de fichier) ; `AF_Partie-03` laissé intact (aucun contenu
organisationnel trouvé). Détail fichier par fichier :

| Fichier | Ancien nom | Nouveau nom | Renvois ajoutés | Txx référencées |
|---|---|---|---|---|
| Partie 1 | `..._v1.5.md` | `..._v1.6.md` | 2 | T12, T13 |
| Partie 2 | `..._v2.11.md` | `..._v2.12.md` | 1 | T5 |
| Partie 3 | — | — (inchangé) | 0 | — |
| Partie 4 | `..._v1.2.md` | `..._v1.3.md` | 1 | T1 |
| Partie 5 | `..._v1.3.md` | `..._v1.5.md` | 1 | T18 |
| Partie 6 | `..._v1.5.md` | `..._v1.6.md` | 1 | T19 |
| Partie 7 | `..._v1.2.md` | `..._v1.3.md` | 0 (harmonisation titre/fichier uniquement) | — |
| Partie 8 | `..._v1.2.md` | `..._v1.3.md` | 3 | T15, T16, T17 |
| Partie 9 | `..._v1.9.md` | `..._v1.10.md` | 3 | T9, T20, T21 |
| Partie 10 | `..._v1.7.md` | `..._v1.9.md` | 8 | T4, T8, T22, T23, T24, T25 |
| Partie 11 | `..._v1.3.md` | `..._v1.4.md` | 5 | T4, T12, T26 |
| Partie 12 | `..._v1.2.md` | `..._v1.4.md` | 1 | T27 |
| Partie 13 | `..._v1.1.md` | `..._v1.2.md` | 0 (harmonisation titre/fichier uniquement) | — |

📌 Chaque fichier renommé a été archivé tel quel (version pré-nettoyage) dans `ARCHIVES/Doc/`
avant incrémentation, conformément à la convention de versionnage du projet. Toutes les
références croisées connues (`CLAUDE.md` + liens inter-`AF_PartieN`) ont été mises à jour vers les
nouveaux noms de fichier.

---

## 📎 Sources archivées
`ARCHIVES/Doc/PLAN_Finalisation_v1.0.md` · `ARCHIVES/Doc/PLAN_Finalisation_v1.1.md` · `ARCHIVES/Doc/SAT_Protocole_Essais_v1.0.md`
