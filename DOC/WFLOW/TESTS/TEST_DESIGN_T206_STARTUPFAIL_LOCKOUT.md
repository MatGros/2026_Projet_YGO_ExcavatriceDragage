# Test design — T206 StartupFail / verrouillage AU

| ID | Temps / stimulus | Attendu |
|---|---|---|
| TD-01 | `Enable=TRUE`, chaîne ouverte au premier scan | `StartupFail=TRUE`, `Ready=FALSE`, verrouillage de démarrage lancé et `Armable=FALSE`. |
| TD-02 | Chaîne refermée puis `Reset` avant 5 s | Cause acquittée ; `Armable=FALSE` jusqu'à l'expiration mesurée depuis TD-01. |
| TD-03 | `ArmRequest` avant expiration | Étape reste 0, `ArmPulse_Cmd=FALSE`. |
| TD-04 | Expiration des 5 s après Reset précoce, préconditions saines | `Armable=TRUE` au scan d'expiration ; aucun lancement automatique. |
| TD-05 | Reset seulement après expiration, préconditions saines | `Armable=TRUE` au scan du Reset ; aucun délai supplémentaire. |
| TD-06 | Lockout contacteur, PowerCutOff, coupure IHM, Enable=FALSE | Comportements existants inchangés ; le verrouillage StartupFail ne permet aucun contournement. |

Les assertions de temps emploient `CST_ArmingLockout` et non un littéral de 5 s ; les causes emploient les constantes nommées, jamais des valeurs hexadécimales.
