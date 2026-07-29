# 📖 REX Nommage — historique, incidents et chantiers différés (v1.0)

> 📌 **Ce document n'est PAS normatif.** Il conserve le *pourquoi* et les décisions non
> appliquées, pour que `DOC/NAMING_CONVENTION.md` ne contienne que ce qui oblige un agent
> aujourd'hui. Ne jamais coder d'après ce fichier — il documente aussi ce qui a été rejeté.

---

## Polarité des booléens — incidents fondateurs

⚠️ **Confusion réelle vécue sur ce projet** (retour terrain, session mise en service) :
l'utilisateur a **forcé manuellement `instWinchM1.SafeStop` à `TRUE`**, en pensant — par analogie
avec la famille "capteur de sécurité" — qu'un "organe de sécurité" devait être en permanence à `1`.
Résultat : `SafeStop` (sortie de COMMANDE, pas un capteur) forcé à `TRUE` = décélération rapide
imposée en permanence, mouvement totalement bloqué, alors que `FB_Safety_Winch` calculait
correctement `FALSE` (aucun défaut). Diagnostic long car le câblage était irréprochable — seul un
Force expliquait la divergence entre la sortie calculée et l'entrée reçue.
**Règle** : ne JAMAIS forcer manuellement une sortie de COMMANDE (`SafeStop`, `ForbidDescent`,
`PowerCutOff`) — elle est TOUJOURS calculée par son bloc Safety. Si un test banc nécessite de
neutraliser une condition, forcer/bypasser l'entrée CAPTEUR en amont (ex. `PRG_00_Inputs.PhaseRotationOk`,
ou un override `GVL_Simulation.<Device>_IsReal` dédié — voir Partie 13), jamais la sortie de
commande elle-même.

⚠️ **Deux bugs de câblage réels sur ce projet** (voir `AUDIT_Coherence_Documentaire_v1.0.md` §27
D72a et §29 D74), famille "capteur de sécurité" :
- `GVL_IN.SlackCableSwitch` câblé **sans inversion** alors que le contact est NF (`TRUE`=pas de mou)
  → jamais détecté un vrai mou de câble. Corrigé : `SlackCableDetected := NOT GVL_IN.SlackCableSwitch`.
- `GVL_IN.PhaseRotationOk` déclaré **sans valeur initiale** → un `BOOL` non initialisé démarre à
  `FALSE` (IEC 61131-3) = "défaut" par défaut → `SafeStop` bloqué en permanence tant que le vrai
  capteur n'est pas câblé, sans aucun vrai défaut.

---

## `Req`/`Cmd` — cap long terme et migration non retenue

🎯 **Cap long terme (pas ce soir)** : généraliser le préfixe (rôle/type d'abord) à TOUT —
`Sensor`/`Position`, seuils (`CableLimitAscentM`), détection/état (`Reached`/`Active`), pas
seulement `Req`/`Cmd` — pour que taper le rôle dans l'autocomplete suffise à retrouver n'importe
quelle variable, peu importe le mécanisme. Gros chantier (renomme `Ready`/`Busy`/`RelayFwd`/
`SpeedRef`/`CablePosM`/`TopPositionSensor`... utilisés dans tout le projet) — **à planifier à
part**, jamais en improvisé. Voir `PLAN_TASK.md` §🏷️ Nommage.

⚠️ **Non retenu (audit 2026-07-22)** : la migration `Req`/`Cmd` avait été appliquée un temps à
`ST_TranslationHMI` (`ReqFwd`/`ReqRev`, ex-`M3_RelayFwd/Rev`, seuls champs créés le 2026-07-15) —
**mais le code actuel garde `BtnFwd`/`BtnRev`/`TglJoystickMaster`/`SelTarget`**, la migration
n'a pas été conservée (revert non tracé dans `VERSION_HISTORY.md`). Le pattern `Req`/`Cmd`
reste une piste valable pour le chantier de nommage généralisé ci-dessus, mais **n'est
appliqué nulle part dans le code actuel** — ne pas s'y fier comme référence d'un état existant.
Reste en préfixe `CmdX` établi (catégorie différente, pas cette migration), à auditer/migrer
plus tard si un jour voulu (voir `PLAN_TASK.md`) :
- `CmdOpen`/`CmdClose`/`CmdReset`/`CmdHome`/`CmdInhibit` (`FB_Bucket`/`FB_Winch`/`ST_BucketHMI`/
  `ST_WinchHMI`) — déjà en préfixe, cohérent avec la règle, mais catégorie `Cmd` utilisée ici pour
  une **requête** (pas un signal final) : à harmoniser vers `Req` dans ce chantier séparé.
- `CmdWinchM1_*`/`CmdTranslationM3_*`/`CmdBucket_*` (`FB_Cycle`) — idem, préfixe déjà correct,
  catégorie à revoir.
- `BrakeCmd` (`FB_Brake`/`FB_Translation`/`FB_Safety_Translation`/`ST_WinchHMI`/`ST_TranslationHMI`) — en
  **suffixe**, contredit la règle ci-dessus mais établi dans 5 fichiers : laissé tel quel.
- `ST_BucketHMI.OpenReq`/`CloseReq` — en **suffixe** également (ancien usage qui a inspiré la
  distinction `Req`/`Cmd`, avant qu'on tranche pour le préfixe) : laissé tel quel.

---

## Convention cible `GVL_Simulation` (migration planifiée)

## Variables de simulation (GVL_Simulation) — Préfixes sémantiques

`GVL_Simulation` mélange aujourd'hui 3 familles différentes pour exprimer « donnée simulée »
(`_IsReal`, `_Simulated`, `Sim...`) sans cohérence, plus des variables hors PascalCase
(`refBucket`). Convention cible (à appliquer en migration planifiée, pas maintenant) :

| Préfixe | Sémantique | Exemple | Remplace |
|---|---|---|---|
| `Bus` | Device bus de terrain (EtherCAT/CANopen), granularité réel/simulé | `BusEncoderM1IsReal`, `BusJoystickIsReal` | `EncoderM1_IsReal`, `Joystick_IsReal` |
| `Sensor` | Capteur/retour câblé (I/O discrète), granularité réel/simulé | `SensorTopPositionIsReal`, `SensorM1ThermalIsReal` | `TopPositionSensor_IsReal`, `ThermalM1_IsReal` |
| `Sim` | Valeur simulée calculée (remplace un `_DI` en mode simu) | `SimM1BrakeFeedback`, `SimKoboldContactFond` | `M1BrakeFeedback_Simulated`, `KoboldContactFond_Simulated` |
| `Tst` | Outil/commande de test banc (même famille que `Tst` côté IHM) | `TstEncoderSpeedFactor`, `TstInjectSyncDeviationM1` | `EncoderSimSpeedFactor`, `InjectSyncDeviationM1` |
| `Link` | Référence CODESYS (`REFERENCE TO`) vers une instance, fenêtre de passage tests PLC | `LinkBucket`, `LinkWinchM2` | `refBucket`, `refWinchM2` |

⚠️ **`Ref` exclu volontairement** pour ce rôle : déjà pris par « consigne » (`SpeedRef`,
`CablePosRef`) ET évoque le référencement codeur (Homing) — collision de sens à 3 signification
s'il était aussi utilisé pour une référence `REFERENCE TO`. `Link` lève l'ambiguïté.

---
