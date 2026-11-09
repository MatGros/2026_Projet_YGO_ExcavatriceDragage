# Contre-revue finale — T429

## 0. Limite de portée (signalée une fois, sans bloquer)

Je n'ai, dans cette session, **aucun accès au dépôt ni à un environnement d'exécution** : je ne peux ni rejouer les 7 commandes du tableau, ni recalculer les hashes, ni ouvrir `connect_session.py`, `index.html` ou les tests. `AGENTS.md` n'est pas lisible non plus.

Conséquence méthodologique, conforme au cadre de la mission : **je ne prononce aucun PASS sur une vérification que je n'ai pas exécutée.** Ce qui suit est donc (a) une revue de cohérence et de solidité logique des preuves **déclarées**, (b) les écarts détectés, (c) la liste minimale de preuves à produire pour un verdict opposable. Rôle reviewer, lecture seule, aucune écriture, aucun commit.

## 1. Synthèse

| Critère | Verdict opposable | Appréciation sur pièces |
|---|---|---|
| **AC-F1.7** | Non prononçable | Favorable sur le principe, **2 réserves techniques** |
| **AC-F3.5** | Non prononçable | **Insuffisant** : la branche deep-link n'est pas démontrée exercée |
| **AC-X.1** | Non prononçable | Plausible, preuve **partielle** |
| **AC-X.2** | Non prononçable | **Aucune preuve étiquetée** pour ce critère |

## 2. AC-F1.7 — alias strict

**Ce qui tient.** `re.fullmatch` + `\S` impose bien un libellé non vide ; un label composé uniquement d'espaces est rejeté. Les ancres `^…$` sont redondantes avec `fullmatch` (cosmétique, pas un défaut). `fullmatch` protège correctement contre un `\n` final, contrairement à `re.match`.

**Réserve 1 — saut de ligne interne.** `\s+` inclut `\r` et `\n` : la chaîne `"T429-CC01\nX"` satisfait `fullmatch`. Si le nettoyage amont ne supprime pas les retours à la ligne internes (copier-coller multi-lignes), la garantie « un alias = une entrée » n'est pas tenue. Correctif : `[^\S\r\n]+` à la place de `\s+`, ou rejet explicite de tout `\r`/`\n` avant validation.

**Réserve 2 — casse du segment intermédiaire.** `[0-9A-Z]+` refuse les suffixes minuscules. À confirmer qu'aucun alias réel du parc n'est de cette forme, sinon régression silencieuse au moment de la connexion (échec de validation d'un alias légitime).

**Preuve manquante.** Une table de cas exécutée — label vide, label espaces seuls, saut de ligne interne, alias valide nominal, casse, préfixe d'outil inconnu — avec sortie brute par cas. `133 passed` ne dit rien de la couverture de ces cas précis.

## 3. AC-F3.5 — deep-link vers la carte d'alerte

C'est l'écart le plus net du dossier.

- Le run censé couvrir le deep-link (`VEILLEUR_UI_DEEP_LINK=1`) produit une **sortie strictement identique** au run sans la variable, et cette sortie ne mentionne ni `focus`, ni deep-link, ni carte d'alerte. Rien n'établit que la branche est exercée : au mieux une preuve **statique** (présence de `focusFindingCard`), pas comportementale.
- **Non-reproductibilité** : la ligne 2 est écrite `node test_ui.mjs` sans chemin, la ligne 1 avec `TOOLS/AGENT_SUPERVISOR/tests/…`. Tel quel, non rejouable depuis la racine ; à corriger ou à préciser (cwd).
- Non couvert par les preuves fournies : `history.replaceState` (URL attendue), `scrollIntoView({block:'center'})` (position réelle), ouverture effective du `[data-alert-id]` **après** `note.close()`, et le fait que l'`AudioContext` n'est pas instancié avant le premier geste (politique autoplay). L'ordre `note.close()` puis `focusFindingCard` est correct en soi si `note` est un `<dialog>` (fermeture synchrone).
- `git diff --check` (exit 0) ne teste que les espaces de fin de ligne : **cela ne peut pas figurer en preuve d'AC**.

**Preuve minimale attendue** : un test partant d'un état où la carte n'est pas visible, déclenchant `note.onclick`, puis assertant (i) `selectedSideSessionId === sessionId`, (ii) vue = monitor, (iii) l'alerte présente dans l'URL, (iv) le nœud `[data-alert-id]` visible/dans le viewport — avec un message de sortie **distinct** de celui du run standard.

## 4. AC-X.1 — immuabilité de `TASKS.yaml`

Hash identique avant/après = condition **nécessaire, non suffisante** : cela ne prouve pas l'absence d'écriture concurrente par un tiers, ni que la suite exécutée est celle qui touche la persistance. Le périmètre surveillé est réduit à un seul fichier.

**Manque** : hash de `%LOCALAPPDATA%\…\agent-supervision.json` avant/après sur la même fenêtre, commande exacte de calcul et horodatage des deux mesures.

## 5. AC-X.2 — aucune preuve rattachée

Le bloc « état sérialisé » est explicitement étiqueté **AC-X.1**, pas AC-X.2. Je ne dispose pas de l'énoncé de AC-X.2 et ne le reconstituerai pas par inférence. Le contenu décrit (deux sessions `enabled:false`, 0 et 6 alertes) est *compatible* avec une isolation par session, mais : « exactement 6 » n'est vérifiable que par le test qui les produit, et `enabled:false` **avec** alertes conservées doit être confronté à l'énoncé (comportement attendu ou régression d'affichage ?). Sans l'énoncé et un test dédié, ce critère est **non instruit**.

## 6. Risque transverse

Le point faible du dossier n'est pas la qualité des correctifs (qui paraissent sérieux sur le fond), c'est la **traçabilité AC ↔ test** : trois runs « PASS » sont cités sans qu'on puisse rattacher un test nommé à un critère nommé. C'est exactement le type de preuve qui doit être opposable en clôture.

## 7. Réponses aux questions

1. **AC-F1.7** — Non prononçable par moi. Sur pièces : favorable, sous réserve du traitement du saut de ligne interne et de la confirmation qu'aucun alias légitime n'utilise de suffixe minuscule.
2. **AC-F3.5** — Non prononçable, et **insuffisant en l'état** : la preuve fournie ne démontre pas que le chemin deep-link est exercé. À reprendre avec un test comportemental produisant une sortie distincte.
3. **AC-X.1** — Non prononçable ; preuve partielle (hash unique, pas de contre-hash de l'état sérialisé). **AC-X.2** — Non prononçable ; aucune preuve étiquetée, énoncé non fourni.
4. **Recommandation : ne pas clore T429 sur ce dossier.** Deux voies :
   - **(a)** m'accorder un accès lecture + exécution (rejeu des commandes, recalcul des hashes, inspection du diff réel) → verdicts opposables en une passe ;
   - **(b)** à défaut, consigner au registre : AC-F1.7 / AC-F3.5 / AC-X.1 = *« PASS auto-déclaré par le coordinateur, contre-revue partielle faute d'accès »*, AC-X.2 = *« preuve absente »*. La clôture n'est alors possible que par **acceptation explicite et motivée du risque résiduel par le responsable**.

Ce que je ne ferai pas : signer PASS sur des sorties que je n'ai pas produites.