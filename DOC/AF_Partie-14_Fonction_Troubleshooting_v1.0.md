# AF Partie 14 - Troubleshooting v1.2

Orientee Fonctions Machine / Utilisation Operateur.

1. LevageSynchroniseM1M2
2. LevageUnitaireM1
3. LevageUnitaireM2
4. BenneOuvertureFermeture
5. TranslationPontM3

---

## Integration programme

> Architecture cible faisant foi : `DOC/AF_Partie-02_Architecture_Programme_v3.0.md` §2 et §4.

| | POU | Statut |
|---|---|---|
| Code actuel | `PRG_TROUBLESHOOTING_CFC` (ST) | page d'observation distincte de `PRG_SUPERVISION_CFC` |
| Cible | `PRG_07_Supervision_CFC` (rang 07) | **absorbe le troubleshooting** : observation et diagnostic au meme endroit |

Il n'existe **pas** de POU `PRG_11_Troubleshooting` dans l'architecture cible : ce nom
appartient au decoupage transverse abandonne. Observer un fonctionnement et le publier a l'IHM
est une seule responsabilite, portee par une page unique executee en dernier.

### Invariant opposable

Le troubleshooting **n'ecrit jamais** une commande, une configuration ou un interlock.
`PRG_07_Supervision_CFC` est en **lecture seule stricte**. Cette regle est inchangee par la
migration : elle est deja l'invariant du POU actuel.

Le contenu fonctionnel des 5 fonctions machine ci-dessus, ses seuils et ses observateurs
(`FB_Acquisition_Preflight`, `FB_Winch_Symmetry`) ne sont pas modifies par le changement de POU.
Fiches : `AF_Partie-06` (Preflight) et `AF_Partie-10` (Symmetry).

📌 Lot de migration : **M6** de `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C2, patch).
