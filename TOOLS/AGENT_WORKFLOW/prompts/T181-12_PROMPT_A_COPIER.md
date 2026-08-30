[COLLER D'ABORD : TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md]

MISSION CODE PRODUCTION : T181-12 — plancher de palier en plongée (FB_DiveSearch → PRG_03 → PRG_04) + câblage du bug latent D12 (CurrentSpeedStep).

Tu implémentes du CODE MACHINE RÉEL. Pas de tâche de test — les TC/harnais suivront dans un lot séparé, en asynchrone.

Lis d'abord :
1. DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-12_MINSTEPDOWN_DIVE.yaml (contrat complet, AC1-AC7)
2. CODE/G_CYCLE/FB_DiveSearch.st
3. CODE/M_MAIN/PRG_03_Modes_Cycle.st (lignes ~128-150 : instanciation instDiveSearch, ~340-350 : Data.ReqProgram.ReqBucket)
4. CODE/M_MAIN/PRG_04_Treuils_Benne.st (région "§5ter Agrégateur de clamp de palier" — déjà livré par T181-10, variables CommonMinStepUp/CommonMinStepDown réservées pour toi, actuellement figées à 1)
5. CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramBucketRequest.st

Bug confirmé (D12) : FB_DiveSearch.CurrentSpeedStep (VAR_INPUT, utilisé en interne lignes 138/182/222/224/266/270/304/308 pour détecter palier > 4) n'est JAMAIS câblé dans l'instanciation instDiveSearch (PRG_03:129-150) → CODESYS le laisse à 0 par défaut → toute la détection "palier 5 interdit en plongée" est morte depuis toujours.

But machine (2 volets) :

**Volet A — câbler CurrentSpeedStep (corrige D12 immédiatement)**
Passer le palier réellement demandé en argument à instDiveSearch (celui de M1, treuil principal — à confirmer dans PRG_04 quelle variable porte le palier courant M1, ex. côté StepNumber/RequestedStep de instWinchM1). Objectif : dès que le Kobold est actif, une demande palier 5 est vue et bloquée par la logique interne existante de FB_DiveSearch.

**Volet B — producteur + flux du plancher de plongée**
- FB_DiveSearch expose une nouvelle sortie (VAR_OUTPUT) : MinStepDown : INT (palier minimum imposé en descente pendant la plongée) — ou un booléen DiveSpeedFloorActive mappé à un palier fixe configurable (à toi de choisir la forme la plus simple et cohérente avec l'existant, justifie ton choix). Gaté sur DescentActive : retombe au front de sortie de plongée (pas de plancher résiduel).
- Ajoute un champ dans ST_ProgramBucketRequest (ou struct plus appropriée si tu identifies mieux) pour porter cette valeur : PRG_03 la remplit depuis instDiveSearch, comme fait déjà pour ForceMinSpeedStep.
- PRG_04 §5ter (agrégateur) : remplace la valeur figée `CommonMinStepDown := 1;` par la vraie source (Data.ReqProgram.ReqBucket.<ton champ>), en respectant la règle de l'agrégateur déjà en place : plancher = MAX des sources plancher ; si plancher > plafond, LE PLAFOND GAGNE (ne casse pas cette règle).
- Cas particulier à respecter (AC4) : si KoboldBottomTouchLatched coupe déjà StartStop (PRG_04, région autour de la ligne ~487-504), le plancher doit devenir sans effet dans ce cas — ne force pas un mouvement qui ne devrait pas avoir lieu.

Scope autorisé :
- CODE/G_CYCLE/FB_DiveSearch.st
- CODE/M_MAIN/PRG_03_Modes_Cycle.st
- CODE/M_MAIN/PRG_04_Treuils_Benne.st (uniquement la région §5ter et le câblage de instWinchM1/M2 déjà en place — ne touche pas au reste de l'agrégateur T181-10)
- CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/** (ajout de champ si besoin)

Interdits :
- CODE/H_TREUILS_BENNE/FB_Winch.st (T181-08, hors scope)
- DOC/WFLOW/TASKS.yaml
- PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
- aucun commit, aucun push
- ne touche à aucun test/harnais (TOOLS/TEST_AUTO_CI/**) — laisse-les rouges/désynchronisés si besoin, un lot dédié les alignera après

Important :
- Travaille dans un worktree/branche séparée (`T181-12`), base = HEAD actuel de main.
- PRG_04 contient déjà le bloc §5ter livré par T181-10 (mergé) — ne le réécris pas, complète-le seulement.
- Conserve TOUTES les sorties actuelles de FB_DiveSearch (DescendPermit, KoboldMeasureEnable, etc.) intactes.
- N'invente aucun seuil de sécurité non déjà présent dans le code ou le contrat.

Restitution attendue :
- git diff complet (production uniquement, pas de bundle CODE_XML si évitable — sinon régénère-le proprement)
- Explication courte : comment CurrentSpeedStep est maintenant alimenté, quelle variable porte le palier M1 réel
- Description du champ ajouté à ST_ProgramBucketRequest (ou équivalent) et de la forme retenue pour le plancher (INT vs BOOL+palier fixe)
- Confirmation explicite que le cas AC4 (maintien joystick post-fond) ne crée pas de mouvement résiduel
- Si un point du contrat est ambigu ou vous force à inventer une règle de sécurité : STOP, remonte-le clairement au lieu de trancher seul.
