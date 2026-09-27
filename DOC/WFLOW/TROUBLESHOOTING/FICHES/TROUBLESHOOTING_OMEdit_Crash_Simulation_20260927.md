# 🕵️ Session de Troubleshooting — Crash OMEdit à la simulation

> 📅 Date : 2026-09-27 · 🧊 Situation : SIMULATION LOCALE OPENMODELICA · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé (2026-09-27 10:55 Europe/Paris)

### Texte de contexte

POC `M3_POC.Examples.AllerRetour` ouvert dans OMEdit 1.27.1 sous Windows. L'utilisateur rapporte
qu'OMEdit disparaît sans message lorsqu'il lance la simulation. Le même fichier passe `checkModel`
et `simulate` avec `omc.exe`. Deux processus OMEdit répondants ont été observés après le lancement.

### Variables & valeurs

| Élément | Valeur | Horodatage |
|---|---:|---|
| OpenModelica | 1.27.1 64-bit | 2026-09-27 |
| `checkModel` CLI | PASS, 54 équations / 54 variables | 2026-09-27 |
| Simulation CLI | PASS, DASSL, 0–70 s | 2026-09-27 |
| Processus OMEdit observés | 2, répondants | 2026-09-27 10:50 |

## 2. 🎯 Symptôme

OMEdit se ferme sans diagnostic visible au clic sur **Simulate** ; fréquence encore inconnue.

## 3. 🧩 Indices / historique

- Dernier changement : POC restructuré en diagramme Modelica.
- Avertissement préalable : traduction `OMEdit_en_US` absente, sans lien démontré avec le crash.
- Reproduction hors GUI : simulation réussie.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Preuve attendue | État |
|---|---|---|---|
| 1 | Crash du solveur/modèle | échec identique avec `omc.exe` | ❌ éliminée |
| 2 | Deux sessions OMEdit / état graphique incohérent | une seule instance après redémarrage propre | 🟡 contributif possible |
| 3 | Défaut natif OMEdit/Qt | événement Windows ou dump OMEdit | ✅ confirmé : Qt6Gui + qmodernwindowsstyle |
| 4 | Configuration utilisateur OMEdit corrompue | reproduction avec configuration neuve | ❓ |
| 5 | Répertoire de compilation verrouillé | message ou fichier verrouillé dans les traces | ❓ |
| 6 | Charge de tracé/résultats | crash seulement pendant l'affichage des résultats | ❓ |

## 5. 📊 Arbre vertical des hypothèses

```text
Simuler dans OMEdit
├─ modèle / solveur → omc.exe PASS ✅
├─ session graphique → 2 processus OMEdit 🟡
├─ rendu Qt → qmodernwindowsstyle.dll dans la pile d'exception ❌
├─ répertoire de build → traces à collecter ❓
└─ affichage résultats → moment exact du crash à préciser ❓
```

**Résumé une ligne** : `[MODÈLE=PASS] → [OMC=PASS] → [GUI OMEdit=CRASH] ❌`

## 6. 📊 Données / interactions & chronogramme

- Simulation CLI : réussite reproductible.
- Simulation GUI : fermeture rapportée par l'utilisateur.

## 7. 🏁 Conclusion

- **Cause racine candidate forte** : crash du style graphique `qmodernwindowsstyle` dans Qt6Gui,
  indépendant du modèle et du solveur.
- **Statut** : à confirmer par une simulation OMEdit relancée avec le style `Fusion`.

## 8. 🛠️ Proposition de correction

- **Option 1** : lancer OMEdit avec `-style Fusion`, sans changement permanent.
- **Option 2** : si le test est concluant, intégrer `-style Fusion` au lanceur du POC après accord humain.
- **⚠️ Validation requise** : aucune modification du modèle pendant le diagnostic.

## 9. ✅ Vérification de la correction / non-régression

- À compléter après reproduction OMEdit.

## 10. 📝 Journal

- 2026-09-27 : fiche ouverte ; `omc.exe` confirme que le modèle et le solveur fonctionnent.
- 2026-09-27 : événement Windows 1002 et stacktrace lus ; exception native dans Qt6Gui / qmodernwindowsstyle.
