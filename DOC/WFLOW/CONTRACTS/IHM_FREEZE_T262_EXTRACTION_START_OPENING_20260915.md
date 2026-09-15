# 🔒 IHM Freeze T262 — Seuil ouverture avant extraction

**Statut : interface figée pour développement IHM · 2026-09-15**

| Élément | Valeur figée |
|---|---|
| Chemin symbole | `Device.Application.GVL_IHM.CycleSemiAuto.Cfg.ExtractionStartOpening_Pct` |
| Type | `INT` |
| Unité | `%` d'ouverture de benne |
| Plage acceptée automate | `0..50` ; toute saisie hors plage est saturée avant persistance |
| Valeur initiale | `0` |
| Persistance | Oui, via `FB_CfgPersistBridge_CycleCfg` et `_CycleCfgPersist` |
| Accès IHM | Lecture / écriture configuration |
| Affichage conseillé | Champ numérique entier : `0 à 50 %` |

## Sens métier

| Valeur | Sens |
|---:|---|
| `0 %` | Réglage par défaut. Le cycle conservera le critère historique de fermeture complète / presque fermée. |
| `1..50 %` | Future autorisation de préparer la transition quand l'ouverture réelle atteint ou passe sous cette valeur. Ex. `20` = 20 % d'ouverture restante. |

## Phase actuellement livrée : A

Le champ est visible, borné et persistant. Il est volontairement **sans effet sur
le cycle à ce stade** : AX10, AX10b, AX11, les treuils, freins et contacteurs
conservent leur comportement actuel jusqu'à validation de la phase B.

L'IHM peut donc être développée et testée immédiatement : écrire une valeur,
contrôler le retour borné, puis vérifier sa restauration après redémarrage.

## 📦 Paquet et test de réception IHM

```text
CODE_XML/CODE_DiffBundle.xml
```

Objets du diff : `ST_CycleCfg`, `PRG_07_Supervision`, `GVL_PERSISTENT`.
Après import CODESYS et compilation, l'équipe IHM peut utiliser le chemin symbole
figé ci-dessus. La configuration des symboles CODESYS reste à régénérer par le
projet compilé avant déploiement IHM.

| Écriture IHM | Valeur lue attendue |
|---:|---:|
| `-1` | `0` |
| `0` | `0` |
| `25` | `25` |
| `51` | `50` |

Puis redémarrer l'automate avec `25` : le champ doit restaurer `25`.
Pendant ces essais, le cycle automatique reste fonctionnellement inchangé.

## ✅ Pré-vérification avant CODESYS

- Structure `ST_CycleCfg` compilée hors CODESYS avec son enum dépendante : PASS.
- Contrat T262 : PASS.
- Liaison bundle G200 : PASS, 0 erreur.
- Recherche du champ : uniquement déclaration, persistance et bornage ; aucune
  lecture cycle, treuil, frein, contacteur ou palier.
- La compilation CODESYS demeure le test final requis après import.

## À ne pas ajouter côté IHM

- Aucun bouton d'activation séparé.
- Aucun contournement ou écriture dans une commande cycle/treuil.
- Aucun message indiquant que la transition anticipée est active tant que la phase B
  n'est pas livrée.

Références : `ST_CycleCfg.st`, `PRG_07_Supervision.st`, contrat T262 et plan
`PLAN_T262_TRANSFERT_AX10_AX11_20260915.md`.
