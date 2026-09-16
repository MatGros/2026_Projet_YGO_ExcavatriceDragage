# 🪟 SPEC 03 — Interface : dévoilement progressif

> **Statut** : v0.1 — **ligne rouge du projet**, écrite avant l'implémentation.
> **Portée** : générique. Ne nomme aucun équipement d'une machine réelle.

---

## 1. 🎯 L'objectif, et la tension qu'il porte

Cet outil va devenir **chargé** : simulation électrique, dynamique, thermique,
chaîne d'effort, modes de panne, balayages, invariants, marges de robustesse.
C'est voulu. C'est même l'intérêt.

Et c'est exactement ce qui tue ce genre d'outil.

> 🔴 **Ligne rouge — non négociable, jamais arbitrable au cas par cas :**
>
> **Au premier regard, on voit une machine qui bouge. Rien d'autre.**
> Toute la puissance est atteignable, mais **jamais imposée** : elle se
> découvre en cliquant sur les objets, pas en subissant un tableau de bord.

La représentation doit être **intuitive et fidèle au réel** — pilotage, capteurs,
actionneurs, dynamique. Quelqu'un qui connaît la machine doit reconnaître sa
machine, immédiatement, sans légende.

---

## 2. 🪜 Les cinq niveaux

| Niveau | Ce qu'on voit | Comment on y arrive |
|---|---|---|
| **N0 — La machine** | La scène. Elle bouge. Zéro chiffre, zéro jargon. | À l'ouverture |
| **N1 — L'objet** | L'état réel d'un équipement : ce qu'il fait, ce qu'il voit | Clic sur l'objet **dans la scène** |
| **N2 — Ses paramètres** | Valeurs, unités, provenance, vérification, niveau | Dans le panneau N1 |
| **N3 — Sa physique** | Courbes, chronogramme, électrique, thermique, chaîne d'effort | Dans le panneau N2 |
| **N4 — L'analyse** | Balayages, invariants, marges, rapports, couverture | Menu dédié, jamais dans la scène |

Chaque niveau est **complet en lui-même**. On peut s'arrêter à N0 et avoir
compris ce que fait la machine ; s'arrêter à N1 et avoir diagnostiqué un blocage.

---

## 3. ⚖️ Règles vérifiables

Un principe d'interface qui reste une intention est violé au troisième écran.
Ces règles sont donc formulées pour être **contrôlables mécaniquement**.

| # | Règle | Contrôle |
|---|---|---|
| **UI-01** | 🔢 **Budget N0** : au plus **7 éléments interactifs** visibles à l'ouverture | comptage automatique |
| **UI-02** | 🚫 **Aucune grandeur non physique en N0** : pas de Hz, pas de mot binaire, pas de pourcentage thermique. Uniquement ce qu'un opérateur lit sur la vraie machine : une position, un mouvement, un état franc | liste blanche de champs autorisés en N0 |
| **UI-03** | 👆 **≤ 3 clics** entre N0 et n'importe quelle donnée du modèle | parcours calculé sur l'arbre des vues |
| **UI-04** | 🤫 **Rien ne s'ouvre tout seul** : aucun panneau, aucune infobulle, aucune modale sans action de l'utilisateur | absence de panneau déplié à l'état initial |
| **UI-05** | ✋ **Ce qui est cliquable se voit** ; ce qui ne l'est pas ne réagit pas | tout élément porteur d'un gestionnaire a une affordance |
| **UI-06** | 🧭 **La vue ne se réorganise jamais seule** — *une seule exception, nommée* : sur défaut de sécurité, la vue concernée passe au premier plan. La machine montre où regarder | une exception, déclarée, testée |
| **UI-07** | ↩️ **Toute profondeur se referme** et rend l'écran exactement à son état précédent | fermeture testée à chaque niveau |
| **UI-08** | 🏷️ **Le vocabulaire est celui de la machine**, jamais celui du modèle : les repères de l'analyse fonctionnelle, pas les noms de types internes | comparaison aux repères `af_ref` |

