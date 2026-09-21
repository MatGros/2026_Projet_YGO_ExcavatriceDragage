=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== REFONTE MAJEURE — remplace BRIEF_T364_D1_REFONTE_ENTREE_HOMING.md ===

## 1. Contexte

Suite à l'audit T364 (`DOC/WFLOW/AUDITS/AUDIT_T364_HOMING_4_POINTS_20260921.md`,
16 écarts trouvés). L'exploitant a fourni sa **spécification complète et
précise** de la séquence homing attendue, différente de la séquence
actuellement codée (`FB_CycleMachineHoming.st`, états `E_MachineHomingTxState`
actuels : HX0_REPOS, HX1_CHOICE, HX2_CLIMB, HX2N_NEUTRAL, HX3, HX3N,
HX4, HX5_BUCKET_COMMIT, HX7_LOCKED_REFERENCE, HXF_FAILED).

**Ce brief est une analyse de refonte, pas un correctif ponctuel** — l'écart
entre séquence existante et séquence demandée est large (nouveaux états,
nouvelle logique de couplage benne/treuils, nouvelles conditions).

## 2. Séquence cible EXACTE, telle que spécifiée par l'exploitant 2026-09-21

| Étape | Contenu demandé |
|---|---|
| **HX0** | Machine pas référencée (état initial) |
| **HX1** | Décision opérateur : fermer la benne ou pas, selon MAINT_N2. Action : tirer joystick pour fermer benne (`WinchSel=2`, FDC benne **désactivé** pendant cette action). Condition de sortie : benne fermée visuellement confirmée → **un seul appui bouton IHM** (pas 3 fois) |
| **HX1a** (nouvel état) | Après confirmation : bascule `WinchSel=0`, FDC benne **réactivé**. Référencement M1+M2, benne fermée. `M1 Homed=0` pas bloquant si impossible de sortir du cycle autrement |
| **HX2** | Monte les 2 treuils vers capteur haut (joystick tiré), **palier 1 MAX toujours** (pas d'autre palier autorisé) |
| **HX3** | Une fois en haut (capteur position TOP M1 ET M2), référence à nouveau M1+M2 "à la volée" sur la position de config (défaut `8.5`) |
| **HX4** | Stabilisation : confirmation codeur + benne homée. Attendu : position au-dessus de 8.5m (inertie). **Si échec** : retour en attente MAINT_N2 pour repositionnement + nouvelle tentative |
| **HX5 / HX6** | (à définir avec l'agent — rôle exact à clarifier avec l'exploitant si besoin, ne pas deviner) |
| **HX7** | Échec — acquittement (Reset) requis pour recommencer |

**Situation après HX4 réussi** : machine en position haute référencée,
fonctionnement normal repris. Deux cas possibles pour la suite :
- **Descente benne AUTO** → la benne s'ouvre automatiquement à la descente.
- **Descente benne PAS auto** → synchronisation des treuils, benne reste fermée.

## 3. Objectif de la tâche

1. **Cartographier l'écart exact** entre la séquence actuelle du code et
   cette spécification, état par état — un tableau comparatif précis
   (ancien état ↔ nouvel état ↔ ce qui change).
2. Identifier tous les points de la spec qui restent ambigus ou à préciser
   avec l'exploitant AVANT toute conception détaillée (ex: rôle exact de
   HX5/HX6 dans la nouvelle séquence, comportement exact si HX4 échoue
   plusieurs fois, articulation avec HX7 tel que décrit ici vs HX7 actuel
   qui est un état "verrouillé" dans le code existant — collision de nom
   à lever).
3. **E1 (couplage M1/M2) DOIT être résolu dans ce lot, pas juste documenté.**
   Le code actuel (`HX2_CLIMB`, commentaire `:716-721`) montre qu'en
   MAINT_N2 c'est le joystick opérateur via l'arbitrage aval qui commande
   réellement les treuils — l'arbitrage ne consomme la demande du cycle
   qu'en SEMI_AUTO. `WinchSel=0` demandé par l'exploitant à HX1a doit être
   **prouvé comme réellement appliqué en aval** avant tout mouvement HX2 —
   sinon HX2 reproduit le même trou de sécurité sous un nouveau nom. Preuve
   par test CI que les 2 treuils montent bien ensemble, pas une simple
   relecture de cohérence. E2 (commit benne non vérifié) et E15/E16 (bypass
   benne) : vérifier leur statut dans la nouvelle séquence, signaler si
   résolus ou s'ils restent des sujets séparés.
4. Produire un document de conception (nouvel état-machine complet, table
   de transition) **avant tout code**.

## 4. Devoir de challenge

- Ne rien deviner sur les points ambigus (ex: HX5/HX6, comportement exact
  échec HX4) — les lister explicitement comme questions ouvertes pour
  l'exploitant, ne pas combler par supposition.
- Vérifier que "FDC benne désactivé pendant HX1" est un risque assumé (la
  benne est manoeuvrée sans fin de course logicielle) — le documenter
  clairement comme dérogation consciente, pas comme un détail anodin.
- Confirmer que le principe validé (référencement = MAINT_N2 uniquement,
  `T185:104-107 APPROVED`) reste respecté dans cette nouvelle séquence.
- **3bis — OBLIGATOIRE, différent de l'existant** : le code actuel désactive
  déjà le FDC benne SANS FDC logiciel, mais uniquement à `HX4_BUCKET_ADJUST`
  (`:647`), c'est-à-dire APRÈS que M1/M2 soient référencés. La spec
  exploitant demande de le faire à HX1, AVANT toute référence encodeur —
  benne pilotée à l'aveugle, sans FDC logiciel ET sans position encodeur
  fiable. Vérifier s'il existe une **butée mécanique indépendante du
  logiciel** protégeant la benne dans cette phase — pas juste documenter
  "dérogation consciente", vérifier physiquement/dans les specs qu'une
  telle butée existe avant d'accepter ce risque dans la conception.
- **3ter** : la référence "à la volée" à HX3 sur la position de config
  (8.5m) hérite du même risque que T301 (calibration terrain jamais faite,
  cf. `DOC/WFLOW/CONTRACTS/PROCEDURE_CALIBRATION_ODOMETRIE_M3_T301.md`) —
  si la cote physique du capteur diverge de la config, l'erreur devient
  systématique et invisible. Croiser explicitement ce point avec T301 dans
  le document de conception, ne pas le traiter isolément.

## 5. Livrables

- Document de conception complet : nouvelle table d'états, transitions,
  conditions, comparaison avec l'existant, questions ouvertes listées.
- **AUCUN CODE** dans ce lot — analyse et conception seulement.

## 6. Contraintes non négociables

- AUCUN CODE avant validation complète de la conception par l'exploitant.
- AUCUN COMMIT.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) sur l'état
  actuel du code, dans la même restitution.
