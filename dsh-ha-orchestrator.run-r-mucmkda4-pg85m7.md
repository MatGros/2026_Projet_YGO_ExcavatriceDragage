# orchestrate run r-mucmkda4-pg85m7

- mode: supervisor | agent: session-40bbfeca-c32a-4b04-b686-f3b4592d4797 | provider: spawn
- concurrency: 3 | durationMs: 616019 | aborted: false
- startedAt: 2026-09-22T12:02:56.188Z | finishedAt: 2026-09-22T12:13:12.207Z

## Challenge adversarial des 3 modifications [completed]

[structured] {"verdict":"MAJOR","hash_revision":"Blobs (git hash-object, fichier de travail) :\n- CODE/M_MAIN/PRG_04_Treuils_Benne.st : 33778e9e1dc44b99195b12a214a80e453f287d36\n- CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st : 89ef7397fc544a9d5862607e77f0de69f9c10947\n- CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st : 34687318b33489dde931194c58807e641ab652f2\n- CODE/H_TREUILS_BENNE/FB_Safety_Winch.st (modifié hors lot annoncé) : 9e578388997ec3ef905233d0a813fe15652bb0e8\n- CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st (modifié hors lot) : 7074aadcf18b364090f0f9e5ec78ce3416c71dcf","constats":[{"gravite":"MAJOR","point":"Q1 — Le gating n'est PAS le bon signal de validité : bornes gatées par Homed BRUT, pas HomedAndReliable ni BucketState.BucketReferenced. Un codeur Homed mais NON FIABLE (suspect/incohérent) compte donc comme valide et réactive les bornes relatives sur une position M1 non fiable. Déviation par rapport au brief §2/§3 et à la convention projet.","preuve":"PRG_04:790-791 'AND PRG_02_Acquisition.Data.EncoderM1.Homed AND ...EncoderM2.Homed' (bruts). FB_EncoderReliability.st:34 : HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent => strictement plus étroit que Homed. Les notions requises existent déjà au même endroit (instBucket :381-382 HomedAndReliableM1/M2) et la convention projet utilise HomedAndReliable pour la validité datum : PRG_04:1304-1305 (fail-safe vitesse), :879-880 (override, 'Conditionné à Homed ET NON HomingSuspect'), FB_CycleMachineHoming:231 (BothAxesHomed). Le brief §2:74-79 et §3:92 prescrivent explicitement HomedAndReliable et/ou BucketReferenced. Scénario boot (non homé du tout) : Homed=FALSE => OK, symptôme T388 résolu ; mais état 'homed mais incohérent' non couvert => bornes réactivées sur datum non exploitable.","verdict":"CONFIRME"},{"gravite":"MAJOR","point":"Q2 — Couverture partielle : les bornes de course ProcessPermitM2_Descend/Ascent et les zones de ralentissement sont bien gatées par ManualBucketLimitsActive (donc par Homed) ; MAIS une borne relative résiduelle (butée haute logicielle M2 en jog benne) reste commandée par ManualBucketJogActive SEUL, SANS gate datum ni ManualBucketLimitsActive => borne de benne non neutralisée quand M1/M2 non référencés.","preuve":"Gatés OK : PRG_04:807-810 (ProcessPermitM2_Descend :809), :818-821 (ProcessPermitM2_Ascent :820), :826-837 (M2JogApproachOpen/Close, `AND ManualBucketLimitsActive` ajouté). Résiduel : PRG_04:927-929 'IF ManualBucketJogActive OR AutoBucketCloseActiveForTopLimit THEN TopLimitM2_M := EncoderM1.Measurement.CablePosM + OffsetCloseM + 2.0' — dépend de ManualBucketJogActive, ne consomme NI ManualBucketLimitsActive NI Homed (le commentaire :919 affirme pourtant que ManualBucketLimitsActive est 'le vrai limiteur mecanique'). Nota : les références d'agent 'ProcessPermitM2_Descend (:811)' et 'CommonPermitM2_Ascent (:822)' sont inexactes (noms/lignes réels ProcessPermitM2_Descend :807 / ProcessPermitM2_Ascent :818-820 ; aucun signal 'CommonPermitM2_Ascent').","verdict":"NUANCE"},{"gravite":"MINOR","point":"Q3 — Cause 4 RÉELLEMENT intacte : le terme 'AND NOT (Mode = MAINT_N1/N2)' est absent ; cause non latchante ; elle se lève pour un mouvement benne hors maintenance sans référencement. Nuance : 'AND NOT MachineHomingActive' (:294) la supprime PENDANT le homing, donc le libellé contextuel 'Referencement en cours' ne peut guère se lever sur une cause vive au moment où le homing est actif.","preuve":"FB_Bucket.st:292-298 : HomingMotionWithoutReference := (ReqAscent OR ReqDescend OR CmdOpen_IHM OR CmdClose_IHM OR ProgramBucketDriveActive) AND NOT MachineHomingActive AND NOT (HomedM1 AND HomedM2); instCauses[4].Latching := FALSE (:297). Aucun terme MAINT_N1/MAINT_N2 (hunk identique à HEAD : seule la ligne de commentaire :292 a changé dans le diff, le corps était déjà sans terme). En dehors d'une maintenance + non référencé + hors homing (MachineHomingActive=FALSE), cause4=TRUE. Pendant homing (MachineHomingActive=TRUE) : cause4=FALSE.","verdict":"CONFIRME"},{"gravite":"MINOR","point":"Q4 — Le message contextuel ne fait PAS disparaître les autres causes : cause2 (timeout) et cause3 (glissement) ont chacune leur propre entrée AlarmArray, distincte de bit4. Nuance : en MAINT, le libellé '(normal)' remplace 'ErrorID:05' pour TOUTE cause4 vive en MAINT (jog hors homing, voire défaut bus encodeur), ce qui peut sous-évaluer une condition réellement anormale ; et la branche MachineHomingStep>0 est largement inerte car la cause est supprimée pendant le homing (cf. Q3).","preuve":"FB_Hmi_BannerFormatter.st:1049-1053 (bit 0x4 cause2 timeout, gated EncM1Valid/EncM2Valid), :1055-1056 (0x8 cause3 glissement), :1058-1065 (0x10 cause4 contextuel). Entrées séparées => pas de masquage des causes 2/3. La condition 'CurrentMode=MAINT_N1/N2 OR MachineHomingStep>0' (:1059) s'applique à toute cause4 vive. Nota : contrairement à cause2 (:1052), la cause4 n'est PAS filtrée par EncM1Valid/EncM2Valid => un défaut bus encodeur en MAINT produit le libellé '(normal)'.","verdict":"NUANCE"},{"gravite":"INFO","point":"Q5 — Bridage de vitesse Palier 1 pendant le homing CONSERVÉ : il borne le MOUVEMENT (vitesse), pas la course => conforme à la règle.","preuve":"PRG_04:1311-1314 (neuf dans le diff) 'IF MachineHoming.Active THEN CommonMaxStepAscent :=1; CommonMaxStepDescent :=1;' + fail-safe préexistant :1304-1308 'IF NOT (HomedAndReliableM1 AND HomedAndReliableM2) THEN palier 1' + repli jog benne non référencé :1388-1391. Bornage du mouvement (vitesse), jamais de la course.","verdict":"CONFIRME"},{"gravite":"MAJOR","point":"Q6 — Périmètre NON respecté : les 3 fichiers annoncés ne sont PAS les seuls modifiés. RecoilLimit et la chaîne AU sont intacts, mais FB_Safety_Winch.st et ST_CycleCmd.st sont aussi modifiés dans le working tree (plus CODE_XML/ et TOOLS/TEST_AUTO_CI/). Collision de lots confirmée (brief §6 : 'un seul écrivain par fichier').","preuve":"git status : M CODE/H_TREUILS_BENNE/FB_Safety_Winch.st, M CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st. git diff --numstat CODE/*.st : FB_Bucket 16/1, FB_Safety_Winch 15/2, BannerFormatter 6/1, ST_CycleCmd 1/1, PRG_04 86/16. FB_Safety_Winch diff : ajout BucketCloseAscentGrant (Sécurité fenêtre T387) + modification comportementale UncommandedActiveB := NOT MovementCommanded (ligne ~347) et relaxation AscentPermit par BucketCloseAscentGrant (~581-588). ST_CycleCmd : TglAutoDiveM2Step5Trial FALSE->TRUE (T381). RecoilLimit : aucun hunk dans FB_Bucket (intact, mais reste ClassCanRun-gated par Homed brut, preexistant, cf. CORRECTION_CONSIGNE §2). Chaîne AU (CODE/B_AU_SECURITE/**) : absente de git status => intacte.","verdict":"CONFIRME"}],"indetermines":["Atteignabilité pratique de l'état 'Homed MAIS incohérent/suspect' en jog benne réel (codeur devenu incohérent après homing pendant la manoeuvre) : non rejoué sur machine — c'est le scénario qui décide de l'impact réel de Q1.","Arbitrage exploitant : la règle littérale dit 'HOMED', le brief exige 'valide/fiable (HomedAndReliable/BucketReferenced)'. La divergence entre les deux n'est pas tranchée — le débat Homed vs HomedAndReliable mérite confirmation humaine.","La borne résiduelle TopLimitM2_M (PRG_04:927-929, jog benne sans gate datum) est-elle du ressort de T388 (bornes relatives) ou de T387 fenêtre benne ? Attribution non établie depuis le working tree seul.","Provenance des modifs FB_Safety_Winch.st et ST_CycleCmd.st (elles proviendraient de T387 fenêtre / T381, pas de T388) : impossible à départager depuis le working tree — nécessite relecture des commits/lots concurrents.","La branche contextuelle 'MachineHomingStep>0' (BannerFormatter:1059) se levera-t-elle jamais sur une cause vive, vu la suppression de cause4 pendant MachineHomingActive (FB_Bucket:294) ? Transition Step>0 quand Active retombe non mesurée."]}
J'ai terminé l'analyse adversarial. Je synthétise mes constats sourcés avant restitution structurée.

