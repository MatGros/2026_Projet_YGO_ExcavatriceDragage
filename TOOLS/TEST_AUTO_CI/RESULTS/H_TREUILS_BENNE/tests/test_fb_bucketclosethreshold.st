(* =======================================================================
   🧪 FB_BucketCloseThreshold — seuil IHM d'ouverture benne (T262 phase B, C4)
   ───────────────────────────────────────────────────────────────────────
   Périmètre STRICT : le FB de décision en BOÎTE NOIRE. Il dérive du réglage
   IHM `ExtractionStartOpening_Pct` une DISTANCE de fermeture équivalente et
   un signal `Reached`. Il ne lit ni GVL, ni FB_Bucket, ni le cycle : aucun
   consommateur n'est testé ici (PRG_04 / FB_Bucket / FB_CycleSemiAuto
   relèvent de l'essai CODESYS et des gates mécaniques).

   ── Propriété cardinale (AC2 du contrat T262-PHASE-B) ──────────────────
   À ThresholdPct = 0, la branche est INACTIVE PAR CONSTRUCTION : `Reached`
   reste FALSE sur TOUTE la table Delta x géométrie. C'est ce qui rend la
   non-régression du comportement historique indépendante d'un MAX.

   ── Conventions ────────────────────────────────────────────────────────
   1) 1 appel `fb(...)` = 1 scan. Le FB est PUR (aucun état, aucun timer).
   2) ⚠️ Aucune assertion dans une boucle FOR/WHILE : ce build STruCpp
      SUPPRIME silencieusement les ASSERT_* du corps d'une boucle (vérifié
      dans le C++ généré). Tous les balayages sont DÉROULÉS.
   3) Tolérance 1e-6 : REAL en simple précision, littéral ST lu en double.
      Les distances attendues (p x 0,15 m) sont exactes à 1e-6 près.

   ── Géométrie de référence (valeurs persistées GVL_PERSISTENT) ─────────
   OffsetOpenM = 0,0 m · OffsetCloseM = 15,0 m · débattement = 15,0 m
   ⇒ distance équivalente = p % x 15,0 m = p x 0,15 m

   Références : DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T262_PHASE_B_SEUIL_BENNE_2026-09-21.md
                DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T262_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml
   ======================================================================= *)

SETUP
VAR
    FB : FB_BucketCloseThreshold;
END_VAR
END_SETUP


(* ── Groupe A · Branche INACTIVE à 0 % (AC2, AC4) ─────────────────────── *)

TEST 'TC-T262B-001 seuil 0 % : Reached FAUX sur toute la table Delta x geometrie'
    (* Balayage DEROULE. Geometrie nominale 0,0 / 15,0 m ; qualification pleine. *)
    FB.ThresholdPct := 0;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;

    FB.DeltaPosition_M := 0.0;   FB();
    ASSERT_FALSE(FB.Reached, '0 % : benne ouverte (Delta = 0,0) -> Reached FAUX');
    ASSERT_FALSE(FB.Active,  '0 % : branche seuil INACTIVE');

    FB.DeltaPosition_M := 7.5;   FB();
    ASSERT_FALSE(FB.Reached, '0 % : mi-course (Delta = 7,5) -> Reached FAUX');

    FB.DeltaPosition_M := 13.0;  FB();
    ASSERT_FALSE(FB.Reached, '0 % : au seuil de la tolerance historique -> Reached FAUX');

    FB.DeltaPosition_M := 14.0;  FB();
    ASSERT_FALSE(FB.Reached, '0 % : benne fermee (Delta = 14,0) -> Reached FAUX');

    FB.DeltaPosition_M := 15.0;  FB();
    ASSERT_FALSE(FB.Reached, '0 % : sur la reference fermee -> Reached FAUX (0 % n autorise RIEN)');

    FB.DeltaPosition_M := 16.0;  FB();
    ASSERT_FALSE(FB.Reached, '0 % : sur-fermeture -> Reached FAUX');

    (* Geometrie derivee : la branche doit rester inerte quelle que soit la geometrie. *)
    FB.OffsetOpenM := -1.0;
    FB.OffsetCloseM := 20.0;
    FB.DeltaPosition_M := 19.5;  FB();
    ASSERT_FALSE(FB.Reached, '0 % : autre geometrie (debattement 21,0) -> Reached FAUX');
    ASSERT_NEAR(FB.Distance_M, 0.0, 0.000001, '0 % : distance equivalente EXACTEMENT 0,0 m');
END_TEST

