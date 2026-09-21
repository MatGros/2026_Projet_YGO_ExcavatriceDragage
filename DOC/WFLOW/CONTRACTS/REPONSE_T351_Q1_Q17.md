=== RÉPONSE ORCHESTRATEUR — T351 Q1-Q17 ===

« Défauts partout » APPLIQUÉ, avec 1 correction :

## Q3 (la seule sur laquelle tu ne pouvais pas trancher seul)

VÉRIFIÉ par l'orchestrateur — le correctif D18 EXISTE et est COMMITTÉ
(git log : `6f708b22` "credit du temps d'arret reel", `657be973` "purge
DeadTimeArmed atteignable", `e638308f` "corrige debordement TIME D18" —
tous `[NON TESTE MACHINE]` mais présents dans HEAD, confirmé par
`git show HEAD:CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st`).
`TASKS.yaml:969` est PÉRIMÉ (dit encore "analyse uniquement"), à corriger
séparément par l'orchestrateur.

**Documente D18 comme MÉCANISME CORRIGÉ, committé, non testé machine —
pas comme un écart ouvert.**

## Tout le reste : applique exactement le paquet "Défauts partout"

- **(a)** délégation DSH16 + ta re-vérification
- Contrat T351 écrit AVANT le code (`check_task_contract.py` PASS)
- Lignes réelles ancrées sur hash de commit + horodatage (Q5)
- Arbitres `FB_WinchCmdArbitrationM1`/`M2` inclus (Q7)
- 4 sources de demande tracées : joystick, boutons IHM, benne M2, cycle auto (Q8)
- Branches MAINT_N1/N2 incluses (Q9)
- Complément M3 en **ANNEXE séparée**, pas dans la fiche T334 (Q10, évite la
  collision avec DSH07)
- 2 chaînes avec colonnes M1/M2 + section asymétries réelles (Q11)
- Gabarit : document de référence "cartographie pure" (§3-4 T334 +
  convergence/divergence), PAS le gabarit troubleshooting complet (Q12)
- Nom en date compacte : `TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` (Q13)
- `TASKS_ORCHESTRATOR.yaml` mis à jour (Q14)
- Sous-agent s'auto-tag DSH16 dans `TASK_LOCKS.json`, tu poses 🔒+🚩 selon
  protocole task-planner (Q15)
- Override 8,5 m inclus dans le traçage (Q16)
- Phase 2 (outil web) capturée en tâche séparée dans `TASKS.yaml`, rien codé (Q17)

Zéro commit de ta part. Aucun des 37 fichiers modifiés non committés touché.
Pas de worktree isolé nécessaire (sur-engineering pour du read-only).
