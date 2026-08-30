[COLLER D'ABORD : TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md]

MISSION CODE PRODUCTION : T181-13 — palier plancher plongée Kobold (3-4) + montée lissée.

⚠️ **DÉPENDANCE BLOQUANTE** : ce lot consomme le plancher produit par T181-12
(`MinStepDown`/champ équivalent dans `ST_ProgramBucketRequest`, câblé dans PRG_04 §5ter
`CommonMinStepDown`). Ne démarre CE lot qu'après avoir lu le diff réel livré par T181-12 —
le nom exact du champ/de la sortie FB_DiveSearch peut différer de ce que ce prompt suppose.
Si T181-12 n'est pas encore mergé dans la branche de base : STOP, remonte-le, n'invente pas
le champ toi-même.

Lis d'abord :
1. DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-13_PLANCHER_KOBOLD.yaml (AC1-AC6)
2. Le diff réel de T181-12 (git log/diff sur la branche de base) — récupère le nom exact du champ
   plancher produit par FB_DiveSearch et consommé par PRG_04 §5ter (`CommonMinStepDown` ou équivalent)
3. CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st (lissage déjà extrait T181-05 — NE PAS réécrire,
   consommer tel quel)
4. CODE/H_TREUILS_BENNE/FB_Winch.st (chaîne RequestedStep -> StepNumber, région autour des lignes
   225-256 — c'est ICI que le plancher doit agir, sur la CIBLE, jamais sur StepNumber directement)
5. CODE/M_MAIN/PRG_04_Treuils_Benne.st (région "§5ter Agrégateur de clamp de palier" — le plancher
   de T181-12 y est déjà agrégé dans `CommonMinStepDown`/`M2MinStepDown` ; à toi de le faire consommer
   côté cible, pas de le recalculer)

But machine :
- En plongée Kobold, joystick hors neutre à tout %, le palier visé (`RequestedStep`/cible avant
  `FB_WinchStepShaper`) est plafonné en bas par le plancher plongée déjà agrégé (`CfgDiveFloorStep`,
  valeur 3 ou 4 — à retrouver dans le contrat ou `GVL_IHM.Commun.Cfg`/`GVL_PERSISTENT` si déjà
  paramétrée, sinon nouvelle config nommée en RETAIN).
- La montée vers ce plancher passe par `FB_WinchStepShaper` (déjà instancié) — aucune transition
  `StepNumber` de plus de +1 par cycle. Ne modifie pas la logique du shaper, câble seulement le
  plancher dans sa cible d'entrée.
- Relâche joystick -> retour à 0 IMMÉDIAT (pas de plancher résiduel, pas de lissage sur la descente
  vers 0 — l'arrêt franc existant ne doit pas être touché).
- Respecte la règle d'agrégation déjà en place (T181-10, §5ter) : si le plancher plongée dépasse le
  plafond courant (ex. SyncDeviationWarn -> palier 1), LE PLAFOND GAGNE. Ne casse pas cette priorité.

Scope autorisé :
- CODE/H_TREUILS_BENNE/FB_Winch.st (câblage de la cible, injection du plancher — pas la logique
  du shaper lui-même)
- CODE/M_MAIN/PRG_04_Treuils_Benne.st (câblage plancher -> cible, uniquement le nécessaire)
- DOC/AF/AF_Partie-04_* (rédaction section plancher plongée, F10.12)
- TOOLS/TEST_AUTO_CI/RESULTS/**/tests/** (si tu ajoutes un TC, sinon laisse pour un lot dédié)

Interdits :
- DOC/WFLOW/TASKS.yaml
- PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
- aucun commit, aucun push
- ne réécris pas FB_WinchStepShaper.st ni la logique d'agrégation T181-10 déjà livrée

Important :
- Travaille dans un worktree/branche séparée (`T181-13`), base = branche où T181-12 est déjà mergé.
- Vérifie que le grep `StepNumber :=` ne contient AUCUNE affectation directe du plancher — le
  plancher agit uniquement sur la cible en amont du shaper (AC4 du contrat).
- N'invente pas de valeur pour `CfgDiveFloorStep` (3 ou 4) sans la retrouver dans le contrat/PLAN —
  si absente, STOP et demande confirmation plutôt que deviner.

Restitution attendue :
- git diff complet
- Confirmation : grep `StepNumber :=` propre (aucune affectation directe du plancher)
- Confirmation : test manuel/raisonnement sur le cas AC3 (relâche joystick -> 0 au cycle suivant,
  sans lissage résiduel)
- Confirmation : croisement plancher vs plafond (SyncDeviationWarn ou équivalent) — le plafond
  gagne toujours, avec l'exemple concret vérifié dans le code
- Bundle régénéré + G200 --report
- Toute ambiguïté sur la valeur de CfgDiveFloorStep ou le nom du champ T181-12 : remontée explicite
