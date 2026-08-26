# Fiche PRG — `PRG_XX` (vX.Y)

> 🎯 Complément d'AF‑02 : détail codable d'un seul POU. AF‑02 reste propriétaire de la `MainTask`,
> de l'ordre inter‑PRG et des diagrammes globaux.

## 🎯 Rôle et frontières

| Lit | Produit | Ne fait jamais |
|---|---|---|
| [producteurs et GVL] | [bus publics / sorties] | [hors responsabilité] |

## ⏱️ Ordre fonctionnel — lire de haut en bas

| Phase | 🎯 But | 🕒 Fraîcheur | Lire concrètement | Écrire / garantir |
|---|---|---|---|---|
| 1. [phase] | [objectif] | 🟢 courant / 🟡 N‑1 justifié | [GVL, bus, image E/S] | [résultat] |

## 🛡️ Invariants

- [Règle de sécurité ou d'intégration non négociable.]

## 🧪 Tests associés

| ID | Vérifie | Preuve |
|---|---|---|
| `TC-…` | [intention] | [test / revue] |

## 📚 Documents liés

- AF‑02 : architecture et ordonnancement global.
- AF‑03 : contrats FB/DUT.
- [AF métier propriétaire].
