# T377 — Échange intégré avec l'agent lot terrain (document unique)

→ RELAIS : agent du lot terrain M3 / Cycle Semi-Auto / MAINT_N2 inconditionnel.
Objet : tout ce que l'agent doit connaître — mini-lot à appliquer, décisions T377,
périmètres, règles, preuves attendues, obligations.
Émetteur : CC03 (session tâche T377, Superviseur T377-CC03) — transmission par l'exploitant.
Remplace : `T377_INFO_AGENT_TERRAIN_20261116_v0.1.md` (contenu intégralement repris ici).
Contexte détaillé : `T377_BROUILLON_ST_DIFF_20261116_v0.1.md` (v0.2), `T377_SEQUENCE_GRAFCET_20261116_v0.1.md`,
challenges `T377_CHALLENGE_REDMODEL_A/B_20261116.md`.

## R1 — Contexte

T377 = homing N1 manuel SANS contact capteur TOP : approche manuelle sous joystick +
homme-mort (palier 1), référence haute validée VISUELLEMENT avant le capteur (preset
8,50 m déjà câblé), capteur TOP = barrière seule (contact → AUCUNE écriture, latch,
dégagement, PAS de FAIL). Séquence arbitré + brouillon ST dans le dossier T377.
Ton lot terrain (10 fichiers non committés, MAINT_N2 inconditionnel) est déjà connu
et vérifié compatible (PRG_03:95-99 override cycle intact, PRG_04:1126-1129 barrière
conservée, masques MAINT_N2 identifiés).

## R2 — Décisions tranchées (GO exploitant 2026-11-16)

- **D1 = C** : pas d'escalade `PowerCutOff` routée en MAINT_N2 (elle y est déjà masquée :
  `PRG_04:1632/1653`), l'évènement contact est exposé par le FB (cause non-latching +
  sortie dédiée + instruction IHM). Dossier de risque résiduel : AU indépendant + butée +
  survol à mesurer en essai site.
- Contact capteur = hybride sans FAIL (latch + dégagement, retour HX2, zéro écriture).
- D5 = bande HX4 asymétrique **+0,10 / -0,10 m** ; garde d'écart M1/M2 ajoutée en HX2.
- Contrat à amender (AC2 → 5 gardes MAINT_N2 seul ; AC3 requalifié « retrait de permis » ;
  AC4 reformulé benne 23,5 m ; typos) — le GO du lot T377 complet suivra la correction contrat.

## R3 — MISSION 1 (GO) : mini-lot 2 lignes — anti-démarrage accidentel du cycle

### Patch 1 — `CODE/M_MAIN/PRG_02_Acquisition.st` ; lignes 607-609 ; REMPLACER

```
    // Lancer / valider le cycle : commande IHM dediee UNIQUEMENT (cadrag T377 2026-11-16 :
    // le BP homme-mort brut du joystick ne peut plus lancer/valider le cycle — motif
    // 3 appuis retire ; garde manche-neutre ajoutee cote FB HX0).
    BtnValidation              := GVL_IHM.CycleMachineHoming.Cmd.BtnValidate,
```

### Patch 2 — `CODE/G_CYCLE/FB_CycleMachineHoming.st` ; lignes 411-418 ; REMPLACER le bloc

```
    E_MachineHomingTxState.HX0_REPOS:
        // Etape initiale pure : aucune action.
        CmdWinchSelect := -1;
        // T377 cadrage 2026-11-16 : entree cycle exige manche au neutre au front de
        // lancement (jeu joystick / deplacement accidentel ne lance pas le cycle).
        IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 AND NOT JoystickDeflected THEN
            HomeReqDone := FALSE;
            RetryCount  := 0;
            SeqStep     := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
        END_IF;
```

### Suite de contrôle après collage (une commande regroupée)

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py . ; python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . CODE/M_MAIN/PRG_02_Acquisition.st CODE/G_CYCLE/FB_CycleMachineHoming.st ; python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report ; python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```

Le bundle régénéré embarquera aussi ton lot non committé — normal, rien n'est commité.

### Conséquence à consigner

Le geste « 3 appuis homme-mort du joystick » disparaît — la validation/lancement cycle
devient bouton IHM exclusif (`BtnValidate` / `BtnStart`). À répéter aux opérateurs.
Compatible 100 % avec le futur lot T377 (garde identique au brouillon §3.4).

## R4 — MISSION 2 (préparation, PAS de GO encore) : lot T377 complet

- Périmètre (9 fichiers) : `E_MachineHomingTxState`, `ST_fbMachineHomingCycle_Cfg`,
  `FB_CycleMachineHoming`, `PRG_02_Acquisition` (publication diagnostic),
  `PRG_07_Supervision`, `ST_HomingChecklist`, `FB_TroubleshootingView`,
  `GVL_Troubleshooting`, `troubleshooting_variables.txt`.
- Spécification : brouillon v0.2 (§1-§9) dans le dossier T377 — enum + HX2/HX2A/HX3/HX4,
  causes, mapping IHM obligatoire, matrice de mapping sortie→consommateur attendue.
- **Interdits** : `FB_Safety_Winch`, `FB_Encoder*`, `FB_WinchSync`, `Device.export`,
  `ARCHIVES/**`, `TASKS.yaml` (lecture seule).
- Le GO suivra la correction du contrat (AC2/AC3/AC4) ; en attendant, tu peux
  challenger le brouillon (R6).

## R5 — Règles d'or

- **Zéro commit, zéro push** sans validation humaine explicite (règle générale).
- **Un seul écrivain** sur `PRG_02_Acquisition.st` à la fois (ton mini-lot l'y touche déjà).
- Preuve d'abord : sortie brute + code retour dans la restitution ; « fait » sans preuve = non fait.
- `Device.export` jamais référence ; vérité = code source + bundle fraîchement régénéré.

## R6 — Chantièrs concurrents (collision à surveiller)

- Ton lot terrain : 10 fichiers `CODE/` non committés (FB_Modes, CycleSemiAuto,
  Translation*, ST_CycleCmd, PRG_03/04/05/06).
- T417-C : campagne experts ollama (dossiers `T417-C_CHALLENGE_SIMU_M3/`), pas de
  collision fichier avec T377.
- Collision connue : `PRG_02_Acquisition.st` (mini-lot + futur lot diagnostic T377).
- Bundle `CODE_XML/CODE_Bundle.xml` est **global disque** : régénérer par le seul agent
  actif, vérifier les autres avant tout commit.

## R7 — Preuves attendues à chaque restitution

`git diff` réel (pas de fichier que tu n'as pas touché dedans) · bandeaux bundle /
diff bundle · `G200 --report` (bloc Auto-vérification collé) · palier C · pour T377
plus tard : les 6 scénarios SimBench + 13 TC adaptés + TC inertie.

## R8 — Obligation d'information (doctrine T427)

Tu peux challenger chaque point de ce document et du brouillon, à tout moment.
**Obligation corrélative** : tout constat touchant T377 (collision, effet de bord de
tes neutralisations MAINT_N2, écart doctrine/code) est signalé **dès apparition** —
jamais en fin de lot, jamais silencieusement. Canal : copie datée au dossier
`DOC/WFLOW/TASKS/T377_HOMING_MANUEL_SANS_CONTACT_TOP/` + mention à l'exploitant.
Échéance d'un constat : sans délai. Au merge : une ligne « rien à signaler au
2026-11-16 » clore le cycle si applicable.
