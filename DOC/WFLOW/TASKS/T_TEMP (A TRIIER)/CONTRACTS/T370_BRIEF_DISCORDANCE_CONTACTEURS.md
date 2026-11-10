=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== INVESTIGATION D'ABORD — zéro code tant que le diagnostic n'est pas validé ===

## 1. Contexte

Mail client GCAM (2026-09-15) : *"Discordance contacteurs : première
détection validée en simulation. Si une commande est demandée alors que le
retour indique les contacteurs au repos, alarme puis SafeStop après 3s. Il
faut compléter les causes multiples de discordance avec suffisamment de
détail pour la maintenance en cas de blocage."*

Rappel terrain utilisateur (2026-09-21) : problème déjà rencontré
concrètement — **l'automate envoie une commande, mais les contacteurs de
puissance ne bougent pas physiquement.**

## 2. Pré-analyse déjà faite par l'orchestrateur (à vérifier, pas à répéter)

Le mécanisme existant, `FB_SyncContactor.st` (+ `ST_SyncContactorDiag.st`,
+ `FB_WinchSync.st`), compare **M1 contre M2** :

```
// ST_SyncContactorDiag.st:11-16
RelayFwdMismatch : BOOL; // TRUE = relais montée M1 <> M2
RelayRevMismatch : BOOL; // TRUE = relais descente M1 <> M2
Step1Mismatch    : BOOL; // TRUE = contacteur palier 1 M1 <> M2
...
```

**Hypothèse à confirmer/infirmer** : ce mécanisme détecte une **asymétrie
entre les 2 treuils** (M1 fait quelque chose que M2 ne fait pas, ou
inversement) — mais si **les deux treuils échouent de façon identique**
(ex. panne d'alimentation puissance générale, commande envoyée aux deux
contacteurs, aucun des deux ne répond), M1 = M2 = FALSE des deux côtés →
**aucune discordance détectée**, alors que c'est exactement le scénario
terrain décrit par l'utilisateur : "commande envoyée, contacteur au repos".

Recherche faite : `grep "CmdVsFeedback\|OrderVsFeedback\|FeedbackVsCmd"` sur
`CODE/H_TREUILS_BENNE/` et `PRG_04_Treuils_Benne.st` = **0 résultat** — pas
de mécanisme trouvé qui compare un ordre émis à SON PROPRE retour contacteur
(indépendamment de l'autre treuil).

**À vérifier absolument avant de conclure** : peut-être qu'un autre point du
code (ex. `FB_Safety_Winch.st`, ou une brique de diagnostic générale des
sorties E/S) couvre déjà ce cas par un autre mécanisme (surveillance E/S
générale, timeout de commande). Ne pas conclure au trou avant d'avoir
cherché partout.

## 3. Objectif de la tâche

1. **Confirmer ou infirmer** l'hypothèse ci-dessus par lecture complète du
   code (`FB_SyncContactor.st`, `FB_WinchSync.st`, `FB_Safety_Winch.st`,
   et tout autre mécanisme de surveillance de sortie/contacteur dans le
   projet — chercher large, pas seulement dans `H_TREUILS_BENNE`).
2. Si le trou est confirmé : cartographier précisément quel(s) signal(aux)
   existent déjà pour construire la détection manquante (ordre émis côté
   PLC vs retour contacteur réel), et proposer où l'ajouter sans dupliquer
   `FB_SyncContactor`.
3. Répondre au 2e point du mail : "compléter les causes multiples de
   discordance avec suffisamment de détail pour la maintenance" — lister
   toutes les causes distinctes qui devraient être distinguées
   (ex. contacteur collé, bobine grillée, alimentation coupée, fusible
   sauté, contact auxiliaire défaillant) et vérifier lesquelles sont déjà
   différenciables avec les signaux disponibles.

## 4. Devoir de challenge

- Ne pas se contenter de l'hypothèse de l'orchestrateur — la vérifier
  vraiment, avec preuve, et la contredire si elle est fausse.
- Vérifier `PRG_06_Outputs.st` (sorties physiques finales) — c'est peut-être
  là qu'une comparaison ordre/retour générale existe déjà, indépendamment
  de `FB_SyncContactor`.
- Chercher aussi côté benne (M2/treuil grappin) si un mécanisme équivalent
  existe pour ce 3e actionneur.

## 5. Livrables

- Rapport écrit : verdict (trou confirmé ou pas), cartographie des signaux
  existants, liste des causes de discordance à distinguer.
- **AUCUN CODE** dans ce lot tant que le diagnostic n'est pas remis et
  validé par l'utilisateur.
- Si le trou est confirmé et qu'une correction est ensuite demandée dans
  un lot séparé : proposer une esquisse d'approche (pas de code), à valider
  avant toute implémentation.

## 6. Contraintes non négociables

- Investigation en lecture seule stricte — zéro modification de `CODE/`.
- AUCUN COMMIT.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution, y compris pour contredire l'hypothèse de l'orchestrateur si
  elle s'avère fausse.
