# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION T165-C2 : Migration des consommateurs PRG_04, PRG_05, PRG_07 vers PRG_03.Data et encapsulation privée de instCycleSemiAuto

## Objectifs du contrat (TASK_CONTRACT_T165-C2_PRG03_CONSUMERS.yaml)
1. **Remapper** toutes les lectures externes `PRG_03_Modes_Cycle.Auth` vers `PRG_03_Modes_Cycle.Data.Auth`.
2. **Remapper** toutes les lectures externes `PRG_03_Modes_Cycle.instCycleSemiAuto.*` vers :
   - `PRG_03_Modes_Cycle.Data.ReqProgram.*`
   - `PRG_03_Modes_Cycle.Data.SequenceState.*`
3. **Encapsuler** `instCycleSemiAuto` en `VAR` privé dans `PRG_03_Modes_Cycle.st`.
4. **Vérifier** qu'il n'existe plus aucun accès `PRG_03_Modes_Cycle.inst*` ni `PRG_03_Modes_Cycle.Auth` dans l'ensemble de `CODE/`.

## Fichiers consommateurs à auditer et modifier
1. `CODE/M_MAIN/PRG_04_Treuils_Benne.st`
2. `CODE/M_MAIN/PRG_05_Translation.st`
3. `CODE/M_MAIN/PRG_07_Supervision.st`
4. `CODE/M_MAIN/PRG_03_Modes_Cycle.st`

## TA MISSION D'AUDIT PRÉALABLE
Pour chacun des 3 fichiers consommateurs (PRG_04, PRG_05, PRG_07) :
1. Établir la liste exacte des lignes contenant `PRG_03_Modes_Cycle.*`.
2. Définir le remplacement exact vers `PRG_03_Modes_Cycle.Data.*`.
3. Signaler toute anomalie ou ambiguïté sémantique.
