
CADRE DU CHALLENGE (etape 0, anti-garbage-in) :
OBJECTIF : produire une liste numerotee d'ecarts VERIFIES entre le contrat T377 ci-dessous et les faits/decisions ci-dessus, avec pour chaque AC une correction proposee en 3 lignes maximum (statement reformule falsifiable + verified_by rejouable).
NON-GOALS : ne pas rediscuter la doctrine hybride (tranchee 2026-09-26), ne pas trancher D4 (source validation) / D5 (permis voie manuelle) / D6 (degagement HX2A) / D7 (garde mode) — signale seulement si un AC en depend ; ne pas proposer de scripts a creer ; ne pas debattre hors table fermee.
FORMAT STRICT : '<ACx> : ECART/CONFORME/INCERTAIN - fait (ligne contrat ou Fx) - correction ≤3 lignes'. En fin : 'TOP3' = les 3 ecarts les plus invalidants.

FAITS SOURCE (ancres fichier:ligne, etudes 2026-11-14 — a considerer comme VRAIS pour ce challenge) :
F1. PRG_02_Acquisition.st:609 : BtnValidation := HwIn.Operator.JoyBtnRaw OR GVL_IHM...Cmd.BtnValidate — le bouton de validation est AUSSI un bouton homme-mort (joystick OU IHM).
F2. FB_WinchCmdArbitrationM1.st:56-61 : seul SEMI_AUTO consomme ReqWinch. En manuel N1/N2 la commande vient du joystick/IHM. Le GRAFCET homing NE COMMANDE PAS le treuil : la sequence observe, la securite interdit.
F3. FB_Safety_Winch.st:574 : le symbole reel est AscentPermit, publie M1SafetyAscentPermit / M2SafetyAscentPermit (PRG_07:875/884). SafetyPermit_Ascent n'existe pas dans le code.
F4. FB_Safety_Winch.st:376-379 et :523-525 + PRG_04:946-948 : DI capteur top directe a la securite (TRUE=libre, AND NOT TopPositionSensor arme la detection au contact) ; CauseMecaDActive est DANS CausesPowerCutOffActive : l'escalade PowerCutOff au contact existe deja.
F5. ST_fbMachineHomingCycle_Cfg.st:29-30 : fenetre reelle HX4 = CfgStabilizationMinM 7.50 / CfgStabilizationMaxM 9.50.
F6. FB_Encoder_Homing.st:229-231 : le preset = offset de calibration (PendingHomingRefRaw := RawPos - TargetPoints ; ref retenue Calib.HomingRefRaw). La decision 2026-11-14 (fiche T377, TASKS.yaml:1663-1664) : reference M1 = CfgTopSensorPos_M = 8,50 m ; validation par le bouton BtnValidation du grafcet a toute etape.
F8. Gates cites par le contrat : G511, G496, G408, G110, G120 EXISTENT tous dans TOOLS (verifie). Critique connue : G110/G120 ne peuvent pas echouer (pas de fixture negative) — 'en PASS' ne prouve rien.
F9. Revue T377_REVUE_PLAN_20261114 : NO-GO. AC1/AC4/AC7 FAIL, AC2/AC5 incomplets, AC6 valide. AC3 = defaut de TEXTE (renommage), pas de capacite.
F10. Grafcet homing 8 etats HX0-HX6 (FB_CycleMachineHoming.st, 703 lignes) : HX4 = tautologie (controle la position que le preset a imposee) ; HX1A/HX4 sans timeout ; repli 'Mode B' emet HomeReq sans lire HomingBusy/HomingDone ; exclusion mutuelle boutons benne pendant homing a ecrire (revue 2.6).
F11. ReadbackOk local ne teste que l'absence de mouvement sur 50 ms (revue 4/AC5) : separation Homed (producteur unique) / MachineHomed (derive) proposee.
F12. Le contrat interdit d'ecrire dans FB_Encoder_Homing.st (T235) : le cycle demande le preset au codeur via HomeReq, l'ecrivain preset reste FB_Encoder_Homing. Les AC doivent rester satisfaisables SANS toucher FB_Encoder_Homing.

TABLE FERMEE — ECARTS DU CYCLE PRECEDENT (le cycle porte STRICTEMENT sur cette liste) :
E1 AC3 statement utilise le symbole mort SafetyPermit_Ascent (vs F3).
E2 AC3 impose 'degagement en descente' + PowerCutOff 'seulement si montee persiste' (vs F4/F6-D6 : CauseMecaDActive arme deja la coupure ; perimetre de coupure totale ou directionnelle a etablir).
E3 AC2 garde 'mode MAINT_N1 OU MAINT_N2' = decision D7 non tranchee ; BtnConfirmHomingBucket a retirer (revue 4/AC2) ; BtnValidate IHM vs BtnValidation homme-mort (F1).
E4 AC1/AC3 supposent que le GRAFCET commande la montee (vs F2).
E5 AC4 cible ~23,5 m 'avec les reglages actuels' : a re-ancrer sur la cote validee 8,50 m et l'offset (F6-F7).
E6 Le contrat doit permettre la satisfaction des AC sans toucher FB_Encoder_Homing.st (F12).
E7 Ligne 134 du contrat : chemin 'T_TEMP (A TRIIER)' typo — path inexistant.
E8 Gate check: aucun execution_plan (T9) ; AC3-AC6 non rejouables automatiquement (T10).
E9 AC5 : ReadbackOk 50 ms seulement (F11).

