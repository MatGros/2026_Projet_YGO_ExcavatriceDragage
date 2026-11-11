Mission read-only : appliquer le contrat investigation ci-dessous. Aucun outil ni acces fichiers disponible pour toi : analyser uniquement les sources fournies. Fournir trois anomalies maximum avec contre-exemples numeriques et tests discriminants. Ne pas declarer une cause terrain prouvee. Le preambule est injecte par le runner.
SOURCE: DOC/WFLOW/ETUDES/ANALYSES_T417/REPRISE_PREUVES_20261030.md
# T417 — Registre de reprise et expériences — 2026-10-30

Référence témoignage : [registre MES](../../REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md). GO utilisateur reçu pour poursuivre l'objectif ; production inchangée, aucun commit autorisé. Référence de lecture initiale : HEAD `14009dcf`, arbre comportant des travaux tiers conservés.

## Contrat d'investigation et de contre-expertise (lecture seule)

Objectif : établir les défauts du modèle susceptibles de fausser les essais AX14–AX18, sans attribuer une cause terrain sur simple inférence.

Critères testables :
1. Remonter les paramètres du variateur jusqu'à son appel effectif ; citer source et valeur transmise.
2. Examiner la dissipation du frottement : proposer un contre-exemple chiffré si le modèle inverse une vitesse sans force motrice.
3. Séparer commande de frein, état mécanique et contact ; ne pas assimiler fréquence électrique et vitesse mécanique sans justification.
4. Évaluer les tests existants et leur raccordement au runner ; ne pas annoncer un PASS non exécuté.
5. Proposer des expériences discriminantes frein ouvert/fermé, pente nulle/non nulle, approches 10/20 Hz ; aucune injection de défaut pour satisfaire un résultat attendu.

Les avis d'agents sont des hypothèses/revues à contrôler par le principal, jamais des preuves terrain. Maximum trois agents simultanés. Ollama disponible : deepseek-v4.1-flash:cloud et glm-5.3-flash:cloud (inventaire interrogé le 30 octobre).

## Registre des preuves

