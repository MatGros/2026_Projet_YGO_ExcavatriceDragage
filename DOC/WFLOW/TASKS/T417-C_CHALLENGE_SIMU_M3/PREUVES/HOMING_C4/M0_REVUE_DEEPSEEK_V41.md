🔴 **BLOCK — Design non approuvable en l’état**  
Verdict : **BLOCK**. Plusieurs contradictions internes peuvent produire mouvement non commandé, perte de limite haute, deadlock Step1/Step2 ou masquage de défaut sécurité. Ne pas écrire dans `CODE/` avant arbitrage des points 1–4 et 7–9.  
Horodatage : 2026-05-10. Périmètre : revue du design fourni uniquement ; aucun fichier `CODE/` lu, donc les lignes `PRG_04:1632,1653` ne sont pas vérifiées ici.

1. **Step 4 contradictoire** `[❌ FAIL]` — D4bis dit « Mouvements bloqués » puis `M1Demand` / `M2Demand` + attente `BothAxesHomed`. Soit les demandes produisent un mouvement, ce qui contredit le blocage ; soit elles ne bougent pas, et `BothAxesHomed` peut ne jamais devenir vrai. De plus `M1Demand = 8.5 m` avec `TopPositionSensor = FALSE` est une cible de mouvement si `M1Demand` n’est pas une simple référence encodeur.  
**Action :** séparer explicitement `EncoderReferenceCommit` et `MotionDemand`. Aucun `DriveDemand` en Step 4. Si un mouvement physique est nécessaire, lever la contradiction et ajouter limite haute indépendante + surveillance surcourse.

2. **Trou Deadman / ArmingPermit** `[❌ FAIL]` — D2 ignore volontairement `DeadmanArmed` en Step 0 car `ArmingPermit = FALSE`. Mais D3 autorise M2 seul en Step 1 et D4 exige `DeadmanArmed` en Step 2. Si `ArmingPermit` reste FALSE : soit M2 bouge sans homme-mort, soit Step 2/3 deadlock.  
**Action :** définir `MotionPermit := DeadmanArmed AND ArmingPermit AND no fault`, requis pour tout ordre M1/M2 en Step 1–3. L’entrée Step 0 reste séparée. Si absent : message et maintien sûr, pas de mouvement.

3. **Meca D en N2 vs secours libre** `[❌ FAIL]` — D7 garde `PowerCutOff` actif en `MAINT_N2`, D1 promet un dégagement libre, D6 bypasse `Meca D` sur descente intentionnelle pure. Contradiction : si `PowerCutOff` actif, le frein/gravité n’est pas maîtrisé ; si bypassé, la fonction sécurité est perdue. `MaintenanceN2BrakeForce` ne doit pas masquer un vrai défaut `Meca B`.  
**Action :** descente secours uniquement avec release frein contrôlée safety-rated + surveillance vitesse/current/temps. Comparer à l’état attendu, ne pas masquer `Meca B/D`. Sans ce mécanisme : bloquer la conception N2.

4. **Step 3 : timer 4 s contournable** `[❌ FAIL]` — La descente est autorisée et le timer ne démarre qu’après relâchement de `TopPositionSensor`. Si le capteur reste TRUE, descente illimitée. S’il chatter, reset. Si l’opérateur pulse, répétition possible.  
**Action :** hard max de descente Step 3 indépendant du capteur ; latch du premier TRUE→FALSE ; neutre obligatoire avant toute descente ; plausibilité capteur. Test stuck TRUE, stuck FALSE, chatter.

5. **Step 2 : 2 s par geste sans cumul** `[❌ FAIL]` — « 2 s max par geste » sans obligation de neutre ni cap cumulé permet des pulses répétés. La transition Step 1→Step 2 « attente arrêt mécanique + neutre + WinchSelArbitrated = 0 » est ambiguë ; si `M2_MechanicStopEngaged` n’est simulé qu’après référence, deadlock possible.  
**Action :** après 2 s, latch + neutre + nouveau geste ; cap cumulé Step 2/homing ; exiger vitesse nulle/frein avant `CmdWinchSelect := 0`. Clarifier `M2_MechanicStopEngaged` réel/sim.

6. **M3 libéré trop largement** `[❌ FAIL]` — `MachineHoming.Active` libère `M3AtTremie`, `T248`, `WinchDescentAuth_M3` sans gating par step. M3 entre capteurs + autorisation descente winch = risque de collision.  
**Action :** gating par step/mode. N1/SEMI_AUTO : `M3Locked` ; N2 : libre uniquement Step 0 ; re-lock à la sortie, abort ou défaut. Test changement de mode en cours de homing.