ROLE (Agent A — Innovation/opportunite) : ton angle = faire de ce contrat un contrat qui SURVIT aux faits et qui sera implementable au premier GO. Propose la reformulation minimaliste de chaque AC, la garde de progression mesurable si necessaire, ce que le contrat omet de couvrir (fenetre 7,50-9,50 m, cote 8,50 m offset, exclusion boutons benne, retour HomeReq jamais lu). Sois constructif, concis, falsifiable.


═══ CONTRAT T377 (source verbatim) ═══

# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE ET SUIVI DE CYCLE DE VIE — projet Excavatrice Dragage
# ═══════════════════════════════════════════════════════════════════════════
#
# T377 — HOMING MANUEL SANS REFERENCEMENT SUR CAPTEUR TOP
#
# Doctrine HYBRIDE arretee avec l'exploitant le 2026-11-02 (remplace la
# lecture « Homed uniquement au FDC mecanique » de T340) :
#   - la MONTEE vers le capteur haut n'est plus automatique : approche
#     manuelle prudente sous joystick, avant contact.
#   - la REFERENCE haute est validee VISUELLEMENT par l'operateur.
#   - le capteur top redevient une BARRIERE DE SECURITE uniquement :
#     s'il est touche, meme par erreur, AUCUN referencement n'est effectue.
#
# Origine : REX terrain MES 2026-09-23 + avarie du 2026-09-25 (capteur fin
# de course mecanique Top M1/M2 casse par contrainte physique), doctrine
# exploitant du 2026-09-26.
# Absorbe T213 (variables de diagnostic du homing) — decision du 2026-11-02.
#
# Validation  : python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier>
# ═══════════════════════════════════════════════════════════════════════════

