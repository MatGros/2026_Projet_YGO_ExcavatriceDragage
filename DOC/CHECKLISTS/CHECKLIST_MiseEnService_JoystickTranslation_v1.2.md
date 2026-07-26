# 🕹️ Checklist & Sécurités de Mise en Service — Joystick & Translation M3 (v1.2)

> 📌 Fiche combinée et optimisée pour la mise en service terrain du 2026-07-24.
> Validée sur matériel réel, sans simulation. S'utilise sans plugin (cases Markdown `[ ]` / `[x]`).

## 1. Joystick JOY1

- [ ] **1. Calibration** : Manche physique au repos, envoyer un front sur `GVL_IHM.JOY1Joystick.BtnCalibrate`. Vérifier que `NeutralXAct` et `NeutralYAct` s'alignent sur les valeurs brutes du capteur physique.
- [ ] **2. Plage de mesure** : Dévier le manche. Vérifier que les signaux de tension `RawX` / `RawY` évoluent de manière cohérente dans la plage `0..10000` (butée à butée).
- [ ] **3. Interdiction Hors Neutre** : Appuyer sur le bouton homme-mort manche dévié (hors neutre) -> `DeadmanArmed` doit rester `FALSE` (anti-démarrage intempestif).
- [ ] **4. Armement au Neutre** : Ramener le manche au neutre exact, appuyer sur le bouton homme-mort -> `DeadmanArmed` doit passer à `TRUE`.
- [ ] **5. Vérification des Axes** : Déplacer le manche en maintenant l'homme-mort -> `AxisCmdX` (Translation) et `AxisCmdY` (Treuils) doivent donner le sens et la vitesse physique attendus.
- [ ] **6. Relâche en Mouvement** : Lâcher l'homme-mort en mouvement -> Rampe de décélération immédiate de la machine jusqu'à l'arrêt, puis aucun redémarrage automatique.
- [ ] **7. Reprise après neutre** : Pour repartir après relâche, confirmer l'obligation physique de ramener le manche au neutre puis de ré-appuyer sur l'homme-mort.
- [ ] **8. Défaut CANopen** : Débrancher la prise M12 du bus CANopen sur le joystick -> `.Online`/`.Operational` du joystick tombent à `FALSE`, `Error` passe à `TRUE` et `ErrorId` mémorise le défaut.
- [ ] **9. Reset Liaison** : Rebrancher le câble CANopen, envoyer un front sur `Modes.BtnFaultReset` -> Le défaut ne doit s'effacer que si la liaison réseau est réellement opérationnelle.

---

## 2. Translation M3 (AC600)

- [ ] **10. Prérequis Zone & AU** : Zone physique M3 évacuée, AU physique testé, retour de puissance OK, modes configurés : `Modes.EmergencyStopOk=TRUE`, `Modes.PowerCutOffActive=FALSE`, `Modes.CurrentMode=MAINT_N1`.
- [ ] **11. Consigne de Vitesse** : Régler `TranslationM3.Cmd.SetFreq_Hz := 20.0` (vitesse terrain prudente) et s'assurer que `TranslationM3.State.Error` et `Safety.Error` sont à `FALSE`.