> 🔍 **UI-02 est la plus dure à tenir et la plus rentable.** La tentation
> permanente est d'afficher « juste cette valeur, elle est utile ». Sept fois
> « juste cette valeur » et l'écran d'accueil est un tableau de bord.

---

## 4. 🧭 Le parcours type

```
   N0   la benne descend, le pont avance, une came s'allume
        │
        │  « pourquoi ça s'est arrêté là ? »        clic sur l'axe
        ▼
   N1   état de l'axe : position, mouvement, ce qui l'a arrêté
        │
        │  « d'où sort cette vitesse ? »            clic sur un paramètre
        ▼
   N2   valeur, unité, provenance, vérification, niveau atteint
        │
        │  « et sous charge, ça tient ? »           clic sur « physique »
        ▼
   N3   courbes, couple, thermique, chaîne d'effort
        │
        │  « et si ce capteur lâche ? »             menu analyse
        ▼
   N4   balayage de pannes, invariants, marge de robustesse
```

Chaque flèche est **une question que l'utilisateur se pose réellement**. Une
profondeur qui ne répond à aucune question posée n'a pas de raison d'exister.

---

## 5. 🎨 Fidélité au réel

L'intuitivité ne vient pas du graphisme, elle vient de la **fidélité**.

| Exigence | Pourquoi |
|---|---|
| 📏 **Échelle vraie** | Une course de 30 m se lit sur 30 m, pas sur une barre de progression |
| 🧱 **Géométrie réelle** | Les espacements non linéaires se voient comme tels |
| 🏷️ **Repères de la machine** | Les noms de l'analyse fonctionnelle, jamais des identifiants inventés |
| 🎞️ **Temps réel** | Un mouvement de 24 s dure 24 s ; l'accélération se ressent |
| 🚦 **États francs** | Un capteur est vu ou non, pas « à 60 % » |
| 🔇 **Sobriété** | Une couleur d'alerte ne sert qu'à une alerte. Trois rouges décoratifs et le vrai rouge ne se voit plus |

---

## 6. ❌ Anti-modèles — refusés par principe

| | Pourquoi c'est refusé |
|---|---|
| 🎄 **Le tableau de bord d'accueil** | Douze cartes de métriques : on ne sait plus où regarder, donc on ne regarde plus |
| 📊 **La métrique décorative** | Un chiffre affiché « parce qu'on l'a » et qui ne répond à aucune question |
| 🪟 **Le panneau permanent** | Un volet toujours ouvert qui vole la moitié de l'écran à la machine |
| 🔴 **L'alerte banalisée** | Tout est rouge, donc rien n'est rouge |
| 🧩 **Le jargon de modèle** | `instance.param.value` affiché à un opérateur |
| 🖱️ **La profondeur cachée** | Une donnée atteignable seulement par un raccourci non découvrable |

---

## 7. 🧪 État actuel — la règle est **violée**

Constat au 2026-09-16, sur la vue du POC :

| Règle | État | Détail |
|---|---|---|
| UI-01 | ❌ | Bandeau de 6 métriques, 6 pastilles d'équipement, 2 boutons de scénario, transport — bien au-delà de 7 |
| UI-02 | ❌ | Hz, mot binaire, niveau calculé, compteurs — tous affichés d'emblée |
| UI-04 | ❌ | Panneau de détail, évènements, paramètres non renseignés et verdict : tous dépliés à l'ouverture |
| UI-03 | ✅ | Tout est à 1 clic |
| UI-08 | ✅ | Repères issus du code et de l'AF |

> C'est un **lecteur de trace de mise au point**, pas l'interface visée. La
> refonte selon cette spec est un travail à part entière, et cette spec existe
> pour qu'il ne soit pas oublié.

---

## 8. 📚 Documents liés

- [`SPEC_01_Modele_Composants.md`](SPEC_01_Modele_Composants.md) — le format du modèle
- `../README.md` — objectifs et périmètre de l'outil
