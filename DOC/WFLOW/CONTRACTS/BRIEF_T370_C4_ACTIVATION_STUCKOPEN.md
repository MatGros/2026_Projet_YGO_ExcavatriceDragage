=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT (ou relais si même acteur que l'investigation T370) ===
=== PRÉPARATION IMPLÉMENTATION + CONTRAT — AUCUN COMMIT ===

## 1. Contexte

Investigation T370 (`BRIEF_T370_DISCORDANCE_CONTACTEURS.md`, déjà livrée) a confirmé un trou
réel : `FB_SyncContactor.st` ne compare que M1 vs M2 (asymétrie entre les 2 treuils), donc si
les deux tombent en panne de façon identique (commande envoyée, aucun des deux ne répond),
aucune discordance n'est détectée — c'est exactement le scénario terrain rapporté par
l'utilisateur.

Meilleure option trouvée (la moins chère, pas une réécriture) : `FB_Winch.st:311-318` a déjà
tout le nécessaire posé, en état "Phase 0" désactivé :

```
ContactorsCheck.Command  := NOT AllContactorsCommandedOff;
ContactorsCheck.Feedback := NOT Sensors.ContactorsAllOff;
TonContactorsDropped(IN := FALSE, PT := Config.ContactorFeedbackTimeout);
ContactorsCheck.StuckClosed := FALSE; // force a FALSE (Phase 0) : detection contacteur colle produite par FB_Safety_Winch, re-alimentee a la phase suivante
ContactorsCheck.StuckOpen := FALSE;
```

`ContactorsCheck.Command`/`.Feedback` comparent déjà l'ordre émis PAR CE TREUIL à SON PROPRE
retour — indépendamment de l'autre treuil. `TonContactorsDropped` est un timer déjà déclaré,
juste jamais câblé (`IN := FALSE`). `ContactorFeedbackTimeout := T#500ms`
(`ST_fbWinch_Cfg.st:28`) est le délai déjà prévu pour ce mécanisme.

## 2. Décision utilisateur actée avant cadrage

- **Diagnostic seul, pas de coupure de puissance automatique** — signal mono-voie (carte vue
  globalement, pas canal par canal), aucun PLr documenté dans le dépôt
  (`SAFETY_POLICY.md` = advisory-only), et précédent du revert 2026-09-02 (DI figé TRUE sans
  DI réel au banc) — ne jamais faire piloter une sécurité par ce type de signal sans
  vérification physique préalable.
- **Vérification terrain (bornier + LED/alarme incident) reportée APRÈS le code**, pas une
  précondition — recette humaine à faire une fois le lot livré.

## 3. Objectif de la tâche

1. Câbler `TonContactorsDropped` correctement : démarrer quand
   `ContactorsCheck.Command <> ContactorsCheck.Feedback` (mismatch commande/retour), s'arrêter
   dès que les deux se réalignent (mismatch levé sans attendre le timeout).
2. `StuckOpen := TonContactorsDropped.Q AND ContactorsCheck.Command AND NOT ContactorsCheck.Feedback`
   (commande active, retour absent, depuis plus de `ContactorFeedbackTimeout`).
3. Ne PAS toucher `StuckClosed` (commentaire dit explicitement que cette détection est produite
   ailleurs par `FB_Safety_Winch` — hors périmètre de ce lot).
4. Publier `ContactorsCheck.StuckOpen` là où un technicien peut le voir (vérifier si déjà
   exposé vers `GVL_Troubleshooting`/IHM via le bus de sortie de `FB_Winch`, sinon ajouter la
   publication minimale — pas de nouvelle logique de sécurité, juste rendre visible ce qui est
   calculé).
5. **Diagnostic uniquement** : ce signal alimente une alarme de maintenance, PAS une coupure de
   puissance ni un interlock de mouvement — ne jamais le câbler dans une chaîne de sécurité
   dans ce lot.

## 4. Devoir de challenge

- Vérifier qu'`AllContactorsCommandedOff`/`Sensors.ContactorsAllOff` ne produisent pas déjà un
  faux mismatch dans un cas normal (ex. transition palier, changement de sens) — un StuckOpen
  qui se déclenche à chaque changement de vitesse serait un nouveau faux positif, pas un
  diagnostic utile. Si un risque existe, le documenter et proposer un garde-fou (ex. n'armer le
  timer qu'à commande stable depuis N scans) avant de conclure la conception prête.
- Vérifier que réactiver ce mécanisme ne recrée pas le problème du revert 2026-09-02 (DI figé
  sans hardware réel au banc) — si `Sensors.ContactorsAllOff` dépend d'un DI potentiellement
  figé au banc de simulation, le signaler avant d'écrire le contrat.

## 5. Livrables

- Design précis du câblage (§3), preuve fichier:ligne de ce qui existe déjà vs ce qui manque.
- Contrat `TASK_CONTRACT_T370_STUCKOPEN.yaml` (C4).
- **AUCUN CODE ÉCRIT, AUCUN COMMIT** dans ce lot — préparation de l'implémentation et du
  contrat seulement, à valider par l'utilisateur avant la vraie écriture.

## 6. Contraintes non négociables

- Zéro affirmation non vérifiée — preuve fichier:ligne.
- Ne jamais proposer de faire de `StuckOpen` une entrée de sécurité/interlock dans ce lot.
- Vérifier `TASK_LOCKS.json` avant de commencer (collision avec T370 initial si même acteur).
