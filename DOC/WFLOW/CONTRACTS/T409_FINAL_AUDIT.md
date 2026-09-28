# T409 — audit d’achèvement

## Éléments prouvés

| Exigence | Preuve | Verdict |
|---|---|---|
| Protocole fixe et borné | `test_t409_protocol.py` | PASS |
| Frein fermé sans mouvement | `test_t409_fmu_scenarios.py` | PASS |
| Marche dans les deux sens | `test_t409_fmu_scenarios.py` | PASS |
| Six mots capteurs admissibles | campagne FMU + garde POU | PASS local |
| Butées -0,30 / 30,30 m | campagne FMU | PASS local |
| UDP 10 ms | `test_t409_gateway_roundtrip.py` : 100/100 | PASS local |
| Reconnexion et reset séquence | `test_t409_recovery.py` | PASS local |
| Trace commande/plante | trace CSV T409 | PASS outil |
| Position initiale explicite | `M3Configuration.initialPosition_M` | PASS modèle |

## Éléments non encore prouvés

| Exigence | Pourquoi non prouvée |
|---|---|
| Compilation du POU dans Control Win | dépend de la copie CODESYS locale |
| Injection effective dans `FB_SimBench` | doit être observée en ligne dans Control Win |
| Rampe PV 15 Hz | décision et commande PLC à vérifier |
| Watchdog frein 500 ms | réaction de `FB_TranslationOutputInterlock` à vérifier |
| Anti-télescopage | dépend des hauteurs M1/M2 réelles de la copie |
| Rebond capteur PLC | FMU et PLC doivent être comparés sur la même trace |
| Désactivation simulation sans effet | essai en ligne requis |
| Safety rotation de phase | divergence CI `TC-T386-M3-001` non arbitrée |

## Verdict

Le socle FMU/UDP est validé localement. La simulation complète intégrée PLC ne peut pas encore être déclarée achevée : les essais Control Win et l’arbitrage safety rotation de phase restent obligatoires.
