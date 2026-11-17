# T377 — RAPPORT DE TRANSMISSION à l'agent lot terrain (concis)

→ RELAIS : agent lot terrain M3 / Semi-Auto / MAINT_N2. De : CC03 (T377-CC03). Via exploitant.

## 1. Décisions tranchées (GO exploitant 16/11)
- D1=C : pas d'escalade PowerCutOff en MAINT_N2 (déjà masquée PRG_04:1632/1653) ;
  contact capteur = latch + dégagement + IHM, PAS de FAIL. Risque résiduel documenté (AU + butée + survol mesuré site).
- Bande HX4 : +0,10/-0,10 m. Garde d'écart M1/M2 ajoutée en HX2 (vos SyncBlocks neutralisés).
- Contrat à amender (AC2/AC3/AC4) avant GO du lot complet T377.

## 2. Ta mission GO — mini-lot 2 lignes (anti-démarrage accidentel)
- PRG_02:609 → `BtnValidation := GVL_IHM.CycleMachineHoming.Cmd.BtnValidate,` (PLUS de `HwIn.Operator.JoyBtnRaw`)
- FB_CycleMachineHoming:414 → `IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 AND NOT JoystickDeflected THEN`
- Patches exacts + commandes : `T377_ECHANGE_AGENT_TERRAIN_20261116_v1.0.md` R3.
- Conséquence : « 3 appuis homme-mort » disparu — lancement/validation = bouton IHM. À répéter aux opérateurs.

## 3. Contrôle après collage (1 commande)
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py . ; python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . CODE/M_MAIN/PRG_02_Acquisition.st CODE/G_CYCLE/FB_CycleMachineHoming.st ; python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report ; python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```

## 4. T377 lot complet — préparé, PAS de GO
- 9 fichiers (enum, Cfg, FB homing, PRG_02/07, checklists, troubleshooting). Spec : brouillon v0.2 (`T377_BROUILLON_ST_DIFF_20261116_v0.1.md`) — tu peux le challenger dès maintenant.
- Interdits : FB_Safety_Winch, FB_Encoder*, FB_WinchSync, Device.export, TASKS.yaml.
- Collision connue : PRG_02 (un seul écrivain). Lot terrain 10 fichiers + T417-C en cours.

## 5. Règles
- Zéro commit/push sans validation humaine. Preuve d'abord (sortie brute + code retour).
- Ordre site : 1er test M3/MAINT_N2 en homing UNITAIRE → T377 intégré au bundle suivant → re-test homing seul.

## 6. Obligation d'information
Challenge bienvenu à tout moment. Tout constat touchant T377 → signalé SANS DÉLAI :
copie datée au dossier T377 + mention exploitant. Jamais silencieux, jamais fin de lot.
Au merge : « rien à signaler au 16/11 » suffit pour clore.

— Détails complets : T377_ECHANGE_AGENT_TERRAIN_20261116_v1.0.md (dossier T377).
