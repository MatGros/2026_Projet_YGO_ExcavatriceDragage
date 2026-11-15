---
plan_project:
  schema: 1
  task_id: <T###_>
  updated_at: <AAAA-MM-JJ>
  milestones:
    - id: M0
      title: "Cadrage du plan"
      done_when: "Périmètre, étapes et critères de réussite consignés"
      execution: NOT_STARTED
      execution_by: ""
      evidence: ""
      execution_comment: ""
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
---

# <T###> — <TITRE DE LA TÂCHE>

> **Version** : v1.0 · **Date** : <AAAA-MM-JJ> · **Auteur** : <CCxx / agent>
> **Statut** : plan soumis à validation humaine — **aucune ligne de `CODE/` modifiée**
> **Contrat** : `DOC/WFLOW/.../TASK_CONTRACT_<T###>_*.yaml`
> **Parent / liens** : <T###, tâches absorbées, tâches voisines>

> Règle d'usage : **un seul plan par tâche** — les livrables de revue, challenge ou étude
> ne doivent PAS contenir « PLAN » dans leur nom (sinon `plan_project.py` refuse : plusieurs
> plans candidats). `DONE` décrit l'exécution ; seule une validation explicite avec
> **auteur + date** compte comme validée.

## 1. Besoin et résultat attendu

Lisible depuis la fiche + le contrat : le problème réel, le résultat mesurable attendu,
la doctrine tranchée (référence datée si décision exploitant).

## 2. Décisions exploitant (datées)

- <AAAA-MM-JJ> — <décision n°1 : valeur / bouton / doctrine>
- <AAAA-MM-JJ> — <décision n°2>

## 3. État réel du code (preuves)

Table courte **fait / preuve** — chaque fait ancré `fichier:ligne`, relis, pas d'hypothèse
sans mention. Conclure sur la portée réelle du refactor (ex. « le preset est déjà câblé ;
le travail porte sur le moment d'émission »).

## 4. Écarts constatés (contrat / docs, classés)

1. <écart — symbole mort, chemin périmé, polarité…> — preuve `fichier:ligne`
2. <écart corrigé à la source — dire quoi a été vérifié et où>

## 5. Séquence technique (touché vs inchangé)

- **Inchangés** : <états / FB / blocs>
- **Modifiés** : <états / FB / blocs> — <quoi change>
- **Nouveaux** : <états / vars / champs> — <règle de nommage NC-xxx appliquée>

## 6. Points à trancher avant code

- **D1 — <sujet>** (preuve `fichier:ligne`).
  - Option A (recommandée) : <…>
  - Option B : <…>
- **Dn — <sujet>** … (une décision = une ligne d'arbitrage exploitant, jamais tranchée par l'agent)

## 7. Périmètre fichiers + interdits

**Modifiables** : <liste exacte des 6-8 fichiers>
**Interdits sans accord explicite** : <FB de sécurité, codeurs, Device.export…>

## 8. Tests & preuves attendues

- **Scénarios** : <numérotés, chaque scénario = entrées, verdicts attendus, symbole observé>
- **Gates** : `generate_codesys_bundle.py` · `G200_check_linkage.py --report` · <gates ciblés>
  · `run_all_gates.py --palier C` + tous · diff bundle pour import rapide

## 9. Séquence de réalisation

1. <relecture/challenge du plan par un agent externe, lecture seule>
2. <correction du contrat — texte des AC, falsifiable>
3. <arbitrage D1-Dn par l'exploitant>
4. <implémentation sur contrat + plan corrigés>
5. <revue de diff par un autre agent + gates>
6. <restitution : diff réel, preuves brutes, bandeaux bundle/gates>
7. <recette CODESYS par l'exploitant — aucun commit sans accord explicite>

## 10. Points d'arrêt (liste fermée de ce lot)

- <doctrine ou cote remise en cause>
- <élargissement de périmètre non arbitré>
- <contrat non corrigé, ou décision Dn non tranchée>
