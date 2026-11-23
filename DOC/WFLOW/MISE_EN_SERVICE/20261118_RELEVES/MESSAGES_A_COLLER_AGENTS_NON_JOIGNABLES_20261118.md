# Messages à coller — agents non joignables par messagerie (18/11/2026 08:39)

> Envoi par TORC-CC10 impossible : `SendMessage` répond « No agent named … is reachable » pour T417-C-AGY02, T432-CDX02, T431-CDX05, T430-CDX04 (sessions Antigravity et Codex, absentes de l'annuaire). Message commun ci-dessous, à coller dans chaque session par l'exploitant. Réponses : à coller ensuite dans la session de TORC-CC10.

## Message commun (remplacer les crochets)
> Point de situation, mise en service du 18/11. De : TORC-CC10 (orchestrateur hors catalogue) · À : [session] · tâche : [Txxx] · désignation : exploitant, oral, 2026-11-18.
> **Consigne de phase : étude et lecture seule d'abord ; rien n'est écrit ni lancé avant validation de l'exploitant, puis implémentation.**
> Réponds en 3 lignes : (1) où en est ta tâche et ce qui est commité, (2) ce qui te bloque, (3) ce que tu attends de l'exploitant. Rien à modifier ni à lancer sur la machine sans GO exploitant. Pas de redémarrage ni de purge des services 8081 / 8082. `RECU` + ta réponse suffisent, pas d'échéance fixée.

## Lignes à ajouter selon la session
- **T417-C-AGY02** : où en sont `PRG_03` (page 8, mapping pages vers modes), le DiffBundle, le correctif de la cause 6 de `FB_Safety_Translation` (retrait de `DriveStatusWord.0`, ajout de `DriveOnline`) : écrit, commité, importé, ou en attente d'un GO ? Le commit `e75d1e08` (18/11 08:23, refonte homing, 20 fichiers `CODE/` dont `FB_Safety_Winch.st`, `PRG_03`, `PRG_04`) chevauche-t-il ton lot ?
- **T432-CDX02** (commandes de session du Superviseur) : ne redémarre ni ne purge aucun service sans informer l'exploitant.
- **T431-CDX05** (Superviseur, coordination du workflow T427) : T427-CC02 doit livrer un plan avant 10:00 ; dis-moi si ta coordination recoupe son périmètre.
- **T430-CDX04** (organisation documentaire du code) : ne déplace, ne renomme ni ne supprime rien dans `DOC/WFLOW/MISE_EN_SERVICE/` ni `DOC/WFLOW/TASKS/T377_*`.
