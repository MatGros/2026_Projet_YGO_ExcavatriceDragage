=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Le forçage d'étape du cycle
semi-automatique (`FB_CycleSemiAuto.st:610-674`, piloté par
`GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget` + `Cmd.BtnForceStepApply`)
est jugé inutilisable par l'exploitant (2026-09-21) :

- Refusé au-delà du step 7 sans `KoboldImmersionQualified` (:653-655) et pour
  les steps 8-12 sans `BottomContextValid` (:656-658).
- Refusé si le cycle est en mouvement (`JoystickDeflected`,
  `DiveStartStopped`, :626).
- Mécanisme en 2 temps (préparation puis confirmation par Start joystick
  neutre) au lieu d'un forçage immédiat.

## 2. Décision utilisateur — RISQUE SIGNALÉ ET ASSUMÉ EXPLICITEMENT

⚠️ **L'orchestrateur a alerté l'exploitant avant rédaction de ce brief** :
retirer la garde `BottomContextValid`/`KoboldImmersionQualified` permet de
forcer un step de fermeture benne ou de remontée chargée **sans que
l'automate ait une référence terrain valide** (position fond/immersion
inconnue au moment du forçage).

**Réponse de l'exploitant, explicite et répétée après l'alerte** : la
protection doit venir d'un accès restreint (mot de passe/niveau d'accès sur
le bouton), pas d'une condition logique dans le FB. Le besoin métier cité :
scénario mi-cycle avec objet coincé dans la benne, nécessité de sauter une
étape immédiatement sans dialogue de confirmation. **Décision : retirer
toutes les conditions de blocage du forçage, sans exception.**

## 3. Objectif de la tâche (T358)

Remplacer le mécanisme actuel par un **step actif = une seule variable,
lecture ET écriture, saut immédiat sans condition ni confirmation** :

1. Une variable unique représente l'étape courante du cycle, lisible (valeur
   actuelle) ET écrivable (nouvelle valeur → saut immédiat au prochain scan,
   aucune condition, aucun garde-fou logique, aucune confirmation par
   joystick).
2. Retirer entièrement les gardes actuelles : `KoboldImmersionQualified`,
   `BottomContextValid`, `JoystickDeflected`, `DiveStartStopped`,
   `Fault.Latched`, restriction `Mode = SEMI_AUTO`, et le mécanisme
   préparation/confirmation (`ForceStepPrepared`/`ForceStepWaiting`/
   `WaitingResume`).
3. Garder uniquement la validation de plage (`CfgForceStepTarget` dans les
   valeurs d'énum `E_AutoCycleStep` valides — écrire une valeur hors énum ne
   doit pas planter le FB, mais rester rejeté silencieusement ou clampé).
4. La protection d'accès (mot de passe / niveau utilisateur) est **hors
   périmètre de ce lot** — à traiter côté IHM séparément si besoin, ne pas
   l'implémenter ici.

## 4. Devoir de challenge (à appliquer malgré la décision prise)

- Documenter dans le contrat de tâche et dans une note d'application la
  liste exacte des gardes retirées et leur rôle d'origine (traçabilité pour
  un futur audit sécurité) — ne pas juste supprimer silencieusement.
- Vérifier qu'aucune des gardes retirées n'est *également* utilisée ailleurs
  dans le FB pour une autre fonction (ex. `Fault.Latched` pourrait avoir un
  rôle plus large que le seul forçage) — si c'est le cas, alerter avant de
  toucher au code partagé.
- Vérifier si `KoboldImmersionQualified`/`BottomContextValid` sont eux-mêmes
  utilisés par d'autres logiques de sécurité du cycle (pas seulement le
  forçage) — ne toucher qu'à leur usage dans le bloc forçage, jamais à leur
  calcul ou à leur usage ailleurs.

## 5. Chantiers concurrents

- Vérifier `TASK_LOCKS.json` avant de commencer —
  `CODE/G_CYCLE/FB_CycleSemiAuto.st` a été modifié récemment (T347).

## 6. Livrables attendus

- Diff réel du bloc forçage simplifié.
- Note d'application listant les gardes retirées et leur rôle antérieur.
- Bundle + diff bundle + G200 --report + gates palier C.
- Contrat `TASK_CONTRACT_T358_*.yaml` (C4 — modification directe d'une
  fonction de commande sans garde de contexte).
- `TASKS.yaml` mis à jour (T358), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 7. Contraintes non négociables

- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Ne pas toucher à la chaîne AU ni aux sécurités mouvement indépendantes du
  forçage (hors périmètre strict de ce lot).