**Faits clés mesurés :**

1. **Q1 — signal de gating (le plus important)** : `PRG_04:790-791` gate les bornes par `EncoderM1.Homed AND EncoderM2.Homed` **bruts** — PAS `HomedAndReliable` ni `BucketReferenced`. Preuve définitive `FB_EncoderReliability.st:34` : `HomedAndReliable := EncoderAvailable AND Homed AND (NOT EncoderIncoherent)`. Donc un codeur **Homed mais NON fiable (incohérent/absent)** compte comme valide → bornes relatives réactivées sur position M1 non fiable. Le brief §2/§3 commandait `HomedAndReliable` et/ou `BucketReferenced`, et la convention projet elle-même utilise `HomedAndReliable` (vitesse :1304-1305, override :879-880, homing `FB_CycleMachineHoming:231`).

2. **Q2 — couverture des voies** : `ProcessPermitM2_Descend`(:807/:809) et `ProcessPermitM2_Ascent`(:818/:820) + ralentissement `M2JogApproachOpen/Close`(:826-837) sont bien tous gatés par `ManualBucketLimitsActive`. **MAIS** l'exemption butée haute logicielle M2 `PRG_04:927-929` (jog benne) est commandée par `ManualBucketJogActive` (SANS gate datum) → borne relative résiduelle non gatée. Incohérence.

