(* =======================================================================
   🧪 FB_CfgT330Normalizer — cas ST unitaires du plan T330 (C3 v1.3)
   ───────────────────────────────────────────────────────────────
   Périmètre STRICT : le FB de normalisation des réglages HAUT, en boîte
   noire (contrat light : Enable / InHoming -> Ready / Corrected).
   Aucune assertion ne porte sur un consommateur (PRG_03 / PRG_04 /
   PRG_06 / GVL_PERSISTENT) : ces cas relèvent d'un lot d'intégration
   dédié (voir TASK_CONTRACT_T341, section « hors scope »).

   ── Conventions ───────────────────────────────────────────────────────
   1) 1 appel fb(...) = 1 scan.
   2) ⚠️ STruCpp v0.6.2 passe les VAR_IN_OUT par COPIE et ne génère que le
      copy-IN. La restitution `cfg := fb.CommunCfg;` est donc OBLIGATOIRE
      après chaque appel : elle émule la sémantique par RÉFÉRENCE de
      CODESYS. Sans elle, toute assertion de correction serait VACUE
      (le FB écrirait dans sa copie privée, jamais dans la variable de test).
      Le post-traitement `inject_var_in_out_copyout.py` ne s'applique PAS à
      une VAR déclarée dans un bloc `VAR` local de TEST (sa regex exige le
      préfixe `s.` que ce build n'émet pas) — d'où l'émulation explicite.
   3) ⚠️ Aucune assertion n'est placée dans une boucle FOR/WHILE : ce build
      STruCpp SUPPRIME silencieusement les ASSERT_* du corps d'une boucle
      (vérifié dans le C++ généré). Les balayages sont donc déroulés.
   4) Tolérance 1e-6 : les REAL sont en simple précision, un littéral ST est
      lu en double — un écart de ~1,4e-7 est normal sur 7,4999.
   5) Amorcage : le FB amorce ses mémoires de front au PREMIER scan où
      `Enable` est vrai, depuis les valeurs RESTAURÉES (piège P2 du cadrage).
      Une stimulation « saisie opérateur » se joue donc au scan SUIVANT.

   Référence : DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md §4.2
   ======================================================================= *)

SETUP
VAR
    FB       : FB_CfgT330Normalizer;
    WinchCfg : ST_WinchCfg;
    ComCfg   : ST_CommunCfg;
END_VAR
END_SETUP


(* ── Groupe A · Normalisation (TC-P10-056 .. TC-P10-062) ──────────────── *)

TEST 'TC-P10-056 R1 — FDC saisi trop haut : FDC corrige, TOP preserve'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* Scan 1 : amorcage sur la config restauree valide (8,50 / 7,50 / 0,50). *)
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Scan d amorcage : config valide, aucune correction');

    (* Scan 2 : l'operateur saisit FDC = 8,70 m (TOP inchange a 8,50 m). *)
    communCfg.CfgCableLimitAscent_M := 8.7;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001,
                'R1 : FDC ramene a TOP - 1,00 m = 7,50');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'R1 : le TOP n est PAS modifie');
    ASSERT_TRUE(FB.Corrected, 'R1 : une correction a eu lieu, message emis');
END_TEST

TEST 'TC-P10-057 R2 — TOP saisi trop bas : TOP corrige, FDC preserve'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : l'operateur saisit TOP = 7,00 m (FDC inchange a 7,50 m). *)
    winchCfg.CfgTopSensorPos_M := 7.0;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001,
                'R2 : TOP ramene a FDC + 1,00 m = 8,50 (le champ saisi est corrige)');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'R2 : le FDC n est PAS modifie');
    ASSERT_TRUE(FB.Corrected, 'R2 : une correction a eu lieu, message emis');
END_TEST

TEST 'TC-P10-058 R1 — Delta = 0,90 m : correction du champ saisi (FDC)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : FDC = 7,60 m => Delta = 8,50 - 7,60 = 0,90 m < 1,00 m. *)
    communCfg.CfgCableLimitAscent_M := 7.6;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Delta < 1,00 m : FDC ramene a 7,50');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'Delta < 1,00 m : TOP preserve');
    ASSERT_TRUE(FB.Corrected, 'Delta < 1,00 m : correction signalee');
