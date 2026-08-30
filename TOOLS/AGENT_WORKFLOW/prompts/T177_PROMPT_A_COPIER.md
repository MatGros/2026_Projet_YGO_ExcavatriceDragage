[COLLER D'ABORD : TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md]

MISSION CODE PRODUCTION : T177 — activer réellement le garde-vitesse (SpeedGuardEnable) sur les 2 treuils.

⚠️ **Écart avec le contrat DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T177.yaml** : le contrat limite le scope
à `CODE/H_TREUILS_BENNE/**`. Après vérification du code, **ce n'est pas là qu'est le bug**. Le contrat
est obsolète sur ce point précis — applique la mission ci-dessous, pas le scope littéral du fichier YAML.

Constat vérifié dans le code (`CODE/M_MAIN/PRG_04_Treuils_Benne.st`) :
- `FB_Winch.st:47` déclare déjà `SpeedGuardEnable : BOOL := TRUE;` par défaut — ce niveau est SAIN.
- MAIS `PRG_04_Treuils_Benne.st:72-73` déclare `SpeedGuardEnableM1/M2 : BOOL := FALSE;` et ne les
  met JAMAIS à `TRUE` ailleurs dans le fichier — ces variables écrasent le défaut sain de `FB_Winch`
  au moment de l'appel (`instWinchM1(SpeedGuardEnable := SpeedGuardEnableM1, ...)`, lignes ~817/853).
  Résultat : le garde-vitesse est mort en pratique sur M1 et M2.
- BONUS (même racine du problème) : `MeasuredSpeedBand := 0` est câblé en dur à l'appel des deux
  instances (lignes ~816/852) — le 2ᵉ étage du garde (`FB_Winch.st:252`, vitesse mesurée vs palier
  demandé) ne peut donc JAMAIS se déclencher, quelle que soit la vitesse réelle.
- `FB_WinchLoadEstimator` (censé produire `SpeedBand`, `CODE/H_TREUILS_BENNE/FB_WinchLoadEstimator.st`)
  est déclaré mais **jamais instancié nulle part** dans `CODE/` (confirmé G200_check_linkage.py,
  orpheline connue de longue date, "hors périmètre M3" selon commentaire du gate — à réévaluer ici
  car c'est justement le périmètre treuils qui en a besoin).

Lis d'abord :
1. DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T177.yaml (AC1-AC4, alert_duty D5)
2. CODE/H_TREUILS_BENNE/FB_Winch.st (lignes 45-50 déclaration SpeedGuardEnable ; 240-256 logique garde)
3. CODE/H_TREUILS_BENNE/FB_WinchLoadEstimator.st (interface complète — sorties `SpeedBand`, `Ready`, `Configured`)
4. CODE/M_MAIN/PRG_04_Treuils_Benne.st (lignes 72-73 déclaration, ~816-820/852-856 appel instWinchM1/M2)
5. CODE/E_CODEURS/FB_Encoder.st — sorties `Speed_Mps`/`SignedSpeed_Mps`/`SpeedValid` déjà publiées par
   PRG_02_Acquisition (voir `PRG_04_Treuils_Benne.st:650-652` où `MeasuredSpeedSignedMps` est déjà lu)

But machine (2 volets, priorité au volet A) :

**Volet A — SpeedGuardEnable réellement actif (minimum viable, AC1/AC3)**
`SpeedGuardEnableM1`/`SpeedGuardEnableM2` dans PRG_04 passent à `TRUE` par défaut (ou sont
purement supprimées et l'appel utilise directement une constante/le défaut sain de FB_Winch —
à toi de choisir la forme la plus propre, en respectant "producteur unique" AF03). Si le contrat
D5 prévoit un bypass safety légitime pour neutraliser le garde en maintenance, câble-le explicitement
(cherche un bypass existant côté GVL_IHM Bypass avant d'en inventer un nouveau) ; sinon TRUE fixe.

**Volet B — MeasuredSpeedBand alimenté par une vraie mesure (AC2, cœur du contrat)**
Instancie `FB_WinchLoadEstimator` (une instance par treuil, M1 et M2) dans `PRG_04_Treuils_Benne.st`,
câblé sur la vitesse mesurée réelle (`MeasuredSpeedMps`/`MeasuredSpeedSignedMps`, déjà publiées par
PRG_02 et déjà lues plus haut dans PRG_04 pour l'affichage) et sur `RequestedStep`/`StepNumber` du
treuil correspondant (regarde l'interface exacte du FB avant de deviner les noms de port).
Câble sa sortie `SpeedBand` dans l'appel `instWinchM1/M2(MeasuredSpeedBand := ...)` à la place du `0`
codé en dur. Si `FB_WinchLoadEstimator` a des paramètres de config (seuils bande) : cherche-les dans
`GVL_PERSISTENT._WinchSpeedConfig` (déjà présent, vu dans GVL_PERSISTENT.st) avant d'en inventer.

Scope réel autorisé (corrige le YAML) :
- CODE/M_MAIN/PRG_04_Treuils_Benne.st
- CODE/H_TREUILS_BENNE/FB_Winch.st (uniquement si un ajustement mineur de l'interface est
  strictement nécessaire pour le câblage — ne touche pas à la logique du garde déjà correcte)
- CODE/H_TREUILS_BENNE/FB_WinchLoadEstimator.st (uniquement si un bug bloque son instanciation)

Interdits :
- CODE/A_COMMUN/**
- DOC/AF/** (la fiche ne bouge qu'après le code, sur preuve)
- PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
- DOC/WFLOW/TASKS.yaml
- aucun commit, aucun push
- pas de tests/harnais — laisse-les au lot suivant

Important :
- Travaille dans un worktree/branche séparée (`T177`), base = HEAD actuel de main.
- N'invente pas de seuil de sécurité non déjà présent dans `GVL_PERSISTENT._WinchSpeedConfig` ou le
  contrat.
- Si `FB_WinchLoadEstimator` s'avère structurellement incompatible avec l'appel prévu (interface
  trop différente, dépendance manquante) : STOP, ne bricole pas une solution de contournement,
  remonte le blocage précisément.

Restitution attendue :
- git diff complet
- Confirmation explicite : `SpeedGuardEnableM1/M2` valent maintenant TRUE en fonctionnement normal
  (grep + explication du chemin de câblage)
- Confirmation explicite : `MeasuredSpeedBand` reçoit une vraie valeur de `FB_WinchLoadEstimator`,
  plus de `:= 0` codé en dur
- Bundle régénéré + `G200_check_linkage.py --report` (le FB ne doit plus apparaître orphelin)
- Toute alerte sur D5 (bypass maintenance du garde) si le point n'est pas tranché dans le contrat
