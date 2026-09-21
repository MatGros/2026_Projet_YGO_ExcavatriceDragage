=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → RELAIS SUR T364 (même acteur si possible, verrou déjà posé) ===
=== URGENT — régression bloquante confirmée sur machine réelle ===

## 1. Bug observé

Au démarrage automate (PLC boot / redémarrage), **avant tout tentative de
homing**, l'IHM affiche directement :

> `Homing: HX7 - Homing incomplet - Acquitter Reset N2`

et exige un acquittement de défaut avant même de pouvoir initier le
grafcet. Confirmé absent avant T364 (régression introduite par la refonte,
commit `42fe45c8`).

## 2. Pistes déjà explorées par l'orchestrateur (pour accélérer, pas pour deviner)

- `SeqStep` (`FB_CycleMachineHoming.st:111`) a un défaut déclaré
  `E_MachineHomingTxState.HX0_REPOS` — donc à froid, sans RETAIN corrompu,
  il ne devrait PAS démarrer à `HX7_FAILED`.
- `MachineHomingFailed` (`:77`) est un simple `BOOL`, défaut `FALSE`.
- `CycleRunning := (SeqStep <> HX0_REPOS)` (`:213`, `:537`) — donc à
  `SeqStep = HX0_REPOS`, `CycleRunning = FALSE`.
- `TransactionAbort` (`:256-259`) exige `CycleRunning = TRUE` en premier
  terme du AND — donc ne devrait pas se déclencher tant que
  `CycleRunning = FALSE`.
- Le message observé vient de `:571-573` :
  `ELSIF MachineHomingFailed OR (SeqStep = HX7_FAILED) THEN ... 'HX7 - Homing incomplet...'`
- **Hypothèse principale à vérifier en premier** : `§3 Detection perte de
  datum` (`:262-281`) — `MachineWasHomed`, `AxesDatumRaw`,
  `MachineHomedRaw`, `ReHomingAckRequired`. Si une de ces variables (ou une
  variable en amont côté `M1Status.Homed`/`M2Status.Homed`) est **RETAIN**
  ou hérite d'un état persisté de l'ancien FB (avant la refonte T364,
  renumérotation de l'énum `E_MachineHomingTxState` — l'ancien `HX7` valait
  une chose différente de l'ordinal `8` actuel), la détection "perte de
  datum au premier scan" (`:267`, `FirstScanDone AND NOT MachineHomedRaw
  AND MachineWasHomed`) pourrait se déclencher à tort dès le premier scan
  après redéploiement, si `MachineWasHomed` a une valeur RETAIN héritée
  incohérente avec le nouveau schéma d'états.
- **Vérifier aussi** : tout autre point du fichier qui écrit
  `SeqStep := E_MachineHomingTxState.HX7_FAILED` (`grep`, au moins 6
  occurrences trouvées : `:424, :440, :456, :475, :494, :501`) — s'assurer
  qu'aucune de ces conditions n'est vraie dès le premier scan à froid.

## 3. Objectif

1. Reproduire en isolé (test CI) : premier scan après `Enable` monté,
   `SeqStep` initial `HX0_REPOS`, aucune donnée RETAIN corrompue — vérifier
   que le guide affiche bien un texte neutre ("non référencé", pas "échec/
   acquitter").
2. Si la cause est une variable RETAIN incohérente après renumérotation de
   l'énum : proposer soit une purge explicite au premier scan
   post-déploiement, soit un typage qui ne dépende jamais de l'ordinal brut.
3. Corriger, avec preuve rouge-avant/vert-après.

## 4. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO — la machine est en
  cours d'essai réel, chaque changement doit être vérifié avant tout
  redéploiement.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Réponse rapide attendue — c'est bloquant sur machine réelle actuellement.
