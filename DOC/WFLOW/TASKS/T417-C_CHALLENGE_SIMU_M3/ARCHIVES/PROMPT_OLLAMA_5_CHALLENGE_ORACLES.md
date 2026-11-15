# Mission 5 — Challenge Indépendant des Oracles Phase 2 (Red Team)

Tu es un Reviewer / Challenger indépendant (Red Team QA & Automatisme).

## Objectif de ta revue
Challenger le document T417-C_ORACLES_EXPERTS_PHASE2_20261113_v1.0.md rédigé par glm-5.3-flash:cloud avant de coder le banc sandbox.
Traque en particulier :
1. **Injections artificielles déguisées** : le scénario force-t-il le bug au lieu de le laisser apparaître naturellement depuis la physique/logique réelle ? (ex. forcer DI=0 en S1 vs CamDropoutActive naturel).
2. **Angles morts ou faux négatifs** : y a-t-il des mécanismes réels (FB_Translation, FB_Safety_Translation, PRG_06) qui bloqueraient ou modifieraient le scénario ?
3. **Pragmatisme & Valeur** : quels scénarios garder, corriger ou supprimer pour aller droit au but sans perte de temps ?

## Document à challenger
🟢 **PASS** — Livrable Mission 4 : 4 scénarios discriminants + oracles stricts chiffrés + 11 critères anti-faux verts ; couverture H1–H6, Trémie/Maintenance, Manu/SEMI_AUTO, 5 et 10 Hz. Verdict portant sur la complétude et cohérence analytique du livrable — aucune exécution sandbox revendiquée. Durée : 1 pass analytique ; horodatage : N/A (session).

## Niveau 1 — Invariants du livrable (auto-revue)

1. [✅ PASS] 4 scénarios discriminants : S1 = H1(+H4) SEMI_AUTO/Trémie/5 Hz ; S2 = H2+H3+H5 Manu/Trémie/10 Hz ; S3 = H6 Manu(jog)/Maintenance/5 Hz ; S4 = H1+H2+H3+H4 SEMI_AUTO/Trémie/10 Hz (naturel).
2. [✅ PASS] Barre de reproduction non ambiguë fondée sur données Phase 1 vérifiées : arrêt nominal ≤ 0,0326 m (1,5 × 0,0217) vs butée mécanique à 0,500 m → facteur ~23× ; zone grise 0,0326–0,45 m interdite à tout PASS.
3. [✅ PASS] S1 et S3 prouvent le bug sur la physique actuelle (couplage VelocityTrue = VelocityTarget suffit : la ré-énergisation fait avancer le chariot) → aucun prétexte « modèle incomplet » pour un faux vert.
4. [✅ PASS] Oracles mécanisables : signaux imposés, seuils numériques, bornes temporelles en scans, verdicts émis par script.
5. [✅ PASS] 11 critères anti-faux verts à disqualification immédiate.
6. [✅ PASS] Données machine manquantes déclarées (6 items) ; S4 BLOQUÉ-data tant que non fournies, jamais simulées à la place.
7. [⚪ N/A] Exécution sandbox — hors périmètre de la présente mission.
8. [✅ PASS] Périmètre respecté : lecture seule, zéro commit/push, zéro modification de fichiers.

## Niveau 1 bis — Argument analytique (cohérence physique, à confirmer en calibration)

- À partir des deux points Phase 1 : d(F) = r + F²·C avec C = k²/(2a) → C = 1,827·10⁻⁴ ; r ≈ 3,4 mm ; composante pure de freinage : 0,0046 m (5 Hz), 0,0183 m (10 Hz). Cohérence exige r > 0 (sinon d10/d5 devrait valoir 4,0, observé 2,71) — la latence de coupure existe.
- Glissement pur avec frein dégradé 0,6× : ≤ 0,0305 m (10 Hz) + terme de délai k·F·t_délai. Le glissement seul n'atteint 0,50 m qu'au-delà d'≈ 40 Hz (frein dégradé) — résultat indépendant de k car a ∝ k². **Conclusion : à 5–10 Hz, un impact mécanique à 0,50 m est impossible par glissement seul ; il prouve nécessairement une ré-énergisation (H1/H5) ou une absence de garde (H6).** Tout oracle exigeant cette signature causale détecte mécaniquement les bancs tricheurs.

