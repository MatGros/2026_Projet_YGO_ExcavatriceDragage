# Extraction Benne — code vs AF11 (v1.0)

> Sources : `CODE/TREUILS/BENNE/*.st`, `CODE/CYCLE/FB_DiveSearch.st`, `FB_ExtractionSequence.st`, `PRG_06_WinchControl.st`.

## Question tranchée : pourquoi Benne reste séparée d'AF09

**Constat code** : `CODE/TREUILS/BENNE/` (déjà niché sous Treuils), appelé par `PRG_06_WinchControl` (même PRG que Winch), instance `instBucket` au même niveau que `instWinchM1/M2`. Aucune I/O physique propre — réutilise entièrement `FB_Winch` M2. Sécurité couche 2 vit dans `FB_Safety_Winch` (pas de FB_Safety_Benne).

**Verdict** : la Benne **n'est pas un domaine autonome** (contrairement à Translation qui a son propre PRG + FB_Safety dédié) — c'est une **sous-fonction du domaine Treuils**. Gardée en **AF11 séparée mais annexée** à AF09 : assez de contenu propre (offsets, Méca C couche 1, cinématique inversée, DiveSearch/ExtractionSequence) pour mériter sa fiche, mais renvoi croisé fort avec AF09.

## Alertes (devoir d'alerte)

| # | G | Sujet | Statut |
|---|---|---|---|
| A1 | P1 | `OffsetCloseM` doc legacy=10.0, **code réel=15.0** (MES-010, non analysée en charge) | Doc à corriger |
| A2 | P1 | **`FB_DiveSearch`/`FB_ExtractionSequence` absents de toute doc v1.4** alors qu'ils pilotent directement la fermeture benne | Lacune majeure — comblée ici |
| A3 | P2 | T57 : possible duplication logique limite haute M2 (Winch/Safety/IHM) | Non vérifié en profondeur |
| A4 | info | T27/T89 : cinématique et offset benne **non essayés en charge réelle** | TBD terrain |

## Composition code

`FB_Bucket` (machine d'état ouverture/fermeture, pilote M2 seul) + `FB_DiveSearch` (qualification Kobold, assistant MAINT) + `FB_ExtractionSequence` (fermeture + remontée contrôlée palier 1, assistant MAINT).
Instance unique `instBucket` dans `PRG_06_WinchControl`, appelée **en premier** (avant arbitrage M1/M2).
