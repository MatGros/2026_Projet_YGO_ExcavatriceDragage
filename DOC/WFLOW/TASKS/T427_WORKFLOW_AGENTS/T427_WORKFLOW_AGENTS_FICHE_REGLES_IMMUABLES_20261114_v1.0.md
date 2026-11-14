# 📘 Fiche de règles immuables — T427 (v1.0, 2026-11-14)

**Principe :** une règle est immuable seulement si **un mécanisme de code l'impose** et que ce mécanisme est **vérifié**. Sinon, c'est une consigne, et elle est contournable.

**Légende :** ✅ en place et vérifié · ⚠️ partiel · ❌ absent · 🔧 à faire

---

## 🧭 1. Principes de base

- **P1 — Le code bloque, le LLM propose.** Toute règle de sécurité ou d'ordre passe par un script ou un hook. ⚠️
- **P2 — Fail-closed : une erreur de contrôle arrête le travail.** Sur un hook `command` ou `http`, il faut `"onFailure": "block"` (Claude Code v2.1.295 ou plus). Un `exit 1` ne bloque pas : il faut `exit 2`. ❌ 🔧
- **P3 — Un agent ne valide jamais son propre travail.** Le validateur est un humain, ou un outil séparé enregistré par le code. Un LLM du même type seul ne suffit pas. ❌ 🔧
- **P4 — L'agent ne modifie pas ses garde-fous.** Hooks, settings, scripts de contrôle et registres sont hors de sa portée d'écriture, avec empreinte vérifiée. ❌ 🔧

## 🔒 2. Règles de code (immuables)

**Étapes**
- **4 — Ordre fixe** : cadrage → étude → réalisation → test → restitution. Un saut est refusé par script. ⚠️
- **5 — Passage d'étape** : un script vérifie la précondition avant de faire avancer l'étape. ⚠️

**Périmètre et écriture**
- **7 — Écriture hors périmètre bloquée**, sauf dérogation enregistrée. ⚠️ Le hook `PreToolUse` ne couvre que Write et Edit. Bash doit passer par une liste blanche, ou être bloqué. ❌ 🔧
- **8 — Pas d'écriture en production sans validation humaine enregistrée**, dans un registre que l'agent ne peut pas écrire. ❌ 🔧
- **9 — Pas de commit ni de push sans accord humain explicite.** Le pre-push est aujourd'hui informatif et non bloquant : à corriger. ❌ 🔧

**Attente et clôture**
- **14 — Si l'agent attend une réponse, il ne peut pas conclure le tour.** ❌ Le Stop hook actuel ne contrôle que la liaison rouge et le bundle périmé (`AGENTS.md`, ligne 275). Il faut un contrôle d'état, pas une lecture du texte. 🔧
- **15 — La clôture d'un constat ou d'une tâche est réservée à l'humain ou au juge.** Un état verrouillé, pas une phrase. ❌ 🔧

**Mémoire**
- **17 — Toute décision s'appuie sur une source localisable** (fichier, identifiant, horodatage). ⚠️

**Dégradation**
- **19 — Un contrôle en erreur, en timeout ou en sortie invalide bloque l'étape** (voir P2). ❌ 🔧

**Garde-fous supplémentaires**
- **Intégrité** : l'agent ne peut pas modifier hooks, settings ni scripts de contrôle. ❌ 🔧
- **Réinjection** : les règles immuables sont réinjectées après compaction du contexte. ❌ 🔧

## 📜 3. Consignes (déclarées contournables)

Ces règles reposent sur la bonne volonté de l'agent. Elles ne sont pas immuables.

- **3 — Pas d'auto-attribution de rôle ou de tâche.** Le rôle se lit dans l'état enregistré.
- **6 — Une étape n'est finie qu'après acceptation par un juge.** Tant que le juge n'est pas défini par code, c'est une consigne.
- **10 — Ne jamais réécrire un choix de l'humain** (titre, nom, décision) sans demande.
- **11 — Un résultat annoncé est accompagné de la sortie brute**, dans le même message.
- **12 — Aucun chiffre repris d'un tour précédent** sans nouvelle exécution.
- **13 — Un échec se signale tel quel**, avec sa sortie.
- **16 — Toute affirmation sur ce que l'humain a dit est citée** avec l'identifiant du message.
- **18 — Ce qui est hors fenêtre n'est pas considéré comme vu.**
- **20 — Un doute est une hypothèse étiquetée**, jamais une certitude.

⚠️ Les règles **11, 12, 13, 16, 18 et 20** n'ont été confirmées par aucune source externe. Ce sont des choix de projet, à assumer comme tels.

## 🔎 4. Ce qui est vérifié, et ce qui ne l'est pas

✅ **Vérifié dans la doc officielle des hooks** (`code.claude.com/docs/en/hooks`) :
- Par défaut, un hook en erreur **ne bloque pas** l'action.
- `onFailure: "block"` existe sur `command` et `http`, à partir de v2.1.295.
- `exit 1` est un piège : non bloquant, sauf avec `onFailure`.
- Sur `PreToolUse`, un hook expiré ne bloque pas par défaut.
- `PreToolUse`, `UserPromptSubmit` et `Stop` peuvent bloquer avec `exit 2`.

✅ **Vérifié dans `AGENTS.md`** : le Stop hook ne contrôle que la liaison et le bundle.

⚠️ **Signalé par l'expert, non vérifié** : le hook `PreToolUse` ne couvre que Write et Edit, et Bash n'est pas couvert.

## 📚 Sources

- [Hooks reference, Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [OWASP, LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
