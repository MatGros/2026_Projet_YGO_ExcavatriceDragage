# Test design T165 — contrats PRG_02 / PRG_03

> Plan de preuve C4. Les tests d'interface ne valent pas validation de sécurité machine ; les essais
> CODESYS/simulation et le recettage humain restent obligatoires.

## 🧪 Niveau 1 — tests de structure

| ID | Vérification | Résultat attendu |
|---|---|---|
| TS-01 | accès externes `PRG_02.inst*` | 0 après T165-B2 |
| TS-02 | accès externes `PRG_03.instCycleSemiAuto` | 0 après T165-C2 |
| TS-03 | producteur de `Data.Joystick`, `Data.Network`, `Data.ReqProgram` | exactement 1 PRG |
| TS-04 | noms de chaîne | aucune nouvelle consigne `*Ref`; `Req→Tgt→Cmd→Act` |
| TS-05 | frontières | PRG_03 ne publie ni `SafeStop`, ni `PowerCutOff`, ni sortie physique |
| TS-06 | POU principaux | nom fichier = nom POU ; `.st` = Structured Text dans bundle |

## 🎮 Niveau 2 — conservation manuelle

| ID | Scénario | Attendu invariant |
|---|---|---|
| TM-01 | M1 montée/descente manuelle | mêmes sens, palier/vitesse et arrêt au neutre |
| TM-02 | M2 montée/descente manuelle | mêmes sens, palier/vitesse et arrêt au neutre |
| TM-03 | M1+M2 couplés | même sélection et synchronisation |
| TM-04 | translation gauche/droite | même cible/sens et arrêt au neutre |
| TM-05 | relâche deadman pendant mouvement | `StartStop=FALSE`, décélération prévue, aucun redémarrage auto |
| TM-06 | perte bus joystick | demandes neutralisées, fault/diagnostic visibles |
| TM-07 | changement réel/simulation | aucune impulsion de mouvement ; source changée visible |
| TM-08 | codeur bus OP mais mesure incohérente | défaut qualifié identique en cycle/safety, mouvement refusé selon décision safety |

## 🤖 Niveau 3 — programme et concordance opérateur

| ID | Scénario | Attendu |
|---|---|---|
| TP-01 | étape demande montée, joystick neutre | demande programme visible, commande aval nulle, attente opérateur explicite |
| TP-02 | étape demande montée, joystick descente | commande aval nulle, raison « sens opposé » |
| TP-03 | geste correct sans deadman | commande aval nulle, raison deadman/arming |
| TP-04 | geste correct + deadman | mouvement seulement si interlocks PRG_04/05 valides |
| TP-05 | safety locale devient fausse | arrêt courant par PRG_04/05, indépendamment de PRG_03 N‑1 |
| TP-06 | changement de mode | demandes incompatibles neutralisées au scan validé, aucun redémarrage auto |
| TP-07 | erreur injectée en X1/X7 | étape fautive exacte mémorisée, pas étape de stabilisation |
| TP-08 | transition d'étape | toutes les anciennes demandes remises neutres avant nouvelles demandes |
| TP-09 | séquence Kobold | succès seulement après chronologie physique validée `0→1→0→1` |
| TP-10 | étape X11 | sens et ouverture conformes à l'AF humaine validée |

## 🖥️ Niveau 4 — maintenance et IHM

| ID | Vérification | Attendu |
|---|---|---|
| TI-01 | vue PRG_03 | mode, séquence, étape, attente opérateur, demandes par domaine lisibles |
| TI-02 | refus mouvement | niveau logique PRG_03 et blocage physique PRG_04/05 distingués |
| TI-03 | défaut | cause, étape au défaut, acquittement conscient visibles |
| TI-04 | aucune commande active | diagnostic distingue « aucune demande » de « demande bloquée » |

## 🔧 Niveau 5 — mécanique et compilation

Ordre obligatoire pour chaque lot d'exécution :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

Puis :

- `git diff --check` et `git diff --name-only` ;
- compilation ciblée via `TOOLS/COMPILER_ST2C_STruCpp` ;
- preuves dans `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/T165_*` ;
- simulation CODESYS manuelle par l'humain ;
- revue indépendante read-only sur le diff réel, jamais sur le seul rapport de l'exécutant.

## ✅ Règle de verdict

- **PASS** : tous les invariants et scénarios applicables sont prouvés ;
- **MAJOR** : interface/diagnostic incomplet sans régression démontrée ;
- **BLOCK** : doute sur deadman, sens, arrêt, interlock, Kobold, réarmement ou producteur unique.