3. **Q3** : cause 4 intacte — le terme `MAINT_N1/N2` est absent (`FB_Bucket:293-295`), non latchante → lève pour un mouvt benne hors maintenance sans référence. **Mais** `AND NOT MachineHomingActive`(:294) la supprime pendant le homing → le message contextuel « pendant le homing » ne peut presque jamais se lever sur une cause vive.

4. **Q4** : aucune perte d'info cause 2/3 (entrées séparées `BannerFormatter:1049-1065`). Nuance " (normal)" applicable à toute cause4 vive en MAINT (y c. jog hors homing / défaut bus).

5. **Q5** : bridage Palier 1 homing conservé (`PRG_04:1311-1314` neuf + fail-safe `:1304-1308`) — borne le **mouvement**. ✅

6. **Q6** : **3 fichiers ≠ seuls** — `FB_Safety_Winch.st` (blob `9e578388`) et `ST_CycleCmd.st` (blob `7074aadc`) modifiés aussi (lots T387 fenêtre / T381). RecoilLimit intact ; chaîne AU non touchée.

## Rejeu CI + preuve par mutation [error]

unsupported JSON schema: schema.properties.constats.items.required names "graveite_placeholder" which is not in properties

## Conformite a la regle + perimetre + message [completed]

[structured] {"constats":[{"exigence":"1. Permis de montée/descente benne (EffectivePermitBucket_Close/Open) conditionné au référencement","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st","ligne":"1180-1189","preuve":"VERIFIE : EffectivePermitBucket_Close/Open = ... AND EncoderM1.Homed AND EncoderM2.Homed (l.1186-1187). M2_RunRequest (FB_Bucket:543,550-566,639-641,666) dépend de ce permit -> manoeuvre benne sans Homed non-servie.","verdict":"CONFORME"},{"exigence":"1. ManualBucketLimitsActive conditionné au référencement","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st","ligne":"787-791","preuve":"VERIFIE : ajout du lot `AND EncoderM1.Homed AND EncoderM2.Homed` (l.790-791). Hors Homed, la bascule bornes jog inactive.","verdict":"CONFORME"},{"exigence":"1. Bornes relatives/anticipations jog (M2JogApproachOpen/Close + ProcessPermitM2)","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st","ligne":"809-821 / 826-837","preuve":"VERIFIE : gatés par ManualBucketLimitsActive (Homed-gated). Seuils OffsetOpenM/OffsetCloseM/anticipations ne s'appliquent que si Homed.","verdict":"CONFORME"},{"exigence":"1. RecoilLimit conditionné au référencement","fichier":"CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st","ligne":"445 / 602-608","preuve":"VERIFIE : gaté par ClassCanRun := HomedM1 AND HomedM2. Code hors diff (intact).","verdict":"CONFORME"},{"exigence":"1. Borne géométrique relative TopLimitM2_M (exemption jog / fermeture AUTO) - exhaustion du dé-bridage","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st","ligne":"925-935","preuve":"DEDUIT : `IF ManualBucketJogActive OR AutoBucketCloseActiveForTopLimit THEN TopLimitM2_M := M1+OffsetCloseM+2.0` sans gate Homed. Fermeture AUTO non atteignable sans Homed (permit Homed-gated, FB_Bucket:550). Jog manuel non référencé : borne géométrique sur M1 sans datum (repli palier 1 l.1388-1401) -> possible « bride sans datum ». Branche jog préexiste au lot mais REGLE« générale ». A arbitrer.","verdict":"INDETERMINE"},{"exigence":"1. Bornes T248BucketJogActive (séquencement benne couplé) - gating référencement","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st","ligne":"800-821","preuve":"DEDUIT : CoupledBucketPhaseLocked AND Arbitrated=2, bornes à CoherenceLimitM, aucun gate Homed explicite. Homed implicite en cycles SEMI_AUTO/AUTO, non garanti par code. Observation.","verdict":"INDETERMINE"},{"exigence":"2. Message (FB_Hmi_BannerFormatter:1058-1065) : condition MAINT_N1/N2 ou MachineHomingStep>0 ; libellé standard hors cadre ; longueur <=70 (G408)","fichier":"CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st","ligne":"1058-1065","preuve":"VERIFIE : condition `MAINT_N1 OR MAINT_N2 OR MachineHomingStep>0` -> « Referencement en cours - codeurs non references (normal) » sinon standard ErrorID:05. Longueur 63<=70. /! Observation : MachineHomingStep=VALID(60)/FAILED -> libellé « ...(normal) » trompeur ; cause 4 déjà supprimée pendant MachineHomingActive (FB_Bucket:294), le terme step>0 est surtout défensif.","verdict":"CONFORME"},{"exigence":"3. Périmètre : 3 fichiers annoncés seuls ? RecoilLimitActive/FB_Safety_Winch/chaîne AU/temporisations intacts ?","fichier":"git status --short / git diff --numstat","ligne":"-","preuve":"DEDUIT : travail mêlé. CODE modifiés : PRG_04, FB_Bucket, FB_Hmi_BannerFormatter (- dé-bridage REGLE) + FB_Safety_Winch.st (grant+MecaB, T387-FENETRE) + ST_CycleCmd.st (T381). RecoilLimitActive : intact. FB_Safety_Winch : MODIFIE (= rattaché T387_FENETRE_BENNE, scope contractuel). Chaîne AU (B_AU_SECURITE) : intacte. Temporisations moteur/frein (PRG_04:1520-1523) : intactes. Si lot = strictement dé-bridage REGLE (3 fichiers) -> ECART périmètre ; si T387 englobe fenêtre benne -> FB_Safety_Winch in-scope, ST_CycleCmd reste hors T387. Frontière exacte INDETERMINE.","verdict":"INDETERMINE"},{"exigence":"4. Cohérence homing : gating par référencement couvre HX1 (FDC benne off) ET HX1a (FDC benne réactivé) ?","fichier":"CODE/M_MAIN/PRG_04_Treuils_Benne.st / CODE/G_CYCLE/FB_CycleMachineHoming.st","ligne":"790-791 / 420-450","preuve":"DEDUIT NON couvert HX1a : gating par Homed (l.790-791) laisse bornes benne OFF pendant toutes étapes pré-référencées (HX1..HX4) car Homed ne tombe TRUE qu'en fin de homing. HX1 (désactivation) : OUI couvert (+ MachineHoming.Active force palier 1, l.1311). HX1a (réactivation FDC) : l.438-441 ne réactive que CmdWinchSelect=0 (couplage), sans gating par référencement -> FDC réactivé en retard (fin de homing). Gap de cohérence homing à arbitrer (lot T387 vs refonte T364).","verdict":"INDETERMINE"}],"hash_revision":"HEAD=01b5e991 / SHA256(diff 3 fichiers)=f92e56536d02e3658e613d597b8e1780d5116b82ab89f269e65a8488a7ad0b43","perimetre":"read-only. Working tree (HEAD 01b5e991). CODE modifiés : PRG_04_Treuils_Benne.st, FB_Bucket.st, FB_Hmi_BannerFormatter.st (3 annoncés dé-bridage REGLE) + FB_Safety_Winch.st (grant fenêtre benne+fix MecaB T387-FENETRE) + ST_CycleCmd.st (T381). Chaîne AU (B_AU_SECURITE) : intacte. RecoilLimitActive : intact. Temporisations moteur/frein (PRG_04:1520-1523) : intactes. CODE_XML/, DOC/WFLOW/CONTRACTS/ (T381/T383/T387), tests CI, index : dirty.","verdict":"ECART"}


