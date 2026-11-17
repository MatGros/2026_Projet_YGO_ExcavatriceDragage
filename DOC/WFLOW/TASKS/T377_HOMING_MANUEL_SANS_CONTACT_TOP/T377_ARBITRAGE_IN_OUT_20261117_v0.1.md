# T377 — Arbitrage revue « entrées/sorties » (glm + deepseek, 2026-11-17)

Verdict consolidé : **ADVISORY — aucun bloquant structurel ; delta v0.4 défini**.
Grille complète : glm = 11/14 transitions OP, 2 BLOQUE-SANS-MSG, 7 trous ; deepseek = 15 cas
manquants, 5 corrections. Les 2 rapports dans le dossier (`_REVIEW_IN_OUT_GLM/_DEEPSEEK_20261117`).

## RETENUS (delta v0.4 du brouillon)

1. **Purge des latches aussi sur Enable FALSE / coupure puissance** (les 2 agents) :
   `TopContactLatchedLoc` et `LastValidationRefused` purgés dans le gate §7 en PLUS de
   §4 (Reset. État HX0 sain au retour après reboot sans latch fantôme.)
2. **ClimbTimer expiré = abort vers HX7 avec cause dédiée (décidé)** — les 2 agents notaient
   INDEFINI. Justification physique : le budget = montée CONTINUE ; 300 s à 0,4 m/s = 120 m
   > course 58,5 m → l'expiration ne peut être qu'une anomalie (coinçage, capteur raté) →
   abort cohérent avec le mécanisme existant (ClimbTimedOut déjà dans TransactionAbort).
   Le budget rechargé à chaque relâche reste le design documenté (pause opérateur ne
   consomme rien) — pas un trou.
3. **Messagerie d'inopérance centralisée** (mapping §10 v0.4) : BtnValidation ignoré quand
   MachineHomed (« déjà référencé — utiliser Start ») · refus BtnHome unitaire en cycle ·
   garde skew KO en HX2 (où : « l'opérateur tire, rien ne bouge ») · WinchSel verrouillé.
   4 messages, un canal.
4. **Invariant purge écrit** : toute purge (Reset OU Enable FALSE) — sorties mouvement déjà
   à FALSE par la tête de scan AVANT toute réaction (§1 → §4 → §8) : « couper les permis
   d'abord » est structurellement vrai ; à écrire comme invariant testé, pas à coder.
5. **HX7 : causes d'entrée exposées** (déjà retenu hier ; confirmé par les 2 agents) :
   enum {ModeLost, HorsPhase, TimeoutHX3, VerifKO} + action affichée.
6. **Reset HX7 en mode N1 : réfuté le piège** — la purge §4 (`FB:294-304`) n'est PAS
   conditionnée au mode ; Reset conscient purge depuis ANY état. À documenter.
7. **Preset accidentel** : délibéré par design — relance possible via BtnStart SEUL (action
   consciente), et protégé par HX4 (bande 8,50 ±0,10 rejète une validation au mauvais
   endroit). Pas de gate de blocage supplémentaire : refuser une re-référence manuelle
   contredirait la doctrine T377 (ré-reference visuelle volontaire). Documenté.
8. HX3 : `HomeReq` = transaction preset (pas de mouvement, câblage PRG_02 confirmé) ;
   mouvement opérateur pendant HX3/HX4/HX5/HX6 → hors phase → abort HX7 (couvert). Tests
   dédiés du déclenchement opérateur pendant ces états ajoutés à la liste §8 du brouillon.

## RÉFUTÉS (avec preuve)

1. « Purge C8 non écrite » (glm) : écrite — `§3.5` clear au dégagement + `§3.2` purge
   ResetEdge ; seul le point Enable FALSE était ouvert → retenu 1.
2. « HX5 sans objet » : libellé/attente existants (mapping §10, 'HX5 - Relacher JOY au
   neutre') ; la transition est immédiate dès neutre+arrêt — pas d'attente piège.
3. « Reprise après relâche homme-mort en HX1 inconnue » : mécanisme permis identique HX2
   (montée benne sous BucketPermit ; relâche = ordre retombe, têtes de scan) — à écrire
   noir sur blanc dans la doc d'application (1 ligne), pas un défaut.
4. « BtnValidation sans effet MachineHomed TRUE silencieux » : le divértement existe ;
   seul le MESSAGE manquait → retenu 3.

## Statut

Brouillon v0.2 reste la base d'implémentation ; delta v0.4 = points 1-4 + messagerie ci-
dessus, appliqué aux docs avant le brief final. Aucun bloquant de sécurité structurel.