END_TEST

TEST 'TC-P10-059 R3 — plancher du ralentissement haut (0,20 -> 0,50)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : ralentissement saisi a 0,20 m (< 0,50 m). *)
    communCfg.WinchSlowdownDistanceTop_M := 0.2;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.WinchSlowdownDistanceTop_M, 0.5, 0.000001,
                'R3 : ralentissement ramene au plancher 0,50 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'R3 : TOP inchange');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'R3 : FDC inchange');
    ASSERT_TRUE(FB.Corrected, 'R3 : correction signalee');
END_TEST

TEST 'TC-P10-060 config valide (Delta = 2,50) : aucune correction, aucun message'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : TOP = 10,00 m, FDC = 7,50 m => Delta = 2,50 m, valide. *)
    winchCfg.CfgTopSensorPos_M := 10.0;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 10.0, 0.000001, 'Config valide : TOP preserve');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Config valide : FDC preserve');
    ASSERT_FALSE(FB.Corrected, 'Config valide : AUCUN message (compteur de messages = 0)');
END_TEST

TEST 'TC-P10-061 Q17 — les DEUX champs changent au meme scan : TOP preserve, FDC corrige'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : les 3 reglages changent ensemble : FDC 9,50 / TOP 8,00 / slowdown 0,10. *)
    communCfg.CfgCableLimitAscent_M := 9.5;
    winchCfg.CfgTopSensorPos_M := 8.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.1;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.0, 0.000001, 'Q17 : le TOP saisi est PRESERVE');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.0, 0.000001,
                'Q17 : FDC = TOP - 1,00 m = 7,00 (R0 a d abord ramene 9,50 a 9,00)');
    ASSERT_NEAR(communCfg.WinchSlowdownDistanceTop_M, 0.5, 0.000001, 'R3 : ralentissement ramene a 0,50');
    ASSERT_TRUE(FB.Corrected, 'Q17 : les trois corrections sont signalees');
END_TEST

TEST 'TC-P10-062 FDC = 0,00 m (borne basse, Delta valide) : accepte, aucune correction'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : FDC = 0,00 m => Delta = 8,50 m, valide. La borne basse est INCLUSE. *)
    communCfg.CfgCableLimitAscent_M := 0.0;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 0.0, 0.000001,
                'FDC a la borne basse : valeur ACCEPTEE telle quelle');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'FDC a la borne basse : TOP inchange');
    ASSERT_FALSE(FB.Corrected, 'FDC a la borne basse : aucune correction, aucun message');
END_TEST


(* ── Groupe B · Idempotence et non-rebond (TC-P10-063 .. TC-P10-068) ──── *)

TEST 'TC-P10-063 Q24 — idempotence : le 2e scan apres correction ne corrige PLUS'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : correction (FDC 8,70 -> 7,50). *)
    communCfg.CfgCableLimitAscent_M := 8.7;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Scan 2 : FDC corrige a 7,50');

    (* Scan 3 : rejeu SANS nouvelle saisie => ni correction, ni message, valeur stable. *)
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Scan 3 : valeur STABLE a 7,50');
    ASSERT_FALSE(FB.Corrected, 'Scan 3 : AUCUNE seconde correction (test probatoire de Q24)');
END_TEST

TEST 'TC-P10-064 reserve EXACTEMENT 1,00 m : aucune correction (aucun epsilon)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Delta = 1,00 m exactement : aucune correction (comparaison stricte)');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M - communCfg.CfgCableLimitAscent_M, 1.0, 0.000001,
                'Le flottant est EXACT : 8,50 - 7,50 = 1,00 (aucun eps necessaire)');

    (* Scan 2 : rejeu identique — la reserve reste exactement 1,00 m. *)
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Scan 2 : aucune oscillation autour du seuil');
END_TEST