TEST 'TC-T262B-002 distance equivalente : 0,15 m par pourcent (geometrie persistee)'
    (* Balayage DEROULE de p = 0 a 20 : la distance est p x 0,15 m. *)
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 0.0;

    FB.ThresholdPct := 0;  FB();  ASSERT_NEAR(FB.Distance_M, 0.0,  0.000001, 'p=0  -> 0,00 m');
    FB.ThresholdPct := 1;  FB();  ASSERT_NEAR(FB.Distance_M, 0.15, 0.000001, 'p=1  -> 0,15 m');
    FB.ThresholdPct := 2;  FB();  ASSERT_NEAR(FB.Distance_M, 0.30, 0.000001, 'p=2  -> 0,30 m');
    FB.ThresholdPct := 3;  FB();  ASSERT_NEAR(FB.Distance_M, 0.45, 0.000001, 'p=3  -> 0,45 m');
    FB.ThresholdPct := 4;  FB();  ASSERT_NEAR(FB.Distance_M, 0.60, 0.000001, 'p=4  -> 0,60 m');
    FB.ThresholdPct := 5;  FB();  ASSERT_NEAR(FB.Distance_M, 0.75, 0.000001, 'p=5  -> 0,75 m');
    FB.ThresholdPct := 6;  FB();  ASSERT_NEAR(FB.Distance_M, 0.90, 0.000001, 'p=6  -> 0,90 m');
    FB.ThresholdPct := 7;  FB();  ASSERT_NEAR(FB.Distance_M, 1.05, 0.000001, 'p=7  -> 1,05 m');
    FB.ThresholdPct := 8;  FB();  ASSERT_NEAR(FB.Distance_M, 1.20, 0.000001, 'p=8  -> 1,20 m (= plancher historique)');
    FB.ThresholdPct := 9;  FB();  ASSERT_NEAR(FB.Distance_M, 1.35, 0.000001, 'p=9  -> 1,35 m');
    FB.ThresholdPct := 10; FB();  ASSERT_NEAR(FB.Distance_M, 1.50, 0.000001, 'p=10 -> 1,50 m');
    FB.ThresholdPct := 13; FB();  ASSERT_NEAR(FB.Distance_M, 1.95, 0.000001, 'p=13 -> 1,95 m');
    FB.ThresholdPct := 14; FB();  ASSERT_NEAR(FB.Distance_M, 2.10, 0.000001, 'p=14 -> 2,10 m (au-dela de la tolerance 2,0)');
    FB.ThresholdPct := 19; FB();  ASSERT_NEAR(FB.Distance_M, 2.85, 0.000001, 'p=19 -> 2,85 m');
    FB.ThresholdPct := 20; FB();  ASSERT_NEAR(FB.Distance_M, 3.00, 0.000001, 'p=20 -> 3,00 m (borne haute)');
END_TEST


(* ── Groupe B · Saturation de la borne 0..20 (AC1) ────────────────────── *)

TEST 'TC-T262B-003 borne basse : seuil negatif ramene a 0 (branche INACTIVE)'
    FB.ThresholdPct := -1;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 14.9;
    FB();
    ASSERT_FALSE(FB.Active, 'Seuil -1 % : branche INACTIVE');
    ASSERT_FALSE(FB.Reached, 'Seuil -1 % : Reached FAUX (aucune autorisation sur saisie hors plage)');
    ASSERT_NEAR(FB.Distance_M, 0.0, 0.000001, 'Seuil -1 % : distance ramenee a 0,0 m');
END_TEST

TEST 'TC-T262B-004 borne haute : seuil 21 ramene a 20 (jamais au-dela)'
    FB.ThresholdPct := 21;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 11.5;   (* ouverture 23,3 % : hors de la plage autorisee *)
    FB();
    ASSERT_NEAR(FB.Distance_M, 3.00, 0.000001, 'Seuil 21 % : distance CLAMPEE a 3,00 m (borne 20 %)');
    ASSERT_FALSE(FB.Reached, 'Seuil 21 % : Reached FAUX a 11,5 m (la borne 20 % est respectee)');
END_TEST

TEST 'TC-T262B-005 seuil 50 (ancienne borne du contrat parent) : ramene a 20'
    FB.ThresholdPct := 50;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 11.5;   (* ouverture 23,3 % : autorisee par 50 %, INTERDITE par la borne 20 % *)
    FB();
    ASSERT_NEAR(FB.Distance_M, 3.00, 0.000001, 'Seuil 50 % : distance CLAMPEE a 3,00 m (regression de borne refusee)');
    ASSERT_FALSE(FB.Reached, 'Seuil 50 % : Reached FAUX a 11,5 m -> la borne 20 % ne peut pas etre contournee');
