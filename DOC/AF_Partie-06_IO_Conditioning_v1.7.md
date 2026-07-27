# 📥 Analyse Fonctionnelle — Partie 6 : Conditionnement E/S (v1.7)

> **Projet** : Excavatrice de dragage — CODESYS 3.5  
> **Statut** : référence active · 2026-07-27  
> **Évolution v1.7** : acquisition centralisée et frontière `HwReal` / `HwIn`.

---

## 1. 🎯 Rôle

Le conditionnement transforme les E/S brutes en signaux métier stables et de polarité explicite.
`FB_Input` filtre les entrées TOR (20 ms) et porte l'inversion NO/NC nécessaire; `FB_Output`
conditionne la sortie relais finale. Aucune logique métier ne lit directement une E/S matérielle.

## 2. 🏗️ Chaîne d'acquisition unique

```text
%IX / PDO ──► HwReal ──► HwIn ──► FB_Input ──► PRG_00 VAR_OUTPUT ──► métier
```

- `PRG_00_Inputs` §0 recopie toutes les entrées physiques et PDO dans `HwReal`.
- §0bis sélectionne par domaine l'image réelle ou celle du banc : `HwIn`.
- §1 applique `FB_Input` (filtre 20 ms, inversion documentée) puis publie les valeurs normalisées.
- Les autres `PRG` et FB lisent exclusivement les sorties de `PRG_00_Inputs`.

La simulation reste ainsi en amont du conditionnement; elle ne force jamais une sortie de FB ni
ne complète une valeur réelle.

## 3. 🔌 Convention de nommage E/S

| Forme | Exemple | `TRUE` signifie |
|---|---|---|
| `<Domaine>_<ÉtatQuandTRUE>_DI` | `M1_BrakeIsOpen_DI` | l'état physique explicitement nommé |
| `<Domaine>_<ActionCommandée>_RQ` | `M1_BrakeRelease_RQ` | l'action demandée est active |
| `_DQ` | `M1_RelayFwd_Up_DQ` | la sortie physique finale est alimentée |

La polarité doit être lisible dans le nom. Les références de renommage et le REX C1 sont dans
`AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`.

## 4. 🔒 Polarités de sécurité

- Les retours NC/fail-safe nommés `Ok`, `Closed`, `Tensioned` ont un repos sain explicite.
- Une entrée inversée est normalisée une seule fois dans `PRG_00` par `FB_Input`, jamais dans les
  consommateurs.
- `PowerContactorEngaged_DI` confirme le contacteur de puissance; ce n'est pas la boucle AU.
- `EmergencyChainClosed_DI` indique la boucle AU fermée.
- `PowerKeepAlive_A/B_RQ = TRUE` maintient l'énergie; sa retombée coupe la puissance.

## 5. 📥 Application CODESYS 3.5

Après import de `CODE/CODE_Bundle.xml`, vérifier en vue instance, dans cet ordre :

1. `HwReal` : point E/S/PDO brut;
2. `HwIn` : source réellement sélectionnée;
3. instance `FB_Input` : filtre/inversion;
4. sortie `PRG_00_Inputs` : valeur métier publiée.

Toute divergence de polarité se corrige à l'étape de conditionnement, pas dans un FB métier.
