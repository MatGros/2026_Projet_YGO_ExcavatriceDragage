=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== URGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Mail client GCAM du 2026-09-15
(DOC/WFLOW/REGISTRES/REGISTRE_MES_Rapport_Mail_GCAM_20260915.md) demande un seuil
configurable de % d'ouverture benne autorisant le début de la remontée AX10→AX10b
avant fermeture totale (transition en grappin, pour soulager M2 seul).

Le paramètre IHM existe depuis longtemps (`GVL_IHM.CycleSemiAuto.Cfg.
ExtractionStartOpening_Pct`, `ST_CycleCfg.st:12`, borné 0..50 % dans
`PRG_07_Supervision.st:239`) mais N'EST CÂBLÉ NULLE PART dans la logique de
transition. Vérifié 2026-09-21 (orchestrateur) : aucune occurrence en dehors
de sa déclaration et de son bornage.

Le comportement réel actuel utilise un seuil FIXE codé en dur :
`PRG_04_Treuils_Benne.st:1789-1794` :
```st
// Tolérance matière benne : « à peu près fermée » = fermée OU
// intermédiaire proche de l'offset fermé (tolérance 2 m). Évite le blocage au fond sur
// matière dense (galets) qui ne ferme jamais à 100% de la consigne fine.
Benne_IsRoughlyClosed := _BucketState.IsClosed
    OR (_BucketState.IsIntermediate
        AND (instBucket.DeltaPosition_M >= (_BucketCfgPersist.Config.OffsetCloseM - 2.0)));
```
C'est `Benne_IsRoughlyClosed` (pas `ExtractionStartOpening_Pct`) qui autorise
réellement la transition AX10→AX10b aujourd'hui. Confirmé fonctionnel en réel
par test utilisateur 2026-09-20 (palier lent, pas d'à-coup) — mais le champ IHM
promis par T262 reste un champ mort, l'opérateur ne peut RIEN régler.

## 2. Objectif de la tâche (T262 Phase B)

Câbler `ExtractionStartOpening_Pct` (%) pour qu'il pilote réellement le seuil de
transition AX10→AX10b, à la place ou en complément de la tolérance fixe 2,0 m
actuelle.

## 3. Décision de conception à trancher (challenge obligatoire, pas d'improvisation)

Le seuil actuel est exprimé en **mètres** (`DeltaPosition_M >= OffsetCloseM - 2.0`),
le paramètre IHM est exprimé en **pourcentage** (`ExtractionStartOpening_Pct`,
0..50 %). Il faut définir la conversion :
- % de QUOI exactement ? Pourcentage d'ouverture de la benne (0% = fermée,
  100% = grande ouverte) ? Si oui, il faut la plage complète OffsetOpenM..
  OffsetCloseM pour convertir un % en position mètres équivalente.
- Le commentaire du code dit "évite le blocage au fond sur matière dense
  (galets) qui ne ferme jamais à 100%" — la logique métier réelle a une raison
  physique précise, à ne pas casser en remplaçant bêtement le nombre.
- Si `ExtractionStartOpening_Pct = 0` (valeur par défaut actuelle), le
  comportement DOIT rester strictement identique à aujourd'hui (tolérance 2,0 m
  historique) — c'est explicitement écrit dans le commentaire du champ
  (`ST_CycleCfg.st:12` : "0 = critère historique").

## 4. Localisation exacte

- `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st:12` — déclaration
  du paramètre (déjà existant, ne pas toucher à sa déclaration sauf besoin
  avéré).
- `CODE/M_MAIN/PRG_07_Supervision.st:239` — bornage 0..50 (déjà existant).
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1789-1794` — logique à modifier
  (`Benne_IsRoughlyClosed`).
- `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` — vérifier `OffsetOpenM`/
  `OffsetCloseM`/`DeltaPosition_M` pour la conversion %→m.

## 5. Contraintes non négociables

- **Non-régression stricte à `ExtractionStartOpening_Pct = 0`** : comportement
  identique à aujourd'hui (tolérance 2,0 m), prouvé par test avant/après.
- Ne pas casser la protection anti-blocage sur matière dense (raison physique
  documentée dans le commentaire existant) — comprendre pourquoi 2,0 m a été
  choisi avant de généraliser.
- Le mail client dit explicitement "à simuler avant toute mise en réel" — donc
  simulation + tests CI d'abord, pas de changement direct sur machine.
- Chaîne complète à vérifier : AX10 → AX10b (raccordement P1) → AX11 (montée
  contrôlée palier IHM 1..2) → AX12 (remontée en charge) — ne pas casser cette
  continuité déjà validée fonctionnelle en réel le 2026-09-20.

## 6. Chantiers concurrents (verrous actifs au moment du brief — à revérifier)

- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` : vérifier `TASK_LOCKS.json` au moment
  de la prise, plusieurs lots y ont touché aujourd'hui (T291-B, T346).
- Aucun autre agent connu explicitement sur cette zone précise (§8 tolérance
  benne) au moment du brief.

## 7. Livrables attendus

- Diff réel + décision de conception documentée (§3 tranchée avec preuve).
- Test CI rouge→vert : comportement à 0% identique à l'historique, comportement
  à une valeur non-nulle qui déplace réellement le seuil de transition.
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat TASK_CONTRACT_T262_PHASE_B_*.yaml (C4, mouvement machine).
- Mise à jour TASKS.yaml (T262), tag agent choisi/incrémenté par l'agent
  lui-même dans TASK_LOCKS.json.

## 8. Contraintes de commit

- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Criticité C4 (mouvement machine réel, benne+treuils) : contrat obligatoire
  avant tout code, comme toute tâche C4 du projet.
