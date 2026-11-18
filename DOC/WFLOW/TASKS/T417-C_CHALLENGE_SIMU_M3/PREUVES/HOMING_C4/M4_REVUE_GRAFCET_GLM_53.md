🟡 **ADVISORY — Refonte D1–D7 conforme sur le fond (GRAFCET, temporisations, anti-blocage : OK). 2 défauts MAJEURS à corriger avant essai réel : (1) détection couplage E1 morte malgré commentaire affirmant le contraire, (2) CfgTopApproachMaxM déclaré/documenté mais jamais lu.**
Durée : audit statique diff — n/a terrain. Horodatage : session en cours.

## 1. Invariants

1. D1 HX0/N1 — BP relâché vu (`RawBtnSeenReleased`) puis maintien 5 s au neutre (`EntryHoldTimer` IN : BP+neutre+arrêt treuils+BootReady+pas Fault/Failed) `[✅ PASS]`
2. D1 HX0/N2 — BtnStart (front `StartEdge`, neutre+arrêt) `[✅ PASS]` — écart : N2 accepte aussi `EntryHoldTimer.Q` (voir F4) `[❌ FAIL]`
3. D2 verrou absolu si homé — garde `NOT MachineHomedRaw` (inclus commit/offset/Fault/Failed) `[✅ PASS]`
4. D2 M3Locked — `CycleRunning OR (NOT MachineHomed AND NOT ModeIsMaint2)` : verrouillé HX0 en N1/SEMI, échappatoire N2 `[✅ PASS]`
5. D3 HX1 — WinchSel=2, SoftLimitsOff, garde TON continue 20 s, cutoff latched re-armé neutre+BP relâché `[✅ PASS]`
6. D4 HX2 — settle couplage 300 ms, dé-tension max 2 s/geste re-armée au neutre, `AllowAscent := ... AND NOT TopPositionSensor`, transition HX3 **sans** HomeReq (aucun preset) `[✅ PASS]`
7. D5 HX3 — `AllowAscent := FALSE` strict, accumulateur 4 s vérifié scan par scan (interruption = `Accum += ET`, reprise = `Restant = PT − Accum`, double appel TON reset+start déterministe, pas d'underflow `Restant−Seg`, done latched), retour HX1 neutre+arrêt+capteur dégagé `[✅ PASS]`
8. D6 HX4 — zéro mouvement (Allow FALSE, SoftLimitsOff FALSE), TOP → repli HX3 avec purge état, preset pulse 1 scan `UseDynamicTarget` M1=`CfgTopHomingTarget_M`, M2=`CfgTopHomingTarget_M + CfgOffsetClose_M` `[✅ PASS]`
9. D7 — commit conditionné `BothAxesHomed AND HomingDone M1/M2 AND NOT HomingBusy AND NOT TopPositionSensor` → pulse `CommitClose` → HX0 ; garde 60 s (`CfgTimeoutHomeAxes`) → HX7 `[✅ PASS]`
10. Anti-blocage silencieux — gardes 300 s (HX2, comptée traction continue) / 60 s (HX4), Reset purge HX7, étapes opérateur guidées, impulsions RAZ tête de scan `[✅ PASS]`
11. Initialisation — defaults IEC (BOOL/TIME/INT), init first-scan, purges Reset/Enable/forcage complètes sur les états actifs `[✅ PASS]`
12. Bugs scan IEC — fronts uniques en §1 avant CASE, cohérence same-scan des pulses (HomeReq+UseDynamicTarget+target), pas de PT nul inattendu, pas de comparaison TIME invalide `[✅ PASS]`
13. Conformité CODESYS 3.5 — chaînes 100 % ASCII sans accents, `LIMIT(0,x,5)` ok, `DINT#999`/`INT_TO_STRING`/`CONCAT` valides, énum [0..5] cohérente avec forcage `[✅ PASS]`
14. Interlock couplage E1 `[❌ FAIL — F1]`
15. Plafond encodeur secours HX2 `[❌ FAIL — F2]`
16. Code mort résiduel `[❌ FAIL — F3]`

## 1 bis. Argumentaire (4 lignes)

Le squelette GRAFCET 5 étapes est sain : transitions toutes opérateur-guidées avec gardes temporelles, pas de deadlock trouvé, accumulateur HX3 correct (cas interruption/reprise testés mentalement scan par scan). Les deux majeurs ne touchent pas la logique séquentielle mais deux protections déclarées et absentes : interlock E1 (`CouplingInterlockFault` forcé FALSE) et plafond encodeur HX2 (`CfgTopApproachMaxM` non référencé). Hors diff : le contrat de câblage PRG_03/PRG_04 (consommation `Allow*`/`SoftLimitsOff`, `CmdWinchM1/M2` désormais jamais pilotés) est une hypothèse de conception non prouvable dans ce périmètre.

## 2. Défauts réels

**F1 — MAJEUR** — `CODE/G_CYCLE/FB_CycleMachineHoming.st`, région §2, ligne ≈258 : `CouplingInterlockFault := FALSE;` (conditionnel annulé). Le commentaire immédiatement au-dessus déclare la détection « si WinchSel arbitre diverge alors qu'un mouvement est commandé » — elle n'existe pas. `instCauses[CST_CauseCouplingFault]` (≈372) est donc mort. Scénario : HX2, opérateur tire, l'arbite diverge à 2 → `CouplingSettleTimer` reset → `AllowAscent` FALSE → mouvement coupé (fail-safe OK) mais **aucun défaut latched** ; l'opérateur relâche puis re-tire, le cycle reste en HX2 jusqu'à épuisement de `ClimbTimer` (300 s) avec texte trompeur « capteur haut non atteint dans la garde » au lieu de la cause couplage. Interlock de sécurité E1 non tracé (exigée en ISO 13849).

**F2 — MAJEUR** — `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st`, ligne ≈28 : `CfgTopApproachMaxM : REAL := 10.5;` « Plafond encodeur secours HX2 si capteur TOP bloque FALSE » — **zéro référence** dans le FB (recherche). Scénario : capteur TOP collé FALSE pendant HX2 → `SoftLimitsOff := TRUE` (l. HX2 + §9), aucune coupure encodeur, la garde 300 s est comptée en traction continue alors que la course palier 1 (58,5 m à 0,4 m/s) s'achève en ≈146 s → butée mécanique atteinte **avant** le timeout. Le paramètre documente une protection qui n'est pas implémentée.

**F3 — MINEUR (code mort / intention résiduelle)** — même fichier :
- `Step3Restart` : écrit (HX0 init, §4, HX2, HX3), jamais lu ;
- `Step4WaitConfirmDelay` : jamais référencé ;
- `TopRiseEdge` : instancié + appelé §1, `.Q` jamais lu ;
- `PendingClose` : écrit jamais lu depuis que HX4 code `BucketCommit.CommitClose := TRUE` inconditionnel ;
- `HomingModeBActive` : jamais mis TRUE (sortie morte) ;
- `CST_StepSlow` inutilisé ; `CmdWinchM1/M2` plus jamais pilotés (RunRequest/StepTgt figés FALSE) — architecture 100 % permis ;
- entrées `CablePosM1/M2`, `CoherenceLimitM` non lues (commentaire « compat »).
Aucun effet runtime ; risque de confusion mainteneur et doc/IHM à aligner.

**F4 — ADVISORY** — D1 N2 : l'entrée est aussi possible en N2 par maintien BP 5 s (`EntryHoldTimer.Q` dans la condition ModeIsMaint2), au-delà du « N2 = BtnStart » spécifié. À arbitrer (produit/doc) ou restreindre l'IN du timer au seul N1.

**F5 — ADVISORY** — Forçage mise en service → step 4 (§4, ≈335) : n'efface pas `PendingClose` et le commit HX4 publie `CommitClose := TRUE` sans que la benne ait été fermée/validée en HX1. Encadré par `CfgCommissioningEnable`+N2, mais divergence d'état benne possible en commissioning.

**F6 — ADVISORY** — Message HX0 N1 durcode « 5s » (§10) alors que `CfgEntryHoldTime` est configurable — dérive IHM si config ≠ 5 s.

**F7 — ADVISORY (hors diff, à vérifier)** — Suppression des champs `CfgStabilizationMinM/MaxM`, `CfgTimeoutFlyingHoming` : vérifier zéro référence externe (GVL persistante, IHM, autres FB) sinon erreur compile ; `CfgTopHomingTarget_M`/`CfgOffsetClose_M` supposés préexistants (hors hunk visible).

## 2 bis. Plan d'action chirurgical

1. **Localisation** : FB_CycleMachineHoming.st §2 — **Ancre** : `CouplingInterlockFault := FALSE;` — **Action** : implémenter la détection promise (HX2 ou HX3) ET settle écoulé ET `JoystickWinchSelectArbitrated <> 0` (latched jusqu'au Reset) — **Risque si ignoré** : divergence E1 sans défaut, diagnostic 300 s trompeur.
2. **Localisation** : §8 HX2 — **Ancre** : `AllowAscent  := CouplingSettleTimer.Q AND NOT TopPositionSensor;` — **Action** : ajouter coupe encodeur `(CablePosM1 < Cfg.CfgTopApproachMaxM) AND (CablePosM2 < Cfg.CfgTopApproachMaxM)` + cause latched dédiée — **Risque si ignoré** : surcourse jusqu'à butée méca si TOP collé FALSE.
3. **Localisation** : VAR + §8 — **Ancre** : `Step3Restart` / `Step4WaitConfirmDelay` / `TopRiseEdge` / `PendingClose` — **Action** : purger ou implémenter l'intention — **Risque si ignoré** : maintenance trompée.
4. **Localisation** : §10 N1 — **Ancre** : `'HX0 - Maintenir BP joy 5s neutre (ou passer N2)'` — **Action** : injecter `CfgEntryHoldTime` converti — **Risque si ignoré** : message mensonger si config modifiée.
5. Vérifier hors diff (grep) : référence des champs Cfg supprimés, existence de `CfgTopHomingTarget_M`/`CfgOffsetClose_M`, consommation réelle de `AllowAscent/AllowDescend/SoftLimitsOff` par PRG_03/PRG_04 — sinon mouvements nuls (détectés par gardes, non silencieux, mais cycle inutilisable).

Verdict recommandé : corriger F1/F2 avant tout essai réel ; le reste est non bloquant pour la logique séquentielle.