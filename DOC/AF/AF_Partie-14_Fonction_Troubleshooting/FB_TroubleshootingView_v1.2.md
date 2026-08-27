# Fiche `FB_TroubleshootingView` v1.2

> 🎯 Brique unique de mise en forme du dépannage. Lecture seule stricte, aucune écriture de
> commande, configuration ou interlock. Profil `👁️ Observateur passif` au sens `AF_Partie-03 §2`
> allégé : ici un FB (pas une page), instancié une seule fois dans `PRG_07_Supervision`.
> 📄 Source : `CODE/J_SUPERVISION/FB_TroubleshootingView.st`
> 📄 GVL alimentée : `CODE/J_SUPERVISION/GVL_Troubleshooting.st`
> 🔗 Producteur unique de `GVL_Troubleshooting.*` — appelé uniquement dans `PRG_07_Supervision`.
> 🗺️ Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md` §2.

---

## 1. Décision d'architecture (validée utilisateur 2026-08-04)

- **Pas de nouveau POU MainTask.** `PRG_11_Troubleshooting` a existé puis a été supprimé
  (commit `0561c98`, fusion dans l'architecture 7 POU) — un `PRG_08_Troubleshooting` séparé
  reviendrait sur cette décision actée. Voir `AF_Partie-02 §2` et `RU_C4_ARCHITECTURE_PROCEDES.md`.
- **Un FB dédié**, appelé une seule fois dans `PRG_07_Supervision` (lecture seule stricte,
  `AF_Partie-02 §5`).
- **But unique** : mise en forme d'une table de visu chronologique (haut → bas), pas une
  nouvelle source de vérité. Chaque champ qu'il publie a déjà un producteur ailleurs dans le
  programme ; ce FB ne fait que les recopier dans un ordre utile au dépannage.
- **Diagnostic AU** : recopie des sorties publiques `EmergencyState`, `EmergencyDiag`,
  `PowerCutOffActive` et des maintiens A/B produits par `PRG_06_Outputs`. La projection
  reste passive et ne lit aucun interne du FB de sécurité.
- **Dossier dédié** `CODE/DEPANNAGE/` : regroupe la GVL et ce FB, sans les disperser dans
  `SUPERVISION` ni dans un domaine métier.

## 2. Rôle

Construit une image de dépannage lisible dans l'ordre **contexte → module → détail**, en
recopiant des faits déjà publiés par leurs producteurs réels :

```text
PRG_02_Acquisition (HwReal/HwIn, InputModuleFault, diag devices)
PRG_03_Modes_Cycle (Auth)
PRG_04_Treuils_Benne (état M1, état M2, safety, benne, synchro)
PRG_05_Translation (état M3, safety)
GVL_IHM (mesures et commandes déjà publiques : Position_M, RelayFwd, BrakeCmd...)
        │
        ▼
FB_TroubleshootingView (recopie pure, aucun calcul métier, aucune décision)
        │
        ▼
