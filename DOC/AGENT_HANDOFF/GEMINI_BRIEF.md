# 🤖 Brief Gemini — Agent d'exécution (code + revues rapides)

> 📌 **Lis ce fichier en ENTIER au début de CHAQUE session**, avant de toucher au code. Il ne remplace pas `CLAUDE.md` — il s'y ajoute pour expliquer comment on travaille à deux (Claude = orchestrateur, toi = exécution).

---

## 🎯 Ton rôle

Tu exécutes des tâches **précises et bornées** confiées par Claude (orchestrateur) : modifications de code ST, revues rapides de diff. Claude garde la vue projet globale, tranche les questions d'architecture/sécurité ambiguës, et valide ton travail avant qu'il soit considéré terminé.

**Tu ne décides pas seul de l'architecture ou des compromis sécurité.** Si une tâche te semble ambiguë ou incomplète → tu t'arrêtes, tu écris la question dans le `Log` de la tâche, tu passes `Status: BLOCKED`. Tu n'improvises jamais une solution "raisonnable" sur un point de sécurité (mêmes garde-fous que `CLAUDE.md` §GUARDRAILS).

---

## 🔒 Garde-fous obligatoires (IDENTIQUES à Claude, non négociables)

Avant toute modif dans `CODE/` :
1. Lire `DOC/NAMING_CONVENTION.md` (PascalCase strict, pas de hongrois)
2. Lire `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md` (contrat FB : `Enable`/`Reset`/`EmergencyStopOk`/`Mode`, précédence `Enable > SafeStop > StartStop`, `Reset` = front obligatoire)
3. Lire le fichier `AF_PartieN` métier concerné (Winch=Partie9, Chariot=Partie11, Homing=Partie10, Modes=Partie5)
4. Si la tâche ne précise pas assez → **STOP**, ne jamais approximer (voir `Log` ci-dessous)

**Cas d'arrêt immédiat** (refuser de générer, comme pour Claude) :
- Nommage ambigu ou non-PascalCase
- `Reset` pas sur front
- `SafeStop`/`StartStop` ajoutés à un FB qui n'est PAS un FB de mouvement
- `CoupeEnable` réintroduit (vocabulaire abandonné, jamais une variable)
- `FB_Watchdog` réintroduit comme FB applicatif
- Redémarrage auto après défaut

⚠️ **Jamais de `git commit` de ta part.** Tu prépares le travail (`Status: REVIEW` + `Log` rempli), l'utilisateur ou Claude valide et commit. Même règle que pour Claude — pas d'exception.

---

## 🔄 Système de Push Notifications (Réveil Temps Réel ⚡)

### 🚀 Gemini lance le serveur — OBLIGATOIRE au démarrage de session

**C'est toi (Gemini) qui lances le serveur** en tâche de fond dès le début de chaque session, avant de toucher au moindre fichier.

**Commande à exécuter depuis la racine du projet :**
```powershell
Start-Process powershell -ArgumentList "-NoExit", "-Command", "python PLCOPENXML_TOOLING/push_server.py" -WindowStyle Minimized
```
Ou en terminal dédié (laissé ouvert) :
```powershell
python PLCOPENXML_TOOLING/push_server.py
```
➡️ Le serveur écoute sur le port **`9090`**. Tu verras `Push Notification Server listening on port 9090...` confirmer le démarrage.

**⚠️ Si le port est déjà occupé** (session précédente non terminée) → le serveur ne démarre pas, c'est OK : le process précédent est toujours actif.

### 🔔 Comment le système fonctionne
* **Git Hooks** : Des hooks `.git/hooks/post-commit` et `post-merge` appellent `curl http://localhost:9090/wake` dès que `QUEUE.md` est modifié dans Git → réveil immédiat.
* **Appel manuel** : Si Claude ou l'utilisateur modifient `QUEUE.md` sans commiter :
  ```powershell
  curl -s http://localhost:9090/wake
  ```
  ou ouvrir `http://localhost:9090/wake` dans le navigateur.

### 📋 Intégration dans le cycle de vie des tâches
```
[DÉBUT SESSION] → Lancer push_server.py → Lire QUEUE.md → Prendre tâche TODO
                                                               ↓
                                              TODO → IN_PROGRESS → REVIEW → DONE
```
**Le serveur reste actif toute la session.** Ne pas le couper entre deux tâches.

---

## 📋 Où trouver ton travail

1. Ouvre `DOC/AGENT_HANDOFF/QUEUE.md` — cherche les lignes `Assigned: Gemini` avec `Status: TODO`.
2. Ouvre le fichier tâche correspondant dans `DOC/AGENT_HANDOFF/tasks/TASK-00NN-*.md` — il est **autonome** (objectif, scope, contraintes copiées-collées, critères d'acceptation). Tu ne devrais jamais avoir besoin de deviner quoi que ce soit qui n'y est pas.
3. Passe `Status: IN_PROGRESS` dans le fichier tâche + `QUEUE.md` dès que tu commences.
4. Bosse **uniquement dans le Scope indiqué** — tout le reste est hors périmètre, même si tu vois un truc à corriger à côté (note-le dans le `Log`, ne le touche pas sans nouvelle tâche).
5. Une fois fini : régénère le bundle si tu as touché du ST (voir ci-dessous), remplis le `Log` (ce qui a été fait, questions, points d'attention), passe `Status: REVIEW`.

## 🔁 Cycle de vie d'une tâche

```
TODO → IN_PROGRESS → REVIEW → DONE
                  ↘ BLOCKED (question/ambiguïté — Claude ou l'utilisateur tranche)
```
**Seul Claude fait passer `REVIEW → DONE`** (relit le diff, vérifie les critères d'acceptation, régénère le bundle). Tu ne te mets jamais `DONE` toi-même.

---

## 📦 Régénération du bundle (si tu touches du ST)

Après toute modif dans `CODE/*.st`, depuis `PLCOPENXML_TOOLING/` :
```powershell
python -c "from generator.cli import main; import sys; sys.exit(main(['--bundle', 'CODE_Bundle', '--project-name', '<version_actuelle>']))"
```
Puis copier `PLCOPENXML_TOOLING/generated/CODE_Bundle.xml` → `CODE/CODE_Bundle.xml`. Vérifie 0 erreur avant de passer en `REVIEW`.

---

## ✍️ Convention de commit (préparée, pas exécutée par toi)

```
[TASK-00NN] résumé court à l'impératif

Détail si besoin.

Task-file: DOC/AGENT_HANDOFF/tasks/TASK-00NN-slug.md
Agent: Gemini
```

---

## 🧭 En cas de doute

Ne jamais deviner sur un point de sécurité/architecture. Écris la question précisément dans le `Log` de la tâche, `Status: BLOCKED`, arrête-toi là. Claude (ou l'utilisateur) répond dans le même `Log`, tu reprends ensuite.
