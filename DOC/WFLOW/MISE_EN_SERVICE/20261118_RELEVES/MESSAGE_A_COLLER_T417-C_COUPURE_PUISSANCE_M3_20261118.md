# Message à coller dans T417-C-AGY02 — bypass de la coupure de puissance et déclenchement sur P1 / Trémie (18/11/2026)

> Préparé par TORC-CC10. T417-C n'est pas joignable par messagerie depuis ma session : à coller par l'exploitant. Réponse à coller ensuite dans la session de TORC-CC10.

**Consigne de phase : étude et lecture seule d'abord ; rien n'est écrit dans `CODE/` ni lancé avant validation de l'exploitant ; ensuite tu implémentes, tu contrôles et tu alertes.**

## Besoin (exploitant, 2026-11-18)
À terme : `BypassAuPowerCutOff` à **FALSE par défaut** (la coupure de puissance par l'automate reste active), **sans déclenchement intempestif** quand M3 accoste P1 ou la Trémie.

## Faits (lus par TORC-CC10, vérifiés dans le dépôt)
1. `GVL_BypassRetain.st:31` : `BypassAuPowerCutOff : BOOL := TRUE` (RETAIN). Câblage : `PRG_06_Outputs.st:518` → `BypassPowerCutOff` de `FB_Safety_EmergencyManagement` (`:217` : `CutOffActive := PowerCutOffRequest AND NOT BypassPowerCutOff ...`). Snapshots : TRUE le 17/11 à 10:34 (après chargement), FALSE depuis 12:50 (réglé à la main, conservé en RETAIN), FALSE le 18/11 à 08:36.
2. Incident M3 du 17/11 vers 16:35 (rapporté par T417-C, trace `Suivi_101`, `BypassAuPowerCutOff` = 0) : maintien du joystick ≥ 1,5 s à l'arrêt sur fin de course P1 → coupure d'urgence, puis « défaut variateur AC600 » indirect.
3. Cause lue : `FB_Safety_Translation.st:200-208`, cause 6 « dépassement de limite extrême » = fin de course ET demande ET (`|freq| > 0,5` OU `DriveStatusWord.0`) pendant 1,5 s ; bit 6 dans le masque `16#00F8` (`:269`) → `PowerCutOff`. `M3_StatusWord` = 137 (bit 0 vrai) à l'arrêt dans tous les relevés.
4. `FB_Translation.st:137-143` n'utilise que `|freq| > 0,5` pour sa propre cause 6 ; `FB_Safety_Winch.st` n'utilise aucun mot d'état.

## À étudier (lecture seule) — rends une note courte
1. Toutes les causes de `FB_Safety_Translation` et `FB_Translation` qui peuvent produire `PowerCutOff` à l'arrivée sur P1 ou Trémie (cause 6, Méca A, Méca B, cause 7, autres) : conditions, durées, scénario déclencheur nominal.
2. Correctif minimal de la cause 6 : retrait de `DriveStatusWord.0` ; ajout de `DriveOnline AND DriveOperational` ; conserver `ReqTremie` / `ReqMaintenance` (avis consultatif déjà donné par TORC-CC10, non validé). Effets de bord : perte de bus sur fin de course, arrivée nominale avec rampe de 2,0 s, `TC-T300-SAF-061` à inverser.
3. Passage de `BypassAuPowerCutOff := TRUE` à `FALSE` par défaut : effet RETAIN (la valeur par défaut ne s'applique qu'après un chargement complet qui remet les RETAIN à zéro), écriture à prévoir, GO C4 explicite, ordre : d'abord le correctif de la cause 6 validé sur la machine, ensuite le défaut à FALSE.
4. Conflits avec le commit `e75d1e08` (`PRG_06`, `PRG_04`) et avec `T377-B`.

## Point 5 à étudier : perte joystick en mode boutons IHM (demande de l'exploitant, 18/11 09:17)
Besoin : quand `GVL_IHM.Modes.Cmd.TglJoystickMaster` est FALSE (pilotage par les boutons IHM), l'absence du joystick ne doit plus mettre les treuils et M3 en SafeStop ; le programme doit le gérer lui-même, sans bypass manuel.
Faits : cause 0 « perte com opérateur » = `NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk` (`FB_Safety_Winch.st:270-274`, `FB_Safety_Translation.st:123-128`), contournable seulement par `BypassProcess` / `BypassOperatorComm`, lequel supprime aussi la surveillance de `HeartbeatIhmOk`. Les deux FB ne reçoivent pas `TglJoystickMaster`.
À étudier : ne garder `JoystickOnline` / `JoystickOperational` que si `TglJoystickMaster` est vrai ; conserver `HeartbeatIhmOk` ; câblage depuis `PRG_04` et `PRG_05` ; effets sur le bandeau (`[CAN] Joystick JOY1 non detecte`, `ArmingPermit`), sur SEMI_AUTO et sur MAINT_N2 ; cas limite : bascule du mode joystick en cours de mouvement ; test de non-régression avec joystick présent.

## Point 6 à étudier : maître joystick / maître IHM et perte du heartbeat IHM (exploitant, 18/11 09:37)
Doctrine de l'exploitant : si le joystick tombe, on passe en mode boutons IHM ; si l'IHM tombe, on ne peut plus choisir N2 et le défaut est le joystick.
Faits : `TglJoystickMaster` vaut TRUE par défaut (`ST_ModesCmd.st:18`), jamais écrit par l'automate, aucun repli si l'IHM disparaît en marche ; `FB_Modes` n'utilise pas `HeartbeatIhmOk` ; en MAINT_N2 le SafeStop n'inclut pas la cause « perte com opérateur » (`PRG_04:1171-1175`).
À étudier : (1) que devient une commande IHM maintenue si l'IHM gèle en N2 mode boutons ; (2) repli automatique vers le joystick quand le heartbeat IHM tombe ; (3) cohérence avec le point 5 (la cause 0 ne regarde que le maître actif) ; (4) effets sur M3 et sur SEMI_AUTO.

## Livrable et suite
Note dans `DOC/WFLOW/MISE_EN_SERVICE/20261118_RELEVES/` ; exploitant valide ; puis lot C4 sous contrat à périmètre épinglé, bundle complet + diff bundle + G200, diff montré fichier par fichier avant tout commit `CODE/`. Pas d'échéance fixée.