## reviewer [via reviewer] [completed]

**RAPPORT EXPLOITANT — T388 dé-bridage benne (PRG_04 / FB_Bucket / BannerFormatter)**

**1. Révision épinglée** (blobs `git hash-object` re-vérifiés ce tour) :
- `PRG_04_Treuils_Benne.st` → `33778e9e…7d36`
- `FB_Bucket.st` → `89ef7397…0947`
- `FB_Hmi_BannerFormatter.st` → `34687318…52f2`
Re-vérification `git status`: les 3 épinglés + **2 fichiers hors lot** (FB_Safety_Winch `9e5783…0e8`, ST_CycleCmd `7074aa…dcf`).

**2. VERDICT : ⛔ A CORRIGER AVANT COMMIT** (2 MAJOR, pas de BLOCK bloquant prouvé).

**3. Constats par gravité**
- **MAJOR Q1 — gating par `Homed` BRUT, pas `HomedAndReliable`/`BucketReferenced`** : `PRG_04:790-791` (bornes jog/permis gatées par `EncoderM1.Homed AND EncoderM2.Homed`), alors que `FB_EncoderReliability.st:34` définit `HomedAndReliable` plus strict. État « homed mais incohérent » ⇒ bornes relatives réactivées sur datum non fiable. Dérogation au brief §2/§3.
- **MAJOR Q6 — périmètre dépassé** : `git status` montre `FB_Safety_Winch.st` (grant `BucketCloseAscentGrant` ~:347,:581-588) et `ST_CycleCmd.st` (`TglAutoDiveM2Step5Trial` TRUE) modifiés (T387/T381) ⇒ collision de lots. Non annoncé.
- **MINOR Q3 — cause 4 hors maintenance intacte** : `FB_Bucket:293-295` n'a **aucun** garde `MAINT_N1/N2`; `Latching:=FALSE` (:297); se lève hors homing (≠`MachineHomingActive`) sans référencement.
- **MINOR Q4 — masquage partiel** : cause 4 séparée des causes 2/3 (`BannerFormatter:1052-1056` vs :1058-1065) → pas de masquage, **mais** non filtrée par `EncM1Valid/EncM2Valid` ⇒ libellé « (normal) » en MAINT même avec défaut bus encodeur.

