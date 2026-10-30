# 🕵️ T417 — Trace 94 : glissement treuil à vérifier

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