7. **FB_WinchSync / WinchBothIntent** `[❌ FAIL]` — Step 2 exige `WinchSelArbitrated = 0` avant mouvement, mais `WinchBothIntent` est gaté sur `WinchSel = 0` et `FB_WinchSync` peut exiger `HomedM1/M2`. Soit deadlock avant homing, soit bypass sync non sûr.  
**Action :** état d’arbitrage homing explicite : `0` seulement si deux axes enabled, même sens, freins prêts, aucun défaut ; sinon abort avec message. Ne pas bypasser silencieusement la sync.

8. **Séquence bucket/M2 incohérente** `[❌ FAIL]` — Step 4 applique `M2Demand = 8.5 m + OffsetCloseM` avant `BucketCommit.CommitClose`. Si la benne est ouverte, l’offset « fermée » est appliqué avant fermeture. `FB_Bucket` invalide `BucketReferenced` tant que M1/M2 ne sont pas homés ; Step 1 de préparation bucket peut donc être bloqué si le mouvement bucket exige cette référence.  
**Action :** fermer/confirmer la benne avant cible M2 avec offset fermé, ou utiliser l’offset de l’état réel. `CommitClose` en one-shot après états stables. Tester bucket ouvert et échec commit.

9. **Top sensor / cible 8.5 m** `[❌ FAIL]` — Step 4 commande `M1Demand = 8.5 m` avec `TopPositionSensor = FALSE`. Si le capteur est stuck FALSE, overshoot possible. D5 interdit l’écriture 8.5 m sur contact TOP, mais n’interdit pas une cible 8.5 m hors contact. `SoftLimitsBypassed` doit rester scopé M2/Step 1.  
**Action :** si `M1Demand` est une référence encodeur, le nommer ainsi et ne générer aucun ordre moteur. Si c’est un mouvement : marge encodeur, hard top limit indépendante, abort si `TopPositionSensor` devient TRUE. Step 2 doit refuser d’entrer si `TopPositionSensor` est déjà TRUE.

10. **Fault/Abort et seuils non prouvés** `[❌ FAIL]` — `HX7_FAILED` vs `Abort` n’est pas mappé. Le timeout Step 1 20 s coupe M2 mais ne définit pas l’état suivant. Les nouveaux défauts doivent être dans `AnyFaultActive`. Les seuils 20 s / 2 s / 4 s / 5 s / 3 s ne sont pas démontrés contre course/vitesse/current.  
**Action :** table de transition explicite : timeout/défaut → `HX7_FAILED` latché, neutre + relâchement homme-mort + reset ; changement mode/annulation → `Abort` sûr. Inclure tous les défauts dans `AnyFaultActive`. `SimBypassRise` ne doit jamais activer `Bypass.TopLimitSwitch` ni `Bypass.Safety`. `FB_SimBench` ne doit engager `M2_MechanicStopEngaged` qu’après référence.

**Invariants minimaux à tester dans `test_fb_cyclemachinehoming.st` :**
1. Step 0 N1 : pas d’entrée si joystick non neutre/stuck ; décompte 5 s ; `MachineHomed = TRUE` bloque Step 1.
2. Step 0 N2 : `BtnStart` sur front seulement, au neutre ; `JoyBtnRaw` 5 s équivalent.
3. Step 1 : M2 seul, aucun ordre M1 ; `SoftLimitsBypassed` scopé ; `TopPositionSensor` et `Meca D` toujours actifs.
4. Step 1 : timeout 20 s coupe M2 uniquement, exige neutre + relâchement homme-mort, pas de redémarrage automatique.
5. Step 1→2 : pas de transition si M2 bouge ; `WinchSelArbitrated = 0` stable ; aucun deadlock `FB_WinchSync`.
6. Step 2 : montée seulement si `DeadmanArmed AND JoystickPull` ; descente slack coupée à 2 s ; neutre obligatoire entre gestes ; contact TOP coupe immédiatement la montée.
7. Step 3 : montée interdite ; descente pure uniquement ; timer 4 s après release ; hard max si capteur stuck ; retour Step 1 au neutre.
8. Step 4 : aucun ordre de mouvement ; référence encodeur seulement ; séquence bucket fermé → offset M2 → `BothAxesHomed` → `CommitClose` one-shot → `MachineHomed`.
9. M3 : verrouillé N1/SEMI_AUTO, libre N2 Step 0 seulement, re-verrouillé sur sortie/abort/défaut ; pas de `WinchDescentAuth_M3` hors step autorisé.
10. Sécurité/sim : vrai défaut frein lève encore `Meca B/D` ; `AnyFaultActive` complet ; `SimBypassRise` ne touche pas Safety/TopLimitSwitch ; `FB_SimBench` n’engage pas le stop M2 avant référence.

**Décision recommandée :** geler l’écriture `CODE/` jusqu’à arbitrage des points 1–4 et 7–9. Le point 1 doit être tranché en premier : référence encodeur ou mouvement physique en Step 4 — le reste de la séquence en dépend.