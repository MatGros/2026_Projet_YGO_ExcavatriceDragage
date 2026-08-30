# 🧪 Challenge expert — Jumeau numérique

> **Statut** : TERMINÉ — rapport de l'expert indépendant intégré.
> **Objet challengé** : `ETUDE_CONCEPTION_JUMEAU_NUMERIQUE.md`, `SPEC_INTERFACE_FRAME.md`,
> `SPEC_ADAPTATEURS_SOURCES.md`.
> **Verdict** : ⚖️ **Avec réserves** — architecture saine, mais 3 points bloquants à corriger (P0).

---

## 1. Points forts ✅

- **Frontière « pur rendu » bien posée** : « le binaire compilé décide, zéro logique métier en JS »
  aligne le jumeau sur la source de vérité `WORKING_COPY` et évite la dérive où l'IHM réimplémente
  le séquenceur.
- **Schéma Frame unique, source-agnostique** : un seul contrat JSON découple le rendu de l'origine
  (binaire, trace, harnais CI/Grafcet) et rend le jumeau testable sur des traces réelles.
- **Provenance étiquetée** : le vocabulaire COMPILED/HARNESS_STIMULUS/CONFIG/DERIVED est déjà
  éprouvé sur `anim_bench/` ; l'étendre est cohérent.
- **Chaîne de fraîcheur SHA** (HTML == trace JSON == source WORKING_COPY) : bon garde-fou contre le
  « jumeau périmé qui ment ».
- **Garde-fou mécanique** certifiant que l'HTML est un lecteur : indispensable.

## 2. Faiblesses / risques ⚠️

1. **Le schéma Frame n'est pas assez strict.** « positions fournies par la frame, jamais calculées
   en JS » est une *intention*, pas une *contrainte*. Rien n'empêche d'ajouter un `computed` dans le
   rendu. Il faut une **validation de schéma (JSON Schema) bloquante** + une **liste blanche de
   champs** : tout champ non déclaré dans `twin_config.json` est rejeté. Le « pur rendu » doit être
   *mécaniquement* prouvé, pas déclaré.
2. **ControlPanel = glissement vers la logique métier.** Le mapping « intention → bit » est
   précisément là où la logique métier se cache. Il faut que le ControlPanel ne produise que des
   **bits bruts adressés** (adresse + valeur), jamais une interprétation. La sémantique reste au
   binaire.
3. **Provenance INJECTED ambiguë.** Un bit injecté et une sortie compilée peuvent avoir la **même
   adresse**. Sans règle de collision, on ne sait pas qui fait foi. Il faut : (a) INJECTED
   **exclusif** — une adresse est soit compilée, soit injectée, jamais les deux ; (b) un **marqueur
   de session** ; (c) un **rendu visuel distinct** (badge).
4. **Cohérence commande↔position non garantie.** Qui vérifie que `cablePosM1` est cohérent avec la
   commande ? Il faut un **contrôle de plausibilité** (delta position vs temps, sens vs commande),
   **signalé comme DERIVED**, jamais comme vérité, et ne bloquant jamais le rendu.
5. **Traçabilité SHA incomplète.** Manque : (a) le **hash du binaire** `cycle_engine.exe` ; (b) la
   **fraîcheur temporelle** (une trace SHA-identique peut être vieille). Le SHA prouve l'identité,
   pas la fraîcheur.
6. **Réutilisabilité de cycle_engine.exe surestimée.** Le binaire ne couvre qu'un FB ; la trace
   existante est probablement **spécifique à ce FB**. Il faut **valider le schéma contre la trace
   existante** avant de promettre la réutilisabilité.
7. **Sécurité machine : le hors-ligne n'est pas une protection.** « HORS-LIGNE » est un *état de
   fait*, pas un *garde-fou*. Il faut : (a) **aucune écriture réseau sortante** vers l'automate ;
   (b) une **bannière HORS-LIGNE non supprimable** ; (c) une **séparation physique** des canaux.

## 3. Questions ouvertes ❓

1. Le schéma Frame est-il **versionné** (`schema_version`) ? Une évolution casse-t-elle les traces ?
2. Qui **valide** la cohérence commande↔position, et avec quelle autorité ?
3. Le ControlPanel injecte-t-il des bits **adressés** ou des **intentions sémantiques** ?
4. La trace existante est-elle **conforme** au schéma générique, ou faut-il un adaptateur spécifique ?
5. Le hash couvre-t-il le **binaire** et la **config** (`twin_config.json`), pas seulement
   HTML/trace/source ?
6. Comment le jumeau **signale-t-il** une frame incohérente sans devenir juge ?

## 4. Recommandations concrètes 🔧

1. **JSON Schema bloquant + liste blanche de champs** (P0) — le « pur rendu » devient mécanique.
2. **INJECTED exclusif + marqueur de session + badge visuel** (P0) — zéro confusion bit
   injecté/compilé.
3. **Contrôle de plausibilité en DERIVED** (P1) — signaler, jamais bloquer, jamais décider.
4. **Étendre la chaîne SHA au binaire + à la config + âge de la trace** (P1).
5. **Valider le schéma contre la trace existante** avant de promettre la réutilisabilité (P1).
6. **Sécurité : bannière HORS-LIGNE non supprimable + isolation réseau** (P0).

## 5. Verdict ⚖️

**Avec réserves.** L'architecture est saine et les principes (binaire décide, provenance, SHA) sont
les bons. Mais trois points bloquent l'implémentation : (1) le « pur rendu » n'est pas *mécaniquement*
prouvé (schéma non strict), (2) la provenance INJECTED n'a pas de règle de collision, (3) la
cohérence commande↔position n'a pas de propriétaire. Corriger P0 (schéma bloquant, INJECTED exclusif,
isolation réseau) puis lancer l'implémentation.

---

## Décisions prises suite au challenge

Les recommandations P0 sont **intégrées** dans l'étude de conception (voir
`ETUDE_CONCEPTION_JUMEAU_NUMERIQUE.md` §7 et `SPEC_INTERFACE_FRAME.md`) :

- ✅ **JSON Schema bloquant + liste blanche de champs** (P0) — ajouté au schéma Frame.
- ✅ **INJECTED exclusif + marqueur de session + badge visuel** (P0) — ajouté à la provenance.
- ✅ **Contrôle de plausibilité en DERIVED** (P1) — ajouté (signale, ne bloque pas).
- ✅ **Chaîne SHA étendue au binaire + config + âge de la trace** (P1) — ajouté à la traçabilité.
- ✅ **Bannière HORS-LIGNE non supprimable + isolation réseau** (P0) — ajouté à la sécurité.
