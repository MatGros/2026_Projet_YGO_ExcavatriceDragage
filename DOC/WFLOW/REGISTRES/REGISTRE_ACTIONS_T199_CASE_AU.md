# Registre d'actions — T199 CASE réarmement AU

| Action | Décision / preuve attendue |
|---|---|
| Qualification | C4 : AU, contacteur, redondance et sorties de maintien. |
| Stratégie | Patch local de §5, aucune modification d'interface ni de câblage. |
| Forme | `CASE ArmingSeqStep OF` : actions puis transitions dans chaque étape. |
| Timers | Un seul appel du TON actif dans son étape ; reset centralisé en étape 0 et `Enable=FALSE`. |
| Cadencement | Un cycle supplémentaire entre étapes est accepté ; aucune temporisation ne peut être raccourcie. |
| État invalide | Cause d'abandon dédiée, diagnostic et lockout ; aucun silence. |
| Non-régression | Les sorties, causes et lockouts existants sont couverts par les TC-P01 existants plus TC-P01-023. |
