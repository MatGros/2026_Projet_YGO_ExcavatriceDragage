# 🧾 Note d'application — T358 · Forçage de step : saut immédiat, sans garde

> **Lot** : T358 (C4) · **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE.yaml`
> **Origine** : `DOC/WFLOW/CONTRACTS/BRIEF_T358_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md` (lecture seule)
> **Fichier principal** : `CODE/G_CYCLE/FB_CycleSemiAuto.st`
> **Doc métier du FB** : `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`
> **Porteur** : DSH21 · **Date** : 2026-09-21 · **Commit** : accord humain explicite distinct du GO ; **aucun push** (voir `git log`).

---

## 1. 🎯 Ce qui change pour l'exploitant

| Avant | Après |
|---|---|
| 2 temps : écrire la cible puis **confirmer par Start au joystick neutre** | **1 geste** : écrire le numéro d'étape → saut appliqué au scan suivant |
| 6 conditions de contexte pouvaient **refuser silencieusement** le forçage | **aucune** condition de contexte — seule la plage `0..22` est validée |
| Refusé en mouvement, sous défaut latché, hors joystick neutre, selon l'immersion/fond | Forçable **même joystick défléchi, même défaut latché, sans homme-mort** |
| AX18 (18) et AX_STAB (19) refusés bien que valeurs d'énum valides | **forçables** |
| Cible **persistée** (`Cfg`) → valeur survivant aux coupures | Cible **non persistée** (`Cmd`) → **aucun saut automatique au démarrage** |

**Ce que le forçage NE fait PAS** (à savoir avant l'essai) : il **ne crée aucun mouvement**. Chaque étape
exige toujours le geste opérateur — par exemple `DeadmanArmed AND JoystickPull` pour la fermeture de benne
(`FB_CycleSemiAuto.st:1306`) et pour les montées (`:1243-1246`, `:1380-1383`, `:1410-1413`, état APRÈS lot).
Sauter sur AX10 « fermer la benne » ne ferme rien tant que l'homme-mort et le joystick ne sont pas actionnés.

---

## 2. 🔒 Gardes retirées — rôle d'origine et usage ailleurs (traçabilité audit sécurité)

> ⚠️ **Convention de numérotation** : les lignes du tableau ci-dessous sont celles de l'état **AVANT le lot**
> (HEAD `d6e54377`) — c'est la référence d'audit. Les numéros **APRÈS lot** sont donnés au §3.

| # | Garde retirée | Ligne (avant) | Rôle d'origine | Utilisée ailleurs à l'origine ? → **état après lot** |
|---|---|---|---|---|
| G1 | `Mode = E_Mode.SEMI_AUTO` | `:625` | Interdire le forçage hors semi-auto | Le FB entier est déjà neutralisé hors semi-auto par `Enable := (instModes.Auth.Mode = E_Mode.SEMI_AUTO)` (`PRG_03_Modes_Cycle.st:191`). **La garde du bloc forçage était redondante, pas protectrice.** → inchangé |
| G2 | `NOT Fault.Latched` | `:625` | Interdire le forçage après un défaut latché | Aussi consommé par : ON_FIRST_START `:573`, `Ready` `:774`, démarrage `:883`, conditions initiales `:899`, `AX1` `:915` → **tous conservés**. ⚠️ **Conséquence assumée** : le forçage permet désormais de **quitter AX_STAB sans que la cause ait disparu** et sans acquittement (l'ancien chemin nominal exige `ResumeAfterFaultAvailable`, `:539-545`). Risque signalé et accepté par l'exploitant. |
| G3 | `NOT JoystickDeflected` | `:626` | Exiger un joystick au neutre | Consommé par 20+ sites (séquenceur, gestes, attentes). **Calcul et usages intacts.** |
| G4 | `DiveStartStopped` | `:626` | Exiger les deux treuils physiquement arrêtés (arrêt mécanique + mesures valides) | Aussi consommé par `:306`, `:308`, `:400`, `:1189`, `:1209` (départs plongée/montée, confirmation fond). **Tous conservés** — le forçage ne contourne donc pas ces départs, il change seulement l'étape courante. |
| G5 | `NOT KoboldImmersionQualified` (cible 7) | `:653-655` | Interdire d'entrer en recherche de fond sans immersion Kobold qualifiée | **Signal toujours VIVANT et calculé** : `:423`, `:1154`, `:1157`, `:1161` (détection de fond AX7, `BottomStopByKobold`). **Aucune modification de son calcul.** |
| G6 | `NOT BottomContextValid` (cibles 8..12) | `:656-658` | Interdire une fermeture benne / montée chargée sans référence fond valide | ❗ **AUCUN autre lecteur** dans tout `CODE/` : 5 occurrences seulement (déclaration `:206`, écritures `:690`/`:858`/`:1168`, et la garde `:656`). **Variable SUPPRIMÉE** (sinon écrite-jamais-lue = dette mort-née, classe de bug G514). |
| G7 | `(CfgForceStepTarget <> 18) AND (<> 19)` | `:628` | Exclure AX18_DONE_SYNC et AX_STAB du forçage | Aucun autre usage. **Retirée** : ce sont des valeurs d'énum valides (`E_AutoCycleStep.st:39`, `:42`). ⚠️ **Conséquence** : injecter `AX_STAB` (état de repli défaut) ou `AX18` (fin de passe : **incrémente les compteurs de prélèvements**) devient possible par forçage. |
| G8 | Mécanisme 2 temps | `:616-623`, `:660-665`, `:792-798` | Préparation (`ForceStepPrepared`) + attente d'une confirmation consciente sur Start joystick neutre | `ForceStepWaiting` servait à distinguer l'attente de forçage de l'attente de reprise de mode (`:195`). **Retirés** : `ForceStepPrepared`, `ForceStepWaiting`, `ForceStepApplyEdge`. |
| — | **CONSERVÉ** : `WaitingResume` | `:743-747` / `:786-819` | Reprise consciente après bascule de mode (anti-redémarrage, AF-04 §4.1) | **Fonction distincte du forçage — préservée à l'identique** (arbitrage humain D4). Un forçage pendant cette attente l'annule pour que le saut ne reste pas gelé. |
| — | **CONSERVÉ** : porte §2 | `:714-772` | `Enable` / `PowerContactorEngaged` / `EncoderFaultPresent` → neutralisation + `RETURN` | **Inchangée.** Le forçage est appliqué **après** cette porte (arbitrage humain D3) : il ne contourne jamais la chaîne AU ni le contrôle codeur. |

---

## 3. 🧠 Mécanique retenue (et écart au brief, assumé et traçable)

**Arbitrages humains du 2026-09-21** : D2 = cible en `Cmd` non persistée · D3 = forçage après la porte §2 ·
D4 = `WaitingResume` conservé · D5 = `BottomContextValid` supprimée, 18/19 forçables, diagnostic conservé.

⚠️ **D1 non arbitré** (mécanique de la « variable unique ») → **option B appliquée par défaut** : la
consigne vit dans `GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt` (écrite par l'IHM seule) et l'étape courante
reste publiée par `GVL_IHM.CycleSemiAuto.State.CycleStep`. L'UX demandée est obtenue (pas de bouton, pas de
confirmation, saut immédiat) mais **pas la lettre du brief** (« une seule variable, lecture ET écriture »).

Pourquoi pas la variante littérale : le harnais de tests CI **ne câble pas** un nouveau `VAR_IN_OUT`
(preuve : `test_main.cpp` généré contenait `s.FB.SAMPLECOUNT = s.SAMPLECOUNT;` mais **aucune** ligne pour la
consigne) → la valeur restait à son défaut `0` = **AX0 forcé à chaque scan**, 25 tests cassés. La variante
retenue est aussi **sans perte d'ordre opérateur** : l'acquittement côté PRG_03 est un
**compare-et-efface** (il n'efface que si le champ porte encore la valeur réellement lue avant l'appel du
FB, `PRG_03_Modes_Cycle.st:294-300`), donc une écriture qui arrive pendant le corps du FB n'est jamais
écrasée — elle est simplement traitée au scan suivant.

| Élément | Rôle |
|---|---|
| `FB.StepForceTgt : INT := -1` | Consigne (entrée). **Défaut = sentinelle** : un câblage absent ou rompu ne peut **jamais** produire un forçage. |
| `FB.StepForceTgtTaken : BOOL` | Impulsion « une consigne était présente ce scan » (appliquée, rejetée ou écartée). |
| `PRG_03` acquittement | `PRG_03_Modes_Cycle.st:294-300` : **compare-et-efface** — la consigne n'est ramenée à la sentinelle `-1` que si le champ porte **encore exactement** la valeur lue avant l'appel (`StepForceTgtCmd`, `:206`) : **anti-boucle** (sinon la même valeur serait rejouée à chaque scan) **et anti-perte** (une écriture d'opérateur arrivée pendant le corps du FB n'est jamais effacée, elle est traitée au scan suivant). Invariant verrouillé par le gate **G517**. |
| Ordre intra-scan | Abandon / acquittement (`:619`, `:632`) puis porte §2 (`:661`) puis **bloc de forçage (`:725-792`)** puis repli défaut `ErrorEdge` (`:838`) — numéros APRÈS lot. Un défaut **LIVE** dont le front tombe sur le même scan garde donc la priorité (repli AX_STAB) ; un défaut **déjà latché** ne bloque plus. |
| Scan du forçage | **Aucune commande** : demandes ramenées à zéro + `StateExecutionInhibit` → l'étape ciblée s'exécute au scan suivant (10 ms), `CycleStep` affiche déjà la cible. |

**Rejouabilité** : la consigne étant acquittée, écrire **deux fois la même valeur** déclenche bien deux fois
le forçage (y compris re-forcer l'étape courante) — c'était impossible avec les variantes « valeur ≠ étape
courante » (boucle) ou « front sur changement de valeur » (valeur intermédiaire obligatoire = saut non voulu).

---

## 4. 📋 Impacts à reprendre côté IHM (action humaine, CODESYS)

| Action | Détail |
|---|---|
| ➕ **Ajouter** | Champ de saisie numérique sur `GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt` (`INT`, sentinelle **-1**, plage 0..22). |
| ➖ **Retirer** | Le bouton lié à `GVL_IHM.CycleSemiAuto.Cmd.BtnForceStepApply` (**champ supprimé**). |
| ➖ **Retirer** | L'affichage lié à `GVL_IHM.CycleSemiAuto.State.ForceStepPrepared` (**champ supprimé**). Le motif de rejet reste disponible : `State.ForceStepRejected` / `State.ForceStepResult`. |
| ⚠️ **Inerte** | `GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget` : **plus aucun lecteur**. Champ conservé *à sa place* pour ne pas décaler le mapping RETAIN positionnel des champs suivants (`ST_CycleCfg.st:19` : « jamais d'insertion au milieu »). **Retirer son contrôle de l'IHM** ; sa suppression physique relève d'un lot de migration de persistance dédié. |
| ⚠️ Indice vacant | `ST_ChainCycleSemiAuto` : `Idx221_ForceStepPrepared` supprimé, **aucune renumérotation** (les autres tags IHM de la chaîne de dépannage restent valides). |

---

## 5. 🧪 Preuves et garde-fous

| Preuve | Résultat |
|---|---|
| CI FB_CycleSemiAuto | **32/37 PASS** — les **5 échecs sont les 5 dettes préexistantes** du rapport committé (`TC-P04-020/021/023/026/SCEN-NOM`, mêmes assertions) : **zéro régression introduite**, +4 tests T358 (001 à 004, tous verts) |
| Bundle PLCopenXML | `CODE_XML/CODE_Bundle.xml` frais — 9 objets |
| Diff bundle | `CODE_XML/CODE_DiffBundle.xml` (FB_CycleSemiAuto, FB_TroubleshootingView, PRG_03, PRG_07, ST_ChainCycleSemiAuto, ST_CycleCfg, ST_CycleCmd, ST_CycleState, ST_SequencePublicState) |
| G200 liaison | **PASS** — 138 OK / 0 KO (2045 instances) |
| Gates palier C | 50/55 PASS — les 5 FAIL (G300/G340/G408/G430/G483) sont **exactement les dettes préexistantes** déjà enregistrées (note T352) ; G408 : les 2 messages trop longs sont `FB_CycleSemiAuto.st:1638` (AX2) et `FB_Hmi_BannerFormatter.st:303`, **antérieurs au lot** |
| **G517** (nouveau) | Verrouille l'enveloppe : **liste BLANCHE des conditions** du bloc forçage (toute garde ajoutée est détectée, même hors des 6 gardes d'origine), placement après la porte §2, plage d'énum seule validation, **table numéro → étape vérifiée membre par membre contre l'énum** (une permutation de cibles est détectée), **neutralisation intégrale** des 4 familles de demandes, acquittement PRG_03 par **compare-et-efface** (boucle ET perte d'ordre exclues), reprise consciente préservée, consigne non persistée. `--selftest` : **19/19 mutations détectées**. |
| **G495** (réaligné) | 6 jetons du mécanisme 2 temps remplacés par les invariants T358 + 4 motifs interdits (retour du 2 temps, retour de la garde fond, retour de l'impulsion bouton) — contrôle **renforcé**, jamais affaibli |
| **Revue indépendante** | Agent à contexte frais, lecture seule : verdict **MINOR** — **10/10 affirmations confirmées** ligne à ligne ; 13 constats dont 3 de fond **corrigés dans le lot** (acquittement attribué au FB dans le contrat, affirmation « aucune course d'écriture » réfutée → compare-et-efface implémenté, gate G517 durci) et les autres documentés ci-dessus |

---

## 6. 🚩 Écarts et constats hors scope (signalés, non corrigés)

| # | Constat | Preuve |
|---|---|---|
| C1 | `CfgCommissioningEnable` (« case mise en service qui déverrouille le forçage ») est **déclaré et câblé mais JAMAIS lu** dans le FB : la case ne fait rien depuis un temps indéterminé. Commentaire rectifié dans le code. | `FB_CycleSemiAuto.st:91` (seule occurrence, hors commentaire) ; `PRG_03_Modes_Cycle.st:259` |
| C2 | Le **BRIEF lui-même** est refusé par G340 (document sans titre H1) — fichier de l'orchestrateur, non modifié par ce lot. | `G340 : BRIEF_T358_...md:1` |
| C3 | **4** noms de tests CI portent encore l'ancienne sémantique **et une séquence d'octets corrompue** (`ForÃ§age`) héritée d'un lot antérieur : `TC-P04-027`, `TC-P04-028`, `TC-P04-030`, `TC-P04-031`. Corps réécrits et **contraires au titre** (ex. `TC-P04-028` s'intitule « AX_STAB refusé » alors qu'il asserte désormais l'acceptation) : **en-têtes non touchés** (édition sûre impossible sur ces octets) — le rapport CI affiche donc des noms faux. Dette d'encodage + de libellé à traiter séparément. | `grep 'Forçage\|ForÃ§age'` → 2 occurrences corrompues, 2 titres ASCII périmés |
| C8 | **Hors lot, préexistant** (identique à HEAD `d6e54377`) : `DivingRetryTrig := FALSE;` est la **seule écriture** de la variable (`:428`, initialisation + `:848` lecture) ⇒ la reprise de plongée `IF DivingRetryTrig AND (State <> AX_STAB)` est **morte**. Le forçage (valeur 20 = `AX_DIVING_RETRY`) devient donc le **seul chemin** vers cette étape : à arbitrer (soit réparer l'écriture, soit assumer). | 3 occurrences dans `FB_CycleSemiAuto.st` |
| C9 | **Préexistant, aggravé** : le test unitaire du gate `TOOLS/AGENT_WORKFLOW/tests/test_g495_cycle_sat_contract.py` fournit un cycle synthétique contenant encore `ForceStepPrepared`/`ForceStepWaiting`, que G495 **interdit** désormais → test rouge **par construction**. Il était déjà rouge avant le lot (le jeton requis `M1_CablePosM >= (CtrlAscentStartM1 + CtrlAscentDistEffM)` manquait déjà du cycle synthétique) et **n'est pas joué par défaut** (G420 en opt-in `--pytest`). Fichier **hors périmètre d'écriture** de ce lot → réalignement à décider. | `G495:99-106` vs test unitaire `:31/:34/:36` ; `run_all_gates.py:235-236` |
| C4 | Les 5 échecs CI et les 5 gates rouges sont **antérieurs au lot** (dettes T278/T299/T347 enregistrées). | rapport JSON committé `HEAD:.../FB_CycleSemiAuto.json` = 28/33 |
| C5 | Le **harnais CI ne câble pas un nouveau `VAR_IN_OUT`** (il câble les entrées) — limite d'outillage découverte pendant le lot, contournée par la mécanique `VAR_INPUT` + acquittement. **Aucun fichier `TOOLS/TEST_AUTO_CI/scripts/` modifié** (hors périmètre du contrat). | `test_main.cpp` généré : copy-in `SAMPLECOUNT` présent, absent pour la consigne |
| C6 | `G100_check_code_style.py:89` exempte un chemin **qui n'existe pas** : l'exemption de frontière simulation porte sur le dossier historique `K_DEPANNAGE` alors que le fichier réel vit désormais dans `CODE/J_SUPERVISION/` : l'exemption ne s'applique donc jamais au bon fichier. | `grep GVL_IHM` sur G100, entrée de chemin `K_DEPANNAGE` |
| C7 | Dette de mapping persistant : `ST_CycleCfg.ForceStepTarget` inerte conservé (cf. §4) — sa suppression impose de re-saisir/valider la config cycle après import. | `ST_CycleCfg.st:19` |

---

## 7. ✅ Recette humaine attendue

1. Import CODESYS du bundle complet (ou du diff bundle pour itérer).
2. IHM : retirer le bouton d'application + l'affichage « step préparé », retirer le contrôle sur `Cfg.ForceStepTarget`, ajouter la saisie sur `Cmd.SetForceStepTgt` (défaut **-1**).
3. Essai machine : cycle en cours, écrire `16` dans le champ → l'étape passe en AX15B au scan suivant **sans** confirmation ni geste ; l'étape courante s'affiche dans `State.CycleStep` et le champ revient à -1.
4. Essai du scénario cité (objet coincé dans la benne) : forcer l'étape de fermeture puis vérifier que **le geste homme-mort + joystick reste indispensable** pour le mouvement.