> ⚠️ **Anomalie constatée le 2026-07-24 — à traiter au prochain passage** : consigne 10 % → mot
> `M3_SetpointFrequencyHz` observé à **1800** au lieu de **600** attendu. Chaîne théorique
> (`FB_Translation.st:180` + `PRG_10_Outputs.st:128`) : `DriveFreqRefHz := (SpeedPct/100)*DriveFreqScaleMaxHz`
> puis `M3_SetpointFrequencyHz := DriveFreqRefHz*100`. Avec `DriveFreqScaleMaxHz=60.0` (défaut
> documenté Partie-11), 10 % devrait donner 600. Hypothèse évoquée (`_TranslationMaxFreq_Hz=180`
> au lieu de 60) **non confirmée par l'utilisateur** — à vérifier concrètement :
> 1. Lire `GVL_PERSISTENT._TranslationMaxFreq_Hz` (ou `DriveFreqScaleMaxHz` en Watch sur l'instance) au moment du test.
> 2. Si la valeur lue est bien 60.0 malgré le résultat 1800 → chercher une échelle additionnelle côté mapping EtherCAT/PDO ou paramétrage variateur AC600 (hors code ST, pas encore investigué).
> 3. Ne pas modifier le code tant que la valeur réelle de `DriveFreqScaleMaxHz` au moment du test n'est pas connue.
- [ ] **12. Liaison EtherCAT Variateur** : Confirmer la communication avec le variateur AC600 -> `DriveCommReady=TRUE` et `DrivePowerReady=TRUE`. Le frein moteur doit être serré physiquement (`BrakeCmd=FALSE`).
- [ ] **13. Décodage Cibles Physiques** : Vérifier que le mot de position `SensorsWord` lu à partir des 5 détecteurs inductifs est cohérent (ex. `11111`, `01111`, etc.) et que le flag `SensorWordIncoherent` est `FALSE`.
- [ ] **14. Premier Mouvement Boutons (IHM)** : Configurer `TglJoystickMaster=FALSE`. Armer l'homme-mort. Maintenir le bouton physique/IHM `BtnFwd` -> Rotation avant (vers Trémie). Relâcher -> Arrêt sur rampe et fermeture du frein.
- [ ] **15. Marche Arrière Boutons (IHM)** : Maintenir `BtnRev` -> Rotation arrière (vers Maintenance). Relâcher -> Arrêt normal.
- [ ] **16. Interlock de Sens** : Inverser Fwd/Rev en cours de mouvement -> Arrêt de l'axe, délai physique minimum de 200 ms à vitesse nulle, puis redémarrage dans le sens opposé.
- [ ] **17. Pilotage Joystick (Axe X)** : Mettre `TglJoystickMaster=TRUE`. Armer l'homme-mort. Dévier l'axe X -> Le sens et la vitesse réelle du moteur suivent la déviation physique du manche.
- [ ] **18. Arrêt sur Cible** : Activer `SelPositioning=TRUE`. Choisir une cible (ex. 1 = Trémie). Lancer le mouvement -> Le pont doit s'arrêter précisément face au capteur inductif sélectionné avec `PositionReached=TRUE`.
- [ ] **19. Butées Extrêmes** : Rouler volontairement jusqu'à l'attaque d'une butée extrême de fin de course -> Arrêt immédiat de la commande variateur, coupure puissance amont (`Safety.ErrorLimitSwitch=TRUE`, `PowerCutOffActive=TRUE`).
- [ ] **20. Reset Défaut Réel** : Déclencher un défaut variateur (ex. coupure alimentation de commande) -> Mémorisation de `ErrorId`, passage immédiat en sécurité. Rétablir le matériel, envoyer un front sur `Modes.BtnFaultReset` -> Retour au repos OK sans redémarrage automatique.

---

## 🛡️ 3. Points de Surveillance Critiques (Garde-fous Système)

> ⚠️ **IMPORTANT** : Pour valider définitivement les sécurités réelles et ne plus avoir à y revenir :

- [ ] **S1. Réenclenchement Interdit** : Simuler un défaut sur la Translation. Maintenir une commande de déplacement active tout en appuyant sur `BtnFaultReset` -> Le pont ne doit **pas** bouger au réarmement.
- [ ] **S2. Interverrouillage de Sens (Anti-contrefiche)** : En déplacement rapide sur un sens (ex. Fwd), pousser instantanément le manche dans le sens opposé (Rev) -> Le variateur doit d'abord décélérer jusqu'à l'arrêt complet avant de basculer la commande de pont.
- [ ] **S3. Perte IHM (Blink Heartbeat)** : Débrancher le câble Ethernet de l'écran ou de la supervision -> Le pont de Translation doit passer en `SafeStop` sous 2 secondes.
- [ ] **S4. Mécanique A (Mouvement non commandé à l'arrêt)** : Commande à 0 et frein serré, simuler une dérive de l'axe (vitesse moteur réelle lue > 0.5 Hz) -> Déclenchement de la sécurité Méca A sous 1 seconde (`ErrorMecaA=TRUE`, `PowerCutOff=TRUE`).
- [ ] **S5. Mécanique B (Frein bloqué ouvert à l'arrêt)** : Commande à 0, simuler un retour de contacteur de frein resté collé/ouvert -> Déclenchement de la sécurité Méca B sous 3 secondes (`ErrorMecaB=TRUE`, `PowerCutOff=TRUE`).
- [ ] **S6. Surchauffe thermique frein** : Débrancher la sonde thermique de frein commun -> Arrêt immédiat de la puissance (`PowerCutOff=TRUE`, `ErrorBrakeThermal=TRUE`).
- [ ] **S7. Incohérence Mot Capteurs** : Occulter ou débrancher un capteur inductif pour créer un mot de position impossible (ex. `10101`) -> Arrêt immédiat par sécurité (`ErrorSensorIncoherent=TRUE`, `PowerCutOff=TRUE`).
