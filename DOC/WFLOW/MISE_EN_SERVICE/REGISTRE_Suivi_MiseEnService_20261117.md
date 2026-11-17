# Mise en service — Fiche de suivi du 17/11/2026

> **Tenue par :** TORC-CC10 (orchestrateur) · **Ouverte :** 2026-11-17
> **Usage :** on suit les **étapes dans l'ordre**. Chaque étape est autonome : procédure, bits, mesures, résultat attendu et notes sont au même endroit. Le journal chronologique est à la fin.
> **Règle :** valeur mesurée = valeur brute + source. Une impression = « hypothèse ».

**Étape en cours : ____** (à mettre à jour) · **Début de journée : __h__**

## Sommaire
[0 État de départ](#étape-0--état-de-départ) · [1 Sauvegarde persistantes](#étape-1--sauvegarde-des-persistantes-en-ligne-rien-chargé) · [2 Chargement](#étape-2--chargement) · [3 Après chargement](#étape-3--contrôles-après-chargement) · [4 MAINT_N2 + homing](#étape-4--maint_n2-et-homing-unitaire) · [5 M3 manuel + étalonnage](#étape-5--m3-en-manuel--référence-et-étalonnage-de-lestimateur) · [6 M3 SEMI_AUTO](#étape-6--m3-en-semi_auto--arrêt-au-1er-trou-capteur) · [7 Options cycle](#étape-7--options-du-cycle-semi_auto) · [8 Clôture](#étape-8--clôture) · [Journal](#journal) · [Constats](#constats-ouverts)

## Légende
Un emoji = un sens. Une ligne en porte au plus un. Les titres n'en portent pas.
⚠️ sécurité machine · ⛔ interdit · 📥 à relever avant · 🎛️ bit ou réglage · 🎯 résultat attendu · 🛠️ manipulation CODESYS · ✍️ à consigner · 📎 renvoi

## Contexte (à connaître avant de commencer)
- Programme sur la machine : v0.7.25 ≈ commit `e38cc09a` (MES du 22-23/09). 📎 `REINTEGRATION_POST_MES_20261027_1707.md`
- Code à tester : `main`, bundles du 16/11 : `CODE_XML/CODE_Bundle.xml` (complet), `CODE_XML/CODE_DiffBundle.xml` (rapide).
- ⚠️ **Tout ce qui est testé aujourd'hui n'a jamais tourné sur la machine réelle.** Les tests simu ne valent pas preuve machine.
- 📎 Guide terrain détaillé (arbres de décision) : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md` · note code : `NOTE_MISE_A_JOUR_CODE_20261116.md` (même dossier).
- Hors machine, à ne pas tester : simulation (T417-D, T421), Superviseur/Task Manager (T429).

---

## Étape 0 — État de départ
**Objectif :** noter l'état réel avant tout changement. Rien n'est modifié.

- [ ] ⚠️ Capteur FdC haut M1/M2 `M1M2_TopPositionFree_DI` : état physique : ____ . Shunté depuis le 25/09 → la barrière haute matérielle est absente. ⛔ Aucun homing automatique ancien.
- [ ] 📥 Version du programme actuellement sur l'automate : ____ (export frais ; ⛔ jamais le `Device.export` du dépôt).
- [ ] 🛠️ Trace M3 prête : charger `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/Trace_Site_M3_Par_Echelle.trace` (35 variables, 4 échelles) — utile aux étapes 5 et 6.

**Connu, non corrigé (ne pas prendre pour une régression) :** FdC haut cassé et shunté côté client · T386 rotation de phase mal gérée (C4) · T394 robustesse position P1 après reboot sous l'eau.

---

## Étape 1 — Sauvegarde des persistantes (en ligne, rien chargé)
**Objectif :** relever toutes les valeurs de `GVL_PERSISTENT` avant d'importer quoi que ce soit.
> Libellés de menus d'après CODESYS 3.5 en anglais (le français peut différer). Si un libellé ne correspond pas : le noter, ne pas improviser.

**Pourquoi :** `GVL_PERSISTENT` est `VAR_GLOBAL PERSISTENT RETAIN`. Le code ajoute les nouvelles variables en fin de liste pour que les anciennes survivent au téléchargement, mais ce n'est pas prouvé sur cette machine (les compteurs horaires n'ont pas été chargés la dernière fois à cause des persistantes).

**Règles :**
- Utiliser le **projet CODESYS qui correspond à l'automate** (état du 23/09).
- ⛔ Ne pas importer le bundle ni télécharger avant la fin de cette étape.
- ⚠️ Si le projet ouvert a déjà reçu le bundle du 16/11 : s'arrêter et le noter. Les valeurs lues pourraient être fausses.

**Manip :**
1. 🛠️ Arbre **Devices** : sélectionner **Application** → menu **Online → Login** (`Alt+F8`).
2. Si une boîte propose de télécharger ou de faire un online change : choisir ce qui **ne charge rien** (« No »). ⛔ Jamais « Yes », jamais « Login with online change ». Si seulement Yes / Cancel : **Cancel** et ✍️ le noter.
3. 🎯 La barre d'état indique l'application **en ligne**. Ne pas démarrer ni arrêter l'automate.
4. 🛠️ Double-clic sur **GVL_PERSISTENT** : en ligne, la valeur courante s'affiche à droite de chaque variable. Le **`+`** déplie les structures.
5. Capturer chaque écran (`Win+Maj+S`) dans `DOC/WFLOW/MISE_EN_SERVICE/20261117_PERSISTANTES_AVANT/` (01, 02, 03…). Je peux relire les captures et les transcrire ici.
   Variante : 🛠️ clic droit sur **Application → Add Object → Watch**, saisir les noms, `Ctrl+C`.
6. 🛠️ **Online → Logout** (`Ctrl+F8`).

📥 **À relever, par priorité :**
- **Critique** (une perte impose une remise en service) :
  - `_CalibM1`, `_CalibM2` : calibration codeurs, tout déplier.
  - `_WinchM1CfgPersist`, `_WinchM2CfgPersist` : dont `CfgTopSensorPos_M` (défaut code 8,5 m).
  - Positions M3 : `_TranslationPosTremie_M`, `_PosPV_M`, `_PosP2_M`, `_PosP1_M`, `_PosMaintenance_M` (défauts code 0 / 1,5 / 3,5 / 5,0 / 10,0 m ; **les réelles peuvent différer**).
  - `_TranslationGainMetersPerHzSec` : valeur réelle : ____ (défaut 0,02). ⚠️ Voir étape 5B : le nouveau code peut la remplacer sans avertissement.
  - `_TranslationPosEstimated_M`, `_TranslationPosEstimatedInitialized`, les 5 jetons `_TranslationAt…Persisted`.
  - `_BucketCfgPersist`, `_BucketState` · `_CommunCfgPersist` · `_JoystickNeutralX/Y`, `_JoystickCfgPersist`.
- 🎛️ **Bits de protection** (défaut du code ; relever la valeur réelle) :
  - `_CommunCfgPersist.LimitLegalEnabled` (TRUE) : ____ · `.TglEnableWinchDescentLock_M3` (TRUE) : ____ · `.SelHomingApproachEnable` (FALSE) : ____
  - `_SyncSoftStopEnable` (FALSE) : ____ · `_CycleMachineHomingCfgPersist.ForceStepTarget` (0) : ____
  - ⚠️ **Bypass** (`ST_BypassWinch`, `…Sync`, `…Commun`, `…Translation`, `…Bucket`) : aucun ne doit être actif. Si le projet contient `GVL_BypassRetain`, le relever aussi. État : ____
- **Réglages** : `_CycleCfgPersist`, `_SyncCfgPersist`, `_WinchCriticalSyncTolerance_M`, `_TranslationMaxFreq_Hz`, `_TranslationSetFreq_Hz`, les 3 rampes de translation, `_TranslationMinHeightM1M2_M`, `_WinchSpeedStepTable`, `_EncoderCfgPersist`.
- **État et compteurs** : `_CycleSampleCount`, `_CycleSampleCountTotal`, `_MaintM1HomingRequired`, `_MaintM2HomingRequired`.
- **Optionnel** : `_WinchSpeedLearnTable`, `_WinchSpeedLearnCfg`.
- **Rien à lire** : `_SimEncoderRawPos*` (simulation), `_RunningHours*`, `_TranslationCalibFreq_Hz`, `_TranslationCalibTimeP2PV_S` (nouvelles).

✍️ **À noter :** heure de la sauvegarde, nombre de captures, tout écart (ex. projet déjà mis à jour).

---

## Étape 2 — Chargement
**Objectif :** charger le programme du 16/11.

- [ ] 📥 Si DiffBundle : recompter les objets (12 au 16/11 13:31 ; le correctif simu `a681b221` a pu en changer).
- [ ] 🛠️ Import du bundle (complet ou diff) → **compilation sans erreur**. Point d'attention : T428 `FB_TroubleshootingGuide` est marqué **[NON TESTE IMPORT]** (commits `40d81bf4`, `8ac56593`).
- [ ] 🛠️ Téléchargement sur l'automate.

✍️ **À noter :** erreurs de compilation (texte exact), heure du téléchargement.

---

## Étape 3 — Contrôles après chargement
**Objectif :** vérifier que rien n'a bougé dans les persistantes et que l'IHM répond.

- [ ] 🛠️ **Online → Login**, ouvrir `GVL_PERSISTENT`, **comparer chaque variable critique aux captures de l'étape 1**.
- [ ] ✍️ **Tout écart est noté dans le journal avant de réécrire quoi que ce soit.**
- Pour réécrire une valeur : 🛠️ double-clic sur la colonne « Prepared value », saisir, puis **Debug → Write Values** (`Ctrl+F7`). Les réglages IHM (positions M3, cycle, joystick, limites) sont plus simples à **ressaisir depuis l'IHM**.
- ⛔ Ne pas réécrire à la main `_CalibM1`/`_CalibM2`, `_BucketState`, `_Translation…Persisted` : noter l'écart et en parler avant.
- [ ] Compteurs horaires (T396, UDINT) : l'IHM affiche heures/minutes machine, M1, M2, M3. 🎯 Valeurs conservées après coupure puis redémarrage. (`GVL_IHM.Commun.RunningHours`)
- [ ] Bannière IHM (T424) : message lisible, AX7 décodé.
- 🛠️ **Online → Logout** si plus nécessaire.

✍️ **À noter :** écarts persistantes (variable : avant → après), compteurs horaires lus.

---

## Étape 4 — MAINT_N2 et homing unitaire
**Objectif :** valider le pilotage inconditionnel en MAINT_N2 (T395, C4) et l'anti-démarrage du homing au joystick (T377 partiel).

- ⚠️ MAINT_N2 contourne des interverrouillages. Le capteur haut étant shunté, **pas de barrière haute matérielle** : manœuvre à vue, AU à portée. Conditions restantes : AU fermé (`PowerContactorEngaged_DI`), homme-mort joystick, capteur haut.

**A — Pilotage MAINT_N2 (T395)**
1. 🎛️ Passer en `MAINT_N2`. Noter `WinchSel` avant chaque manœuvre : `1` = M1 seul · `2` = M2 seul · `0` = M1+M2.
2. Pour chaque sélection : montée + descente, au joystick et aux boutons IHM.
3. 🎯 Fermeture franche des contacteurs et freins ; `WinchSel=0` ne bascule pas seul à 2 ; les deux treuils partent ensemble en `0`.

**B — Homing unitaire et anti-démarrage (T377 partiel)**
1. Toucher manche et homme-mort en MAINT_N2 : 🎯 **rien ne démarre** (le cycle homing ne se lance plus au joystick).
2. Homing unitaire `BtnHome` / `BtnHomingAtZero` : 🎯 fonctionne.
3. Démarrage du cycle par bouton IHM, manche au neutre : 🎯 fonctionne.
4. Le geste « 3 appuis homme-mort » n'existe plus : à répéter aux opérateurs.
- ⛔ T377 complet : pas de GO aujourd'hui. Ordre imposé : 1er test en homing **unitaire**.

**Connu, non corrigé :** `ReHomingAckRequired` : si `MachineHomed` a déjà été TRUE puis perdu, un Reset IHM à l'arrêt mécanique est nécessaire avant SEMI_AUTO.

✍️ **À noter :** `WinchSel` testés, résultats par treuil, comportement du joystick en MAINT_N2, tout défaut.
📎 Guide terrain §3 étape 1 · `DOC/WFLOW/TASKS/T377_HOMING_MANUEL_SANS_CONTACT_TOP/T377_RAPPORT_TRANSMISSION_20261116_v1.0.md`
Preuves livrées (jamais une preuve machine) : `5ecfa1d6` (T395), `f28a84ab` (T377).

---

## Étape 5 — M3 en manuel : référence et étalonnage de l'estimateur
**Objectif :** (A) mesurer l'arrêt M3 en MANU, qui sert de référence ; (B) étalonner l'estimateur de position avec les mêmes passages.

**A — Référence d'arrêt en MANU**
1. Arrêts Trémie et P1 en MANU.
2. 🎯 Arrêt à ~10 cm après le capteur, frein qui tient.
- Mesures : distance d'arrêt Trémie : ____ m · P1 : ____ m
- ✍️ État frein M3 affiché à l'IHM pendant l'arrêt : ____ (souvenir exploitant incertain).

**B — Étalonnage de l'estimateur de position (T301)**
Principe : vous saisissez **un temps et une fréquence**, le programme calcule `gain = (Pos_P2 − Pos_PV) / (fréquence × temps)`. Pas de saisie IHM (voulu, contrat T301 v2) : **tout se fait dans CODESYS**. Le programme mesure et propose, il n'applique jamais. Risque faible : l'estimation ne pilote aucun arrêt. Nouveau : absent du programme machine.

1. 📥 Mesurer au mètre la **distance réelle P2 ↔ PV** : ____ m. La comparer à `_TranslationPosP2_M − _TranslationPosPV_M` (défaut 3,5 − 1,5 = 2,0 m, **estimation**). Si elle diffère : corriger les 2 positions, ✍️ noter avant → après.
2. Passer P2 → PV puis PV → P2, **sans arrêt, sans toucher à la consigne**, 3 passages par sens (les passages de A peuvent servir).
3. 🛠️ À chaque passage, lire sous `PRG_05_Translation.Data.TranslationState` : `OdometryMeasuredTime_S` · `OdometryMeasuredFreqAvg_Hz` · `OdometryMeasuredFreqSpread_Hz` · `OdometryMeasureCount`.
   🎯 `…FreqSpread_Hz` petit = mesure fiable ; grand = refaire. La mesure est abandonnée si M3 passe sous 1 Hz ou dépasse 60 s.

| Passage | Sens | Temps (s) | Fréq. moy. (Hz) | Écart (Hz) |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |

4. 🎛️ Saisie (🛠️ Watch → « Prepared value » → Debug → Write Values) :
   - `GVL_PERSISTENT._TranslationCalibFreq_Hz` ← fréquence moyenne : ____
   - `GVL_PERSISTENT._TranslationCalibTimeP2PV_S` ← temps moyen des passages cohérents : ____
5. 🎯 `OdometryCalibValid` = TRUE et `OdometryGainActive` ≈ `OdometryMeasuredGain`. Gain hors de [0,005 ; 0,05] : refusé, le gain de repli reprend la main → vérifier la distance (point 1).
6. ⚠️ **Piège :** tant que `_TranslationCalibTimeP2PV_S` garde son défaut 2,0 s, le nouveau code recalcule le gain à **0,02** et **ignore** `_TranslationGainMetersPerHzSec`. Si le gain de la machine relevé à l'étape 1 est différent de 0,02, il est remplacé sans avertissement.
- ⛔ Ne pas suivre `T301_PROCEDURE_CALIBRATION_ODOMETRIE_M3.md` (dossier `T_TEMP (A TRIER)/CONTRACTS/`) : périmée (gain 0,008333, capteurs à 5/15/20/30 m, modification du code source).

✍️ **À noter :** distance mesurée, le tableau ci-dessus, valeurs saisies, gain actif.

---

## Étape 6 — M3 en SEMI_AUTO : arrêt au 1er trou capteur
**Objectif :** vérifier que M3 s'arrête en SEMI_AUTO comme en MANU (T417-E).

**Quoi :** rampe rapide et fermeture du frein dès le 1er trou (Trémie ou P1). Latch `M3_TremieHardStopLatched` en `RETAIN` (survit à une coupure).

1. 🛠️ Trace chargée (étape 0), fréquence **20 Hz**.
2. Cycle SEMI_AUTO : AX14 (Trémie) puis AX2 (P1).
3. 🎯 Au 1er front capteur, `BrakeReleaseRequest` et `DriveControlWord` tombent à 0.
   Avant correction, en **simulation** : −0,40 m à la Trémie, +5,38 m à P1.
- Mesures : distance d'arrêt Trémie SEMI_AUTO : ____ m · P1 : ____ m (à comparer à l'étape 5A).

**Aussi à tester :**
- Latch après coupure puis remise sous tension.
- Recul volontaire vers P1 ou Maintenance : le latch se lève.
- Reset IHM.

**À observer pendant le vidage (récit exploitant du 30/10, hypothèses) :**
- ✍️ Le chariot dérive très lentement vers la butée pendant l'ouverture benne : relever l'état frein M3 (IHM et `M3_BrakeIsOpen_DI`), la position à t0 et à t+30 s : ____ , ____ . Pente de rail éventuelle : ____
- ✍️ Défauts brake M3 à AX14 → AX15, plus fréquents à 10 Hz qu'à 20 Hz (souvenir à confirmer).
- Hypothèse non tranchée : relâchement du frein + pente. Ce lot ne la traite pas forcément.

**Connu, non corrigé :** T334 (arrêt M3 au-delà de P1/Trémie) : T417-E le vise, **non prouvé** tant que non testé machine.

✍️ **À noter :** distances d'arrêt, état du latch, relevés de dérive.
📎 `T417-C_SYNTHESE_ETUDE_M3_20261115_v1.0.md` · `DOC/WFLOW/MISE_EN_SERVICE/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md` (récit non instrumenté). Preuves livrées : `fd1bb138`, `0f9dec83`, `8fc65110`, `aa20ed28` (simulation uniquement).

---

## Étape 7 — Options du cycle SEMI_AUTO
**Objectif :** valider les 3 réglages IHM (T417-F). Défaut = comportement historique.
Emplacement : `GVL_IHM.CycleSemiAuto.Cmd.*`. **Non persistés : ils retombent à leur défaut à chaque redémarrage.**

**A — Pause avant ouverture benne**
- 🎛️ `SetPauseBeforeDump_S` · défaut 0.0 s (plage 0 à 30) · initial : ____
- Test à 0.0 puis 0.5 · essayé : ____
- 🎯 À 0.0 : `AX14 → AX15A → AX15B` immédiat. À 0.5 : maintien de 0,5 s en `AX15A` avant l'ouverture.

**B — Ouverture benne dès la zone PV**
- 🎛️ `TglAllowDumpInPV` · défaut FALSE · initial : ____ · essayé : ____
- Test en AX14, pousser le manche (`JoystickPush`) dès `M3_PosPV_DI`.
- 🎯 Dès `Benne_IsOpen`, passage en `AX18_DONE_SYNC`, puis retour vers P1 sans toucher `M3_PosTremie_DI`.
- ✍️ **Nuance codée :** X gauche et Y poussé **en même temps** → M2 n'ouvre pas tant que X n'est pas relâché (`FB_WinchCmdArbitrationM2.st:69`). À décider sur site.

**C — Départ souple**
- 🎛️ `TglRelaxSemiAutoStart` · défaut FALSE · initial : ____ · essayé : ____
- À FALSE : le diagnostic AX1 donne 3 messages exacts (M3 en Maintenance / M1-M2 hors zone haute / état benne non qualifié).
- À TRUE : départ dès que les treuils sont dans la fenêtre haute élargie (0,4 → 2,0 m), sans qualification stricte de la benne. Le blocage « M3 en zone Maintenance » reste actif.

**Connu, non corrigé :** AX15D non réintégré : en AX15B, **tirer le manche ne fait rien**. Le texte opérateur « Tirer : fermer et remonter » est faux (déjà sur machine).

✍️ **À noter :** chaque changement de bit (avant → après), résultats A, B, C, messages AX1 relevés.
📎 `NOTE_MISE_A_JOUR_CODE_20261116.md` §1-3. Preuves livrées : `9081b291`, `b567cf5d`, `aa20ed28`.

---

## Étape 8 — Clôture
- [ ] 📥 Export frais du projet (l'état réellement testé) : fichier ____
- [ ] 📥 Sauvegarde des persistantes finales (même procédure que l'étape 1, capturée dans `20261117_PERSISTANTES_APRES/`)
- [ ] 🎛️ Remettre les options du cycle (étape 7) à leur défaut, ou noter l'état laissé : ____
- [ ] ✍️ Liste des constats ouverts (tableau en fin de fiche)
- [ ] ✍️ Décision : programme laissé sur l'automate = lequel (version, bundle) : ____

---

## Journal
Format : `HH:MM · étape · fait / mesure / constat · source`. Étiquettes : **[FAIT]** · **[MESURE]** valeur brute · **[CONSTAT]** écart ou défaut · **[HYPOTHÈSE]** · **[BIT]** changement d'un bit ou réglage (avant → après) · **[DÉCISION]**.

- `2026-11-17 (heure à compléter)` · préparation · **[FAIT]** fiche créée par TORC-CC10 à partir du guide terrain M3 v3.0, de la note de mise à jour code (16/11), du registre de réintégration (27/10), du témoignage M3 (30/10), du rapport T377 (16/11) et de l'historique git depuis le 27/10.
- `…`

## Constats ouverts

| # | Heure | Étape | Constat / décision | Suite (qui, quoi) |
|---|---|---|---|---|
| | | | | |
