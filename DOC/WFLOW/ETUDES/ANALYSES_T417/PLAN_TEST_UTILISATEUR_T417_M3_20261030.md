# 🧪 T417 — Affiche d’essais M3

> Actualisation du 31/10 : [plan d'investigation et décisions](PLAN_INVESTIGATION_20261031.md). Retour utilisateur : aucune amélioration visible constatée. Validation globale ouverte.

> **État : essais déjà réalisés · aucun nouvel essai demandé pour l’instant**  
> Banc de simulation isolé uniquement. Aucun code automate de production modifié.

## ✅ Essais réalisés

| Essai | Preuve | Ce que l’on peut dire |
|---|---|---|
| M3 manuel / automatique | `Suivi_94_SIMU_M3_manu_auto_20261029.trace` | chronologies M3 enregistrées |
| M3 étiqueté 10 Hz | `Suivi_95_SIMU_M3_manu_auto_10hz_20261029.trace` | chronologie M3 enregistrée |
| Frein / variateur | traces 94 et 95 | commande à 0, fréquence réelle décroissante, retour frein observé |
| Dynamique simulée | `APRES_G518_COUVERTURE_R2_20261030.json` | 16/16 PASS |
| Chronologie AX14→AX15 | `CI_CYCLE_AX14_AX15_R4_20261030.json` | 1/1 PASS, scénario logiciel ciblé |
| Liaison bundle | rapport G200 du 30/10 | 0 erreur |
| Compilation CODESYS | essai manuel utilisateur | compilation annoncée OK ; preuve à conserver côté utilisateur |

## ⚠️ Non démontré

- Les positions physiques et estimées n’étaient pas dans les traces 94/95.
- La demande d'essai −10 m / −13 m au titre de M3 était une erreur de périmètre de l'agent ; elle est retirée.
- Les traces ne prouvent pas une distance résiduelle après arrêt.
- Le comportement observé en simulation ne doit pas être présenté comme une observation machine réelle.
- La cause physique (pente, inertie, frein silencieux) reste une hypothèse tant qu’elle n’est pas séparée par un scénario contrôlé.

## 🧹 Affirmations retirées

- « La machine réelle s’arrête immédiatement à Trémie » : **non établi**.
- « Le dépassement −0,45 m / +5,38 m est une mesure machine réelle » : **faux** ; c’était une observation de simulation.
- « Le glissement est déjà expliqué par le frein » : **non démontré**.

## 📌 État de la simulation

- Correctif de dissipation discrète appliqué dans `FB_Sim_Translation`.
- Couverture dynamique T417 : 16/16 PASS.
- Aucun ajustement empirique de 30–50 cm ni modification du code automate pour fabriquer le résultat attendu.
- Aucun commit ni validation finale annoncés.

## ⏸️ Suite cadrée

1. Comparer les traces 94/95 et le modèle actuel.
2. Ajouter les voies de position vraie/estimée à la configuration de trace (responsabilité outillage T417).
3. Ne demander un nouvel essai qu’après une amélioration démontrée de la simulation, avec une instrumentation vérifiée et un bénéfice attendu précis.

**Règle de restitution :** ✅ vérifié · 🟡 hypothèse · ❌ retiré/non prouvé.