TEST 'TC-P10-065 pt1 balayage 7,4999 — Delta = 1,0001 m : FDC conserve'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    communCfg.CfgCableLimitAscent_M := 7.4999;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.4999, 0.000001,
                'Delta > 1,00 m : FDC conserve tel quel');
    ASSERT_FALSE(FB.Corrected, 'Delta > 1,00 m : aucun message');
END_TEST

TEST 'TC-P10-065 pt2 balayage 7,5000 — Delta = 1,00 m exactement : FDC conserve'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    communCfg.CfgCableLimitAscent_M := 7.5;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001,
                'Delta = 1,00 m (point limite INCLUS) : FDC conserve');
    ASSERT_FALSE(FB.Corrected, 'Delta = 1,00 m : aucun message');
END_TEST

TEST 'TC-P10-065 pt3 balayage 7,5001 — Delta = 0,9999 m : FDC corrige, une seule fois'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    communCfg.CfgCableLimitAscent_M := 7.5001;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Delta < 1,00 m : FDC ramene a 7,50');
    ASSERT_TRUE(FB.Corrected, 'Delta < 1,00 m : correction signalee');

    (* Scan suivant : la valeur corrigee ne rebondit pas (aucune oscillation au seuil). *)
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Scan suivant : aucune seconde correction (pas d oscillation)');
END_TEST

TEST 'TC-P10-066 LIMITE DECLAREE — guerre d ecriture IHM : correction a CHAQUE scan'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* ⚠️ Ce cas fige une LIMITE ASSUMEE du lot (plan v1.3 §4.2, C3), PAS une exigence :
       si le panneau IHM reecrit 8,70 m a CHAQUE scan, la normalisation corrige a chaque
       scan et le message rebondit — aucun amortissement n'est specifie ni implemente.
       Le test est volontairement falsifiable : ajouter un anti-rebond le fera echouer,
       ce qui forcera une decision DOCUMENTEE plutot qu'une derive silencieuse.
       Balayage DEROULE (3 scans) : une assertion dans une boucle serait supprimee
       silencieusement par STruCpp et le test deviendrait VACUE. *)
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2. *)
    communCfg.CfgCableLimitAscent_M := 8.7;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Scan 2 : correction reappliquee');
    ASSERT_TRUE(FB.Corrected, 'Scan 2 : message emis (rebond ASSUME)');

    (* Scan 3. *)
    communCfg.CfgCableLimitAscent_M := 8.7;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Scan 3 : correction reappliquee');
    ASSERT_TRUE(FB.Corrected, 'Scan 3 : message emis (rebond ASSUME)');

    (* Scan 4. *)
    communCfg.CfgCableLimitAscent_M := 8.7;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Scan 4 : correction reappliquee');
    ASSERT_TRUE(FB.Corrected, 'Scan 4 : message emis (rebond ASSUME)');
END_TEST

TEST 'TC-P10-067 valeur IDENTIQUE re-saisie : aucun front, aucune correction'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : le champ est REEcrit avec la MEME valeur (8,50 -> 8,50). *)
    winchCfg.CfgTopSensorPos_M := 8.5;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Valeur identique re-saisie : aucun front, aucun message');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'Valeur identique : TOP inchange');
END_TEST

TEST 'TC-P10-068 changement de page IHM sans modification : aucune correction'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* Scan 2 : page quittee => normalisation suspendue, AUCUNE valeur modifiee. *)
    FB.Enable := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Normalisation suspendue : aucun message');
    ASSERT_FALSE(FB.Ready, 'Normalisation suspendue : Ready = FALSE');

    (* Scan 3 : retour sur la page, valeurs inchangees => ni front, ni correction. *)
    FB.Enable := TRUE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Retour de page sans modification : aucune correction');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'Retour de page : TOP inchange');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Retour de page : FDC inchange');
END_TEST


(* ── Groupe C · Boot, restauration, hot restart (TC-P10-069 .. TC-P10-074) ─ *)

TEST 'TC-P10-069 NVRAM valide au demarrage a froid : 0 correction, valeurs preservees'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_TRUE(FB.Ready, 'Normalisation ARMED des le premier scan apres restauration');
    ASSERT_FALSE(FB.Corrected, 'NVRAM valide : aucune correction');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'NVRAM valide : TOP preserve');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'NVRAM valide : FDC preserve');
    ASSERT_NEAR(communCfg.WinchSlowdownDistanceTop_M, 0.5, 0.000001, 'NVRAM valide : ralentissement preserve');