## Niveau 2 — Gabarit banc sandbox : scénarios, stimuli, oracles

### Définitions communes (tous scénarios)

- P_elec = 0,000 m (plan capteur électrique), P_mech = −EndStopMargin_M = −0,500 m — **lus du flux de config à t0 et hashed**. pen(t) = P_elec − PositionTrue_M (positif sens approche). Impact = ObsEndStopHitCount ++ + clamp position à P_mech.
- CI commune : PositionTrue_M = +1,000 m (approche ≥ 1,0 m, ramp-up terminé hors zone came), vitesse 0, frein fermé, permis sains, compteurs à 0, hash config consigné, timeout 30 s.
- Trace obligatoire (scan automate + physique ≤ 1 ms) : PositionTrue_M, VelocityTrue_Mps, VelocityTarget_Mps, M3_PosTremie_DI, M3_TremieHardStopActive, EffectivePermitM3_Tremie, EffectivePermitM3_Maintenance, DriveFreqCmd_Hz, BrakeReleaseRequest, BrakeCloseDelay_S, BrakeDecel_Mps2, ReqTremieSemantic, ObsEndStopHitCount, ObsEndStopImpactSpeed_Mps, ObsCartFree, TonLimitSwitchOverrun, CamDropoutActive.
- v_cross = moyenne |d(PositionTrue)/dt| sur 0,1 s avant premier franchissement de P_elec ; exigé ≥ 0,02 m/s. « ≤ 2 scans » = ≤ 2·T_scan + 5 ms ; T_scan = 10 ms par défaut si non déclaré.
- Ancrage chaîne : FB_Sim_TranslationDrive.st:57-61 (physique), PRG_06_Outputs.st:431-451 (permis Trémie), PRG_06_Outputs.st:441 (Maintenance), FB_Safety_Translation.st:200-204, FB_Translation.st:137-141. Outil : script oracles pytest (gabarits G521/G200) sur trace hachée.

### S1 — Trémie / SEMI_AUTO / 5 Hz (rejoué à 10 Hz) — H1, H4 — sans réécriture physique

- **Stimuli exacts** : ordre d'approche 5 Hz maintenu. Bras A (classe réaliste « capteur collé bas / fil coupé », injection déclarée) : à t_trip + 100 ms, M3_PosTremie_DI forcé 0 jusqu'à impact/timeout. Bras B (classe « rebond/came étroite ») : forçage 0 pendant 0,2 s seulement. Variant C (H1, retombée Req) : ReqTremieSemantic 1→0 avec DI = 1, ordre de palier SEMI_AUTO supposé indépendant (donnée manquante n° 6).
- **Oracle (tous obligatoires pour PASS bras A)** :
  1. t_trip existe : front 0→1 de M3_PosTremie_DI pendant approche à 5 ± 0,1 Hz — sinon échec d'accès, pas de repro.
  2. ≤ 2 scans après chute DI : M3_TremieHardStopActive 1→0 **et** EffectivePermitM3_Tremie 0→1 (preuve absence de latch).
  3. ≤ 5 scans après réouverture : DriveFreqCmd_Hz ≥ 4,9 et VelocityTrue_Mps > 0.
  4. min(PositionTrue_M) ≤ −0,499 m ; ObsEndStopHitCount 0→≥ 1 ; ObsEndStopImpactSpeed_Mps consigné et ≥ max(0,01 ; 0,5 × v_cross) ; position clampée à P_mech (aucun passage à travers).
  5. TonLimitSwitchOverrun (Cause 6) = 0 en fin (bras B : fenêtre 0,2 s < 1,5 s → angle mort prouvé).
  6. Bras B attendu (informationnel) : ré-armement ≤ 2 scans, puis re-coupure si chariot encore dans came à la fin de fenêtre ; consigner pénétration finale et distance restante au bord de came.
- **Risque si ignoré** : vert sans bras A+différentiel = G3 ; sans signature 2–3 = G11. Contingence déclarée : si l'ordre du palier retombe au HardStop → pas de re-puissance → FAIL-repro documenté (renvoie à donnée n° 6).

### S2 — Trémie / Manu (homme-mort) / 10 Hz — H2 + H3 + H5 — gated physique

