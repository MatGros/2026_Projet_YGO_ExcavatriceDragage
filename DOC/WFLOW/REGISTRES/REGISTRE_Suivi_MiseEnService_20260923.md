# 🧾 Mise en service — suivi du 23/09/2026

> **Périmètre :** passage cycle `AX10 → AX10B → AX11`, treuils M1/M2, machine réelle.  
> **Nature :** constat terrain daté ; aucune modification de `CODE/` dans ce relevé.

---

## ✅ Résultat de l’essai rapporté

| Essai | Constat | Niveau de preuve |
|---|---|---|
| Passage `AX10 → AX10B → AX11` | Passage déclaré **fluide** par l’opérateur le 23/09/2026. | Observation terrain rapportée ; pas de trace horodatée jointe à ce registre. |

## 🔎 Rapprochement avec le défaut observé le 22/09

Les traces terrain `Suivi_83_BonEnSimu_Mais pas en reelAX10_11_ARRET_20260922.trace` et `Suivi_84_BonEnSimu_Mais pas en reelAX10_11_ARRET_20260922.trace` avaient montré un temps mort M1 de l’ordre de `800 ms` pendant un mouvement M2 seul. Le réglage M1 est explicitement `DirectionInterlockDelayAscent := T#800ms` dans `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1448-1453`.

Le retour « contacteurs relâchés » de chaque treuil alimente la condition d’activation de son interlock :

| Chaîne factuelle | Source |
|---|---|
| Retour M1 lu dans `M1WinchSensors.ContactorsAllOff` depuis `M1_ContactorsReleased_DI`. | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1421-1425` |
| Retour M2 lu dans `M2WinchSensors.ContactorsAllOff` depuis `M2_ContactorsReleased_DI`. | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1503-1507` |
| L’interlock de direction n’est activé que lorsque `StepNumber = 0` et que `Sensors.ContactorsAllOff` est vrai. | `CODE/H_TREUILS_BENNE/FB_Winch.st:196-205` |
| Au front d’une demande, le délai restant est calculé à partir de l’arrêt physique déjà capturé ; le délai d’inversion est ensuite appliqué. | `CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st:73-121` |
| Tant que l’inversion est en attente, `DirectionChangePending` reste vrai. | `CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st:124-160` |
| En commande couplée, un `DirectionChangePending` M1 ou M2 inhibe la requête de l’autre treuil afin de préserver le démarrage atomique. | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1400-1409`, `CODE/M_MAIN/PRG_04_Treuils_Benne.st:1495-1501` |

## ⚠️ Qualification de la cause

| Élément | Statut au 23/09 | Limite de l’affirmation |
|---|---|---|
| Temps mort M1 de `800 ms` et effet sur la commande couplée | **Établi** par les traces du 22/09 et la chaîne logicielle ci-dessus. | La durée exacte dépend du sens demandé et de l’arrêt déjà crédité par l’interlock. |
| Retours d’état des contacteurs M1/M2 croisés ou inversés (câblage ou mapping) | **Hypothèse prioritaire**, rapportée après la correction terrain. | Non confirmée ici au bornier, par LED contacteur et par lecture brute des deux DI. |
| Passage désormais fluide | **Observation terrain rapportée** le 23/09. | Une observation ne prouve pas à elle seule le croisement physique ni sa correction définitive. |

## 🛡️ Contrôle de clôture requis — sans bypass

À réaliser par personnel habilité, machine en condition sûre et selon la procédure site. Ne pas neutraliser l’interlock ni les retours contacteurs.

| État physique attendu | `M1_ContactorsReleased_DI` | `M2_ContactorsReleased_DI` |
|---|---:|---:|
| M1 et M2 relâchés | `TRUE` | `TRUE` |
| M1 collé seul | `FALSE` | `TRUE` |
| M2 collé seul | `TRUE` | `FALSE` |
| M1 et M2 collés | `FALSE` | `FALSE` |

1. Relever simultanément l’état réel des contacteurs, les deux DI brutes et les deux valeurs `HwIn` ; confirmer la correspondance M1↔M1 et M2↔M2.
2. Refaire au minimum trois passages `AX10 → AX10B → AX11` avec trace des deux DI, `DirectionChangePending` M1/M2 et `BothBlocked`.
3. Si une discordance persiste, arrêter l’essai et consigner le câblage / mapping réellement constaté avant toute autre action.

---

*Consigné le 2026-09-23 à partir du constat opérateur du jour et des traces terrain du 22/09. Aucun changement logiciel réalisé dans ce registre.*
