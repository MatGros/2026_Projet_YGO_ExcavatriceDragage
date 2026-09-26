# Mission DSH — T374 — conditions MAINT_N2 existantes

> Avant transmission : coller **intégralement en tête** le contenu de
> `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`. Ce brief vient ensuite.
> Contrat obligatoire : `TASK_CONTRACT_T374_DSH_CONDITIONS_EXISTANTES.yaml`.

## Objectif

Analyser le code actuel avant de proposer une seule condition nouvelle. Le client veut piloter en MAINT_N2 M1 seul, M2 seul ou M1+M2, dans chaque sens, par boutons IHM maintenus. Il accepte en principe AU/PowerCutOff, défauts variateur, interverrouillage de sens, cohérence frein/contacteurs, commande maintenue et absence de redémarrage automatique. **Ce sont des intentions à confronter au code, pas une liste à implémenter telle quelle.**

## Faits initiaux à vérifier, pas à recopier comme preuves

- Les six boutons sont déclarés dans `ST_MaintenanceN2Cmd.st:9-14` ; recherche CODE/ : seul lecteur trouvé, `PRG_07_Supervision.st:705-710` (`ActiveForcing`). Aucun raccordement moteur trouvé.
- Trois boutons frein sont lus par `PRG_06_Outputs.st:320-330` et vont aux sorties `:375/:384`.
- T259 est historiquement clos avec une déclaration de validation machine ; cette déclaration semble contredite par le code actuel. T273, T364 et T345 sont des scopes distincts.

## Analyse attendue

1. Lire `AGENTS.md`, standards, AF02/03/05/10, contrat ci-dessus et code réel. Prendre `git status --short` au début et à la fin.
2. Pour les six boutons, tracer **bouton IHM → arbitrage → FB treuil → safety → interlock final → PRG_06 → DQ**. Nommer exactement le premier maillon absent.
3. Relever les gardes **déjà présentes** à chaque étage, avec expression, fichier:ligne et conséquence pour M1, M2, Both, montée et descente. Séparer chemin moteur et desserrage frein.
4. Classer les protections envisagées : `présente`, `absente`, `non prouvée`. Examiner demandes opposées simultanées, joystick/cycle/homing actifs, perte du bouton, défaut puis retour de permission, et commande frein seul. Ne pas présumer qu'une condition nouvelle est souhaitable.
5. Comparer au moins deux points de raccordement possibles des boutons avec effets de bord sur conduite normale, homing et cycle. Proposer six cas de simulation ROUGE avant correction et la preuve de non-régression à exiger après un éventuel GO.
6. Remettre un rapport dans `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T374_DSH_CONDITIONS_EXISTANTES_20260922.md`, verdict et questions réellement bloquantes. **Arrêt avant CODE/**.

## Limites

Lecture seule de `CODE/` et des outils. Aucun code, test, gate, bundle, commit, push, suppression ou correction opportuniste. Un résultat de recherche n'est pas un essai CODESYS. Remonter immédiatement toute contradiction de sécurité ; l'orchestrateur valide le rapport et présente le plan à l'humain.
