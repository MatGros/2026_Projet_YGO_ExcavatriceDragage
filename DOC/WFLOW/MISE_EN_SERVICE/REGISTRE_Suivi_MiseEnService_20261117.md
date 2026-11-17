²# Mise en service — Fiche de suivi du 17/11/2026

> **Tenue par :** TORC-CC10 (orchestrateur) · **Ouverte :** 2026-11-17
> **Usage :** on suit les **étapes dans l'ordre**. Chaque étape est autonome : procédure, bits, mesures, résultat attendu et notes sont au même endroit. Le journal chronologique est à la fin.
> **Règle :** valeur mesurée = valeur brute + source. Une impression = « hypothèse ».
> **Documents liés :** revue de l'agent = `REVUE_TORC-CC10_MES_20261117.md` (autocritique, à lire après la journée) · relevés des persistantes = `20261117_PERSISTANTES/` · conventions du dossier = `README.md`.

**Étape en cours : ____** (à mettre à jour) · **Début de journée : __h__**

## Sommaire
[0 État de départ](#étape-0--état-de-départ) · [1 Sauvegarde persistantes](#étape-1--sauvegarde-des-persistantes-en-ligne-rien-chargé) · [2 Chargement](#étape-2--chargement) · [3 Après chargement](#étape-3--contrôles-après-chargement) · [4 MAINT_N2 + homing](#étape-4--maint_n2-et-homing-unitaire) · [5 M3 manuel + étalonnage](#étape-5--m3-en-manuel--référence-et-étalonnage-de-lestimateur) · [6 M3 SEMI_AUTO](#étape-6--m3-en-semi_auto--arrêt-au-1er-trou-capteur) · [7 Options cycle](#étape-7--options-du-cycle-semi_auto) · [8 Clôture](#étape-8--clôture) · [Journal](#journal) · [Constats](#constats-ouverts)

## Légende
Un emoji = un sens. Une ligne en porte au plus un. Les titres n'en portent pas.
⚠️ sécurité machine · ⛔ interdit · 📥 à relever avant · 🎛️ bit ou réglage · 🎯 résultat attendu · 🛠️ manipulation CODESYS · ✍️ à consigner · 📎 renvoi

## Contexte (à connaître avant de commencer)
- Programme sur la machine : ⚠️ **`v0.7.24_CptHorraire_20260922`, téléchargé le mercredi 23/09/2026 à 16:23** (relevé CODESYS « Details » le 17/11, CODESYS V3.5 SP19 Patch 1). Le projet `v0.7.25_…DernièreMES` n'a **jamais été téléchargé** (« Download time : none »). L'ancienne hypothèse « machine = `e38cc09a` » (registre de réintégration) n'est donc **plus à retenir** : `e38cc09a` est daté 23/09 16:37, **après** le téléchargement, et le lien v0.7.24 ↔ commit n'est pas établi. 📎 `REINTEGRATION_POST_MES_20261027_1707.md`
- Code à tester : `main`, bundles du 16/11 : `CODE_XML/CODE_Bundle.xml` (complet), `CODE_XML/CODE_DiffBundle.xml` (rapide).
- ⚠️ **Tout ce qui est testé aujourd'hui n'a jamais tourné sur la machine réelle.** Les tests simu ne valent pas preuve machine.
- 📎 Guide terrain détaillé (arbres de décision) : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md` · note code : `NOTE_MISE_A_JOUR_CODE_20261116.md` (même dossier).
- Hors machine, à ne pas tester : simulation (T417-D, T421), Superviseur/Task Manager (T429).

---

## Étape 0 — État de départ
**Objectif :** noter l'état réel avant tout changement. Rien n'est modifié.

- [ ] ⚠️ Capteur FdC haut M1/M2 `M1M2_TopPositionFree_DI` : état physique : ____ . Shunté depuis le 25/09 → la barrière haute matérielle est absente. ⛔ Aucun homing automatique ancien.
- [x] 📥 Version du programme actuellement sur l'automate : **`v0.7.24_CptHorraire_20260922`, téléchargé le 23/09/2026 à 16:23** (CODESYS → Details, 17/11). ⛔ Jamais le `Device.export` du dépôt.
- [ ] 🛠️ Trace M3 prête : charger `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/Trace_Site_M3_Par_Echelle.trace` (35 variables, 4 échelles) — utile aux étapes 5 et 6.

**Connu, non corrigé (ne pas prendre pour une régression) :** FdC haut cassé et shunté côté client · T386 rotation de phase mal gérée (C4) · T394 robustesse position P1 après reboot sous l'eau.

---

## Étape 1 — Sauvegarde des persistantes (en ligne, rien chargé)
**Objectif :** relever toutes les valeurs de `GVL_PERSISTENT` avant d'importer quoi que ce soit.
> Libellés de menus d'après CODESYS 3.5 en anglais (le français peut différer). Si un libellé ne correspond pas : le noter, ne pas improviser.

**Pourquoi :** `GVL_PERSISTENT` est `VAR_GLOBAL PERSISTENT RETAIN`. Le code ajoute les nouvelles variables en fin de liste pour que les anciennes survivent au téléchargement, mais ce n'est pas prouvé sur cette machine (les compteurs horaires n'ont pas été chargés la dernière fois à cause des persistantes).

**Règles :**
- Utiliser le projet **`PRJ_CODESYS/v0.7.24_CptHorraire_20260922.project`** : c'est celui que l'automate déclare. ⛔ Pas `v0.7.25…DernièreMES` (jamais téléchargé), pas `v0.7.43`. Si CODESYS redit « aucune information de compilation correspondante » avec le v0.7.24 : **No**, et le noter.
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
- **Rien à lire** : `_SimEncoderRawPos*` (simulation), `_TranslationCalibFreq_Hz`, `_TranslationCalibTimeP2PV_S` (nouvelles).
- **À vérifier dans le v0.7.24** : le nom du projet contient « CptHorraire ». `_RunningHours*` (M1, M2, M3, machine) existent peut-être déjà sur l'automate : si oui, **les relever** (compteurs cumulés à ne pas perdre).

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

1. 📥 Mesurer au mètre la **distance réelle P2 ↔ PV** : ____ m. La comparer à `_TranslationPosP2_M − _TranslationPosPV_M`. **Valeurs relevées sur la machine le 17/11 : PV = 5, P2 = 15 → 10 m** (le code actuel a pour défaut 1,5 et 3,5, soit 2,0 m ; la machine garde ses valeurs persistantes). Ce sont peut-être des valeurs théoriques jamais mesurées. Si la distance réelle diffère : corriger les 2 positions, ✍️ noter avant → après.
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
6. **À savoir :** avec les positions de la machine (P2 − PV = 10 m) et les défauts de calibration (50 Hz, 2,0 s), le gain calculé vaut 10 / (50 × 2) = **0,1**, hors de la plage [0,005 ; 0,05] : il est **refusé** et le gain de repli `_TranslationGainMetersPerHzSec` (relevé à **0,02**) reste actif. Aucun remplacement silencieux dans ce cas. ⚠️ Le piège réapparaîtrait si on corrigeait les positions pour que 2,0 s donne un gain valide : relever le gain avant toute modification.
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
- `2026-11-17 (heure à compléter)` · mise sous tension du matin · **[CONSTAT]** trois défauts affichés à la bannière IHM : `1/3 [M 1] ErrorID:02 - perte codeur` · `2/3 [M 2] ErrorID:02 - perte codeur` · `3/3 [AU] ErrorID:04 - echec autotest demarrage`. Survenu **après une longue période d'arrêt** de la machine. Source : message de l'exploitant.
- `2026-11-17 (heure à compléter)` · analyse du code (lecture seule, sans trace ni état des bus) · **[HYPOTHÈSE]** cause commune au démarrage : le bus EtherCAT des codeurs n'est pas encore opérationnel à la mise sous tension, ce qui **latche** « perte codeur » (`FB_Safety_Winch.st:277-281`, `FB_Encoder_Abs.st:75/91`). L'autotest AU ne s'exécute **qu'une fois** au 1er Enable : il exige boucle AU fermée, contacteur au repos et aucune séquence résiduelle (`FB_Safety_EmergencyManagement.st:177-183`), l'échec est latché jusqu'à un Reset. **Non prouvé.** À relever : ordre de mise sous tension, état EtherCAT des codeurs M1/M2, état de la boucle AU avant le 1er Enable, effet d'un Reset une fois le bus prêt.
- `2026-11-17 (heure à compléter)` · connexion CODESYS · **[CONSTAT]** message : l'adresse de l'automate `VH601-0808TP` (`0301.900A`) diffère de celle enregistrée dans le projet (`3001.A00A`, lecture à confirmer). Réponse : Scan Network. Le message n'est plus apparu ensuite. **[HYPOTHÈSE]** exploitant : lié à la simulation. À vérifier : être bien connecté à l'automate réel et non à la simulation (menu Online → Simulation non coché).
- `2026-11-17 (heure à compléter)` · connexion CODESYS · **[CONSTAT]** message « application en RUN sur l'automate, **aucune information de compilation correspondante**, cliquer Yes pour télécharger ou No pour abandonner ». **[DÉCISION]** proposée : **No** (ne rien charger). Le projet ouvert ne correspond pas au programme de l'automate : le relevé des persistantes (étape 1) exige le projet de la dernière MES (`v0.7.25_…DernièreMES_20260922.project`) ou une autre version correspondante. Résultat : ____
- `2026-11-17 (heure à compléter)` · connexion CODESYS, bouton « Details » · **[MESURE]** application dans l'IDE : `v0.7.25_CptHorraireGVLPerssistantePasImplémen…`, **Download time : none**. Application dans l'automate : **`v0.7.24_CptHorraire_20260922`, téléchargée le mercredi 23/09/2026 à 16:23**. **[CONSTAT]** le programme de la machine n'est **pas** le v0.7.25 : toutes les hypothèses « machine ≈ `e38cc09a` » de la fiche et du registre de réintégration sont à revoir. **[DÉCISION]** : relever les persistantes avec le projet `v0.7.24_CptHorraire_20260922.project`.
- `2026-11-17 (heure à compléter)` · connexion CODESYS avec `v0.7.24_CptHorraire_20260922.project` · **[FAIT]** le message n'est plus « aucune information de compilation correspondante » : CODESYS affiche « l'application est en **RUN** sur l'automate, voulez-vous **télécharger les dernières modifications** ? » (Yes / No / Details). **[HYPOTHÈSE]** les informations de compilation correspondent à l'automate, mais le projet a des modifications par rapport au programme chargé (à confirmer via Details). **[DÉCISION]** : **No** (se connecter sans rien charger). Résultat : ____
- `2026-11-17 (heure à compléter)` · connexion CODESYS (projet `v0.7.24`) · **[CONSTAT]** après « No » à la fenêtre « télécharger les dernières modifications ? », l'exploitant n'est **pas connecté** à l'automate (rien n'est chargé : conforme à l'objectif, mais pas de connexion en ligne). Cause non établie. **[HYPOTHÈSE]** le projet diffère du programme de l'automate et CODESYS abandonne la connexion sans téléchargement. À relever : contenu du bouton « Details », fenêtre Messages (View → Messages), état de la barre d'état et de l'arbre (Application [run] ?).
- `2026-11-17 (heure à compléter)` · connexion CODESYS (projet `v0.7.24`), bouton « Details » · **[MESURE]** onglet « Code Changes Since Last Download » : aucun changement de code listé (liste vide d'après le texte collé). Application dans l'IDE : `v0.7.24_CptHorraire_20260922`, **Download time : none**. Application dans l'automate : `v0.7.24_CptHorraire_20260922`, téléchargée le mercredi 23/09/2026 à 16:23, CODESYS V3.5 SP19 Patch 1. **[CONSTAT]** les deux noms sont **identiques**. **[HYPOTHÈSE]** le fichier projet `v0.7.24` n'a gardé aucune trace du téléchargement (enregistré avant, ou copié), d'où la demande de télécharger ; le code serait le même, non prouvé. **[DÉCISION]** : ne pas répondre « Yes » (pas de chargement avant relevé des persistantes).
- `2026-11-17 (heure à compléter)` · projet `v0.7.24` ouvert, hors ligne · **[CONSTAT]** dans l'arborescence CODESYS, **certains titres d'objets sont en bleu** alors que l'exploitant n'est pas connecté. Liste des objets concernés : ____ . **[HYPOTHÈSE]** (non vérifiée) la couleur marque des objets modifiés depuis le dernier téléchargement, ce qui expliquerait la demande de télécharger. Le sens exact de la couleur reste à confirmer (survol, capture).
- `2026-11-17 (heure à compléter)` · File → Source Upload, fenêtre « Select Device » · **[MESURE]** un seul automate visible : nom `VH601-0808TP`, adresse `0301.900A`, driver UDP, 32 canaux, Target ID `1809 0004`, Target Name `VH601_0808TP`, Target Type `4102`, fabricant Shenzhen Veichi Control Technology. **[FAIT]** le Target ID `1809 0004` est le même que dans les fenêtres de connexion précédentes. Non connecté pour l'instant. À faire : bouton « Wink » pour confirmer visuellement l'automate de la machine, puis OK. Résultat : ____
- `2026-11-17 (heure à compléter)` · CODESYS · **[FAIT]** l'exploitant dispose d'une interface « Backup and Restore » (onglet de l'éditeur du Device). **[HYPOTHÈSE]** (aide CODESYS 3.5.12, non confirmée pour ce Veichi VH601) : la sauvegarde lit sur l'automate l'application de démarrage (`Application.app`, `.crc`, fichiers externes) et, seulement si l'option « source à chaque téléchargement » était active, `Archive.prj` (source). **Non démontré :** que les variables persistantes soient incluses. Usage prévu : filet de sécurité (copie du programme actuel) avant tout téléchargement, pas relevé de `GVL_PERSISTENT`. Résultat : ____
- `2026-11-17 (heure à compléter)` · File → Source Upload (aucun projet ouvert) · **[CONSTAT]** le projet extrait de l'automate est « presque vierge » et **sans rapport avec le projet de la machine** (d'après l'exploitant). **[HYPOTHÈSE]** (non vérifiée) l'automate ne contient pas l'archive de source du projet de la machine (jamais stockée via Source Download), ou contient une archive minimale d'origine. **[DÉCISION]** : la voie Source Upload est écartée pour relever `GVL_PERSISTENT`. Projet extrait : à fermer sans l'enregistrer dans le dépôt. Aucune écriture sur l'automate.
- `2026-11-17 (heure à compléter)` · analyse des fichiers `PRJ_CODESYS/` (lecture seule, horodatages du disque) · **[MESURE]** `v0.7.24_CptHorraire_20260922.project` : dernière modification **2026-09-23 16:23**, soit l'heure du téléchargement relevé dans l'automate. Aucun fichier `.compileinfo` n'existe pour le v0.7.24 ; les `.compileinfo` du dossier datent du 23/09 **14:13** (v0.7.22 / v0.7.23). Fichiers modifiés aujourd'hui : `v0.7.24_CptHorraire_20260922_copiebak.project` (08:33, avec fichier de verrou `.~u` à 08:49) et `v0.7.24_…Device.Application.xml` (08:29). **[HYPOTHÈSE]** (non prouvée) le v0.7.24 est bien le fichier téléchargé à 16:23 ; l'absence d'informations de compilation (compileinfo) explique que CODESYS ne se connecte pas sans télécharger. **[DÉCISION]** exploitant : les valeurs des persistantes sont indispensables ; le relevé de secours seul ne suffit pas.
- `2026-11-17 (heure à compléter)` · Device → Backup and Restore · **[FAIT]** message CODESYS : « Backup and restore is not supported by the device » (colonnes File / Size / Requires STOP vides). **[CONSTAT]** le Veichi VH601 ne propose pas de sauvegarde `.tbf` : **pas de filet de sécurité** de ce type avant un téléchargement. Voies de relevé écartées à ce stade : connexion sans téléchargement (impossible), Source Upload (archive sans rapport), Backup (non supporté).
- `2026-11-17 (heure à compléter)` · IHM web de l'exploitant · **[FAIT]** description de l'écran transmise par l'exploitant (texte de seconde main, tiré de captures : **les chiffres sont à vérifier sur les captures d'origine**). Contexte affiché : **[RÉEL]** (donc pas la simulation) · [SEMI-AUTO] · [CYCLE AUTO]. Bandeau : « [SÉCURITÉ] Coupure puissance active - acquitter défaut treuil/pont » · étape « AX0 - Verification coherence systeme » · « Descente treuil verrouillee : chariot M3 pas a P1/Maintenance ». Défaut actif affiché : « 1/3 [M1] ErrorID:02 - perte codeur ». Voyant `PhRotOK` éteint (champ 0). Chaîne AU : `ChainOK` vert, `Power Contactor` vert, `AU ARM` vert. **[MESURE]** (lues sur l'IHM) M1 : 8.50 / 8.15 m · M2 : 8.50 / 8.13 m · `CableLimitAscent_M` 7.70 · anticipation benne OPEN 1.30 / CLOSE 1.20 · synchro 3.00 / 6.00 · `WinchMaxStepAscent` 5, `Descent` 4 · limites basses Cycle −30.00 m, Legal −30.00 m · descente M1 et M2 −50.00 m.
- `2026-11-17 (heure à compléter)` · lecture de l'IHM, rapprochement avec le code · **[CONSTAT]** `CableLimitAscent_M` = **7.70** à l'IHM, alors que le défaut du code est **7.5** (`_CommunCfgPersist`) : valeur persistante **réelle différente du défaut** → premier témoin que les persistantes ne sont pas à leur défaut. **[HYPOTHÈSE]** les graduations M3 `0 / 5 / 15 / 20 / 30` vues à l'IHM seraient les positions réelles Trémie/PV/P2/P1/Maintenance de la machine, alors que le code actuel suppose `0 / 1,5 / 3,5 / 5 / 10`. **Non prouvé** : ce peut être l'échelle du dessin. À vérifier sur les champs de saisie des positions M3. **[HYPOTHÈSE]** `PhRotOK` éteint pourrait participer à la coupure de puissance (T386) ; non vérifié.
- `2026-11-17 (heure à compléter)` · onglet Files du Device · **[CONSTAT]** « Refresh » impossible : l'exploitant n'est pas connecté. **[HYPOTHÈSE]** le chemin de communication actif du Device n'est pas défini dans le projet (onglet Communication Settings → Scan Network → Set active path). Menu « Online Config Mode » vu à l'écran : **[DÉCISION]** ne pas l'utiliser (d'après l'aide CODESYS, il télécharge sur l'automate une application cachée `HiddenOnlineConfigModeApp`, donc il écrit sur l'automate).
- `2026-11-17 (heure à compléter)` · Device actif `VH601-0808TP (active)`, onglet Log · **[CONSTAT]** « Refresh » du Log : le message « connexion au device » s'affiche mais la connexion **ne s'établit pas** (reste en attente). Texte exact du journal : ____ . **[HYPOTHÈSE]** (non vérifiée) le Veichi n'accepte qu'une connexion d'application (Login) et refuse l'accès hors-application (Files, Log, Backup), ou attend une confirmation / un identifiant. Piste Files : à confirmer.
- `2026-11-17 (heure à compléter)` · projet ouvert = **`v0.7.24_CptHorraire_20260922_copiebak.project`** (titre de la fenêtre CODESYS), menu « Declarations » : Add All Instance Paths · Reorder List and Clear Gaps · Save Current Values to Recipe · Restore Values from Recipe. **[CONSTAT]** la copie `_copiebak` (modifiée aujourd'hui 08:33) contient un objet de liste de variables persistantes (`PersistentVars`) absent du fichier original d'après l'exploitant (à confirmer). **[DÉCISION]** : ne pas utiliser « Add All Instance Paths » ni « Reorder List and Clear Gaps » (modifient la déclaration/l'ordre de la liste, risque de réinitialisation des valeurs au téléchargement) ; « Save Current Values to Recipe » = lecture seule sur l'automate, **en ligne seulement** ; « Restore Values from Recipe » = écriture sur l'automate, uniquement après décision.
- `2026-11-17 (heure à compléter)` · connexion CODESYS · **[DÉCISION]** exploitant : réponse **« Yes »** à la demande de téléchargement, après avoir constaté que dans la comparaison en ligne les variables persistantes n'étaient pas marquées en rouge. Projet utilisé : ____ (original ou `_copiebak`). Type d'opération (online change / téléchargement complet) : ____ . **[MESURE]** en ligne : `Device.Application.GVL_PERSISTENT._CycleSampleCountTotal` = **734**. **[HYPOTHÈSE]** les persistantes n'ont pas été perdues par ce « Yes » (la valeur n'est pas à son défaut 0) ; **un seul témoin, non suffisant** : à confirmer sur `CableLimitAscent_M` (7.70 à l'IHM), les positions M3, `_CalibM1`/`_CalibM2`, `_BucketState`. À faire sans attendre : Declarations → Save Current Values to Recipe (texte, hors Git).
- `2026-11-17 (heure à compléter)` · relevé de `GVL_PERSISTENT` en ligne (extraction par l'exploitant à partir de captures, **erreur de lecture possible** ; fichier `CODE_BACKUP/extraction_gvl_persistent_partiel_capture_20261117.md`) · **[MESURE]** comparaison avec les défauts du code (`CODE/GVL_PERSISTENT.st`) : **identiques** pour la plupart des réglages (rampes, paliers de vitesse, `_WinchM1/M2CfgPersist` 8,5 m, synchro 3/6/7, benne, joystick 5000/5000, limites légales −30, `_TranslationGainMetersPerHzSec` 0,02…). **Différents du défaut (donc modifiés sur site, donc conservés) :** `CfgCableLimitAscent_M` 7,7 (défaut 7,5) · `_CycleCfgPersist.SetDepth_M` −30 (défaut −29) · `DrainTime_S` 2 (défaut 5) · `_BlinkTimeOff` 900 ms (défaut 800 ms) · **positions M3 `0 / 5 / 15 / 20 / 30`** (défauts du code : 0 / 1,5 / 3,5 / 5 / 10) · `_TranslationPosEstimated_M` 30 · `_CycleSampleCount` 30 · `_CycleSampleCountTotal` 734 · `_CalibM1`/`_CalibM2` renseignées (`Homed` TRUE, `HomingSuspect` FALSE, valeurs brutes non nulles) · `_BucketState` renseigné (`IsOpen` TRUE, `BucketReferenced` TRUE, M2 ouverte 8,13 m / fermée 22,16 m). **[CONSTAT]** les persistantes ont **survécu** au « Yes » pour toutes les variables comparées ; l'hypothèse « positions M3 réelles = 0/5/15/20/30 » est confirmée comme **valeurs enregistrées**, pas comme distances mesurées (non démontré). **[À VÉRIFIER]** `_WinchSpeedStepTable.P5R4` = FALSE à la capture, TRUE au défaut du code (P5R3 non visible) : lecture à contrôler. **[CONSTAT]** `_RunningHours*`, `_TranslationCalibFreq_Hz`, `_TranslationCalibTimeP2PV_S` ne figurent pas dans la capture (le dernier élément est `_CycleSampleCountTotal`) : variables absentes du projet en ligne ou non capturées.
- `2026-11-17 (heure à compléter)` · outillage de relevé des persistantes · **[FAIT]** à la demande de l'exploitant, création dans `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/` (dossier choisi par l'exploitant après refus du garde dans `codesys_console/`, `PRJ_CODESYS/` et hors dépôt) : `generate_persistent_variable_list.py`, `persistent_variables.txt`, `poc_lecture_persistante.py`, `snapshot_persistent.py`. Non commités. **[CONSTAT]** le garde d'écriture du projet (`hook_scope_guard`, deny-list « code machine, réglages, hooks, skills ») refuse à l'agent les scripts destinés à la console CODESYS ; il a fait perdre un temps important pendant la MES. À traiter après la journée (voir constats ouverts).
- `2026-11-17 (heure à compléter)` · POC `poc_lecture_persistante.py` dans la console CODESYS, projet en ligne · **[MESURE]** `_CalibM1.Homed` = TRUE · `_CalibM1.HomingRefRaw` = UDINT#16750628 (identique à la capture du matin) · `StepThreshold_Pct[1]` = REAL#20 · `LoadPctByStepAndSpeedBand[1][1]` = REAL#0 · `Cell[1,1,1,1].Valid` = FALSE, avec ou sans espaces. **[CONSTAT]** lecture d'un champ et des tableaux `[i]`, `[i][j]`, `[i,j,k,l]` : OK ; préfixe `Device.Application.` : « Invalid expression » ; structure entière (`_CalibM1`) : « Invalid pointer size » (lire champ par champ). **[DÉCISION]** script complet `snapshot_persistent.py` : chemins courts, sans login, sans écriture. À lancer par l'exploitant.
- `2026-11-17 10:08` · `snapshot_persistent.py` lancé dans la console CODESYS (projet en ligne) · **[MESURE]** 233 variables lues en 3,61 s, **6 erreurs** « Invalid expression » : `_RunningHoursMachine_S`, `_RunningHoursM1_S`, `_RunningHoursM2_S`, `_RunningHoursM3_S`, `_TranslationCalibFreq_Hz`, `_TranslationCalibTimeP2PV_S` (variables nouvelles du code actuel, absentes du v0.7.24 : attendu). Fichier : `DOC/WFLOW/MISE_EN_SERVICE/20261117_PERSISTANTES/Persistantes_20261117_100831.csv`. **[CONSTAT]** comparaison avec l'extraction par captures du matin : **147 valeurs identiques**, **1 différence** : `_WinchSpeedStepTable.P5R4` = FALSE à la capture, **TRUE** dans le CSV (= défaut du code) → erreur de lecture de la capture, la valeur du CSV fait foi. **[HYPOTHÈSE]** les autres écarts de la comparaison (36 « absentes du CSV ») viennent de la façon dont l'outil de comparaison nomme les tableaux et d'un classement erroné de champs dans l'extraction (non vérifiés un par un). Le CSV est la copie de référence des persistantes de la machine avant tout nouveau chargement.
- `2026-11-17 10:14` · `snapshot_persistent.py`, liste complète (`--with-learning --with-sim`) · **[MESURE]** 355 variables lues en 10,65 s, 6 erreurs « Invalid expression » (les 6 variables nouvelles du code actuel, attendues). Fichier : `DOC/WFLOW/MISE_EN_SERVICE/20261117_PERSISTANTES/Persistantes_20261117_101458.csv`. **[CONSTAT]** comparaison avec le relevé de 10:08 : **0 valeur différente** sur les 233 lignes communes (état stable) ; 122 lignes nouvelles = table d'apprentissage `_WinchSpeedLearnTable` (120 variables, 0 erreur : tous `Valid` = FALSE, `SpeedMps` = 0, `SampleCount` = 0 → table vierge, jamais utilisée) + `_SimEncoderRawPosM1/M2` = 1000000 (valeur par défaut). **Relevé complet de référence : Persistantes_20261117_101458.csv** (à copier hors du dépôt avant le chargement du nouveau code).
- `…`

## Constats ouverts

| # | Heure | Étape | Constat / décision | Suite (qui, quoi) |
|---|---|---|---|---|
| 1 | | 0 / 1 | Défauts au démarrage : codeurs M1 et M2 (ErrorID:02), autotest AU (ErrorID:04) après longue période d'arrêt. Cause non établie. | Relever ordre de mise sous tension, état EtherCAT, état boucle AU ; tester un Reset une fois le bus prêt |
| 2 | | 1 | Aucune information de compilation correspondante entre le projet ouvert et l'automate : relevé des persistantes impossible avec ce projet | Ouvrir `v0.7.24_CptHorraire_20260922.project` (déclaré par l'automate) ; sinon File → Open Project from PLC |
| 4 | | 1 / 2 | Programme de la machine = `v0.7.24` du 23/09 16:23, pas `e38cc09a`. Hypothèse (non vérifiée) : l'écart v0.7.24 → code actuel peut être plus grand que prévu ; la liste « jamais testé » (§ Contexte) est à revoir | Comparer v0.7.24 et commits du 22-23/09 (T387, T392, compteurs horaires…) avant le chargement |
| 3 | | 1 | Avertissement d'adresse VH601-0808TP (`0301.900A` ≠ `3001.A00A`) : vérifier connexion à l'automate réel | Online → Simulation non coché ; noter l'IP et le nom |
