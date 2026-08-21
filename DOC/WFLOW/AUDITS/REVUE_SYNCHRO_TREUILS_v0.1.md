# 🧭 D-P10 — Revue critique du bloc synchro treuils `FB_WinchSync` (v0.1)

> 📄 Statut : **ÉTUDE (lecture seule, zéro code)** · 📅 2026-08-21 · 🧠 DSH-02 + utilisateur
> 🎯 Objectif : clarifier les responsabilités du bloc synchro M1/M2, sa sortie, et son découpage.
> 🔗 Source : `CODE/H_TREUILS_BENNE/FB_WinchSync.st` (186 lignes). Tâche : [`../PLAN_TASK.md`](../PLAN_TASK.md) → T146 (volet D-P10).

---

## 1. 🎯 Problème identifié — le bloc fait 2 choses mélangées

`FB_WinchSync` traite actuellement **deux préoccupations distinctes** dans un seul FB :

| # | Préoccupation | Données | Sorties |
|---|---|---|---|
| A | **Écart position M1/M2 (codeurs)** | `CablePosM1/M2`, `HomedM1/M2`, `ActiveOffsetM` | `DeltaPosM`, `SyncWarn`, `SyncDegradedStep1` |
| B | **Cohérence commande (relais + contacteurs)** | `RelayFwd/Rev`, `Contactor1-4` (M1/M2) | `MismatchActive` (bit1) |

→ 1 FB = 1 responsabilité violée : on peut être désynchronisé **par les codeurs** **OU** par les contacteurs. Et si on bypasse les codeurs, on voudrait quand même surveiller les contacteurs (besoin réel en essais).

---

## 2. 🔍 Observations & décisions utilisateur

| Point | Observation utilisateur | Décision |
|---|---|---|
| 2.1 | `SyncWarn` vs `SyncDegradedStep1` | ⚠️ **Revue 2 : ils ne sont PAS identiques** — `SyncWarn := Status.Error` (toute erreur), `SyncDegradedStep1` = écart seul. Malgré ça, les remplacer par **2 seuils explicites** `SyncDeviationWarn`/`SyncDeviationFault` reste un bon design (2 paliers distincts). |
| 2.2 | `SyncActive` | ✅ = **autorisation de couplage** (anti-télescopage) : **reste `1`**, pas liée à l'erreur. Le problème est porté par `SyncDeviationWarn`/`SyncDeviationFault`, **pas** par `SyncActive`. |
| 2.3 | Entrée `Mode` | ✅ **Retirée** : le bloc ne reçoit que **si on l'active ou pas** (`SyncEnable`). L'arbitrage mode = caller. |
| 2.4 | Entrée `PowerContactorEngaged` | ✅ **Retirée** : hors responsabilité du bloc (arrêt au contacteur = externe). |
| 2.5 | `HomedM1/M2` | ✅ Remplacer par **`HomedAndReliable`** (notre bit fiable, `FB_EncoderReliability`). |
| 2.6 | `ActiveOffsetM` | ✅ Source **unique** (décalage actif benne ouverte/fermée) à vérifier. |
| 2.7 | **Affichage écart lors de la bascule offset benne** | ✅ **Révisé** : le bloc reçoit `ActiveOffsetM` **déjà résolu** (comparateur pur, **n'interprète PAS l'état benne**). Le calcul offset-selon-état-benne (gel à l'écart réel en intermédiaire non référencé) va dans **`FB_Bucket` (`HoldOffset`)**. On part de l'écart réel (ex. 7 m) et on monte en gardant cet écart, sans bloquer la synchro. |
| 2.8 | **Découpage en 2 blocs** | ✅ Séparer `FB_SyncDeviation` (écart codeurs) + `FB_SyncContactor` (cohérence contacteurs). |

---

## 3. 💡 Proposition de découpage

### 3.1 Bloc écart codeurs — `FB_SyncDeviation` (comparateur pur)

> ⚠️ **Correction (revue 2) : NE PAS mettre l'interprétation benne dans ce bloc.** Il resterait « 2 responsabilités mélangées ». Le bloc reçoit `ActiveOffsetM` **déjà résolu** par l'appelant ; il ne décode pas l'état benne.

```
Entrées : CablePosM1, CablePosM2, HomedAndReliableM1, HomedAndReliableM2, ActiveOffsetM (résolu), SyncEnable
Sorties : SyncDeviationWarn      (seuil 1 : signaler)
          SyncDeviationFault     (seuil 2 : critique)
          DeltaPosM / SignedDeltaPosM
```
- Le bloc **signale** les 2 seuils, il ne ralentit pas (le consommateur décide).
- **Responsabilité déportée** : le calcul `offset selon état benne` (ouvert/fermé/intermédiaire non référencé) vit dans **`FB_Bucket`** (un `HoldOffset` = gel à l'écart réel en intermédiaire), pas ici.
- Le bloc n'expose l'écart que quand la synchro est active (pas d'écart sauteur en benne ouverte/fermée).

### 3.2 Bloc cohérence contacteurs — `FB_SyncContactor`
```
| Entrées : RelayFwd/Rev M1/M2, Contactor1-4 M1/M2, SyncEnable
| Sortie  : ContactorMismatch
```
- Surveille que les commandes/contacteurs des 2 treuils sont identiques.
- **Indépendant des codeurs** → surveillable même si codeurs bypassés.

---

## 4. 🏁 Verdict provisoire

- `FB_WinchSync` mélange **écart codeurs** + **cohérence contacteurs** → à **scinder**.
- Le bloc écart doit **signaler** (Warn/Fault), pas décider de ralentir.
- Le bloc reçoit `HomedAndReliable` (pas `Homed`) et `ActiveOffsetM` **résolu** ; il ne porte **pas** `Mode`/`PowerContactorEngaged`, ni l'interprétation benne.
- Le calcul offset-selon-état-benne (`HoldOffset`) va dans **`FB_Bucket`** (producteur unique), pas dans le bloc synchro.
- **Phase étude — zéro code** tant que le plan n'est pas validé.

---

📖 Liens : [`../PLAN_TASK.md`](../PLAN_TASK.md) → T146 · [`TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md`](TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md) (D-P10) · **revue indépendante** [`REVUE_EXPERTE_SYNCHRO_TREUILS_v0.1.md`](REVUE_EXPERTE_SYNCHRO_TREUILS_v0.1.md) (verrou sécurité) · code `FB_WinchSync.st`.
