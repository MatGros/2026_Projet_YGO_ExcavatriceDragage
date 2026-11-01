# 🕵️ T417 — Trace 94 : glissement treuil à vérifier

> **RECTIFICATION 2026-10-31 — historique ci-dessous conservé, conclusions remplacées.**
> La demande de refaire un essai treuil (§4) est retirée du périmètre T417 ; aucune
> acquisition supplémentaire n'est demandée. L'arrêt à 49 786 ms est en **étape 0**,
> pas AX14 ; l'arrêt AX14 de 94 est à 186 793 ms. `ActualFrequencyHz` est en
> centi-Hz (division par 100). Fréquence nulle ne prouve pas immobilité mécanique.
> Les traces 94/95 ne mesurent aucune distance vraie/estimée et ne capturent ni mode
> ni réglage PV. Référence active : [investigation exécutée, lots A–D](../../ETUDES/ANALYSES_T417/PLAN_INVESTIGATION_20261031.md).

> 📅 2026-10-30 · 🧪 **SIMULATION** · 📄 Statut : **EN COURS**  
> Source : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_94_SIMU_M3_manu_auto_20261029.trace`

## 1. Symptôme rapporté

Après un homing en erreur à 5 Hz, passage à 20 Hz en manuel, puis consigne automatique annoncée à **−10 m** ; l’IHM est rapportée à **−13 m**. Question : glissement important des **treuils** en descente ?

⚠️ Ces valeurs de position ne sont **pas présentes** dans la trace 94 ; elles restent à confirmer par une trace contenant la position physique simulée et la position estimée automate.

## 2. Faits vérifiés dans la trace

| Élément | Preuve observée | Verdict |
|---|---|---|
| Périmètre de la trace | Les variables disponibles sont celles de la translation M3 ; aucun signal M1/M2/treuil identifiable | ⚠️ ne permet pas d'analyser le treuil |
| Cycles de déplacement | `SequenceState.Step` évolue 0→2→21→4… puis cycles suivants | ✅ plusieurs séquences M3 capturées |
| Consignes | `RequestedDriveFreqHz` monte jusqu’à 50 puis redescend à 0 | ✅ rampe commandée |
| Arrêt | Exemple AX14/Trémie : commande variateur = 0 à t=49 786 ; fréquence réelle décroît ensuite jusqu’à 0 à t=50 205 | ✅ décélération observée |
| Frein | `BrakeIsOpen_DI` passe 1→0 à t=49 890 ; `BrakeCmd` reste à 1 jusqu’à t=50 829 | ✅ fermeture avant fin de séquence |
| Après arrêt | fréquence réelle, commande variateur et consigne restent à 0 sur la suite de la fenêtre | ✅ aucun mouvement résiduel démontré par ces signaux |
| Position −10/−13 m | aucun signal de position absolue/estimée dans ce fichier | ❓ non vérifiable |

## 3. Hypothèses, séparées des faits

- 🟡 **Hypothèse principale** : l’écart −10→−13 m peut provenir de l’estimateur, d’un signe/origine ou d’une unité ; aucun signal treuil ne permet d’évaluer un glissement.
- 🔴 **Non établi** : « beaucoup de glissement des treuils en descente ». La trace 94 ne contient pas les positions, vitesses, consignes ni freins M1/M2.

## 4. Décision d’investigation

Ne pas modifier le code automate sur cette seule preuve. Refaire un essai treuil avec, dans la même trace :

1. position réelle/estimée du treuil concerné ;
2. consigne de position et vitesse ;
3. fréquence réelle et commande variateur du treuil ;
4. demande/retour de frein du treuil ;
5. consigne numérique et état homing/configuration PV.

Le test sera concluant si la distance parcourue après `DriveFreqCmd_Hz=0` est calculable et comparée à l’écart d’estimation.

## 5. Journal

- 2026-10-30 : analyse de la trace 94 ; signaux M3 observés, aucun signal treuil exploitable.
- 2026-10-30 : trace 95 reçue, étiquetée par l'utilisateur « essai 10 Hz ». Elle contient la même famille de 30 signaux M3, sans position/vitesse/frein M1/M2 ; elle ne permet donc pas de conclure sur le glissement des treuils.
- 2026-10-30 : trace 95 montre une rampe M3 jusqu'à 50 Hz puis retour à 0 et retour du frein ; comparaison 10/20 Hz treuil non réalisable avec ces variables.
- 2026-10-30 : position −10/−13 m classée **rapport utilisateur à confirmer**, absente de la trace fournie.

### R38–R42 — diagnostic CODESYS AX15C (2026-11-01)

**Verdict :** blocage AX15C expliqué par l'autorisation de descente M3, observé en Simulation IDE sur copie isolée. Ce n'est pas encore un verdict de défaut automate : le comportement demandé par la séquence et la règle d'autorisation se contredisent, et la spec ne tranche pas.

| Preuve | Résultat | Portée |
|---|---|---|
| R40–R41, verrou par défaut TRUE, AX15C | demandes M1/M2 `RunRequest=TRUE`, `ReqDescend=TRUE`; `WinchDescentAuth_M3=FALSE`; paliers treuil 0, relais inverse FALSE, freins non ouverts | Chaîne d'autorisation bloquante observée |
| R42, déverrouillage temporaire en RAM de la copie | M1/M2 palier 1, relais inverses TRUE, commandes frein TRUE et retours frein ouvert TRUE | Le verrou est discriminant pour l'activation de la chaîne de sortie |
| R42, positions | environ 8,5 m → 1,24/1,42 m en 3 s | Variation trop forte et non calibrée : preuve de mouvement exploitable ni de vitesse physique |
| R42, fermeture | arrêt application, logout et runner terminés; aucun processus CODESYS restant | Le readback de restauration du réglage a échoué; ne pas réutiliser cette session. Copie projet disque inchangée et valeur persistante source par défaut TRUE |

**Traçage inverse :** `FB_CycleSemiAuto.st:1566–1585` place AX15C en repositionnement et demande la descente couplée M1/M2. `PRG_03_Modes_Cycle.st:503–513` autorise cette descente seulement si le verrou est désactivé, M3 est à P1/Maintenance ou un bypass est actif. À la Trémie, le verrou TRUE donne donc l'autorisation FALSE. `PRG_04_Treuils_Benne.st:1070–1083` combine permis process/sécurité puis applique cette autorisation; les relais restent coupés.

**Décision ouverte :** faire trancher la règle métier/sécurité AX15C à la Trémie avant toute modification automate ou tout nouvel essai avec le verrou neutralisé. Si la descente doit être interdite, le parcours/attendu AX15C doit changer. Si elle doit être permise, fournir une règle d'autorisation explicite et la faire valider dans le workflow C2 avant proposition de correction. R42 révèle aussi un défaut de harnais : il doit marquer le réglage « modifié » avant écriture et confirmer sa restauration, avec arrêt sûr au moindre échec.

Preuves brutes : `TOOLS/AGENT_WORKFLOW/.tmp/t417_auto_r40_20261101/`, `...r41.../`, `...r42.../` (journaux runtime et résultats). Simulation uniquement; pas de validation distance, vitesse, tolérance ni parcours complet accepté.