END_TEST

TEST 'TC-P10-070 NVRAM invalide au demarrage a froid : Q17 (TOP preserve, FDC corrige)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* NVRAM restauree INVALIDE : TOP = 7,00 m / FDC = 7,50 m. *)
    winchCfg.CfgTopSensorPos_M := 7.0;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 7.0, 0.000001,
                'Q17 : le TOP restaure est PRESERVE (c est la cote gravee par le homing)');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 6.0, 0.000001, 'Q17 : FDC = TOP - 1,00 m = 6,00');
    ASSERT_TRUE(FB.Corrected, 'NVRAM invalide : correction signalee');
END_TEST

TEST 'TC-P10-071 premier scan NOT Initialized : normalisation INHIBEE, aucune ecriture'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* Ponts non restaures : les valeurs presentes sont les DEFAUTS DUT, pas une saisie. *)
    winchCfg.CfgTopSensorPos_M := 99.0;
    communCfg.CfgCableLimitAscent_M := 99.0;
    communCfg.WinchSlowdownDistanceTop_M := 99.0;
    FB.Enable := FALSE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Ready, 'NOT Initialized : normalisation NON armee');
    ASSERT_FALSE(FB.Corrected, 'NOT Initialized : aucun message');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 99.0, 0.000001, 'NOT Initialized : AUCUNE ecriture TOP');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 99.0, 0.000001, 'NOT Initialized : AUCUNE ecriture FDC');
    ASSERT_NEAR(communCfg.WinchSlowdownDistanceTop_M, 99.0, 0.000001,
                'NOT Initialized : AUCUNE ecriture ralentissement');
END_TEST

TEST 'TC-P10-074 ptA restauration NVRAM : AUCUNE correction fantome (defauts DUT -> restaure)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* PREUVE EXIGEE par le plan §2.2 point 3 : la transition « defauts DUT ->
       valeurs RESTAUREES » ne doit PAS etre prise pour une saisie operateur. *)
    winchCfg.CfgTopSensorPos_M := 8.5;      (* defauts DUT au 1er scan *)
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := FALSE;                     (* ponts non restaures *)
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    winchCfg.CfgTopSensorPos_M := 8.5;      (* valeurs RESTAUREES, valides *)
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Restauration NVRAM : AUCUNE correction fantome');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'Restauration NVRAM : TOP preserve');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Restauration NVRAM : FDC preserve');
END_TEST

TEST 'TC-P10-074 ptB download/RTS : comportement DETERMINISTE, une seule correction'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* NVRAM restauree INVALIDE apres download : une correction, jamais repetee. *)
    winchCfg.CfgTopSensorPos_M := 7.0;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_TRUE(FB.Corrected, 'NVRAM invalide : une correction, signalee');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 6.0, 0.000001, 'NVRAM invalide : FDC = 6,00 (Q17)');

    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Scan suivant : aucune correction fantome repetee');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 6.0, 0.000001, 'Valeur corrigee STABLE');
END_TEST


(* ── Groupe E · Modes et domaines (TC-P10-082 .. TC-P10-092) ──────────── *)

TEST 'TC-P10-082 Q22/C2 — homing : gel NVRAM, repli NIVEAU Q17, non-memorisation'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
    fbRestart : FB_CfgT330Normalizer;
    wR        : ST_WinchCfg;
    cR        : ST_CommunCfg;