**4. Réponses explicites**
- (a) **NON** : gates par `HomedM1 AND HomedM2` bruts (`PRG_04:790-791`), pas `HomedAndReliable`/`BucketReferenced`.
- (b) **NON** : le rejeu CI + preuve par mutation a **échoué** (schema JSON de sortie invalide) → aucune preuve de détection de régression produite.
- (c) **OUI** : se lève encore hors maintenance sans référencement (`FB_Bucket:293-295`), sauf pendant `MachineHomingActive`.
- (d) **OUI partiellement** : peut masquer un défaut encodeur (cause4 sans filtre `Valid`) en MAINT; ne masque pas causes 2/3.

**5. Indéterminé à mesurer**
- Atteignabilité réelle de l'état « homed mais incohérent » en jog benne (impact de Q1 non rejoué machine).
- Borne résiduelle `TopLimitM2_M` jog sans gate datum (`PRG_04:927-929`) : T388 ou T387 ?
- Frontière exacte du lot (FB_Safety_Winch in-scope si T387 englobe fenêtre ?) — à arbitrer avant commit.
- Branche `MachineHomingStep>0` (`:1059`) inertie réelle vu suppression cause4 en homing.

*(≤25 lignes ; aucune assertion sans fichier:ligne ci-dessus.)*

## supervisor#1 [completed]

