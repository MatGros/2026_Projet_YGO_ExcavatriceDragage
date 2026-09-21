=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== PHASE 1 : INVESTIGATION + POC — pas d'outil définitif avant validation ===

## 1. Contexte

L'utilisateur exporte/importe des configurations de trace CODESYS (fichiers `.trace`,
`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/*.trace`) — format confirmé : XML UTF-16,
racine `<Trace><TraceConfiguration>...`. Il a plusieurs dizaines d'exemples déjà enregistrés
dans le dépôt (variables, triggers, échelles) issus de sessions de debug réelles.

Idée : au lieu de configurer une trace à la main dans l'IDE à chaque nouveau besoin de debug
(ex. "je veux tracer le homing HX0-HX7"), générer automatiquement un fichier `.trace`
importable directement dans CODESYS, à partir d'une liste de variables + d'un trigger simple.

## 2. Objectif de la tâche

1. **Analyser le format réel** : parser 3-5 fichiers `.trace` existants et variés (au moins un
   avec plusieurs variables, un avec trigger configuré) pour documenter la structure XML
   exacte — quels champs sont obligatoires, comment un trigger (variable, condition, mode
   single/continu, pré/post-trigger) est encodé, comment chaque variable est référencée
   (chemin complet, type, échelle d'affichage).
2. **Écrire un script générateur** (`TOOLS/PLC_CSV_SNAPSHOT/scripts/generate_trace_template.py`
   ou équivalent) qui prend en entrée une liste de variables (chemins complets, comme celles du
   tableau homing déjà produit ce soir) + un trigger optionnel (variable, condition, mode), et
   produit un fichier `.trace` valide, structurellement identique aux exemples réels.
3. **Preuve de validité** : le fichier généré doit être importable dans CODESYS sans erreur —
   à défaut de pouvoir tester l'import réel (agent sans accès IDE), comparer byte-à-byte la
   structure XML générée contre un exemple réel équivalent (mêmes variables/trigger) pour
   prouver l'identité structurelle, pas juste "ça ressemble".

## 3. Méthode

- Lire plusieurs `.trace` réels pour couvrir la variabilité (nombre de variables différent,
  avec/sans trigger, types de variables différents BOOL/INT/REAL/STRING).
- Ne pas halluciner le format : si un champ n'est pas clairement compris depuis les exemples,
  le signaler comme "non prouvé" plutôt que de deviner sa syntaxe.
- Commencer par un POC minimal (1 variable, pas de trigger) avant de couvrir le cas complet
  (plusieurs variables + trigger + pré/post-trigger).

## 4. Devoir de challenge

- Vérifier qu'un simple export d'un fichier `.trace` "modèle" légèrement modifié (renommer les
  variables dedans) ne serait pas une solution plus simple et plus fiable qu'un générateur XML
  from-scratch — si c'est le cas, le dire clairement plutôt que sur-ingénierier.
- Vérifier s'il existe déjà un outil CODESYS officiel (script CLI, ScriptEngine) pour créer des
  traces par programme, qui serait plus robuste qu'un générateur XML maison.

## 5. Livrables

- Rapport : structure XML documentée, verdict sur l'approche la plus simple (générateur maison
  vs template modifié vs API CODESYS).
- Si générateur maison retenu : script + 1 exemple généré (ex. le tableau de variables homing
  produit ce soir) + preuve de comparaison structurelle.
- **Pas de modification de `CODE/`** — ce lot est un outil, hors périmètre PLC.

## 6. Contraintes

- Zéro affirmation non vérifiée sur le format XML — preuve par lecture réelle des fichiers.
- Pas de commit sans accord explicite.