- **Gate** : physique H3 active (VelocityTrue découplé), BrakeCloseDelay_S machine, frein dégradé 0,6 × nominal — sinon N/A-physique (PASS interdit).
- **Stimuli exacts** : jogging 10 Hz maintenu ; à t0 (DI 0→1) relâcher l'homme-mort (ordre 0, BrakeReleaseRequest 1→0) ; à t0 + 0,40 s **reprendre l'homme-mort quelle que soit la vitesse** ; timeout 30 s.
- **Oracle** :
  1. Précondition glissement (anti-faux vert physique) : entre t0 + ε et reprise, VelocityTrue_Mps > 0,05 pendant ≥ 0,3 s avec DriveFreqCmd_Hz = 0, et ObsCartFree exposé — sinon N/A-physique.
  2. H2 mesuré : délai BrakeReleaseRequest 1→0 → fermeture = BrakeCloseDelay_S ± 10 % ; décélération mesurée par pente de VelocityTrue = BrakeDecel_Mps2 ± 20 % — sinon verdict nul (physique ≠ déclaré, G2/G8).
  3. Reprise : DriveFreqCmd ≥ 9,9 Hz ≤ 5 scans ; HardStop ré-armé si DI = 1 ; si sorties de came (M3_PosTremie_DI 1→0) : EffectivePermitM3_Tremie 0→1 ≤ 2 scans (signature H1) → ré-énergisation → impact.
  4. Barre : ObsEndStopHitCount ≥ 1 ; pen ≥ 0,499 m ; ObsEndStopImpactSpeed_Mps ≥ max(0,01 ; 0,3 × v_reprise).
  5. Si arrêt à l'intérieur de la marge (0,0326 < pen_max < 0,495) : **FAIL-repro**, consigner pen_max, durée de glissement, distance restante au bord de came (entrée de calibrage pour la décision Phase 2).
- **Risque si ignoré** : PASS sans preuve de glissement ni mesure H2 = G11/G2.

### S3 — Maintenance / Manu jog / 5 Hz — H6 — sans réécriture physique, bras différentiel obligatoire

- **Stimuli exacts** : jog 5 Hz maintenu jusqu'à impact ou 30 s, aucune autre action.
- **Oracle** :
  1. Sur toute la fenêtre : EffectivePermitM3_Maintenance = 1 et M3_TremieHardStopActive = 0 malgré M3_PosTremie_DI = 1 puis franchi ; DriveFreqCmd_Hz reste à 5 (preuve asymétrie PRG_06_Outputs.st:441).
  2. Impact : pen ≥ 0,499 m ; ObsEndStopHitCount ≥ 1 ; ObsEndStopImpactSpeed_Mps ≥ 0,9 × v_cross (constante, pas de freinage sur le chemin).
  3. Bras différentiel Trémie (mêmes CI/stimuli) : coupure permis ≤ 2 scans après DI 0→1 ; pen ≤ 0,0326 m ; hit = 0. Si le bras Trémie ne coupe pas → chaîne sandbox ≠ PRG_06 → **test à corriger, jamais un PASS**.
- **Risque si ignoré** : vert sans différentiel = G3 ; gardes masquées = G4.

### S4 — Trémie / SEMI_AUTO / 10 Hz — H1 + H2 + H3 + H4 — naturel, zéro injection, BLOQUÉ-data si paramètres absents

- **Gate** : W_cam (cotes came), k (m/s par Hz), BrakeCloseDelay_S machine disponibles — sinon BLOQUÉ-data (ne pas simuler).
- **Stimuli exacts** : approche 10 Hz jusqu'à impact/30 s. Bras H4 annoté : latence DI montante += 50 ms + 1 scan ; sous-bras optionnel : creux d'ordre de 1 scan pendant dépassement.
- **Oracle** :
  1. Chute **naturelle** M3_PosTremie_DI 1→0 ≤ 5 s après t_trip (bord de came franchi par glissement) — sinon FAIL-repro, consigner pen_max et budget restant W_neg − pen_slide.
  2. Signature H1 : permis 0→1 ≤ 2 scans après chute ; re-power DriveFreqCmd ≥ 9,9 ≤ 5 scans ; ≥ 1 cycle de ré-énergisation avant impact.
  3. Impact : hit ≥ 1 ; pen ≥ 0,499 m ; ObsEndStopImpactSpeed_Mps ≥ max(0,01 ; 0,3 × v_re-power).
  4. Cause 6 : TonLimitSwitchOverrun = 0 malgré LimitSwitch × Commanded pendant un transit de came < 1,5 s (angle mort prouvé). Sous-bras : creux d'ordre 1 scan → timer réinitialisé visible.
  5. Arm H4 : pénétration au moment de la coupure = v × (L + T_scan) mesurée, comparée à la prévision ± 20 %.
