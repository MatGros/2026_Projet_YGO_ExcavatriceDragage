# 🚨 🔴 BLOCK — Audit chaîne M3 butée électrique : coupure électrique fonctionnelle mais surcourse mécanique prouvée + verrou de dernier recours désarmable et non latched

Durée : analyse statique 1 passe + lecture trace 27 (2026-09-04) — Lecture seule respectée.

---

## Niveau 1 — Invariants

1. `[✅ PASS]` **Chemin de coupure FDC Trémie complet et sans bypass possible** : DI brut → HardStop → SEL → sorties, le calcul `M3_TremieHardStopActive` ne reçoit aucun bypass (`PRG_06_Outputs.st:431-432`), y compris en MAINT_N2 (`BypassLimitSwitch` ne touche que Safety/FB — `PRG_05_Translation.st:513,616`).
2. `[✅ PASS]` **Trace 27 : coupure électrique effective à la fenêtre du contact** — 26438 ms : Tremie=1, Cmd 1→0, ContactFrein 1→0, dans une fenêtre ≤ 85 ms après le dernier échantillon rouliant (26353 ms). La chaîne logique réagit au contact.
3. `[❌ FAIL]` **Surcourse physique post-coupure prouvée** — 26553 ms : Tremie=0 (perdu) alors que feedback frein déjà fermé et fréquence sortie 9.13 Hz. Pente mesurée (10.00−9.13)/0.115 s ≈ 7.6 Hz/s ⇒ ~1.3 s avant 0 Hz si pente constante (inférence, 2 points). Aucun DecelFast utilisé sur événement FDC dans le code montré (`CfgRampDecelFastRate` déclaré mais non consommé — `PRG_05_Translation.st:576`).
4. `[❌ FAIL]` **HardStop armé sur la REQUÊTE, pas sur les SORTIES** (`PRG_05_Translation.st:709` → `PRG_06_Outputs.st:431-432`) : désarmé si la requête retombe pendant un roulis (Manu : relâchement homme-mort pendant la rampe de freinage).
5. `[❌ FAIL]` **Aucun verrou au-delà du FDC** : HardStop et permis se ré-ouvrent dès la perte du DI brut (`PRG_06_Outputs.st:431`, `PRG_06_Outputs.st:439-440`) sans condition de recalage ; seule barrière = latch ErrorId=64 (trace 27), sémantique au Reset non prouvée (`PRG_05_Translation.st:584`).
6. `[❌ FAIL]` **Sens Maintenance sans équivalent HardStop ni AND DI brut** (`PRG_06_Outputs.st:441` vs `PRG_06_Outputs.st:439-440`) — protection côté P1/Maintenance uniquement debounced (`PRG_05_Translation.st:504,607`).
7. `[⚪ N/A]` Latence d'ordre des tâches PRG_05→PRG_06 (même scan ou scan-1) — non prouvable avec l'extrait ; +1 scan documenté explicitement sur la couche Safety/frein (`PRG_05_Translation.st:480-483`).
8. `[⚪ N/A]` ErrorId=64 indécodé (enum `FB_Translation` absent du contexte) — information minimale manquante bloquant la conclusion sur l'invariant 5.

## Niveau 1 bis — Argumentaire technique

La trace invalide l'hypothèse « le logique ne coupe pas » : la coupure CW/Freq et la commande frein tombent dans la même fenêtre que le contact (trace 26438). La surcourse est donc **cinématique post-coupure** : le chariot roule encore sous rampe (~7.6 Hz/s mesurée) et le passage du FDC est constaté 115 ms après fermeture du feedback frein (26553). Trois failles structurelles s'ajoutent et sont indépendantes du mode : (a) le HardStop suit la requête et non les sorties — désarmable au moment critique ; (b) aucun verrou directionnel au-delà du capteur — les permis s'ouvrent avec la perte du DI brut et seule la sémantique du latch ErrorId=64 tient la FB ; (c) le sens Maintenance n'a aucun HardStop ni gate DI brut. Le veto SEMI_AUTO (`PRG_05_Translation.st:715-721`) remet aussi `ReqTremieSemantic` à 0 mais sans effet propre puisqu'il force déjà CW/Freq/frein à 0.

## 1. Chemin de coupure butée Trémie (petite vitesse) — Manu vs SEMI_AUTO

Chaîne commune (dès que la requête est armée) :

