=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== INVESTIGATION D'ABORD — FB de sécurité, zéro code avant validation humaine ===

## 1. Contexte

Trouvé par l'orchestrateur pendant un test live de l'utilisateur (2026-09-21, tests réels sur
machine) : blocages/défauts inattendus pendant la montée homing (HX2, avant d'atteindre le
capteur haut), suspectés liés au FDC logiciel qui resterait actif pendant la montée alors qu'il
devrait être désactivé pendant tout le référencement.

## 2. Constat technique (orchestrateur, à vérifier en entier par l'agent)

`InReferencingMode` (VAR_INPUT de `FB_Safety_Winch.st:40`) désactive le FDC logiciel et
d'autres gardes pendant le référencement (`FB_Safety_Winch.st:576/581`, entre autres) :
```
OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM)
    AND NOT (BypassGlobal OR BypassTopLimitSoftware))
```

Câblage source (`PRG_04_Treuils_Benne.st:949/1018`) :
```
InReferencingMode := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy,
```
(idem M2, ligne 1018)

`HomingLifecycle.Busy` (`FB_Encoder_Homing.st:289`) :
```
Lifecycle.Busy := PresetVerificationActive;
```

**Hypothèse à vérifier** : `PresetVerificationActive` n'est vrai que pendant l'instant bref de
la prise de référence elle-même (le franchissement du capteur, HX3), **pas** pendant toute la
montée HX2 qui précède. Si c'est confirmé : pendant HX2, si la machine était déjà `Homed=TRUE`
d'une session antérieure et que la position mémorisée (`CablePosM`) est déjà au-delà de
`TopLimitM`, le FDC logiciel peut encore agir et arrêter/faire fauter la machine **avant même
d'atteindre le capteur** — ce qui correspondrait aux blocages constatés en re-homing.

## 3. Objectif de la tâche

1. **Confirmer ou infirmer précisément** : lire `FB_Encoder_Homing.st` en entier pour établir
   exactement quand `PresetVerificationActive` passe TRUE/FALSE, et comparer avec les étapes
   réelles du grafcet `FB_CycleMachineHoming.st` (HX2_CLIMB_COUPLED vs HX3_FLYING_REFERENCE) —
   preuve fichier:ligne pour chaque affirmation.
2. Si confirmé : cartographier TOUTES les gardes de `FB_Safety_Winch.st` qui dépendent de
   `InReferencingMode` (pas seulement TopLimitM ligne 581 — voir aussi lignes 310, 319, 378, 422,
   440, 565, 576) et dire pour chacune si le même trou s'applique.
3. Vérifier si le grafcet homing (`FB_CycleMachineHoming.st`) a lui-même un moyen de forcer
   `InReferencingMode` pendant HX1A/HX2/HX3 (peut-être un autre chemin existe déjà et le
   problème est ailleurs) — ne pas conclure au trou sans avoir cherché large.
4. Proposer une correction précise (fenêtre `InReferencingMode` élargie à toute la séquence
   HX1A→HX4, pas seulement l'instant de calage) — **conception seulement, pas de code**.

## 4. Devoir de challenge

- C'est un `FB_Safety_Winch.st` — vérifier qu'élargir `InReferencingMode` ne désactive pas une
  protection qui doit rester active même en référencement (ex. survitesse, mou de câble) — lister
  précisément ce que chaque garde citée au §3.2 protège avant de proposer de la neutraliser plus
  longtemps.
- Vérifier si le cas réellement vécu par l'utilisateur (re-homing avec ancienne position mémorisée
  au-delà de la nouvelle limite) est plausible avec les valeurs réelles de `TopLimitM`/persistant,
  ou si c'est un autre mécanisme qui a bloqué (ne pas forcer la conclusion).

## 5. Livrables

- Rapport écrit : preuve fichier:ligne de la fenêtre `InReferencingMode`, cartographie des gardes
  concernées, verdict sur la plausibilité du scénario terrain.
- Proposition de correction précise (pas de code) si le trou est confirmé.
- **AUCUN CODE** dans ce lot tant que le diagnostic n'est pas remis et validé par l'utilisateur —
  c'est un FB de sécurité, l'arbitrage doit être humain et explicite.

## 6. Contraintes non négociables

- Lecture seule stricte — zéro modification de `CODE/`.
- AUCUN COMMIT.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même restitution.
- Vérifier `TASK_LOCKS.json` avant de commencer (collision possible avec T370 sur `FB_Winch.st`
  domaine voisin, ou d'autres lots treuils actifs ce soir).