Verification rejouée en lecture (working tree, HEAD `01b5e991`) — blobs et lignes-clés confirmés. Rapport exploitant :

**1. Révision épinglée** (blobs `git hash-object` re-vérifiés ce tour)
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` → `33778e9e…7d36`
- `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` → `89ef7397…0947`
- `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` → `34687318…52f2`
- ⚠️ Hors lot confirmé (`git status`) : `FB_Safety_Winch.st` `9e5783….0e8`, `ST_CycleCmd.st` `7074aa….dcf` + `CODE_XML/`, `TOOLS/TEST_AUTO_CI/`, contrats `T381/T383/T386/T387`.

**2. VERDICT : ⛔ A CORRIGER AVANT COMMIT** (2 MAJOR prouvés, 0 BLOCK).

**3. Constats** 
- 🔴 MAJOR — gating par `Homed` BRUT, pas `HomedAndReliable` : `PRG_04:790-791` (`EncoderM1.Homed AND EncoderM2.Homed`). Or `FB_EncoderReliability.st:34` : `HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent` (strictement plus étroit), exposé en `PRG_02_Acquisition:648/703` et **déjà utilisé** par la seule autre barrière de validité `PRG_04:1304-1305`. État « homed mais incohérent » ⇒ bornes relatives réactivées sur datum non fiable. Dérogation brief §2/§3.
- 🔴 MAJOR — périmètre dépassé : `FB_Safety_Winch.st` (`BucketCloseAscentGrant`, comportemental `UncommandedActiveB`) et `ST_CycleCmd.st` modifiés hors lot (T387/T381) ⇒ collision mono-écrivain violée (AGENTS.md).
- 🟠 MINOR — cause 4 intacte hors maintenance, non latchante : `FB_Bucket:293-295` sans terme `MAINT_N1/N2`, `Latching:=FALSE` (:297), levée dès mvt sans réf tant que `NOT MachineHomingActive`.
- 🟠 MINOR — masquage partiel : `BannerFormatter:1060` libellé « (normal) » pour cause4 en MAINT **non filtré par `EncM1Valid/EncM2Valid`** (contrairement à cause timeout :1052) ⇒ défaut bus encodeur affiché « normal ». Causes 2/3 séparées (:1052-1056), non masquées.
- 🟡 INFO — résiduel jog : `PRG_04:927-929` `TopLimitM2_M := M1+OffsetCloseM+2.0` sous `ManualBucketJogActive` sans gate datum, alors que le commentaire :919 affirme `ManualBucketLimitsActive` « vrai limiteur mécanique » — incohérence d'attribution.

**4. Réponses**
- (a) **NON** : `PRG_04:790-791` gate `HomedM1 AND HomedM2` **bruts**. Ni `HomedAndReliable`, ni `BucketReferenced` (`FB_Bucket` ne les consomme pas ici). Le fail-safe :1304, lui, utilise bien `HomedAndReliable`.
- (b) **NON** : la preuve par mutation a **échoué** (erreur schéma JSON rejeu-CI) → **aucune** preuve de détection de régression produite. À refaire.
- (c) **OUI** : se lève encore hors maintenance (`FB_Bucket:293-295`) pour un mouvement sans référencement, sauf pendant `MachineHomingActive`.
- (d) **OUI partiellement** : en MAINT cause4 n'est pas filtrée par `Valid` (`BannerFormatter:1058-1065`) ⇒ peut présenter une cause réelle (défaut encodeur) comme « normal ». Ne masque pas causes 2/3.

**5. Indéterminé à mesurer**
- État « homed mais incohérent » atteignable en jog benne réel (impact Q1) — non rejoué machine.
- Branche `MachineHomingStep>0` (`:1059`) inertie réelle (cause4 supprimée pendant homing).
- Frontière lot : `FB_Safety_Winch` in-scope si T387 englobe fenêtre benne ? À arbitrer avant commit (+ relecture diff T381/T387).
- Mutations de régression (b) à exécuter réellement et source de couverture.

## supervisor#2 [completed]

# Rapport exploitant — T388 dé-bridage benne (≤25 lignes)

**1. Révision épinglée** (blobs `git hash-object`, ré-vérifiés)
- `PRG_04_Treuils_Benne.st` → `33778e9e…7d36` · `FB_Bucket.st` → `89ef7397…0947` · `FB_Hmi_BannerFormatter.st` → `34687318…52f2`
- Ré-vérif `git status` : les 3 épinglés **+ 2 hors lot** (`FB_Safety_Winch.st` `9e5783…0e8`, `ST_CycleCmd.st` `7074aa…dcf`) + `CODE_XML/`, `TOOLS/TEST_AUTO_CI/`, contrats T381/T383/T386/T387.

**2. VERDICT : ⛔ A CORRIGER AVANT COMMIT** — 2 MAJOR prouvés, 0 BLOCK.

**3. Constats par gravité**
- **MAJOR — gating `Homed` BRUT, pas `HomedAndReliable`/`BucketReferenced`** : `PRG_04:790-791` (`EncoderM1.Homed AND EncoderM2.Homed`) ; or `FB_EncoderReliability.st:34` définit `HomedAndReliable` plus strict, déjà utilisé au fail-safe `PRG_04:1304-1305`. État « homed mais incohérent » ⇒ bornes relatives réactivées sur datum non fiable. Dérogation brief §2/§3.
- **MAJOR — périmètre dépassé** : `git status` = `FB_Safety_Winch.st` (grant `BucketCloseAscentGrant` ~:347,:581-588, modif `UncommandedActiveB`) et `ST_CycleCmd.st` (`TglAutoDiveM2Step5Trial` TRUE) modifiés (T387/T381) ⇒ collision mono-écrivain (AGENTS.md).
- **MINOR — cause 4 intacte hors maint., non latchante** : `FB_Bucket:293-295` sans terme `MAINT_N1/N2`, `Latching:=FALSE` (:297) ; se lève dès mvt sans réf tant que `NOT MachineHomingActive`.
- **MINOR — masquage partiel** : `BannerFormatter:1060` « (normal) » pour cause 4 en MAINT **non filtré par `EncM1Valid/EncM2Valid`** (contrairement timeout :1052) ⇒ défaut bus encodeur affiché « normal ». Causes 2/3 séparées (:1052-1056) : non masquées.
- **INFO — résiduel jog** : `PRG_04:927-929` `TopLimitM2_M := M1+OffsetCloseM+2.0` sous `ManualBucketJogActive` sans gate datum, alors que le commentaire :919 affirme `ManualBucketLimitsActive` « vrai limiteur mécanique ».

**4. Réponses explicites**
- (a) **NON** : `PRG_04:790-791` gate `HomedM1 AND HomedM2` **bruts** ; ni `HomedAndReliable`, ni `BucketReferenced` consommés ici (le fail-safe :1304, lui, utilise `HomedAndReliable`).
- (b) **NON** : la preuve par mutation a **échoué** (rejeu CI : erreur de schéma JSON avant exécution) ⇒ **aucune** preuve de détection de régression produite. À refaire.
- (c) **OUI** : se lève encore hors maintenance (`FB_Bucket:293-295`) pour un mouvement sans référencement, sauf pendant `MachineHomingActive`.
- (d) **OUI partiellement** : en MAINT cause 4 non filtrée par `Valid` (`BannerFormatter:1058-1065`) ⇒ peut présenter une cause réelle (défaut encodeur) comme « normal ». Ne masque pas causes 2/3.

**5. Indéterminé — à mesurer**
- Atteignabilité réelle de « homed mais incohérent » en jog benne (impact de Q1) — non rejoué machine.
- Borne résiduelle `TopLimitM2_M` jog (`:927-929`) : ressort T388 ou T387 ?
- Frontière lot : `FB_Safety_Winch` in-scope si T387 englobe fenêtre benne ? À arbitrer avant commit (+ relecture T381/T387).
- Mutation de régression (b) à exécuter réellement (source de la couverture).

## summary

supervisor 结论：# Rapport exploitant — T388 dé-bridage benne (≤25 lignes)

**1. Révision épinglée** (blobs `git hash-object`, ré-vérifiés)
- `PRG_04_Treuils_Benne.st` → `33778e9e…7d36` · `FB_Bucket.st` → `89ef7397…0947` · `FB_Hmi_BannerFormatter.st` → `34687318…52f2`
- Ré-vérif `git status` : les 3 épinglés **+ 2 hors lot** (`FB_Safety_Winch.st` `9e5783…0e8`, `ST_CycleCmd.st` `7074aa…dcf`) + `CODE_XML/`, `TOOLS/TEST_AUTO_CI/`, contrats T381/T383/T386/T387.

**2. VERDICT : ⛔ A CORRIGER AVANT COMMIT** — 2 MAJOR prouvés, 0 BLOCK.

**3. Constats par gravité**
- **MAJOR — gating `Homed` BRUT, pas `HomedAndReliable`/`BucketReferenced`** : `PRG_04:790-791` (`EncoderM1.Homed AND EncoderM2.Homed`) ; or `FB_EncoderReliability.st:34` définit `HomedAndReliable` plus strict, déjà utilisé au fail-safe `PRG_04:1304-1305`. État « homed mais incohérent » ⇒ bornes relatives réactivées sur datum non fiable. Dérogation brief §2/§3.
- **MAJOR — périmètre dépassé** : `git status` = `FB_Safety_Winch.st` (grant `BucketCloseAscentGrant` ~:347,:581-588, modif `UncommandedActiveB`) et `ST_CycleCmd.st` (`TglAutoDiveM2Step5Trial` TRUE) modifiés (T387/T381) ⇒ collision mono-écrivain (AGENTS.md).
- **MINOR — cause 4 intacte hors maint., non latchante** : `FB_Bucket:293-295` sans terme `MAINT_N1/N2`, `Latching:=FALSE` (:297) ; se lève dès mvt sans réf tant que `NOT MachineHomingActive`.
- **MINOR — masquage partiel** : `BannerFormatter:1060` « (normal) » pour cause 4 en MAINT **non filtré par `EncM1Valid/EncM2Valid`** (contrairement timeout :1052) ⇒ défaut bus encodeur affiché « normal ». Causes 2/3 séparées (:1052-1056) : non masquées.
- **INFO — résiduel jog** : `PRG_04:927-929` `TopLimitM2_M := M1+OffsetCloseM+2.0` sous `ManualBucketJogActive` sans gate datum, alors que le commentaire :919 affirme `ManualBucketLimitsActive` « vrai limiteur mécanique ».

**4. Réponses explicites**
- (a) **NON** : `PRG_04:790-791` gate `HomedM1 AND HomedM2` **bruts** ; ni `HomedAndReliable`, ni `BucketReferenced` consommés ici (le fail-safe :1304, lui, utilise `HomedAndReliable`).
- (b) **NON** : la preuve par mutation a **échoué** (rejeu CI : erreur de schéma JSON avant exécution) ⇒ **aucune** preuve de détection de régression produite. À refaire.
- (c) **OUI** : se lève encore hors maintenance (`FB_Bucket:293-295`) pour un mouvement sans référencement, sauf pendant `MachineHomingActive`.
- (d) **OUI partiellement** : en MAINT cause 4 non filtrée par `Valid` (`BannerFormatter:1058-1065`) ⇒ peut présenter une cause réelle (défaut encodeur) comme « normal ». Ne masque pas causes 2/3.

**5. Indéterminé — à mesurer**
- Atteignabilité réelle de « homed mais incohérent » en jog benne (impact de Q1) — non rejoué machine.
- Borne résiduelle `TopLimitM2_M` jog (`:927-929`) : ressort T388 ou T387 ?
- Frontière lot : `FB_Safety_Winch` in-scope si T387 englobe fenêtre benne ? À arbitrer avant commit (+ relecture T381/T387).
- Mutation de régression (b) à exécuter réellement (source de la couverture).
