=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). T278 (mail client GCAM
2026-09-15) demandait un masquage des alarmes transitoires au démarrage/
réarmement AU + un auto-reset borné (1-3 tentatives). Le FB existe déjà et
est câblé : `FB_AutoResetTransientDiag.st`, instancié
`PRG_02_Acquisition.st:223`.

Observation utilisateur 2026-09-21 (watch machine réelle, AU manipulé) :
`State` reste bloqué à `0`, `Phase` ne passe jamais à `1`/`2`, `ResetPulse`
ne bouge jamais — alors que les entrées liées à la chaîne AU
(`EmergencyChainClosed`, etc.) bougent normalement.

**Cause déjà identifiée par l'orchestrateur** (à vérifier/confirmer par
l'agent, pas à reprendre en aveugle) :

```st
// PRG_02_Acquisition.st:223-239
instAutoResetTransientDiag(
    Enable                  := TRUE,
    StartupEnable           := GVL_Simulation.AutoResetTransientDiagAtStartupEnable,
    PowerRearmEnable        := GVL_Simulation.AutoResetTransientDiagAfterRearmEnable,
    ...
);
```

```st
// GVL_Simulation.st:106-107
AutoResetTransientDiagAtStartupEnable    : BOOL := FALSE;
AutoResetTransientDiagAfterRearmEnable   : BOOL := FALSE;
```

Ces 2 booléens conditionnent l'entrée dans `State=1` (démarrage,
`FB_AutoResetTransientDiag.st:87`) et `State=2` (post-réarmement, ligne 97).
**Les deux valent `FALSE` par défaut et aucun autre point du code ne les met
jamais à `TRUE`** (grep confirmé sur tout `CODE/`, 0 résultat hors GVL_Simulation
et le câblage PRG_02). Aucun toggle IHM non plus (`CODE/J_SUPERVISION/`, 0
résultat).

**Décision utilisateur 2026-09-21 : pas de toggle IHM** — ces interrupteurs
ne doivent pas être exposés à l'opérateur, la fonction doit fonctionner par
défaut, sans réglage.

## 2. Objectif de la tâche (T352)

1. Confirmer par preuve (simulation/test isolé du FB) que le mécanisme
   fonctionne normalement dès que `StartupEnable`/`PowerRearmEnable` sont à
   `TRUE` — la logique interne du FB semble saine, seul le câblage amont est
   suspect.
2. Déterminer la cause historique : erreur de câblage (le FB a été raccordé
   sur une GVL de simulation au lieu de sa config définitive) ou
   fonctionnalité jamais terminée.
3. Proposer et implémenter le correctif : déplacer les 2 flags vers un
   emplacement définitif avec défaut `TRUE` câblé en dur (pas de toggle IHM,
   décision utilisateur) — candidat naturel : `GVL_PERSISTENT` avec valeur
   par défaut `TRUE`, ou constante fixe si aucun besoin de désactivation n'est
   identifié.

## 3. Méthode — preuve avant correctif

- Écrire ou réutiliser un test CI qui instancie `FB_AutoResetTransientDiag`
  isolément, force `StartupEnable`/`PowerRearmEnable` à `TRUE`, et prouve que
  la séquence progresse normalement (State 0→1→stabilisation→ResetPulse→
  éventuellement 2/3 selon Cfg_MaxAttempts).
- Chercher dans `git log` l'origine du câblage sur `GVL_Simulation` (commit
  d'introduction de `instAutoResetTransientDiag` dans `PRG_02_Acquisition.st`)
  pour comprendre si c'était volontaire (test/debug temporaire jamais finalisé)
  ou une erreur de câblage dès le départ.

## 4. Contraintes de conception

- **Pas de toggle IHM** — décision utilisateur explicite, ne pas proposer
  d'exposition opérateur.
- Défaut `TRUE` : la fonction doit s'activer automatiquement, sans réglage,
  dès l'import.
- Respecter strictement les gardes de sécurité déjà présentes dans le FB
  (`SafeCommon`, `EmergencyChainClosed`, `NOT MotionActive`, etc.) — ne
  toucher à aucune de ces conditions, seulement au câblage des 2 entrées
  `*Enable`.
- Vérifier `Cfg_MaxAttempts`/`Cfg_StabilizationTime`/`Cfg_InterAttemptTime`
  (aussi câblés sur `GVL_Simulation`, lignes 236-238) : même question — sont-ils
  censés être configurables en persistant, ou peuvent-ils rester en simulation
  s'ils ont des valeurs par défaut correctes (`1` tentative, `1s`/`1s`) ? À
  trancher avec preuve, pas par supposition.

## 5. Devoir de challenge

- Ne pas supposer que déplacer les flags suffit — vérifier qu'aucune autre
  dépendance cachée à `GVL_Simulation` n'existe pour ce FB (`SimulationModeActive`
  ou autre garde qui pourrait désactiver la fonction en dehors du mode
  simulation).
- Vérifier que le FB ne pose aucun risque une fois activé par défaut sur
  machine réelle (relire les commentaires de garde en tête de fichier :
  "ne reset jamais la chaîne AU, les sécurités mouvement, les codeurs de
  sécurité, les contacteurs, les freins").

## 6. Chantiers concurrents

- `CODE/M_MAIN/PRG_02_Acquisition.st` : vérifier `TASK_LOCKS.json` avant de
  commencer, plusieurs lots y ont touché récemment (T340 complément).
- `CODE/L_SIMULATION/GVL_Simulation.st` : vérifier verrous actifs.

## 7. Livrables attendus

- Preuve de fonctionnement du FB isolé (test CI ou simulation dédiée).
- Diagnostic écrit de la cause historique du câblage erroné.
- Diff réel (câblage corrigé + emplacement des flags).
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat TASK_CONTRACT_T352_*.yaml (C3, sécurité/diagnostic).
- TASKS.yaml mis à jour (T352), tag agent choisi/incrémenté par l'agent
  lui-même dans TASK_LOCKS.json.

## 8. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Ne pas toucher à la chaîne AU, aux sécurités mouvement, aux codeurs de
  sécurité, aux contacteurs ou aux freins — strictement hors périmètre de ce
  FB, garde déjà documentée dans son en-tête.