END_TEST


(* ── Groupe C · Point de bascule au seuil (AC3) ───────────────────────── *)

TEST 'TC-T262B-006 p=10 : bascule exactement a Delta = 13,50 m (faux / vrai / vrai)'
    FB.ThresholdPct := 10;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;

    FB.DeltaPosition_M := 13.49;  FB();
    ASSERT_FALSE(FB.Reached, 'p=10 : Delta = 13,49 m (ouverture 10,07 %) -> Reached FAUX');

    FB.DeltaPosition_M := 13.50;  FB();
    ASSERT_TRUE(FB.Reached, 'p=10 : Delta = 13,50 m (ouverture 10,00 %) -> Reached VRAI, egalite INCLUSE');

    FB.DeltaPosition_M := 13.51;  FB();
    ASSERT_TRUE(FB.Reached, 'p=10 : Delta = 13,51 m (ouverture 9,93 %) -> Reached VRAI');
END_TEST

TEST 'TC-T262B-007 p=19 : bascule exactement a Delta = 12,15 m'
    FB.ThresholdPct := 19;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;

    FB.DeltaPosition_M := 12.14;  FB();
    ASSERT_FALSE(FB.Reached, 'p=19 : Delta = 12,14 m -> Reached FAUX');

    FB.DeltaPosition_M := 12.15;  FB();
    ASSERT_TRUE(FB.Reached, 'p=19 : Delta = 12,15 m -> Reached VRAI (egalite incluse)');

    FB.DeltaPosition_M := 12.16;  FB();
    ASSERT_TRUE(FB.Reached, 'p=19 : Delta = 12,16 m -> Reached VRAI');
END_TEST

TEST 'TC-T262B-008 p=20 (borne) : bascule exactement a Delta = 12,00 m'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;

    FB.DeltaPosition_M := 11.99;  FB();
    ASSERT_FALSE(FB.Reached, 'p=20 : Delta = 11,99 m (ouverture 20,07 %) -> Reached FAUX');

    FB.DeltaPosition_M := 12.00;  FB();
    ASSERT_TRUE(FB.Reached, 'p=20 : Delta = 12,00 m (ouverture 20,00 %) -> Reached VRAI');

    FB.DeltaPosition_M := 12.01;  FB();
    ASSERT_TRUE(FB.Reached, 'p=20 : Delta = 12,01 m -> Reached VRAI');
END_TEST


(* ── Groupe D · Qualification de la mesure (AC5) ──────────────────────── *)

TEST 'TC-T262B-009 geometrie INVALIDE (OffsetOpenM >= OffsetCloseM) : jamais d autorisation'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 15.0;      (* inversee *)
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 14.9;  (* tres proche de la reference, mais geometrie inexploitable *)
    FB();
    ASSERT_FALSE(FB.Active, 'Geometrie invalide : branche seuil INACTIVE');
    ASSERT_FALSE(FB.Reached, 'Geometrie invalide : Reached FAUX (le faux 0 % ne vaut JAMAIS preuve de fermeture)');
    ASSERT_NEAR(FB.Distance_M, 0.0, 0.000001, 'Geometrie invalide : distance neutralisee a 0,0 m');
END_TEST

TEST 'TC-T262B-010 geometrie INVALIDE (OffsetOpenM > OffsetCloseM) : jamais d autorisation'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 16.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 14.9;
    FB();
    ASSERT_FALSE(FB.Active, 'Geometrie inversee : branche seuil INACTIVE');
    ASSERT_FALSE(FB.Reached, 'Geometrie inversee : Reached FAUX');
    ASSERT_NEAR(FB.Distance_M, 0.0, 0.000001, 'Geometrie inversee : distance neutralisee');
END_TEST

TEST 'TC-T262B-011 MeasureValid FAUX (ActiveOffsetValid) : jamais d autorisation'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := FALSE;    (* references non fiables / defaut / puissance absente *)
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 14.9;
    FB();
    ASSERT_FALSE(FB.Active, 'MeasureValid FAUX : branche seuil INACTIVE');
    ASSERT_FALSE(FB.Reached, 'MeasureValid FAUX : Reached FAUX');
END_TEST

