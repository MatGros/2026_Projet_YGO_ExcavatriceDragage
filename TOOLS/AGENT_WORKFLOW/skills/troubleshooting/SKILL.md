---
name: troubleshooting
description: Diagnostic d'un incident ou d'un comportement inattendu dans le programme CODESYS. À charger pour une analyse causale structurée ; conserver une fiche quand elle sert au suivi, à la reprise ou à la conservation des preuves.
---

# Troubleshooting — diagnostic proportionné

Cette skill traite les incidents réels ou simulés du PLC. Elle n'impose ni un outil unique, ni une
fiche pour chaque question, ni une modification de code.

## Garde-fous

- Ne jamais modifier le code, forcer une variable ou piloter une machine sans autorisation et
  procédure explicites. Un test simulé ou un mock ne prouve pas le comportement terrain.
- Ne pas utiliser `Device.export` comme référence de l'état courant. S'appuyer sur le code versionné,
  la configuration fraîche fournie pour le diagnostic et les observations horodatées.
- Distinguer explicitement **fait**, **hypothèse**, **inférence** et **inconnu**. Une cause racine
  n'est confirmée que par une preuve qui la distingue des causes concurrentes.
- **Observations terrain** : un constat rapporté par l'exploitant est un postulat d'analyse immédiat,
  conservé tant que le code ou une trace ne le contredit pas. Une contradiction se signale et ne
  l'annule pas seule. Un chiffre donné de mémoire reste une hypothèse paramétrable.
- **Preuve manquante ≠ arrêt** : l'absence d'oscilloscope ou de traceur limite le verdict, jamais
  l'analyse. Si un diagnostic est demandé, produire un arbre court de causes physiques déduit du code
  et des principes électromécaniques, de la plus probable à la moins probable. Le résultat s'écrit
  « cause la plus probable », jamais « cause prouvée ». Pas de correctif tant qu'il n'est pas demandé.
- Respecter T279 : ne rien supprimer, déplacer ou nettoyer automatiquement.

## Choisir l'effort utile

1. Reformuler le symptôme et la décision à débloquer en une phrase.
2. Examiner les éléments déjà fournis et les sources directement concernées. Continuer l'analyse
   statique utile sans attendre une réponse lorsque cela ne dépend pas d'une donnée manquante.
3. Choisir la mesure la plus légère qui peut départager les hypothèses : code/chaîne de signaux,
   trace ou snapshot existant, test CI ciblé, puis acquisition live seulement si nécessaire et
   explicitement dans le périmètre.
4. Poser une question uniquement si une information absente change la méthode, la sécurité ou le
   verdict. Demander l'élément minimal et expliquer quelle décision il débloque.
5. Après deux essais non discriminants, revoir l'hypothèse et l'instrumentation avant de relancer.
   Pour une investigation à enjeu élevé, demander une revue indépendante selon le contrat.

## Fiche de diagnostic

Créer ou mettre à jour `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_<Sujet>_<AAAAMMJJ>.md`
à partir du gabarit existant si au moins un critère s'applique : investigation en plusieurs étapes,
reprise par un autre agent, preuve utile au-delà de la conversation, incident récurrent ou sujet de
sécurité. Une question simple ou une lecture ponctuelle reçoit une réponse directe, sans fiche.

La fiche, si créée, consigne : symptôme et périmètre, décision visée, hypothèses avec prédictions,
preuves et provenance, résultats, limites, verdict et prochaine action. Les acquisitions existantes
sont référencées sans être déplacées. Ne pas créer une seconde note si un document de tâche existant
porte déjà ces informations ; mettre à jour le document de référence.

## Délégation

Déléguer seulement des branches indépendantes dont le résultat peut accélérer ou améliorer la
décision. Fournir le brief complet via `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`, les
critères mesurables, les preuves connues, les limites, les permissions et l'auto-revue demandée.
Les reviewers sont read-only. Le responsable vérifie chaque affirmation dans les sources réelles.

## Restitution

Répondre avec :

1. **Acquis** — faits démontrés et preuve.
2. **Écart / incertitude** — hypothèses encore ouvertes et ce qui manque.
3. **Verdict** — cause prouvée, cause la plus probable (déduction), cause écartée ou diagnostic non concluant.
4. **Action suivante** — une action précise et l'information nouvelle qu'elle doit produire.

Références détaillées, cas de snapshot et méthode d'arbre inverse :
`TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`. Ne suivre que les sections pertinentes au cas.