contract:
  task_id: T377_HOMING_MANUEL_SANS_CONTACT_TOP
  criticality: C3
  strategy: patch

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Supprimer tout referencement obtenu en montant jusqu'au contact du capteur
    haut : la reference de M1 et M2 est desormais validee visuellement par
    l'operateur sur une approche manuelle arretee AVANT le capteur, et le
    capteur top ne sert plus que de barriere de securite — s'il est touche,
    meme fortuitement, aucune reference n'est ecrite, la montee est coupee et
    la descente est imposee. Objectif : ne plus casser le capteur mecanique
    Top M1/M2 en allant le heurter pour se referencer.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: >
        Aucune etape du cycle de referencement ne commande une montee dont
        l'objectif est d'atteindre le contact du capteur haut : la montee vers
        le haut est une approche manuelle sous joystick et homme-mort, avec
        arret AVANT le capteur.
      verified_by: >
        Lecture du diff de FB_CycleMachineHoming.st (etapes HX2/HX3) montrant
        l'absence de commande de montee automatique vers TopPositionSensor ;
        puis bundle regenere + G511_check_homing_climb_guard.py et
        G496_check_top_sensor_polarity.py en PASS.

    - id: AC2
      statement: >
        La reference haute est ecrite uniquement sur validation visuelle de
        l'operateur (BtnValidate / BtnConfirmHomingBucket), et cette validation
        n'est acceptee que si les quatre gardes sont vraies au meme scan :
        mode MAINT_N1 ou MAINT_N2, WinchesMechanicallyStopped = TRUE,
        TopPositionSensor = FALSE, homme-mort arme. Hors de ces gardes, la
        validation est refusee et un message IHM explicite est emis.
      verified_by: >
        Grep du cablage PRG_02_Acquisition.st -> FB_CycleMachineHoming.st
        (BtnValidation / BtnConfirmHomingBucket / TopPositionSensor /
        WinchesMechanicallyStopped) + test de simulation SimBench rejouant
        les 4 combinaisons de refus + G408_check_ihm_message_length.py PASS.

    - id: AC3
      statement: >
        Sur contact du capteur top pendant la montee, meme fortuit : aucune
        reference n'est ecrite (aucun HomeReq, aucun preset declenche),
        SafetyPermit_Ascent passe a FALSE, le degagement en descente est
        impose, et le PowerCutOff n'est declenche que si une montee persiste
        malgre la consigne coupee.
      verified_by: >
        Scenario SimBench « contact fortuit capteur top pendant HX2 » rejoue :
        observation de HomeReq = FALSE, preset non declenche,
        SafetyPermit_Ascent = FALSE, descente commandee, PowerCutOff = FALSE ;
        puis scenario « montee persistante » ou PowerCutOff = TRUE.

    - id: AC4
      statement: >
        La cible de reference de M2 benne fermee vaut la position M1 validee
        plus OffsetCloseM (environ 23,5 m avec les reglages actuels), et non
        la position du capteur haut ; cette cible est publiee et lisible dans
        le snapshot de depannage.
      verified_by: >
        Grep des chemins GVL_Troubleshooting.F_HomingM2.* dans le bundle et
        dans troubleshooting_variables.txt regenere (champs
        BucketReferenceRequested, UseDynamicTarget effectif,
        BucketReferenceTargetM, TargetPositionM retenu, SeqStep) + G200 PASS.

    - id: AC5
      statement: >
        Aucun consommateur ne confond une position validee visuellement avec
        un referencement valide : Homed / MachineHomed restent ecrits par la
        seule transaction preset verifiee (ReadbackOk), et une validation
        visuelle sans preset verifie laisse Homed a FALSE.
      verified_by: >
        Grep de tous les consommateurs de Homed / HomedAndReliable dans CODE/
        (PRG_04, PRG_05, FB_Safety_*) et test de simulation « validation
        visuelle + verification preset en echec » montrant Homed = FALSE et
        aucun mouvement autorise.

    - id: AC6
      statement: >
        Le fichier PRG_02_Acquisition.st conserve un nom de fichier identique
        au nom du POU declare et un suffixe de langage identique au langage
        genere dans le bundle.
      verified_by: >
        Bundle PLCopenXML frais : comparaison du nom de fichier et du nom de
        POU, et verification du suffixe de langage contre le langage declare
        dans le bundle.

    - id: AC7
      statement: >
        Les POU et types touches restent conformes a la NAMING_CONVENTION
        (PascalCase, prefixes, unites _M pour les positions) et aucun nouveau
        champ ne duplique un fait deja publie ailleurs dans le snapshot.
      verified_by: >
        G110_check_naming_style.py et G120_check_fb_dut_naming.py en PASS,
        plus revue du diff des nouveaux champs.

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:
      - CODE/G_CYCLE/FB_CycleMachineHoming.st
      - CODE/M_MAIN/PRG_02_Acquisition.st
      - CODE/M_MAIN/PRG_07_Supervision.st
      - CODE/J_SUPERVISION/GVL_Troubleshooting.st
      - CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st
      - CODE/J_SUPERVISION/FB_TroubleshootingView.st
      - TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt
      - DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
      - DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md
      - DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/CONTRACTS/T377_CONTRAT_HOMING_MANUEL_SANS_CONTACT_TOP.yaml
    forbidden:
      - PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
      - CODE/E_CODEURS/FB_Encoder_Homing.st
      - CODE/E_CODEURS/FB_Encoder.st
      - CODE/H_TREUILS_BENNE/FB_WinchSync.st
      - ARCHIVES/**

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  conservation:
    must_survive:
      - "Le capteur haut reste une barriere de securite independante : polarite, latch et SafeStop existants non affaiblis"
      - "La transaction preset verifiee (ReadbackOk + CST_HomingVerifyToleranceM) reste la seule source de Homed"
      - "Le homing conjoint benne (recalage M2 sur M1 + offset) deja cable dans PRG_02 reste fonctionnel"
      - "FB_Encoder_Homing.st et FB_Encoder.st restent inchanges (perimetre T235 distinct)"
      - "Aucune position n'est validee sur une mesure non fiable : M1 doit etre HomedAndReliable pour une cible derivee de M1"
    dropped_on_purpose:
      - "Le referencement par contact physique du capteur haut M1/M2 — abandonne sciemment le 2026-09-26 (avarie du 2026-09-25)"

  # ── 5. Preuves attendues en restitution ───────────────────────────────────
  evidence_required:
    - bundle
    - check_linkage
    - run_all_gates
    - diff_review
    - simulation_scenario

  # ── 6. Modeles autorises ──────────────────────────────────────────────────
  models_allowed:
    - "omni/cc/claude-sonnet-5"
    - "omni/cx/gpt-5.6-terra"
    - "deepseek-v4.1-flash:cloud"

  # ── 7. Devoir d'alerte ────────────────────────────────────────────────────
  alert_duty: >
    Tout ecart constate entre la doctrine hybride et le code est remonte
    IMMEDIATEMENT a l'orchestrateur, pas a la fin et jamais silencieusement :
    chemin de montee encore automatique, capteur top utilise comme source de
    reference, Homed ecrit hors transaction preset, ou conflit avec T340 /
    T240 / T235. Signaler n'est pas elargir le scope.

# ═══════════════════════════════════════════════════════════════════════════
# 🚦 SUIVI DE L'ETAT D'AVANCEMENT
# ═══════════════════════════════════════════════════════════════════════════
status: PENDING

execution:
  executed_by: ""
  completed_at: ""
  status: PENDING
  summary: >
    Contrat redige le 2026-11-02 apres briefing read-only (workflow 4 audits).
    Aucun fichier CODE/ modifie. Doctrine hybride a valider par l'exploitant
    avant toute ecriture.
  evidence_submitted: []

validation:
  status: PENDING
  validated_by: ""
  validated_at: ""
  notes: >
    Arrêt de validation obligatoire : la doctrine hybride et la liste des AC
    doivent etre validees par l'exploitant avant levée de l'ARRET VALIDATION.