| ID | Constat de lecture actuel | Statut et prochaine vérification |
|---|---|---|
| E01 | SimBench ne transmet pas DecelRate_HzPerS ni DriveTimeConstantS ; FB_Sim_Translation transmet ses valeurs 25 Hz/s et 0,15 s au FB variateur. | Établi statiquement pour cet appel ; les défauts 20 Hz/s et 0,03 s du FB enfant ne décrivent donc pas le banc intégré. |
| E02 | Branche ObsCartFree : vitesse += (force externe − frottement signé) × dt, sans bornage au passage par zéro. | Risque numérique identifié ; contre-exemple à tester sur ST, pas encore verdict CI. |
| E03 | test_fb_sim_translation_dynamics.st contient déjà M3-DYN-030 (100 ms, deux sens, pas d'inversion) et M3-DYN-040 (10 ms). Recherche dynamics/Dynamics dans registry.yaml sans résultat. | Identifier le runner historique avant de refaire des tests déjà écrits. |
| E04 | M3-DYN-050 utilise frottement 0,1 et attend un départ sous pente 0,2 ; le modèle courant ajoute un seuil statique par défaut 0,35. | Attendu historique devenu incompatible ; ne pas modifier l'attendu sans expliciter le contrat physique. |
| E05 | M3-DYN-100 attend un retour fréquence indépendant du balancement ; FB_Sim_TranslationDrive soustrait gain × ABS(vitesse angulaire). | Divergence test/code à arbitrer sur les données réelles, pas sur le seul test. |
| E06 | Le runner tiers run_m3_study_agents.py tronque le code translation aux 6000 premiers caractères et remplace silencieusement les fichiers absents par une chaîne vide. | Ne pas le réutiliser tel quel ; fournir des sources complètes pertinentes aux contre-experts. Fichier tiers laissé intact. |

## Prochaines expériences

- Retrouver l'exécution historique des tests dynamiques et rejouer l'état actuel sans changer les attentes.
- Vérifier les traces réelles et leur provenance : retrait commande, décroissance fréquence, commande/contact frein ; résolution temporelle explicitée.
- Prouver l'isolation et le câblage du harnais avant de prétendre tester le cycle AX14–AX18.
- Conserver séparément dépassement d'arrêt et dérive lente après arrêt ; pente et frein relâché restent des hypothèses, pas des calibrations terrain.

SOURCE: DOC/WFLOW/REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md
# Registre MES — Témoignage exploitant M3 — 2026-10-30

## Provenance et valeur du récit

Consigné le **30 octobre 2026**, à la demande explicite de l'exploitant. Cette date est celle du recueil, pas celle des essais machine. Le récit ci-dessous repose notamment sur des souvenirs et peut être altéré par la mémoire : il constitue une référence de ce que l'exploitant rapporte, **pas une preuve instrumentée des causes ni des chronologies**. Les vérifications devront s'appuyer sur les données et traces du projet et sur l'historique Git pour identifier les versions correspondantes. Une trace de simulation ne prouve pas le comportement de la machine réelle. Aucune trace réelle n'est validée ou analysée par cette consignation.

Ce témoignage corrige et remplace les reformulations antérieures de l'agent concernant les « observations sur la machine réelle », explicitement rejetées par l'exploitant. Les anciens documents restent historiques ; en cas de divergence sur le témoignage, revenir au présent texte, sans fusionner réel, simulation et hypothèses.

## Texte de l'exploitant — conservé sans correction

> - Visuel réel (Translation M3 en semi auto) : en approche Trémie / vidage benne, le chariot continue de bouger doucement vers la butée après l'arrêt même pendant l'ouverture benne. On a pensé à une roue libre sur l'inertie ou une pente de rail, avec un frein qui arrive en douceur… A confirmer mais le variateur utilise toujours sa résistance de freinage donc rampe contrôlée. Donc ma dernière hypotèse cest plus un relâchement du frein silencieux ou pas (aucun souvenir si IHM affiche etat frein) mais si frein relaché et que le rail chariot est en pente on peut avoir cet effet de déplacement vers butée mécanique tres lentement…
> J'ai constaté aussi des défaut brake M3 au passage de AX14 à AX15 mais qui ont été aténué par hazard car la PV 20HZ a quasiment masqué le défaut ... alors que 10Hz bcp plus souvent le défaut et commande électrique moins bonne saccade plus.
> Et le défaut pouvait arriver au retour P1 mais pas souvent (infirmation moins fiable pas certain).
>
> - Manuel vs Auto : en Manuel, l'arrêt sur Trémie et P1 est propre, avec une décélération correcte et un arrêt à environ 10 cm après le capteur. En Auto, l'automate affiche 0,0 m (Trémie) et 5,0 m (P1), mais la simulation continue jusqu'à −0,45 m et +5,38 m. alors que l'on devrait être proche du manuel … apres il y a peut être un bug mais ca peut pas être la cause du déplacement lent de 30 à 50cm vers butée meca.
>
> - Oscilloscope CODESYS (test en simulation pas machin relle) : au capteur Trémie, TranslationFinalInterlockRequest.BrakeReleaseRequest passe à 0 instantanément, sans maintien de 2 s (comme hypotèse agent). Le contact physique simulé M3_BrakeIsOpen_DI retombe peu après (temps mécanique). En revanche, TranslationState.BrakeCmd met environ 1 s de plus à descendre.
>
> Je demande que le simulateur reproduise les bug problème de la machine reele sans modifier le code automate (quon modifie plustard apres simu OK)

## Règles d'utilisation pour la reprise

- **Réel rapporté** : déplacement lent vers la butée pendant l'ouverture benne ; défauts brake M3 à AX14 → AX15, moins fréquents à PV 20 Hz qu'à 10 Hz avec davantage de saccades à 10 Hz. Retour P1 : souvenir explicitement incertain.
- **Hypothèse actuelle de l'exploitant** : relâchement du frein et pente permettant un déplacement très lent. Ni la pente, ni le relâchement, ni leur causalité ne sont établis par ce récit. Le fonctionnement avec résistance de freinage et rampe contrôlée est une information rapportée à confronter aux données ; ne pas postuler une roue libre immédiate au retrait de commande.
- **Simulation explicitement identifiée** : positions −0,45 m / +5,38 m face à l'affichage 0 / 5 m ; observation oscilloscope des trois signaux de frein. Ne pas les réattribuer au réel. Le contexte du constat manuel est conservé tel qu'écrit, sans attribution supplémentaire.
- **Deux phénomènes à distinguer** : dépassement à l'arrêt et déplacement très lent pendant le vidage. Ne pas imposer une cause commune ; ne pas transformer l'interprétation de l'exploitant en causalité démontrée.
- **Objectif confirmé** : simulateur plausible et isolé, priorité AX14–AX15–AX18 et suite du cycle, pour reproduire naturellement les problèmes et évaluer la fiabilité de la position estimée par l'automate. Le reste de M3 fonctionne globalement selon le retour exploitant.
- **Ordre imposé** : valider d'abord le simulateur, puis seulement traiter les éventuels bugs du programme machine dans un lot ultérieur. Aucune modification du code automate dans le présent travail de simulation ; aucune alimentation de l'estimateur par la position vraie du simulateur pour masquer un écart.

## Documents antérieurs à lire avec cette correction

- [Passation T417 du 30 octobre](../TROUBLESHOOTING/FICHES/PASSATION_T417_SimM3_20261030.md).
- [Étude T417, notamment §5bis](../ETUDES/ETUDE_CONCEPTION_T417_SIMULATION_TRANSLATION_M3.md).
- [Reprise du 28 octobre](../AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/REPRISE_20261028.md).

Ces liens facilitent la reprise ; ils ne valent pas validation des affirmations contenues dans ces documents.

SOURCE: CODE/L_SIMULATION/FB_Sim_TranslationDrive.st
(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Dynamique reduite du variateur M3, sans commande metier. *)
FUNCTION_BLOCK PUBLIC FB_Sim_TranslationDrive
VAR_INPUT
    Enable : BOOL;
    FrequencyTgt_Hz : REAL;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 20.0; // Pente d'arret relevee sur trace reelle MES (-20.0 Hz/s)
    TimeConstant_S : REAL := 0.03;   // Reponse dynamique AC600 en boucle fermee (30 ms)
    LoadAngularVelocity_RadPerS : REAL;
    LoadFrequencyDroopGain_Hz : REAL := 0.50;
    CycleTime_S : REAL := 0.01;
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    FrequencyCmd_Hz : REAL;
    ElectricalFrequency_Hz : REAL;
    ActualFrequency_Hz : REAL;
    ResponseAlpha : REAL;
END_VAR
VAR
    FrequencyDelta_Hz : REAL;
    FrequencyStep_Hz : REAL;
END_VAR
VAR CONSTANT
    CST_MinTime_S : REAL := 0.001;
    CST_MaxFrequency_Hz : REAL := 50.0; // plafond variateur reel (GVL_PERSISTENT._TranslationMaxFreq_Hz)
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    FrequencyCmd_Hz := 0.0;
    ElectricalFrequency_Hz := 0.0;
    ActualFrequency_Hz := 0.0;
    ResponseAlpha := 0.0;
    RETURN;
END_IF;

FrequencyDelta_Hz := LIMIT(0.0, FrequencyTgt_Hz, CST_MaxFrequency_Hz) - FrequencyCmd_Hz;
IF FrequencyDelta_Hz >= 0.0 THEN
    FrequencyStep_Hz := MAX(0.0, AccelRate_HzPerS) * CycleTime_S;
ELSE
    FrequencyStep_Hz := MAX(0.0, DecelRate_HzPerS) * CycleTime_S;
END_IF;
FrequencyCmd_Hz := FrequencyCmd_Hz + LIMIT(-FrequencyStep_Hz, FrequencyDelta_Hz, FrequencyStep_Hz);
IF TimeConstant_S > CST_MinTime_S THEN
    ResponseAlpha := CycleTime_S / (TimeConstant_S + CycleTime_S);
ELSE
    ResponseAlpha := 1.0;
END_IF;
ElectricalFrequency_Hz := ElectricalFrequency_Hz
    + ResponseAlpha * (FrequencyCmd_Hz - ElectricalFrequency_Hz);
ActualFrequency_Hz := MAX(0.0, ElectricalFrequency_Hz
    - MAX(0.0, LoadFrequencyDroopGain_Hz) * ABS(LoadAngularVelocity_RadPerS));
IF ActualFrequency_Hz < 0.005 THEN
    ActualFrequency_Hz := 0.0;
END_IF;
Ready := TRUE;

SOURCE: CODE/L_SIMULATION/FB_Sim_TranslationBrake.st
(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Chaine bobine, effet mecanique et contact frein M3. *)
FUNCTION_BLOCK PUBLIC FB_Sim_TranslationBrake
VAR_INPUT
    Enable : BOOL;
    ReleaseCmd : BOOL;
    ActualFrequency_Hz : REAL;
    OpenDelay_S : REAL := 0.10;
    CloseDelay_S : REAL := 0.09;
    ContactDelay_S : REAL := 0.01;
    CycleTime_S : REAL := 0.01;
    (* Branche de FAUTE EXPLICITE — defaut FALSE : chemin nominal strictement inchange.
       Rejoue le defaut terrain « cause 6 instantanee » : contact frein ferme alors que le
       variateur retourne encore de la vitesse (trace 2026-09-04, 26,437 s, 10,00 Hz,
       State.ErrorId=64). La garde nominale CST_StopFrequency_Hz est CONSERVEE telle quelle :
       elle est validee par la meme trace (frein ouvert a 0,60 Hz, ferme a 0,00 Hz). *)
    FaultCloseWhileRunning : BOOL := FALSE;
    FaultCloseDelay_S : REAL := 0.0;
    (* L3 — FREIN PHYSIQUE (2026-10-28). FALSE = historique : la retombee mecanique attend
       f <= 0,5 Hz (garde qui recopiait la logique PLC dans l'usine simulee). TRUE = frein a
       manque de courant reel : retombe CloseDelay_S apres la coupure bobine, QUELLE QUE SOIT
       la vitesse. *)
    PhysicalBrakeActive : BOOL := FALSE; (* defaut FB = historique ; la simulation M3 passe TRUE via GVL_Simulation (source unique) *)
END_VAR
VAR_OUTPUT
    Ready : BOOL;
    CoilEnergized : BOOL;
    MechanicallyOpen : BOOL;
    ContactOpen : BOOL;
    FaultCloseActive : BOOL;   (* <-- [DIAG] Branche de faute effectivement appliquee ce scan *)
END_VAR
VAR
    MechanicalTimer_S : REAL;
    ContactTimer_S : REAL;
    FaultTimer_S : REAL;
END_VAR
VAR CONSTANT
    CST_StopFrequency_Hz : REAL := 0.5;
END_VAR

IF NOT Enable THEN
    Ready := FALSE;
    CoilEnergized := FALSE;
    MechanicallyOpen := FALSE;
    ContactOpen := FALSE;
    FaultCloseActive := FALSE;
    MechanicalTimer_S := 0.0;
    ContactTimer_S := 0.0;
    FaultTimer_S := 0.0;
    RETURN;
END_IF;

(* Faute explicite : chronometre propre, remis a zero des que le stimulus retombe. *)
IF FaultCloseWhileRunning THEN
    FaultTimer_S := FaultTimer_S + CycleTime_S;
ELSE
    FaultTimer_S := 0.0;
END_IF;
FaultCloseActive := FaultCloseWhileRunning AND (FaultTimer_S >= MAX(0.0, FaultCloseDelay_S));

(* La faute fait retomber la bobine : l'etat electrique publie reste coherent avec la
   fermeture mecanique observee (jamais « bobine energisee ET frein serre »). *)
CoilEnergized := ReleaseCmd AND NOT FaultCloseActive;
IF CoilEnergized THEN
    IF NOT MechanicallyOpen THEN
        MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
        IF MechanicalTimer_S >= MAX(0.0, OpenDelay_S) THEN
            MechanicallyOpen := TRUE;
            MechanicalTimer_S := 0.0;
        END_IF;
    ELSE
        MechanicalTimer_S := 0.0;
    END_IF;
ELSIF FaultCloseActive OR PhysicalBrakeActive OR (ActualFrequency_Hz <= CST_StopFrequency_Hz) THEN
    IF MechanicallyOpen THEN
        MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
        IF MechanicalTimer_S >= MAX(0.0, CloseDelay_S) THEN
            MechanicallyOpen := FALSE;
            MechanicalTimer_S := 0.0;
        END_IF;
    ELSE
        MechanicalTimer_S := 0.0;
    END_IF;
ELSE
    MechanicalTimer_S := 0.0;
END_IF;
IF MechanicallyOpen <> ContactOpen THEN
    ContactTimer_S := ContactTimer_S + CycleTime_S;
    IF ContactTimer_S >= MAX(0.0, ContactDelay_S) THEN
        ContactOpen := MechanicallyOpen;
        ContactTimer_S := 0.0;
    END_IF;
ELSE
    ContactTimer_S := 0.0;
END_IF;
Ready := TRUE;

SOURCE: CODE/L_SIMULATION/FB_Sim_Translation.st
(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Modele dynamique M3 confine au SimBench. *)
FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable : BOOL;
    ReqTremie : BOOL;
    ReqMaintenance : BOOL;
    SpeedTgt_Pct : REAL;
    (* T301/L1 — SOURCE UNIQUE : le banc ne porte AUCUNE position ni echelle propre.
       Positions capteurs = reglages machine (GVL_PERSISTENT._TranslationPos*_M) et gain =
       gain EFFECTIVEMENT consomme par l'estimateur (PRG_05 FB_Translation_OdometryGain.GainActive),
       passes par PRG_02 -> FB_SimBench. Vitesse chariot = sens x gain x frequence.
       Historique : l'ancienne echelle en dur (30 m / FullTravelTimeS / 40 Hz) a diverge du gain
       reel (T360/T361, sauts de 4 a 9 m) — doublon supprime, gate G518 anti-retour. *)
    PosTremie_M        : REAL := 0.0;   (* --> [CFG] Position capteur Tremie (m) *)
    PosPV_M            : REAL := 1.5;   (* --> [CFG] Position capteur PV (m) *)
    PosP2_M            : REAL := 3.5;   (* --> [CFG] Position capteur P2 (m) *)
    PosP1_M            : REAL := 5.0;   (* --> [CFG] Position capteur P1 (m) *)
    PosMaintenance_M   : REAL := 10.0;  (* --> [CFG] Position capteur Maintenance (m) *)
    GainMetersPerHzSec : REAL := 0.02;  (* --> [CFG] Gain odometrique effectif, m/(Hz.s) *)
    (* Distance capteur extreme -> butee mecanique (seule donnee propre au banc : physique du rail).
       Bornee a CST_MinEndStopMargin_M pour que le capteur extreme reste franchissable. *)
    EndStopMargin_M    : REAL := 0.5;
    BrakeReleaseCmd : BOOL := TRUE;
    (* ECHELLE DE LA CONSIGNE. PRG_02 envoie SpeedCmd_Pct = f / 50 Hz x 100 : le simulateur reconvertit
       avec le MEME maximum, sinon 20 Hz reels (40 %) deviendraient 16 Hz simules.
       Maximum = GVL_PERSISTENT._TranslationMaxFreq_Hz (50 Hz), passe par FB_SimBench (CST_M3MaxFreq_Hz,
       egalite verifiee par G518). Ne pas confondre avec l'ancienne echelle (40 Hz) : echelle
       ODOMETRIQUE (gain 0,02 m/(Hz.s)). *)
    MaxFreq_Hz : REAL := 50.0;
    (* ACCELERATION DU BANC (confort d'essai). Le chariot avance SpeedFactor fois plus vite ET la
       frequence RETOURNEE au PLC est multipliee d'autant : l'estimateur (f x gain) suit exactement
       le chariot, sans saut de recalage, et le ratio publie reste 0,02 m/(Hz.s) (G518).
       Borne 1..5. 1,0 = dynamique reelle. Le frein et la memoire de sens restent sur la frequence
       physique du variateur simule. *)
    SpeedFactor : REAL := 1.0;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 25.0; // pente d'arret relevee sur trace reelle (rampe variateur / rampe PLC)
    DriveTimeConstantS : REAL := 0.15;
    BrakeOpenDelayS : REAL := 0.10;
    BrakeCloseDelayS : REAL := 0.09;
    BrakeContactDelayS : REAL := 0.01;
    (* FAUTE EXPLICITE frein M3 — defaut FALSE : reproduit le defaut terrain « frein ferme
       alors que le variateur retourne encore 10,00 Hz » (trace 2026-09-04, 26,437 s,
       State.ErrorId=64). La garde nominale 0,5 Hz du frein n'est pas modifiee. *)
    BrakeFaultCloseWhileRunning : BOOL := FALSE;
    BrakeFaultCloseDelay_S : REAL := 0.0;
    (* L3 — FREIN PHYSIQUE (2026-10-28). FALSE = historique (frein ne retombe que sous 0,5 Hz,
       arret instantane). TRUE = frein a manque de courant reel : retombe CloseDelay apres la
       coupure bobine QUELLE QUE SOIT la vitesse, puis le chariot decelere sur le frein
       (BrakeDecel_Mps2) ; frein serre = chariot bloque meme si le variateur pousse. *)
    BrakePhysicalActive : BOOL := FALSE; (* defaut FB = historique ; GVL_Simulation.SimM3BrakePhysicalActive = TRUE (source unique) *)
    BrakeDecel_Mps2 : REAL := 2.0;   (* HYPOTHESE : 0,4 m/s (20 Hz) -> arret ~0,2 s / ~4 cm *)
    (* L4 — CHARIOT LIBRE (2026-10-28). FALSE = historique (chariot esclave de la frequence).
       TRUE = quand le frein est OUVERT et que le variateur n'applique plus de couple (mot a 0
       et rampe variateur terminee), le chariot n'est plus tenu : il garde sa vitesse et subit
       la poussee de la benne suspendue (rapport de masse x g x angle), la pente et le
       frottement de roulement. Valeurs = HYPOTHESES, sans mesure terrain. *)
    CartFreeActive : BOOL := FALSE;
    LoadMassRatio : REAL := 0.5;          (* masse benne / masse totale chariot+benne *)
    RollingFriction_Mps2 : REAL := 0.30;  (* FEM 1.001 : frottement global galets + reducteur accouple *)
    StaticFriction_Mps2 : REAL := 0.35;   (* Seuil de decollement statique (anti-pompage pendulaire) *)
    Slope_Mps2 : REAL := 0.0;             (* composante de pente, + vers Maintenance *)
    (* L5 — came capteurs (vu -> perdu -> retrouve -> fixe), appliquee aux 5 capteurs. *)
    SensorCamDropoutActive : BOOL := FALSE;
    SensorCamDropoutStart_M : REAL := 0.02;
    SensorCamDropoutWidth_M : REAL := 0.04;
    SuspendedLoadLength_M : REAL := 1.5;
    SuspendedLoadDamping : REAL := 0.35;
    LoadReactionGain_Mps2 : REAL := 0.20;
    (* BUTEE MECANIQUE — recul borne apres arret serre.
       0.0 (defaut) conserve EXACTEMENT le comportement historique : position ET vitesse
       figees a la butee (decision de review tracee, correctif « contact rigide »).
       > 0 : l'inertie du chariot reste absorbee par la butee, MAIS la reaction de la charge
       peut ressortir le chariot de la zone capteur — comportement observe sur la trace
       terrain du 2026-09-04 a 26,437 s (Tremie actif 1 echantillon puis perdu
       definitivement). Valeur SYNTHETIQUE, en attente de mesure terrain. *)
    EndStopRecoilMax_M : REAL := 0.0;
    LoadFrequencyDroopGain_Hz : REAL := 0.50;
    SensorJitterAmplitude_M : REAL := 0.01;
    SensorStabilizationS : REAL := 1.0;
    SensorElectricalDelayS : REAL := 0.01;
    SensorIntermittenceActive : BOOL := FALSE;
    SensorLoadAngleTriggerRad : REAL := 0.01;
    SensorScenarioSeed : UDINT := 3001;
    SensorHysteresis_M : REAL := 0.02;
    SensorIntermittencePeriodS : REAL := 0.12;
    (* BLIP COURT — second profil capteur, independant du train ~1 s ci-dessus.
       BlipTransitions = 0 (defaut) : profil historique strictement inchange.
       Valeurs de trace : Tremie 1 excursion de 0,2 s (2 echantillons a 100 ms),
       PV 1 excursion de 0,1 s (1 echantillon).
       ⚠️ LIMITE CONNUE (revue 2026-09-20, F11) : UNE SEULE largeur globale est appliquee aux
       cinq capteurs. Les deux signatures de la trace (Tremie 0,200 s et PV 0,100 s) ne sont
       donc PAS rejouables dans la meme passe : il faut deux executions avec des valeurs
       differentes de SensorBlipDurationS. Une largeur par capteur exigerait un
       ARRAY[1..5] OF REAL, non retenu dans ce lot. *)
    SensorBlipTransitions : UDINT := 0;
    SensorBlipDurationS : REAL := 0.2;
END_VAR
VAR_OUTPUT
    PosTremie : BOOL;
    PosPV : BOOL;
    PosP2 : BOOL;
    PosP1 : BOOL;
    PosMaintenance : BOOL;
    FrequencyCmd_Hz : REAL;
    ElectricalFrequency_Hz : REAL;
    ActualFrequency_Hz : REAL;
    BrakeCoilEnergized : BOOL;
    BrakeMechanicallyOpen : BOOL;
    BrakeContactOpen : BOOL;
    BrakeFaultCloseActive : BOOL;
    PositionTrue_M : REAL;
    VelocityTrue_Mps : REAL;
    LoadAngle_Rad : REAL;
    SensorPosition_M : REAL;
    SensorTransitionCount : UDINT;
    SensorBlipActive : BOOL;
    HardStopTremieActive : BOOL;
    HardStopMaintenanceActive : BOOL;
    (* L2 — OBSERVATION (aucun effet sur le modele ni sur le programme) *)
    ObsOvershootLast_M : REAL;          (* Distance roulee entre le 1er front du dernier capteur d'arret (Tremie, P1, Maintenance) et l'arret *)
    ObsOvershootSensorId : INT;         (* 1 = Tremie, 3 = P1, 5 = Maintenance, 0 = aucun *)
    ObsEndStopHitCount : UDINT;         (* Nombre de chocs en butee mecanique *)
    ObsEndStopImpactSpeed_Mps : REAL;   (* Vitesse au dernier choc en butee *)
    ObsBrakeClosedMovingCount : UDINT;  (* Nombre de fermetures mecaniques du frein chariot en mouvement *)
    ObsCartFree : BOOL;                 (* L4 : frein ouvert ET variateur sans couple -> chariot libre *)
    ObsFreeRollLast_M : REAL;           (* L4 : distance parcourue pendant le dernier episode libre *)
END_VAR
VAR
    ObsArmed : BOOL;                    (* Front capteur d'arret vu, arret pas encore constate *)
    ObsEdgePosition_M : REAL;           (* Position vraie au 1er front du capteur d'arret *)
    ObsPrevTremie : BOOL;
    ObsPrevP1 : BOOL;
    ObsPrevMaintenance : BOOL;
    ObsPrevBrakeOpen : BOOL;
    ObsPrevHardStop : BOOL;
    ObsSpeedBeforeStop_Mps : REAL;      (* Vitesse du scan avant le calcul de butee *)
    DriveTorqueActive : BOOL;           (* L4 : variateur commande ou encore en rampe -> chariot tenu *)
    FreeAccel_Mps2 : REAL;              (* L4 : acceleration nette du chariot libre *)
    FreeRollStart_M : REAL;             (* L4 : position au debut de l'episode libre *)
    instCycleTime : FB_CycleTime;
    Initialized : BOOL;
    DirectionSign : REAL;
    (* Sens de deplacement MEMORISE. La commande peut etre retiree AVANT l'arret physique
       (deceleration libre du variateur) : le sens du dernier ordre valide est conserve tant
       que le variateur retourne de la vitesse, puis purge a l'arret. Sans cette memoire, la
       vitesse du chariot s'effondrait au scan de retrait de commande alors que la frequence
       retournee decroit encore.
       ⚠️ ORDRE DE GRANDEUR NON MESURE : la trace terrain ne contient AUCUNE variable de
       position (15 TraceVariable : DI, frequences, mots d'etat, erreurs). La distance de
       roue libre de la fenetre 14,67 -> 16,16 s est donc une ESTIMATION dependante du modele
       d'echelle, qui vaut approximativement 1,1 a 1,3 m selon la methode d'integration
       retenue (gain audit 0,0551 m/(Hz.s)). A ne pas citer comme une mesure. *)
    TravelDirection : REAL;
    FrequencyTarget_Hz : REAL;
    SpeedFactorApplied : REAL := 1.0;
    CycleTimeS : REAL;
    EndStopTremie_M : REAL;       (* butee mecanique cote Tremie = capteur Tremie - marge *)
    EndStopMaintenance_M : REAL;  (* butee mecanique cote Maintenance = capteur Maintenance + marge *)
    VelocityTarget_Mps : REAL;
    CartAcceleration_Mps2 : REAL;
    PreviousVelocity_Mps : REAL;
    PositionCandidate_M : REAL;
    (* Recul de butee ECRETE a la course : une valeur d'entree aberrante ne peut pas
       autoriser une position hors des butees (revue du 2026-09-20, F8). *)
    RecoilMax_M : REAL;
    SensorNoiseState : REAL := 0.371;
    SensorNoise_M : REAL;
    instSensorTremie : FB_Sim_PositionSensor;
    instSensorPV : FB_Sim_PositionSensor;
    instSensorP2 : FB_Sim_PositionSensor;
    instSensorP1 : FB_Sim_PositionSensor;
    instSensorMaintenance : FB_Sim_PositionSensor;
    instDrive : FB_Sim_TranslationDrive;
    instBrake : FB_Sim_TranslationBrake;
    instSuspendedLoad : FB_Sim_SuspendedLoad;
END_VAR
VAR CONSTANT
    (* Marge mini capteur extreme -> butee : au-dela de l'hysteresis capteur, sinon le mot
       11111 / 00000 ne pourrait jamais etre produit (capteur colle a la butee). *)
    CST_MinEndStopMargin_M : REAL := 0.05;
    (* Meme seuil d'arret que FB_Sim_TranslationBrake.CST_StopFrequency_Hz (0,5 Hz).
       Valide par la trace terrain du 2026-09-04 : frein ouvert a 0,60 Hz, ferme a 0,00 Hz. *)
    CST_StopFrequency_Hz : REAL := 0.5;
END_VAR

instCycleTime(DefaultValueS := 0.010);
(* Le modele mono-pas suit le temps de cycle reel jusqu'a 100 ms. Cette borne
   evite de ralentir artificiellement la dynamique lorsque la trace est executee
   dans VISU_TASK (environ 100 ms), tout en restant stable pour le pendule reduit.
   Au-dela, FB_CycleTime fournit deja son temps de secours et aucun saut aberrant
   n'est accepte. La qualification des delais sub-100 ms exige toutefois une tache
   de trace plus rapide que 100 ms. *)
CycleTimeS := LIMIT(0.001, instCycleTime.CycleTimeS, 0.100);

(* Butees mecaniques derivees des capteurs extremes (reglages machine) + marge du rail. *)
EndStopTremie_M := PosTremie_M - MAX(EndStopMargin_M, CST_MinEndStopMargin_M);
EndStopMaintenance_M := PosMaintenance_M + MAX(EndStopMargin_M, CST_MinEndStopMargin_M);

IF NOT Enable THEN
    Initialized := FALSE;
    instDrive(Enable := FALSE);
    instBrake(Enable := FALSE);
    instSuspendedLoad(Enable := FALSE);
    FrequencyCmd_Hz := 0.0;
    ElectricalFrequency_Hz := 0.0;
    ActualFrequency_Hz := 0.0;
    BrakeMechanicallyOpen := FALSE;
    BrakeContactOpen := FALSE;
    BrakeCoilEnergized := FALSE;
    BrakeFaultCloseActive := FALSE;
    PositionTrue_M := PosP1_M;
    VelocityTrue_Mps := 0.0;
    PreviousVelocity_Mps := 0.0;
    TravelDirection := 0.0;
    LoadAngle_Rad := 0.0;
    SensorTransitionCount := 0;
    SensorBlipActive := FALSE;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    (* Repli deterministe compatible avec le mot thermometre P1 = 00011. *)
    PosTremie := FALSE;
    PosPV := FALSE;
    PosP2 := FALSE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
    instSensorTremie(Enable := FALSE);
    instSensorPV(Enable := FALSE);
    instSensorP2(Enable := FALSE);
    instSensorP1(Enable := FALSE);
    instSensorMaintenance(Enable := FALSE);
    RETURN;
ELSIF NOT Initialized THEN
    Initialized := TRUE;
    PositionTrue_M := PosP1_M;
    TravelDirection := 0.0;
END_IF;

IF Enable THEN
    DirectionSign := 0.0;
    IF ReqTremie AND NOT ReqMaintenance THEN
        DirectionSign := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        DirectionSign := 1.0;
    END_IF;

    FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * MaxFreq_Hz / 100.0, MaxFreq_Hz);
    IF DirectionSign = 0.0 THEN
        FrequencyTarget_Hz := 0.0;
    END_IF;
    instDrive(Enable := TRUE, FrequencyTgt_Hz := FrequencyTarget_Hz,
        AccelRate_HzPerS := AccelRate_HzPerS, DecelRate_HzPerS := DecelRate_HzPerS,
        TimeConstant_S := DriveTimeConstantS,
        LoadAngularVelocity_RadPerS := instSuspendedLoad.AngularVelocity_RadPerS,
        LoadFrequencyDroopGain_Hz := LoadFrequencyDroopGain_Hz, CycleTime_S := CycleTimeS);
    FrequencyCmd_Hz := instDrive.FrequencyCmd_Hz;
    ElectricalFrequency_Hz := instDrive.ElectricalFrequency_Hz;
    SpeedFactorApplied := LIMIT(1.0, SpeedFactor, 5.0);
    ActualFrequency_Hz := instDrive.ActualFrequency_Hz * SpeedFactorApplied;
    instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
        ActualFrequency_Hz := instDrive.ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
        CloseDelay_S := BrakeCloseDelayS, ContactDelay_S := BrakeContactDelayS,
        CycleTime_S := CycleTimeS,
        FaultCloseWhileRunning := BrakeFaultCloseWhileRunning,
        FaultCloseDelay_S := BrakeFaultCloseDelay_S,
        PhysicalBrakeActive := BrakePhysicalActive);
    BrakeCoilEnergized := instBrake.CoilEnergized;
    BrakeMechanicallyOpen := instBrake.MechanicallyOpen;
    BrakeContactOpen := instBrake.ContactOpen;
    BrakeFaultCloseActive := instBrake.FaultCloseActive;

    (* Sens memorise (C3). Regles, dans cet ordre :
       1. un ordre simple valide (re)memorise le sens ;
       2. deux ordres contradictoires neutralisent immediatement le sens — aucune
          excitation inventee (preserve TC-T300-MEC-030) ;
       3. commande retiree : le sens est CONSERVE tant que le variateur retourne de la
          vitesse (deceleration libre), puis purge des que la vitesse est nulle. *)
    IF ReqTremie AND NOT ReqMaintenance THEN
        TravelDirection := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        TravelDirection := 1.0;
    ELSIF ReqTremie AND ReqMaintenance THEN
        TravelDirection := 0.0;
    ELSIF ABS(instDrive.ActualFrequency_Hz) <= CST_StopFrequency_Hz THEN
        TravelDirection := 0.0;
    END_IF;

    PreviousVelocity_Mps := VelocityTrue_Mps;
    IF BrakeMechanicallyOpen THEN
        (* Source unique : meme gain que l'estimateur machine (vitesse = gain x frequence). *)
        VelocityTarget_Mps := TravelDirection * MAX(0.0, GainMetersPerHzSec) * ActualFrequency_Hz;
    ELSE
        VelocityTarget_Mps := 0.0;
    END_IF;
    (* L4 : le variateur tient le chariot tant qu'il est commande ou que sa SORTIE electrique
       alimente encore le moteur (rampe + reponse) ; ensuite, plus aucun couple.
       Reprise de commande en roue libre : pas de reprise a la volee (le variateur repart de 0 Hz). *)
    DriveTorqueActive := (DirectionSign <> 0.0) OR (instDrive.ElectricalFrequency_Hz > CST_StopFrequency_Hz);
    ObsCartFree := CartFreeActive AND BrakeMechanicallyOpen AND NOT DriveTorqueActive;
    IF ObsCartFree THEN
        (* Poussee de la benne (angle du scan precedent) + pente - frottement oppose au mouvement. *)
        (* Pendule sur chariot libre : x'' = m_benne / m_chariot x g x theta = r / (1 - r) x g x theta. *)
        FreeAccel_Mps2 := (LIMIT(0.0, LoadMassRatio, 0.9) / (1.0 - LIMIT(0.0, LoadMassRatio, 0.9)))
                          * 9.81 * instSuspendedLoad.Angle_Rad + Slope_Mps2;
        IF ABS(VelocityTrue_Mps) < 0.001 THEN
            (* Adherence statique au repos : ne decolle que si la poussee depasse le frottement statique *)
            IF ABS(FreeAccel_Mps2) <= MAX(0.0, StaticFriction_Mps2) THEN
                FreeAccel_Mps2 := 0.0;
                VelocityTrue_Mps := 0.0;
            ELSIF FreeAccel_Mps2 > 0.0 THEN
                FreeAccel_Mps2 := FreeAccel_Mps2 - MAX(0.0, StaticFriction_Mps2);
            ELSE
                FreeAccel_Mps2 := FreeAccel_Mps2 + MAX(0.0, StaticFriction_Mps2);
            END_IF;
        ELSIF VelocityTrue_Mps > 0.0 THEN
            FreeAccel_Mps2 := FreeAccel_Mps2 - MAX(0.0, RollingFriction_Mps2);
        ELSE
            FreeAccel_Mps2 := FreeAccel_Mps2 + MAX(0.0, RollingFriction_Mps2);
        END_IF;
        VelocityTrue_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
    ELSIF BrakeMechanicallyOpen THEN
        (* Vitesse suivant directement le variateur (deja filtre par instDrive) sans double PT1 *)
        VelocityTrue_Mps := VelocityTarget_Mps;
    ELSIF BrakePhysicalActive THEN
        (* L3 : frein serre -> deceleration sur le frein jusqu'a l'arret, puis chariot bloque. *)
        IF VelocityTrue_Mps > 0.0 THEN
            VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps - MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
        ELSE
            VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps + MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
        END_IF;
    ELSE
        VelocityTrue_Mps := 0.0;   (* historique : arret instantane *)
    END_IF;
    ObsSpeedBeforeStop_Mps := VelocityTrue_Mps;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
    IF PositionCandidate_M < EndStopTremie_M THEN
        PositionTrue_M := EndStopTremie_M;
        VelocityTrue_Mps := 0.0;
        HardStopTremieActive := TRUE;
    ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
        PositionTrue_M := EndStopMaintenance_M;
        VelocityTrue_Mps := 0.0;
        HardStopMaintenanceActive := TRUE;
    END_IF;
    CartAcceleration_Mps2 := (VelocityTrue_Mps - PreviousVelocity_Mps) / CycleTimeS;
    instSuspendedLoad(Enable := TRUE, BrakeMechanicallyOpen := BrakeMechanicallyOpen,
        CartAcceleration_Mps2 := CartAcceleration_Mps2, Length_M := SuspendedLoadLength_M,
        Damping := SuspendedLoadDamping, ReactionGain_Mps2 := LoadReactionGain_Mps2,
        CycleTime_S := CycleTimeS);
    LoadAngle_Rad := instSuspendedLoad.Angle_Rad;
    IF HardStopTremieActive OR HardStopMaintenanceActive THEN
        RecoilMax_M := MIN(MAX(0.0, EndStopRecoilMax_M), EndStopMaintenance_M - EndStopTremie_M);
        IF (RecoilMax_M > 0.0) AND BrakeMechanicallyOpen THEN
            (* Recul autorise UNIQUEMENT en s'eloignant de la butee touchee, borne par
               EndStopRecoilMax_M : jamais plus loin dans la butee, jamais de saut cache. *)
            VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
            (* Contre une butee, l'entrainement DECROCHE : il ne maintient pas une consigne de
               vitesse dans l'obstacle. Sans cette purge, la consigne de vitesse ecrasait en
               permanence la reaction de charge et le chariot ne pouvait jamais ressortir de
               la zone capteur (recul alors impossible, quelle que soit la charge). *)
            TravelDirection := 0.0;
            IF HardStopTremieActive THEN
                VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps);
                PositionCandidate_M := LIMIT(EndStopTremie_M,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    EndStopTremie_M + RecoilMax_M);
            ELSE
                VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps);
                PositionCandidate_M := LIMIT(EndStopMaintenance_M - RecoilMax_M,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    EndStopMaintenance_M);
            END_IF;
            PositionTrue_M := PositionCandidate_M;
        ELSE
            VelocityTrue_Mps := 0.0;
        END_IF;
    ELSE
        IF NOT ObsCartFree THEN
            (* Reaction historique (negligeable) ; en mode libre la poussee est deja integree (L4). *)
            VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
        END_IF;
        PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
        IF PositionCandidate_M < EndStopTremie_M THEN
            PositionTrue_M := EndStopTremie_M;
            VelocityTrue_Mps := 0.0;
            HardStopTremieActive := TRUE;
        ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
            PositionTrue_M := EndStopMaintenance_M;
            VelocityTrue_Mps := 0.0;
            HardStopMaintenanceActive := TRUE;
        ELSE
            PositionTrue_M := PositionCandidate_M;
        END_IF;
    END_IF;
END_IF;

IF Enable AND (ABS(LoadAngle_Rad) > 0.0001) THEN
    SensorNoiseState := 3.91 * SensorNoiseState * (1.0 - SensorNoiseState);
    SensorNoise_M := (2.0 * SensorNoiseState - 1.0) * SensorJitterAmplitude_M;
ELSE
    SensorNoise_M := 0.0;
END_IF;
(* Les capteurs sont fixes au rail et observent le chariot. Le balancier agit
   seulement par la reaction mecanique sur PositionTrue_M et conditionne un
   episode electrique ; aucune deflexion de godet n'est injectee directement. *)
SensorPosition_M := PositionTrue_M + SensorNoise_M;
(* Les capteurs M3 sont volontairement cumulatifs : 11111 -> 00000. Chaque
   brique garde son hysteresis et son episode propres ; aucun timer partage ne
   peut masquer un front d'un autre capteur. *)
instSensorTremie(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosTremie_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 11,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CamDropoutActive := SensorCamDropoutActive, CamDropoutStart_M := SensorCamDropoutStart_M,
    CamDropoutWidth_M := SensorCamDropoutWidth_M,
    CycleTimeS := CycleTimeS);
instSensorPV(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosPV_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 23,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CamDropoutActive := SensorCamDropoutActive, CamDropoutStart_M := SensorCamDropoutStart_M,
    CamDropoutWidth_M := SensorCamDropoutWidth_M,
    CycleTimeS := CycleTimeS);
instSensorP2(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosP2_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 37,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CamDropoutActive := SensorCamDropoutActive, CamDropoutStart_M := SensorCamDropoutStart_M,
    CamDropoutWidth_M := SensorCamDropoutWidth_M,
    CycleTimeS := CycleTimeS);
instSensorP1(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosP1_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 53,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CamDropoutActive := SensorCamDropoutActive, CamDropoutStart_M := SensorCamDropoutStart_M,
    CamDropoutWidth_M := SensorCamDropoutWidth_M,
    CycleTimeS := CycleTimeS);
instSensorMaintenance(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosMaintenance_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 71,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CamDropoutActive := SensorCamDropoutActive, CamDropoutStart_M := SensorCamDropoutStart_M,
    CamDropoutWidth_M := SensorCamDropoutWidth_M,
    CycleTimeS := CycleTimeS);

PosTremie := instSensorTremie.ElectricalOutput;
PosPV := instSensorPV.ElectricalOutput;
PosP2 := instSensorP2.ElectricalOutput;
PosP1 := instSensorP1.ElectricalOutput;
PosMaintenance := instSensorMaintenance.ElectricalOutput;
SensorTransitionCount := instSensorTremie.TransitionCount + instSensorPV.TransitionCount
    + instSensorP2.TransitionCount + instSensorP1.TransitionCount
    + instSensorMaintenance.TransitionCount;
SensorBlipActive := instSensorTremie.BlipActive OR instSensorPV.BlipActive
    OR instSensorP2.BlipActive OR instSensorP1.BlipActive
    OR instSensorMaintenance.BlipActive;

(* ── L2 OBSERVATION (lecture seule, aucun effet sur le modele) ───────────────────────── *)
IF Enable THEN
    (* Frein serre en mouvement : front de fermeture mecanique avec vitesse non nulle. *)
    IF ObsPrevBrakeOpen AND NOT BrakeMechanicallyOpen AND (ABS(PreviousVelocity_Mps) > 0.03) THEN
        ObsBrakeClosedMovingCount := ObsBrakeClosedMovingCount + 1;
    END_IF;
    ObsPrevBrakeOpen := BrakeMechanicallyOpen;

    (* Choc en butee : front de HardStop, vitesse avant contact. *)
    IF (HardStopTremieActive OR HardStopMaintenanceActive) AND NOT ObsPrevHardStop THEN
        ObsEndStopHitCount := ObsEndStopHitCount + 1;
        ObsEndStopImpactSpeed_Mps := ABS(ObsSpeedBeforeStop_Mps);
    END_IF;
    ObsPrevHardStop := HardStopTremieActive OR HardStopMaintenanceActive;

    (* Depassement : 1er front d'un capteur d'arret (Tremie montant, P1 dans les deux sens,
       Maintenance descendant) -> position memorisee ; les rebonds du MEME capteur sont ignores
       tant que l'arret n'est pas constate ; un autre capteur franchi remplace le repere. *)
    (* Armement seulement chariot en mouvement : un rebond capteur a l'arret n'ecrase pas la mesure. *)
    IF ABS(VelocityTrue_Mps) <= 0.005 THEN
        ObsArmed := ObsArmed;   (* chariot a l'arret : aucun armement *)
    ELSIF (PosTremie AND NOT ObsPrevTremie) AND NOT (ObsArmed AND ObsOvershootSensorId = 1) THEN
        ObsArmed := TRUE; ObsOvershootSensorId := 1; ObsEdgePosition_M := PositionTrue_M;
    ELSIF (PosP1 <> ObsPrevP1) AND NOT (ObsArmed AND ObsOvershootSensorId = 3) THEN
        ObsArmed := TRUE; ObsOvershootSensorId := 3; ObsEdgePosition_M := PositionTrue_M;
    ELSIF (ObsPrevMaintenance AND NOT PosMaintenance) AND NOT (ObsArmed AND ObsOvershootSensorId = 5) THEN
        ObsArmed := TRUE; ObsOvershootSensorId := 5; ObsEdgePosition_M := PositionTrue_M;
    END_IF;
    ObsPrevTremie := PosTremie;
    ObsPrevP1 := PosP1;
    ObsPrevMaintenance := PosMaintenance;

    (* L4 : distance de l'episode libre (frein ouvert, variateur sans couple). *)
    IF NOT ObsCartFree THEN
        FreeRollStart_M := PositionTrue_M;
    ELSE
        ObsFreeRollLast_M := ABS(PositionTrue_M - FreeRollStart_M);
    END_IF;

    IF ObsArmed AND (ABS(VelocityTrue_Mps) < 0.001) THEN
        ObsOvershootLast_M := ABS(PositionTrue_M - ObsEdgePosition_M);
        ObsArmed := FALSE;
    END_IF;
END_IF;

