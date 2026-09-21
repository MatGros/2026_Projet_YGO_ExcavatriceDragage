=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT (ou relais T364 si même acteur) ===

## 1. Contexte

Deux séquenceurs (grafcets) existent dans le projet, pilotés par des FB
différents :

- **Homing** (`FB_CycleMachineHoming.st`, états `HX0`...`HX7`, refonte T364
  en cours) — objet de ce brief.
- **Cycle automatique** (`FB_CycleSemiAuto.st`, états `AX0`...`AX18`) —
  déjà mature, structure éprouvée (forçage de step T358, textes IHM,
  gestion joystick, homme-mort).

Demande utilisateur 2026-09-21 : **ne pas faire quelque chose de trop
différent entre les deux côtés** — le homing doit suivre les mêmes
conventions de conception que le cycle auto, pas réinventer un style
différent.

Constat complémentaire (déjà identifié, audit T364 point E6) : aucune
documentation à jour du grafcet homing n'existe — `AF_Partie-09` est
périmée (parle encore de HX0-HX6, avant T364).

## 2. Objectif

1. **Comparer** la structure de `FB_CycleMachineHoming.st` (après refonte
   T364) à celle de `FB_CycleSemiAuto.st` sur les points suivants :
   - Convention de nommage des états et des variables de transition.
   - Façon de gérer le geste opérateur (homme-mort, front, neutre requis
     ou pas) — le cycle auto a une doctrine "continuité sans à-coup"
     (joystick maintenu du début à la fin sans relâcher entre étapes) :
     le homing suit-il la même logique, ou une logique différente et
     pourquoi ?
   - **Textes opérateur en haut d'écran, PRIORITAIRE** : le cycle auto a
     `OperatorAction`/`CycleStateStr`, clairs, courts, cohérents à chaque
     étape. Vérifier que CHAQUE état du homing (HX0→HX7) a un texte
     équivalent, clair pour l'opérateur (pas de jargon type "datum"),
     dans le même style que le cycle auto. Lister chaque état homing et
     son texte actuel — signaler tout état sans texte ou avec un texte
     technique illisible.
   - Mécanisme de forçage de step (T358 existe côté cycle auto,
     `Cmd.SetForceStepTgt`) — le homing a-t-il un équivalent cohérent, ou
     doit-il en avoir un ?
   - Gestion des échecs/timeouts (le cycle auto a explicitement abandonné
     tout timeout de garde — le homing doit suivre la même doctrine).
2. **Documenter** la séquence homing actuelle (HX0→HX7) dans
   `AF_Partie-09_Fonction_Encoder_v2.4.md` (ou nouveau document dédié si
   plus approprié) : tableau états/transitions/conditions, à jour avec le
   code réel post-T364.
3. Lister les écarts de conception trouvés entre les deux séquenceurs et
   proposer, pour chacun, soit un alignement soit une justification
   explicite de la différence (certaines différences sont légitimes :
   le homing sollicite des actionneurs différemment du cycle de dragage).

## 3. Devoir de challenge

- Ne pas aligner aveuglément — si une différence est justifiée
  physiquement (ex. le homing n'a pas besoin du même mécanisme de
  forçage), le dire clairement plutôt que de forcer une similitude
  artificielle.
- Vérifier que le retrait de tout timeout de garde (déjà demandé sur T364)
  est bien cohérent avec ce que fait déjà le cycle auto.

## 4. Livrables

- Document de comparaison + document de séquence homing à jour (fichier
  réel, pas juste une réponse de chat).
- Liste des écarts avec recommandation par écart.
- Aucun code sans validation explicite des recommandations.

## 5. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
