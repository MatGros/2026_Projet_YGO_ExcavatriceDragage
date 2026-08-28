# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION : Revue formelle T165-C1 — Publication PRG_03.Data

## Objectif
Auditer le code final produit pour T165-C1 et donner le verdict final (PASS / BLOCK).

## Fichiers à auditer
1. `CODE/M_MAIN/PRG_03_Modes_Cycle.st`
2. `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesCycleInterPrg.st`
3. `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramRequest.st`
4. `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_SequencePublicState.st`
5. `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/E_ProgramSequence.st`

## Preuves fournies
- Tests unitaires CI `M_MAIN` : 7/7 PASS (dont `PRG_03_Modes_Cycle` 5/5 PASS)
- Bundle PLCopenXML : frais et valide
- G200 Linkage : PASS (0 erreur)
- 22 Gates : 22/22 PASS (G430 PASS)

## Vérifications demandées
1. **Conformité contrat** : Data contient Auth, ReqProgram, SequenceState.
2. **Absence Safety dans ReqProgram** : vérification qu'aucun ordre physique/safety n'est présent.
3. **Neutralisation déterministe** : bloc ELSE complet mettant toutes les demandes et états à neutre hors SEMI_AUTO.
4. **Ordre ST** : `instModes` -> `instCycleSemiAuto` -> Publication `Data`.

Donne ton verdict formel avec justification concise.