1. **Acquisition** : `M3_PosTremie_DI` brut (`PRG_06_Outputs.st:431`, qualifié « même scan » — commentaire `PRG_06_Outputs.st:429-430`) ; variante stable débounce pour FB/Safety (`PRG_05_Translation.st:503,606`).
2. **Armement** : `M3_TremieHardStopActive := M3_PosTremie_DI AND ReqTremieSemantic` (`PRG_06_Outputs.st:431-432`) ; `ReqTremieSemantic := M3_ReqTremie_Active` (`PRG_05_Translation.st:709`).
3. **Verrouillage sorties** : SEL CW→0 (`PRG_06_Outputs.st:445-447`), Freq→0.0 (`PRG_06_Outputs.st:448-450`), frein `BrakeReleaseRequest AND NOT HardStop` (`PRG_06_Outputs.st:442-443`), sans anti-chatter (`PRG_06_Outputs.st:454`).
4. **Permis** : `EffectivePermitM3_Tremie AND NOT M3_PosTremie_DI` (`PRG_06_Outputs.st:439-440`) — recul Maintenance conservé (`PRG_06_Outputs.st:428-432`).
5. **Sorties physiques** : `M3_BrakeRelease_RQ`, `M3_CommandWord`, `M3_SetpointFrequencyHz` (`PRG_06_Outputs.st:457-459`).
6. **Redondance amont** : FB_Translation sur FDC stable (`PRG_05_Translation.st:606`) + Safety → agrégat SafeStop (`PRG_05_Translation.st:524-526`, `PRG_06_Outputs.st:418-424`).

Divergences par mode :
- **Manu** : requête = homme-mort arbitrée (`PRG_05_Translation.st:536-538`) ; HardStop armé tant que le joystick est tenu. **Relâchement pendant l'approche → HardStop désarmé** (faille F1).
- **SEMI_AUTO** : veto force CW/Freq/frein/`ReqTremieSemantic` à 0 hors étape autorisée (`PRG_05_Translation.st:715-721`) ; étape autorisée → chemin identique à Manu. La physique d'arrêt (rampe + frein) est **identique dans les deux modes** — la surcourse dépend de la rampe, pas du mode.

## 2. Failles et latences