GVL_Troubleshooting (table ordonnée pour Watch CODESYS / export SCADA dépannage)
```

**Interdit** : ce FB ne calcule aucun état, ne fusionne aucune source, ne décide d'aucune
interdiction. Si une donnée n'existe pas encore ailleurs, elle n'est pas inventée ici — elle est
signalée comme absente (§6 TBD) et son vrai producteur doit être créé dans le domaine concerné,
pas dans ce FB.

## 3. Interface

Un seul appel, dans `PRG_07_Supervision`, après que tous les domaines aient publié leurs sorties
(donc en toute fin de section §3 « Projections IHM et mapping »).

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | `TRUE` en permanence (aucune condition de scan) |
| `HwIn`, `HwReal` | `ST_HardwareImage` | Image acquisition (`PRG_02_Acquisition`) |
| `InputModuleFault` | `BOOL` | Agrégat modules DI (`PRG_02_Acquisition`) |
| `LocalDigitalIoOk`, `Vh0800EndOk`, `Vh0808EtpOk` | `BOOL` | États modules individuels |
| `Auth` | `ST_fbModes_Autorisations` | Mode et autorisations (`PRG_03_Modes_Cycle`) |
| `SimulationModeActive`, `SimWinchActive`, `SimTranslationActive`, `SimOperatorActive`, `SimSafetyActive` | `BOOL` | Contexte simulation (`GVL_Simulation`) |
| `WinchM1`, `WinchM2` | `ST_WinchHMI` | Image publique déjà produite (`GVL_IHM.M1TreuilRetenue`, `.M2TreuilBenne`) |
| `Sync` | `ST_SyncHMI` | Image publique synchro (`GVL_IHM.M1M2Sync`) |
| `Translation` | `ST_TranslationHMI` | Image publique translation (`GVL_IHM.TranslationM3`) |
| `Commun` | `ST_CommunHMI` | Signaux communs machine (`GVL_IHM.Commun`) |
| `Network` | `ST_NetworkDiagHMI` | Diagnostics bus + modules (`GVL_IHM.Network`) |

Aucune `VAR_OUTPUT` autre que diagnostic interne minimal (`Ready`). Toute la publication utile
se fait par écriture directe de `GVL_Troubleshooting.*` dans le corps du FB — c'est la seule
exception au principe « pas de GVL comme bus de commande » (`AF_Partie-03 §5`), car il s'agit ici
d'une **sortie d'observation**, jamais relue par un autre FB métier.

## 4. Structure de `GVL_Troubleshooting` — décision de réutilisation

Les DUT `ST_Chain*` existent déjà dans le code (`ST_ChainContextGlobal`, `ST_ChainWinchSync`,
`ST_ChainWinch`, `ST_ChainBucket`, `ST_ChainTranslation`) mais proviennent d'un `PRG_11_Troubleshooting`
**supprimé** avec l'ancienne architecture (commit `0561c98`, 2026-07-xx). Ils référencent des POU
legacy inexistants (`PRG_00_Inputs`, `PRG_03_Safety`, `PRG_06_WinchControl`...).

**Décision** : les réutiliser comme **squelette de nommage** (numérotation `Idx1xx..5xx`
chronologique, déjà un bon principe pour la lecture haut→bas), mais republier leur contenu
depuis les **producteurs réels actuels**, pas depuis les POU legacy cités dans les anciens
commentaires. La correspondance exacte champ par champ est en §5.

Aucun nouveau DUT `ST_Chain*` n'est créé : la structure existante suffit, une fois ses valeurs
raccordées aux vrais producteurs.

## 5. Table de correspondance — chaque champ `ST_Chain*` vers son vrai producteur 2026

### 5.1 `ContexteMachineGlobal : ST_ChainContextGlobal`

| Champ | Producteur réel 2026 |
|---|---|
| `Idx101_ModeActive` | `Auth.Mode` |
| `Idx102_SimulationEnabled` | `SimulationModeActive` |
| `Idx103_JoystickCommOk` | `Network.CanError` (inversé) ou diag CANopen publié |
| `Idx201_JoystickSelected` | `GVL_IHM.Modes.Cmd.TglJoystickMaster` |
| `Idx202_BypassNetworkGlobal` | `Network.Bypass.Global` |
| `Idx203_BypassSensorsGlobal` | à agréger depuis les bypass par domaine (§6 TBD si absent) |
| `Idx301_EmergencyChainClosed` | `HwIn.Machine.EmergencyChainClosed_DI` |
| `Idx302_PowerContactorEngaged` | `HwIn.Machine.PowerContactorEngaged_DI` |
| `Idx303_SafeStopActiveAny` | `WinchM1.State.Error OR WinchM2.State.Error OR Translation.State.Error` (à documenter comme agrégat, pas un nouveau calcul métier — simple `OR` de faits déjà publiés) |
| `Idx304_PowerCutOffActiveAny` | idem, agrégat de faits publiés uniquement |
| `Idx401_HmiHeartbeatOk` | `Commun.HeartbeatIhmOk` |
| `Idx402_CycleAutoBusy` | `GVL_IHM.Cycle.State` (à vérifier champ exact — §6 si absent) |

### 5.2 `LevageSynchroniseM1M2 : ST_ChainWinchSync`

| Champ | Producteur réel 2026 |
|---|---|
| `Idx101_M1_CablePos_M` / `Idx102_M2_CablePos_M` | `WinchM1.State.Position_M` / `WinchM2.State.Position_M` |
| `Idx103_SyncDelta_M` | `Sync.State.DeltaPos_M` |
| `Idx202_SyncEnabled_IHM` | `Sync.Cmd.SelSyncEnable` |
| `Idx301_EmergencyChainClosed` | `HwIn.Machine.EmergencyChainClosed_DI` |
| `Idx302_SyncFaultActive` | `Sync.State.Error` |
| `Idx501_M1_CmdRelayFwd_DQ` / `Idx502_M2_CmdRelayFwd_DQ` | `WinchM1.State.RelayFwd` / `WinchM2.State.RelayFwd` |
| *(reste)* | champs à revoir un par un lors de l'implémentation — pas de calcul inventé si absent |

### 5.3 `LevageUnitaireM1` / `LevageUnitaireM2 : ST_ChainWinch`

Toutes les sous-structures `Inputs_100/Demandes_200/Safety_300/Control_400/Outputs_500`
recopient depuis `WinchM1`/`WinchM2 : ST_WinchHMI` (déjà toutes les données nécessaires,
cf. audit de session : `RelayFwd`, `Contactor1-4`, `BrakeCmd`, `FinalInterlockState`,
`FinalInterlockReason`, `FinalAuthorizedStep`, `BrakeCommandOpenConfirmed`,
`FinalBrakeTimeoutElapsed` existent déjà dans `ST_WinchState`).

⚠️ Deux champs bruts n'ont **pas d'équivalent public actuel** et sont hors périmètre sans
nouveau producteur : `Idx101_EncoderRawPos` (points bruts codeur) et `Idx208/209_Arbitrated*`
(consigne avant sécurité, aujourd'hui variable interne `PRG_04_Treuils_Benne.M1_SpeedTgt_Active`,
non publiée en `VAR_OUTPUT`). Ce sont des `TBD` (§6), pas des valeurs à deviner.

### 5.4 `BenneOuvertureFermeture : ST_ChainBucket`

Recopie depuis `WinchM2.Bucket : ST_BucketHMI` (déjà complet : `MechState.IsOpen/IsClosed`,
`ActiveOffset_M`, `Busy`, `Done`, `Error`, `ErrorId`).

### 5.5 `TranslationPontM3 : ST_ChainTranslation`

Recopie depuis `Translation : ST_TranslationHMI` (`Cmd`, `State`, `Safety`).

## 6. TBD — à trancher avant implémentation complète

| # | Point | Statut |
|---|---|---|
| 1 | `Idx103_JoystickCommOk`, `Idx402_CycleAutoBusy` | champ exact à confirmer côté `GVL_IHM.Cycle`/`Network` |
| 2 | `Idx203_BypassSensorsGlobal` | agrégat multi-domaine à définir (OR simple documenté, pas un nouveau diagnostic) |
| 3 | `Idx101_EncoderRawPos` (points bruts) | pas de producteur public actuel — publier depuis `PRG_02_Acquisition` si jugé utile, hors périmètre de ce FB |
| 4 | `Idx208/209_Arbitrated*` (consigne pré-sécurité) | idem, nécessite une nouvelle `VAR_OUTPUT` côté `PRG_04_Treuils_Benne`/`PRG_05_Translation` |

Ce FB ne doit pas être bloqué par ces 4 points : ils sont publiés à `0`/`FALSE` avec commentaire
« non câblé, TBD » plutôt que d'inventer un calcul. Aucune valeur affichée ne doit laisser croire
à une mesure réelle si elle ne l'est pas.

## 7. Règles non négociables

- Aucune écriture vers un domaine métier, IHM `Cmd`, bypass ou configuration.
- Aucun `SafeStop`, `Enable` de mouvement, ni interlock ne sort de ce FB.
- Un champ sans producteur réel reste à sa valeur d'initialisation et est documenté comme tel
  (§6), jamais recalculé ici.
- `GVL_Troubleshooting` n'est jamais relue par un FB métier — seule l'IHM/Watch CODESYS la lit.

## 8. Tests de contrat

> **Etat** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé,
> non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

| ID | Attendu | Vérification | Etat |
|---|---|---|---|
| TC-P14-TSV-01 | `FB_TroubleshootingView` n'a aucune `VAR_OUTPUT` de commande | Lecture interface | `NV` |
| TC-P14-TSV-02 | Chaque champ `GVL_Troubleshooting.*` a un producteur documenté en §5 | Revue de cette fiche | `NV` |
| TC-P14-TSV-03 | Aucun champ TBD (§6) n'affiche une valeur laissant croire à une mesure réelle | Revue code + commentaire explicite | `NV` |
| TC-P14-TSV-04 | `G200_check_linkage.py` : instance unique, appelée dans `PRG_07_Supervision` seul | `G200_check_linkage.py --report` | `NV` |
| TC-P14-TSV-05 | Aucune régression sur les gates existants | `run_all_gates.py` | `NV` |

## 9. Documents liés

- `AF_Partie-02_Architecture_Programme_v3.2.md` §2/§5 — décision architecture, lecture seule.
- `AF_Partie-03_Contrats_Composants_v2.2.md` §1bis/§4 — profil FB, fiche contrat obligatoire.
- `AF_Partie-07_Interface_IHM_v2.0.md` §5 — principe troubleshooting lecture seule.
- `AF_Partie-14_Fonction_Troubleshooting_v1.1.md` — chapô, table de visu acquisition existante.