END_VAR
    (* Scan 1 : config valide, hors homing. *)
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 7.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;

    (* ① PENDANT le homing : TOP saisi 7,00 m => R2 INHIBEE et NVRAM GELEE (aucune ecriture). *)
    winchCfg.CfgTopSensorPos_M := 7.0;
    FB.InHoming := TRUE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 7.0, 0.000001,
                'Homing : le TOP saisi reste 7,00 INCHANGE (R2 inhibee, gel NVRAM)');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 7.5, 0.000001, 'Homing : FDC gele');
    ASSERT_FALSE(FB.Corrected, 'Homing : aucune ecriture Cfg, donc aucun message');

    (* ② SORTIE du homing : la config est toujours invalide => REPLI NIVEAU = Q17. *)
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 7.0, 0.000001, 'Sortie de homing : TOP PRESERVE (Q17)');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 6.0, 0.000001,
                'Sortie de homing : FDC = 7,00 - 1,00 = 6,00 (repli NIVEAU)');
    ASSERT_TRUE(FB.Corrected, 'Sortie de homing : message NOMINAL, une seule fois');

    (* ③ Scan suivant : AUCUNE seconde correction (idempotence). *)
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Scan suivant : aucune seconde correction');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 6.0, 0.000001, 'Scan suivant : FDC stable a 6,00');

    (* ④ Variante (c) — coupure pendant le homing : l intention est PERDUE. Un redemarrage
       a froid (instance NEUVE : les memoires du FB ne sont pas persistantes) applique la
       normalisation Q2 ORDINAIRE : rien de specifique n a ete memorise. *)
    wR.CfgTopSensorPos_M := 7.0;
    cR.CfgCableLimitAscent_M := 7.5;
    cR.WinchSlowdownDistanceTop_M := 0.5;
    fbRestart.Enable := TRUE;
    fbRestart.InHoming := FALSE;
    fbRestart(WinchCfgM1 := wR, CommunCfg := cR);
    wR := fbRestart.WinchCfgM1;  cR := fbRestart.CommunCfg;
    ASSERT_NEAR(wR.CfgTopSensorPos_M, 7.0, 0.000001, 'Redemarrage : TOP restaure preserve');
    ASSERT_NEAR(cR.CfgCableLimitAscent_M, 6.0, 0.000001, 'Redemarrage : Q2 ordinaire => FDC = 6,00');
    ASSERT_TRUE(fbRestart.Corrected, 'Redemarrage : message Q2 ordinaire (aucune memoire d intention)');
END_TEST

TEST 'TC-P10-090 ptA R0 — FDC = 0,00 m : valeur A LA BORNE, acceptee sans message'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := 0.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 0.0, 0.000001, 'R0 : 0,00 m reste 0,00 m (borne INCLUSE)');
    ASSERT_FALSE(FB.Corrected, 'R0 : a la borne, aucune correction, aucun message');
END_TEST

TEST 'TC-P10-090 ptB R0 — FDC = -1,00 m : CLAMPE a 0,00 m + message'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 8.5;
    communCfg.CfgCableLimitAscent_M := -1.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 0.0, 0.000001, 'R0 : -1,00 m CLAMPE a 0,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 8.5, 0.000001, 'R0 : TOP inchange (Delta = 8,50 m valide)');
    ASSERT_TRUE(FB.Corrected, 'R0 : clamp signale (jamais muet)');
END_TEST

TEST 'TC-P10-090 ptC R0 — TOP = 0,50 m : CLAMPE a 1,00 m + message, R0 observe SEUL'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* FDC = 0,00 m : apres clamp du TOP a 1,00 m, Delta = 1,00 m exactement => la regle
       Delta reste INERTE, ce qui isole R0 (exigence Q21 bis). *)
    winchCfg.CfgTopSensorPos_M := 0.5;
    communCfg.CfgCableLimitAscent_M := 0.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 1.0, 0.000001, 'R0 : TOP 0,50 m CLAMPE a 1,00 m');
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 0.0, 0.000001, 'R0 : FDC inchange a 0,00 m');
    ASSERT_TRUE(FB.Corrected, 'R0 : clamp signale (jamais muet)');
END_TEST

