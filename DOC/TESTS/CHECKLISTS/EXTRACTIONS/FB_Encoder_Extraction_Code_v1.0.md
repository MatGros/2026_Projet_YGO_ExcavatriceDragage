# Extraction Encodeurs/Homing — code vs AF09 (v1.0)

> Sources : `CODE/CODEURS/*.st`, `CODE/MAIN/PRG_02_Encoders.st`, `CODE/TREUILS/FB_Safety_Winch.st` (consommateur).
> Statut : fiche de travail avant AF09 v2.0. Renommage `EmergencyStopOk→PowerContactorEngaged` déjà à jour partout ici.

## Alertes (devoir d'alerte)

| # | G | Sujet | Statut |
|---|---|---|---|
| A1 | P1 | Bits ErrorId 6/7/8 documentés (legacy) mais **non codés** dans `FB_Encoder_Homing` (saut incohérent §3.5 jamais implémenté) | TBD assumé legacy |
| A2 | **P0** | `Homed=FALSE` seul (jamais mis en doute) **ne bloque pas SEMI_AUTO** — seul `EncoderFaultPresent` (bornage+HomingSuspect) le fait. Un treuil jamais homé pourrait passer en SEMI_AUTO | **Décision utilisateur requise** |
| A3 | P1 | `CfgTopSensorPos_M` : défaut déclaré 8.5m vs **valeur RETAIN réelle 8.0m** (MES-009) — deux vérités cohabitent dans le code | Doc à corriger |
| A4 | P2 | `CodeSeqTriggerCmd` toujours 0, rôle jamais confirmé | TODO ouvert |
| A5 | P2 | `FB_Encoder_SpeedMonitor` : seuils câblés à 0 → diagnostic inerte jusqu'à réglage (T45) | Volontaire, documenté |
| A6 | info | Bouton `BtnHomingAtZero` (force homing à 0.0m) existe en code, absent de toute doc | À documenter |
| A7 | info | Numérotation ErrorId **différente par FB** (`FB_Encoder_Homing` ≠ `FB_Encoder_Safety`) — pas une table unifiée comme suggéré par doc legacy | À clarifier dans nouvelle doc |

## Composition code

`FB_Encoder_Abs` (bus EtherCAT) → `FB_Encoder_Homing` (orchestration + RETAIN `ST_Encoder_Calib`) → `FB_Encoder_Scale` (pts→m) → `FB_Encoder_Safety` (bornage+cohérence) → `FB_Encoder_SpeedMeasure` (vitesse 50ms/6 éch.)
Instances ×2 (M1/M2), toutes dans `PRG_02_Encoders` — producteur unique position/vitesse.
`FB_Encoder_SpeedMonitor` : diagnostic seul, instances dans `PRG_03_Safety`.