- **Risque si ignoré** : exécuter sans gate = géométrie improvisée = G1/G9.

## Critères anti-faux verts (disqualification immédiate)

1. **Géométrie gelée** : EndStopMargin_M lu config à t0 = 0,500 m (assertion), P_mech constant, came calculée exclusivement depuis PositionTrue_M avec cotes machine ; tout override de test, téléportation ou clamp de position = disqualifié.
2. **Quantités physiques uniquement** : oracles sur PositionTrue_M / VelocityTrue_Mps ; toute preuve basée sur *Target / *Cmd = disqualifié.
3. **Bras différentiels obligatoires** (S1, S3) : vert sans bras de référence = nul ; si le bras baseline impacte aussi → escalation (bug plus profond), jamais PASS propre.
4. **Zéro garde ajoutée** : aucun debounce/latch/filtre sur DI/permis hors chaîne PRG_06 (vérif hash/diff) ; une « protection » qui masque la signatureteste un fix, pas le bug = disqualifié.
5. **Télémétrie brute** : inhibiteur Phase 1 (ObsCartFree masqué en coupure normale en butée) interdit dans les fenêtres mesurées ; fenêtre masquée = test non probant, à rejouer.
6. **Barre de contact** : PASS exige ObsEndStopHitCount ≥ 1 **et** pen_max ≥ 0,499 m **et** ObsEndStopImpactSpeed_Mps > 0 ; pénétration < 0,45 m jamais PASS ; ≤ 0,0326 m = comportement nominal (réf Phase 1).
7. **Petite vitesse réelle** : DriveFreqCmd ≤ 10,1 Hz pendant l'approche, distance ≥ 1,0 m, v_cross ≥ 0,02 m/s ; > 10 Hz = scénario disqualifié (phénomène différent).
8. **Oracles scriptés** : verdicts émis par script déterministe (pytest) sur trace intègre (hash, dt constant ≤ 1 ms physique, horodatage scan) ; lecture visuelle/LLM interdite pour un PASS ; trace avec trou ou dt variable = disqualifiée.
9. **Injection déclarée uniquement** : id, signal, fenêtre consignés ; injection non déclarée découverte a posteriori → session entière disqualifiée.
10. **Pas de reset intra-scénario** : compteurs/position/permis jamais réinitialisés ; fin uniquement par impact + stabilisation (|v| < 0,01 à +2 s) ou timeout 30 s.
11. **Physique ancienne** (VelocityTrue ≡ VelocityTarget quand alimenté) : tout scénario exigeant du glissement (S2, S4) = N/A-physique ; PASS à cet état = disqualifié.

## Données machine minimales manquantes (bloquantes S4 ; informatives S1-C, S2)

1. Cotes came M3 autour de 0,0 (W_pos / W_neg). 2. k en m/s par Hz (ou courbe vitesse machine). 3. BrakeCloseDelay_S machine. 4. BrakeDecel_Mps2 nominal. 5. T_scan automate réel. 6. Indépendance ordre de palier SEMI_AUTO vs ReqTremieSemantic + sémantique exacte homme-mort Manu.

## Sémantique de verdict (à imposer au rapporteur)

- **PASS/repro** = impact ≥ 0,50 m + signature causale complète du scénario. **FAIL-repro** = exécuté sans impact, données consignées (utile Phase 2). **N/A-physique** = précondition physique absente (critère 11), refaire banc. **BLOQUÉ-data** = paramètre machine manquant (S4), ne pas simuler à sa place.

Prochaine action coordinateur : créer le banc selon ce gabarit (physique H2/H3 flaggée v2 + script oracles pytest sur trace) ; S1/S3 exécutables immédiatement sur la physique actuelle. Zéro commit de ma part ; aucun fichier modifié.

## Livrable attendu (concis, structuré Niveau 0/1/2)
Verdict (PASS / ADVISORY / BLOCK), liste des failles trouvées dans les oracles, et version durcie des critères à retenir pour le banc sandbox.
