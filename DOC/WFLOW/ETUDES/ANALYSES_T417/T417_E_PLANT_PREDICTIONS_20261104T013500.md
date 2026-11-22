# T417 — Expérience E-PLANT : géométrie mesurée côté simulateur — prédictions AVANT exécution

Horodatage : **2026-11-04T01:35:00+01:00** — avant toute exécution.
Banc : P6 + simulation, cycle AX14 → AX2 → P1 forcé en AX14, PV 20 Hz. `CODE/` inchangé : mutation sur copie scratch seulement.

## Hypothèse testée

Le simulateur recopie les cotes et le gain de l'automate (`PRG_02_Acquisition.st:378-383`). Il ne peut donc pas montrer d'écart
entre position réelle et position estimée. Les traces MES montrent un autre tracé, mesuré en Hz·s (invariant indépendant du gain).

| Segment | Mesure réelle | Source | Simulateur actuel (5 m, 0,02) |
|---|---|---|---|
| Trémie ↔ PV | ≈ 91,5 Hz·s | trace 04/09, fréquence réelle | 75 |
| PV ↔ P2 | ≈ 350 Hz·s | trace 23/09, consigne (345–351) | 100 |
| P2 ↔ P1 | ≈ 88,5 Hz·s | déduit : 530 − 91,5 − 350 | 75 |
| Trajet moteur complet | 551–554 Hz·s, 13,0–13,8 s | trace 23/09, 3 trajets | ≈ 265, ≈ 7,5 s |

## Variantes

- **BASE** : aucune mutation.
- **PLANT** : mutation de `FB_Sim_Translation` : position simulée PV 1,83 / P2 8,83 / P1 10,60 / Maintenance 12,60, gain 0,02 (échelle
  métrique arbitraire, seuls les Hz·s sont comparés). L'automate garde ses réglages (0 / 1,5 / 3,5 / 5 / 10, 0,02).

## Prédictions

| ID | Mesure | BASE | PLANT |
|---|---|---|---|
| E1 | Durée mot ≠ 0, AX14 | 6–9 s | 12,5–14,5 s (réel 13,84) |
| E2 | ∫f AX14 | 240–300 Hz·s | 520–580 Hz·s (réel 553,6) |
| E3 | ∫f après retrait, AX14 et AX2 | 8–12 Hz·s | 8–12 Hz·s (réel 10,1–11,0) |
| E4 | Fréquence au retrait | 20 Hz | 20 Hz (réel 20,0) |
| E5 | Sauts estimateur > 0,15 m | 0 ou très faibles | ≥ 2 par trajet (réel : sauts au passage des capteurs, trace 89) |
| E6 | Écart max vrai − estimé | < 0,15 m | > 1 m |
| E7 | Parcours d'étapes 14-15-16-18-2 complet | oui | **incertain** : le programme peut réagir aux sauts ; tout écart est rapporté tel quel |

Ce fichier n'est pas modifié après exécution.
