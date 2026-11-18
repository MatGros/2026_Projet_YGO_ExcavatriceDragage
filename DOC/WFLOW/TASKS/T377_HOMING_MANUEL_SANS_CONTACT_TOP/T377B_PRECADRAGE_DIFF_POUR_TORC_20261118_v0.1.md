# T377-B — Pré-cadrage diff (fourni par T377-CC03, étude du 2026-11-17)

Brouillon de cadrage, PAS du code : chaque bloc = intention + localisation.
Base : `T377_ETUDE_BOOT_PERTE_CODEUR_20261117_v0.1.md` (faits fichier:ligne vs hypothèses séparés).

## Diff 1 — FB_Encoder_Abs.st (producteur unique du flag « bus sain »)

- Ajout VAR_OUTPUT `BusOppedOnce : BOOL` + un latch (R_TRIG sur `SlaveOperational`
  entrant, remis à zéro par reboot PLC — RAM, pas de persist).
- ~5 lignes dans la région §1 (après le calcul de cause 0, FB_Encoder_Abs.st:75-91).
- État : vérifié à la source (interface du FB lue, cause 0 live). Hypothèse : nom exact
  à réviser à l'implémentation selon NAMING_CONVENTION.

## Diff 2 — FB_Safety_Winch.st (cause 1, lignes 277-282)

- Cible : ne pas armer `EncoderFaultLatched` tant que le bus n'a pas atteint OP une fois
  depuis le boot, avec délai max X s (latch quand même si pas d'OP après X).
- Condition d'armement : actuelle `(NOT (BypassProcess OR EncoderFaultBypass))
  AND NOT EncoderAvailable` → même condition et (BusOppedOnce OU BootGraceExpired).
- + 1 entrée (`BootGraceExpired` proposée par le câblage PRG_04 ou TON interne PT config).
- ~3-4 lignes + texte de cause inchangé + latch/Reset inchangés.
- État : cause 1 et warmup vérifiés à la source (FB_Safety_Winch:268, :277-282) ;
  valeur X = MESURE SITE (temps de montée bus) — hypothèse chiffrée interdite.

## Diff 3 — PRG_04_Treuils_Benne.st (:942, :1012)

- Câblage : passer `BusOppedOnce` (exposée par `Data.EncoderM1/M2`) en argument des
  2 appels `instSafetyWinchM1/M2` + constante de grâce.
- État : sites d'appel vérifiés à la source (PRG_04:928-948, :1012).

## Diff 4 — FB_Safety_EmergencyManagement.st (§3, lignes 171-186)

- Reporter l'autotest au point d'armement réel : les 4 contrôles exécutés sur
  `ArmRequest` (transition CST_STEP_IDLE → TEST_A, §5 ~:281-322) au lieu du 1er scan
  (`Enable := TRUE` inconditionnel, PRG_06:502-503).
- Latch de cause 3 + Reset inchangés (discipline ISO conservée).
- État : ordre des contrôles et latch vérifiés à la source (:171-186, :194, :496-497).

## Matrice de tests (6 scénarios)

1. Reboot PLC sous puissance → pas de latch après init bus (ErrorId 0).
2. Cold boot, chaîne AU ouverte → comportement documenté/corrigé.
3. AU mid-run + réarmement → latch « perte codeur » immédiat (cas historique préservé).
4. Codeur mort au boot (pas d'OP) → latch après délai max X.
5. Perte bus en exploitation → latch immédiat (aucun changement).
6. Reset opérateur → purge des latches confirmée (déjà vraie, FB_FaultCore via fronts).

## Ce qui reste HYPOTHÈSE (à lever avant code)

- Position exacte de la chaîne AU au boot matinal + câblage 24 V codeurs vs AU →
  DOC/WFLOW/ELEC (l'exploitant) — ne pas coder le repli « boot + 5 s » avant.
- Valeur X : mesure site du temps de montée bus.
- Nom exact de la sortie ajoutée (NC).

## Mesures de référence T377-B (jour 2026-11-18, tests VOULUS par l'exploitant)

1. **Rechargement/stop PLC volontaire (matin ~10:34 + midi)** — comportement mesuré :
   - au boot : alarmes parasites attendues (autotest AU ErrorID 04, perte codeur
     latchée avec codeurs ensuite RUNNING — snapshot `...103433.csv`) ;
   - pendant le rechargement : slaves COD1/COD2/AC600 → STOPPED, carrousel
     « Defaut bus EtherCAT2 / COD1 non détecté / AC600 non détecté / ErrorID:02 M1+M2 »
     — perte réelle au moment de la coupure, puis latch résiduel (snapshot
     `...122253.csv` : codeurs RUN dans le matin/STOPPED au midi ; retest propre par
     la suite → cause = rechargement, pas défaut matériel).
2. Usage pour le délai X : le rechargement = le cas « PLC boot, bus à re-négocier » ;
   la fenêtre observée (latch posé pendant que le bus monte) est le vrai temps à
   couvrir par X. Prochaine mesure : chronométrer le retour RUNNING après coupure
   (snapshot + trace) pour figer X > temps mesuré.
3. Le test du midi confirme aussi le cas LÉGITIME (perte réelle, verrou correct) et le
   path de reprise opérationnel : Reset + re-homing, pilotage N2 pendant l'indispo.

## Conflit avec le lot T377 : AUCUN

Le lot T377 touche FB_CycleMachineHoming + PRG_02/PRG_07 + diagnostics ; il NE touche
PAS FB_Safety_Winch ni FB_Encoder_Abs, et PRG_04 n'est pas dans son périmètre. Les 2
lots se superposent sans collision de fichier ; seul l'ordre git (2 commits séparés)
importe.