- **F1 (critique) — Armement requête-dépendant** : `PRG_05_Translation.st:709` + `PRG_06_Outputs.st:431-432`. Roulis sous rampe avec requête retombée → seul FDC-traitement = stable debounced (`PRG_05_Translation.st:606`) et Safety directionnelle (`PRG_05_Translation.st:501-503`) ; le HardStop le plus rapide est précisément désarmé dans ce scénario.
- **F2 (critique) — Pas de latch au-delà du FDC** : HardStop se lève à la perte DI brute (`PRG_06_Outputs.st:431`) ; permis ré-ouverts dès `TremieLimitClear` re-clearé (`PRG_05_Translation.st:554`). Seule barrière : latch ErrorId=64 (trace 27, apparait au contact et persiste). Après Reset IHM, re-marche Trémie possible **au-delà du capteur, zone sans capteur** → choc (recul Maintenance reste permis, c'est correct — `PRG_06_Outputs.st:432`).
- **F3 (majeur, prouvé par trace) — Cinématique post-coupure** : pente ~7.6 Hz/s ; frein fermé au feedback (trace 26438) mais mouvement constaté après (26553) → retard serrage mécanique + rampe dominent la distance d'arrêt. Vitesse d'approche = paramètre site persisté (`PRG_05_Translation.st:578`) → risque de mauvaise config. NB : `ActualFrequencyHz` = fréquence sortie variateur (inférence), pas la vitesse chariot mesurée.
- **F4 (majeur) — Asymétrie Maintenance** : aucun `MaintenanceHardStopActive` dans l'extrait ; permis sans AND DI brut (`PRG_06_Outputs.st:441`) ; sémantique `M3_LimitSwitchMaintenanceEffective` inconnue (`PRG_05_Translation.st:553`).
- **F5 (mineur) — Latences additives** : +1 scan documenté frein/Safety (`PRG_05_Translation.st:480-483`) ; ordre tâches PRG_05/PRG_06 à vérifier (`PRG_06_Outputs.st:408-411`) ; `CaptorDebounce`/`BrakeDelay*` aux défauts FB non câblés IHM (`PRG_05_Translation.st:573`) ; `DelayMotorDecel` cité dans la demande, **absent de l'extrait** — interne FB probable.

**Faits** : trace 27 (26438/26553), code lignes citées. **Inférences** : pente linéaire, perte FDC = franchissement (rebond capteur alternatif non exclu). **Inconnues** : décodage ErrorId=64 ; valeur débounce/BrakeDelay réels ; config site `_TranslationCfgPersist.CfgApproachSpeedTremie_Hz` au jour de la trace ; suite de la trace après 26553 (reprise ? OC ?).

## 3. Points à vérifier dans FB_Translation.st / FB_Safety_Translation.st (max 5)

1. **Latch ErrorId=64** (FB_Translation) : décoder le code ; prouver qu'il tient `RequestedDriveControlWord`/Freq à 0 après perte du DI, que sens Trémie exige recalage (retour zone PV, `PRG_05_Translation.st:594`) et pas un Reset seul, recul Maintenance conservé.
2. **Profile d'arrêt FDC** (FB_Translation) : CW=0 = coast/OFF1 ou Freq→0 sur `CfgRampDecelFastRate` (`PRG_05_Translation.st:576`) ? Existence/effet de `DelayMotorDecel` sur les SlowdownSensor* (`PRG_05_Translation.st:594,600,604`) ; bornage des vitesses d'approche persistées (`PRG_05_Translation.st:578-580`).
3. **Chronologie frein** (FB_Translation) : BrakeDelayClose/BrakeFeedbackTimeout défauts (`PRG_05_Translation.st:573`) ; maintien éventuel de CW≠0 pendant serrage (moteur contre frein — vs trace 26553 Freq=913 frein fermé) ; latence BrakeCmd jusqu'à `PRG_06_Outputs.st:453`.
4. **Lane Safety FDC** (FB_Safety_Translation) : stable (`PRG_05_Translation.st:503-504`) → ErrorLimitSwitch → SafeStop (`PRG_06_Outputs.st:418-424`) ou PowerCutOff ? Conditionnement directionnel (`PRG_05_Translation.st:501-502`), délais internes, comportement sous BypassLimitSwitch MAINT_N2 (`PRG_05_Translation.st:513`).
5. **Synchronisation/qualification** : ordre réel des tâches PRG_02→PRG_05→PRG_06 (même scan ? `PRG_06_Outputs.st:408-411`) ; nature de `M3_PosTremie_DI` en PRG_02 (brut vs filtré) ; valeur effective CaptorDebounce (`PRG_05_Translation.st:573`).

## Niveau 2 — Plan d'action chirurgical (coordonnateur, périmètre à valider)

1. **Reconditionnement HardStop sur sorties** — Localisation `PRG_06_Outputs.st:431-432` ; Ancre `M3_TremieHardStopActive :=` ; Action : conditionner à `(ReqTremieSemantic OR RequestedDriveControlWord <> 0 OR ABS(RequestedDriveFreqHz) > 0.1)` avec sources `PRG_05_Translation.st:707-709` ; Outil : pytest simulation temporelle ; Risque si ignoré : faille F1 (roulis sans verrou).
2. **Verrou directionnel au-delà du FDC** — Localisation `PRG_06_Outputs.st:428-450` ; Ancre avant le SEL ; Action : latch armé sur front `M3_PosTremie_DI` avec CW=1, libéré uniquement sur recalage PV confirmé (`PRG_05_Translation.st:594`) ou recul constaté, consommé par les SEL `445-450`/`442-443` ; Outil : pytest scénario « FDC coupé → DI perdu → Reset → re-demande » ; Risque : choc mécanique en zone morte (chaine incident trace 27).
3. **Rampe rapide + frein à l'événement FDC** — Localisation FB_Translation (réaction FDC), ancre traitement `LimitSwitchTremie` ; Action : appliquer `CfgRampDecelFastRate` (`PRG_05_Translation.st:576`) sur FDC ; Outil : pytest + mesure terrain ; Risque : surcourse F3 persistante.
4. **Équivalent Maintenance** — Localisation `PRG_06_Outputs.st:441` + calcul voisin de `431` ; Action : `MaintenanceHardStop` sur DI brut × sorties (front, pas niveau, pour tolérer le départ), aligné sur `439-440` ; Outil : pytest symétrique ; Risque : surcourse côté P1/Maintenance (F4).
5. **Preuves déterministes avant toute validation** — grep/enum dump ErrorId 0x40 dans FB_Translation.st ; lecture config tâche pour l'ordre PRG ; mesures CaptorDebounce/BrakeDelay réels. Zéro PASS annoncé sur vérification indirecte.

Note (signalée une fois) : `AGENTS.md` et standards applicables non fournis dans ce contexte ; lecture seule et non-modification du registre respectées.