TEST 'TC-P10-091 ptA Q21 bis — R0 SEUL : Delta >= 1 avant clamp (FDC 9,50 / TOP 12,00)'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* LE cas probatoire : Delta = 2,50 m >= 1,00 m, donc AUCUNE regle Delta ne se
       declenche : SEUL R0 agit. Sans R0 en amont, ces deux valeurs restaient hors
       domaine indefiniment. *)
    winchCfg.CfgTopSensorPos_M := 12.0;
    communCfg.CfgCableLimitAscent_M := 9.5;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 9.0, 0.000001, 'Q21 bis : FDC ramene a la borne haute 9,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 10.0, 0.000001, 'Q21 bis : TOP ramene a la borne haute 10,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M - communCfg.CfgCableLimitAscent_M, 1.0, 0.000001,
                'Q21 bis : coherence Delta = 1,00 m APRES clamp');
    ASSERT_TRUE(FB.Corrected, 'Q21 bis : clamp signale, message non alarmant');
END_TEST

TEST 'TC-P10-091 ptB Q21 bis — domaines absurdes : R0 borne AVANT tout usage aval'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    winchCfg.CfgTopSensorPos_M := 150.0;
    communCfg.CfgCableLimitAscent_M := -150.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 0.0, 0.000001, 'Domaines absurdes : FDC borne a 0,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 10.0, 0.000001, 'Domaines absurdes : TOP borne a 10,00 m');
    ASSERT_TRUE(winchCfg.CfgTopSensorPos_M <= 10.0, 'Aucune valeur hors domaine ne subsiste');
    ASSERT_TRUE(FB.Corrected, 'Domaines absurdes : clamp signale');
END_TEST

TEST 'TC-P10-092 ptA C1 — R0 d abord : TOP 11,00 -> 10,00 et FDC 10,00 -> 9,00, Delta valid'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* TOP volontairement AU-DELA de la borne : c'est ce qui rend le cas DISCRIMINANT.
       Si R0 ne s'appliquait pas, Delta = 11,00 - 10,00 = 1,00 m serait deja « valide »
       et AUCUNE regle ne corrigerait : les deux valeurs resteraient hors domaine.
       Avec R0 en amont : TOP -> 10,00, FDC -> 9,00, Delta final = 1,00 m exactement. *)
    winchCfg.CfgTopSensorPos_M := 11.0;
    communCfg.CfgCableLimitAscent_M := 10.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(communCfg.CfgCableLimitAscent_M, 9.0, 0.000001, 'C1 : FDC 10,00 m ramene a la borne 9,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 10.0, 0.000001, 'C1 : TOP 11,00 m ramene a la borne 10,00 m');
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M - communCfg.CfgCableLimitAscent_M, 1.0, 0.000001,
                'C1 : Delta = 1,00 m exactement => aucune correction supplementaire');
    ASSERT_TRUE(FB.Corrected, 'C1 : seule la correction R0 est signalee');
END_TEST

TEST 'TC-P10-092 ptB C1 — R2 au plus haut de sa plage : TOP = 10,00 m, jamais au-dela'
VAR
    winchCfg  : ST_WinchCfg;
    communCfg : ST_CommunCfg;
END_VAR
    (* Amorcage a la borne haute : FDC = 9,00 m (borne), TOP = 10,00 m (Delta = 1,00 m). *)
    winchCfg.CfgTopSensorPos_M := 10.0;
    communCfg.CfgCableLimitAscent_M := 9.0;
    communCfg.WinchSlowdownDistanceTop_M := 0.5;
    FB.Enable := TRUE;
    FB.InHoming := FALSE;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_FALSE(FB.Corrected, 'Amorcage a la borne haute : aucune correction');

    (* L'operateur saisit TOP = 2,00 m : R2 doit redonner EXACTEMENT 10,00 m. *)
    winchCfg.CfgTopSensorPos_M := 2.0;
    FB(WinchCfgM1 := winchCfg, CommunCfg := communCfg);
    winchCfg := FB.WinchCfgM1;  communCfg := FB.CommunCfg;
    ASSERT_NEAR(winchCfg.CfgTopSensorPos_M, 10.0, 0.000001,
                'C1 : R2 redonne exactement TOP = 10,00 m (jamais > 10,00)');
    ASSERT_TRUE(winchCfg.CfgTopSensorPos_M <= 10.0, 'C1 : aucune valeur hors borne ne peut etre produite');
    ASSERT_TRUE(FB.Corrected, 'C1 : correction signalee');
END_TEST
