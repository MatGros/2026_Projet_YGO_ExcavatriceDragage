# 🔒 IHM Freeze T262 — Seuil ouverture avant extraction

**Statut : interface figée pour développement IHM · 2026-09-15**
**⚠️ Mise à jour 2026-09-21 — phase B livrée : la plage passe de `0..50` à `0..20`, et le champ n'est plus sans effet.**

| Élément | Valeur figée |
|---|---|
| Chemin symbole | `Device.Application.GVL_IHM.CycleSemiAuto.Cfg.ExtractionStartOpening_Pct` |
| Type | `INT` |
| Unité | `%` d'ouverture de benne |
| Plage acceptée automate | `0..20` ; toute saisie hors plage est saturée avant persistance |
| Valeur initiale | `0` |
| Persistance | Oui, via `FB_CfgPersistBridge_CycleCfg` et `_CycleCfgPersist` |
| Accès IHM | Lecture / écriture configuration |
| Affichage conseillé | Champ numérique entier : `0 à 20 %`, avec la mention **« effet à partir de 9 % »** (voir ci-dessous) |

## Sens métier

| Valeur | Sens |
|---:|---|
| `0 %` | Réglage par défaut. Branche **inactive** : le cycle conserve le critère d'arrivée de fermeture d'origine (anticipation de fermeture 1,2 m). |
| `1..8 %` | **Sans effet observable** : le critère d'origine (1,2 m = 8 % d'ouverture restante) est déjà plus permissif que le réglage. Ce n'est pas un défaut — à écrire noir sur blanc sur l'IHM, sinon un opérateur réglant 5 % conclura à tort que la fonction est en panne. |
| `9..20 %` | Autorisation d'atteindre la même conclusion **plus tôt** : la fermeture est considérée atteinte dès qu'il reste ce pourcentage d'ouverture. `20` = 20 % d'ouverture restante, soit 3,0 m avec la géométrie persistée actuelle (`OffsetOpenM = 0.0` / `OffsetCloseM = 15.0`). |

> 🛡️ Le réglage est une **branche ajoutée** aux critères d'origine : il ne peut jamais **resserrer** le critère
> existant, ni supprimer le filet anti-blocage sur matière dense (tolérance 2,0 m conservée). La conversion est
> `distance = (p / 100) × (OffsetCloseM − OffsetOpenM)` : elle **suit la géométrie réellement persistée** sur la
> machine, jamais une cote figée.

## Phases livrées : A (bornage/persistance) **puis B (câblage réel)**

- Phase A (2026-09-15) : le champ était visible, borné et persistant, mais **sans effet sur le cycle**.
- Phase B (2026-09-21) : le champ pilote réellement le seuil de transition `AX10 → AX10B`, via
  `FB_BucketCloseThreshold` (FB pur testé en CI, 16 cas) consommé par `PRG_04_Treuils_Benne` **et** par `FB_Bucket`.
  ⚠️ Les **deux** sites sont nécessaires : la porte de sortie AX10 conjoncte la fin de fermeture et l'état benne
  (`FB_CycleSemiAuto.st:1298`). Brancher un seul des deux laisse le champ **sans effet** — c'est exactement le défaut
  qui a duré du 2026-09-15 au 2026-09-21.
- L'essai machine reste **obligatoire avant mise en réel** (mail GCAM du 2026-09-15) : une simulation ne prouve pas
  l'effort mécanique réellement soulagé sur M2.

L'IHM peut donc être développée et testée immédiatement : écrire une valeur,
contrôler le retour borné, puis vérifier sa restauration après redémarrage.

## 📦 Paquet et test de réception IHM

```text
CODE_XML/CODE_DiffBundle.xml
```

Objets du diff : `FB_BucketCloseThreshold` (nouveau), `FB_Bucket`, `PRG_04_Treuils_Benne`,
`PRG_07_Supervision`, `ST_CycleCfg`.
Après import CODESYS et compilation, l'équipe IHM peut utiliser le chemin symbole
figé ci-dessus. La configuration des symboles CODESYS reste à régénérer par le
projet compilé avant déploiement IHM.

| Écriture IHM | Valeur lue attendue |
|---:|---:|
| `-1` | `0` |
| `0` | `0` |
| `20` | `20` |
| `21` | `20` |
| `50` | `20` |

Puis redémarrer l'automate avec `20` : le champ doit restaurer `20`.
L'essai de réception IHM **ne doit plus** conclure « champ sans effet » : à `20`, la
transition `AX10 → AX10B` doit survenir avec 3,0 m d'ouverture benne restante
(géométrie persistée actuelle), au lieu de 1,2 m.

## ✅ Pré-vérification avant CODESYS

- `FB_BucketCloseThreshold` : test CI `16/16 PASS` (dont table de vérité à `0 %`,
  saturation `0..20`, bascule au seuil, refus sur mesure non qualifiée, monotonie).
- `FB_Bucket` : test CI `38/38 PASS`, aucune régression sur l'interface élargie.
- Contrat de tâche de la phase B : `check_task_contract.py` PASS, 0 erreur.
- Garde-fou `G515` : PASS, `--selftest` 8 mutations rejetées.
- Liaison bundle G200 : PASS, 0 erreur — `instCloseThreshold` vérifiée déclarée/appelée.
- La compilation CODESYS demeure le test final requis après import.

## À ne pas ajouter côté IHM

- Aucun bouton d'activation séparé.
- Aucun contournement ou écriture dans une commande cycle/treuil.
- Aucun affichage de la transition anticipée comme « transition normale » : le
  franchissement du seuil laisse la benne **partiellement ouverte**, ce qui est le
  comportement voulu, et AX12 reste au **palier lent** tant que la fermeture franche
  n'est pas confirmée.

Références : `ST_CycleCfg.st`, `PRG_07_Supervision.st`, `FB_BucketCloseThreshold.st`,
contrat de tâche de la phase B et plan `PLAN_T262_TRANSFERT_AX10_AX11_20260915.md`.