TEST 'TC-T262B-012 IsIntermediate FAUX (mesure hors bande plausible) : jamais d autorisation'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := FALSE;  (* sur-fermeture / sur-ouverture : mesure non plausible *)
    FB.DeltaPosition_M := 14.9;
    FB();
    ASSERT_FALSE(FB.Active, 'IsIntermediate FAUX : branche seuil INACTIVE');
    ASSERT_FALSE(FB.Reached, 'IsIntermediate FAUX : Reached FAUX');
END_TEST


(* ── Groupe E · Pas de front : la branche reste vraie (AC9, anti-deadlock AX10) ── *)

TEST 'TC-T262B-013 p=20 : Reached reste VRAI sur 3 scans consecutifs a Delta constant'
    (* Preuve anti-deadlock : la porte AX10 ne doit pas dependre d un front present au
       scan exact d arrivee. Sans cette propriete, un geste absent au bon scan figerait
       la sortie AX10 (defaut constate et corrige par la tolerance historique). *)
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 12.00;

    FB();  ASSERT_TRUE(FB.Reached, 'Scan 1 : Reached VRAI');
    FB();  ASSERT_TRUE(FB.Reached, 'Scan 2 : Reached TOUJOURS VRAI (aucun front requis)');
    FB();  ASSERT_TRUE(FB.Reached, 'Scan 3 : Reached TOUJOURS VRAI');
END_TEST

TEST 'TC-T262B-014 p=20 : sortie puis retour dans la zone -> Reached de nouveau VRAI'
    FB.ThresholdPct := 20;
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;

    FB.DeltaPosition_M := 12.00;  FB();
    ASSERT_TRUE(FB.Reached, 'Entree dans la zone : Reached VRAI');

    FB.DeltaPosition_M := 10.00;  FB();   (* ouverture 33,3 % : hors zone *)
    ASSERT_FALSE(FB.Reached, 'Sortie de la zone : Reached FAUX');

    FB.DeltaPosition_M := 12.50;  FB();   (* geste repris, la benne se referme *)
    ASSERT_TRUE(FB.Reached, 'Retour dans la zone : Reached VRAI sans etat memorise');
END_TEST


(* ── Groupe F · Monotonie : un reglage plus grand ne resserre JAMAIS (AC4) ── *)

TEST 'TC-T262B-015 monotonie : Delta fixe, Reached VRAI pour p = seuil .. 20'
    (* Le point probatoire de la conception : augmenter le reglage ne peut JAMAIS
       rendre le critere plus strict. On se place a l ouverture 15 % (Delta = 12,75 m). *)
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 12.75;          (* ouverture exactement 15,00 % *)

    FB.ThresholdPct := 0;   FB();  ASSERT_FALSE(FB.Reached, 'p=0  : inerte (historique seul)');
    FB.ThresholdPct := 10;  FB();  ASSERT_FALSE(FB.Reached, 'p=10 : inerte, seuil non atteint a 15 % d ouverture');
    FB.ThresholdPct := 14;  FB();  ASSERT_FALSE(FB.Reached, 'p=14 : inerte (distance 2,10 m < 2,25 m restants)');
    FB.ThresholdPct := 15;  FB();  ASSERT_TRUE(FB.Reached,  'p=15 : BASCULE (egalite incluse)');
    FB.ThresholdPct := 16;  FB();  ASSERT_TRUE(FB.Reached,  'p=16 : VRAI (un reglage plus grand ne resserre pas)');
    FB.ThresholdPct := 20;  FB();  ASSERT_TRUE(FB.Reached,  'p=20 : VRAI (monotonie tenue jusqu a la borne)');
END_TEST

TEST 'TC-T262B-016 monotonie : Reached VRAI a p est encore VRAI a p+1 pour un Delta donne'
    (* Balayage DEROULE : Delta = 12,30 m (ouverture 18,00 %). *)
    FB.OffsetOpenM := 0.0;
    FB.OffsetCloseM := 15.0;
    FB.MeasureValid := TRUE;
    FB.IsIntermediate := TRUE;
    FB.DeltaPosition_M := 12.30;

    FB.ThresholdPct := 17;  FB();  ASSERT_FALSE(FB.Reached, 'p=17 : FAUX (distance 2,55 m > 2,70 m restants)');
    FB.ThresholdPct := 18;  FB();  ASSERT_TRUE(FB.Reached,  'p=18 : VRAI (egalite incluse)');
    FB.ThresholdPct := 19;  FB();  ASSERT_TRUE(FB.Reached,  'p=19 : VRAI');
    FB.ThresholdPct := 20;  FB();  ASSERT_TRUE(FB.Reached,  'p=20 : VRAI');
END_TEST
