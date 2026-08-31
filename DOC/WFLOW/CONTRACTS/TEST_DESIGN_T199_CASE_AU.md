# Test design — T199 CASE réarmement AU

| ID | Stimulus | Attendu |
|---|---|---|
| TD-01 | Front `ArmRequest`, chaîne fermée, contacteur ouvert | Étapes 1→6, autotest A/B, pulse puis confirmation; pas de redémarrage sans front. |
| TD-02 | Chaque étape 1..6 | Seul le TON de l'étape active est appelé; `ForceTestA/B` est explicite et sûr. Le harnais insère un scan d'entrée avant d'avancer la durée de l'étape. |
| TD-03 | Redondance A ou B / restauration A ou B | Même `LastAbortCause`, même verrouillage et mêmes commandes qu'avant refactor. |
| TD-04 | `BtnEmergencyCutOff`, `PowerCutOffRequest`, chute de chaîne en 5/6 | Abandon prioritaire au scan courant; `ArmPulse_Cmd=FALSE`; cause et lockout conformes. |
| TD-05 | Étape forcée à 7 | Retour IDLE, diagnostic `CST_ABORT_INVALID_STEP`, lockout, aucune impulsion. |
| TD-06 | `Enable=FALSE` pendant chaque phase | Tous forcages/timers/commandes neutralisés comme dans §2. |

Critère de temps : chaque délai est supérieur ou égal à sa valeur normative. Un décalage d'un scan au passage d'étape est admis et doit être observé dans le harnais.
