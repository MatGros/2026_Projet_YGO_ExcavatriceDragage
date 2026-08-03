# Extraction Translation M3 — code vs AF11 (v1.0)

> Sources : `CODE/TRANSLATION/*.st`, `CODE/MAIN/PRG_05_Translation.st`, `PRG_03_Safety.st`.

## Alertes (devoir d'alerte)

| # | G | Sujet | Statut |
|---|---|---|---|
| A1 | info | `PowerCutOff M3 codé en dur FALSE` (cité par audits historiques) : **FAUX aujourd'hui** — calcul réel `(ErrorId AND 16#00F8)` | Audits anciens périmés sur ce point |
| A2 | P2 | `PostRampTimeout`(3s) et TON Méca A(1s) sont des **constantes internes non paramétrables**, contrairement à ce que suggère la doc legacy | À documenter explicitement |
| A3 | P2 | Variante Méca B si `HeartbeatIhmOk=FALSE` (surveillance élargie) — non documentée avant | Comblé ici |
| A4 | P2 | `ApproachSpeedPct`/`CaptorDebounce`/`DirectionInterlockDelay` : doc dit "câblés RETAIN", **faux** — restent au défaut du FB, aucune variable PERSISTENT dédiée | Doc à corriger |
| A5 | info | `PRG_03_Safety` lit `PRG_07.M3_Direction_Active` — dépendance croisée position 3 lit position 7 (1 scan de retard, ~10ms) | Non documenté avant, clarifié ici |
| A6 | info | Mode MAINT, `SetFreq_Hz=0` → défaut codé en dur **30%** | Vestige mise en service, jamais formalisé |

## Composition code

`FB_Translation_PositionDecoder` (5 capteurs→mot, dans PRG_00 avant Safety) → `FB_Safety_Translation` (safety métier) → `FB_Translation` (mouvement) → `FB_TranslationOutputInterlock_LD` (barrière finale, dans PRG_10).
Instance unique par FB (pas de ×2 comme Winch — un seul axe M3).
