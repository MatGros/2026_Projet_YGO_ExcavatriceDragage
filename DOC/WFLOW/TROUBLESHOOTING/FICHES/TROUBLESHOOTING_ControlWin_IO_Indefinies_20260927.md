# 🕵️ Session de Troubleshooting — Control Win : E/S physiques indéfinies

> 📅 Date : 2026-09-27 · 🧊 Situation : SIMULATION BANC · 📄 Statut : CORRIGÉ ET COMPILÉ SUR COPIE ISOLÉE

## 1. 🧊 Contexte figé

Après remplacement de la cible matérielle `VH601-0808TP` par `CODESYS Control Win V3 x64 3.5.19.10`, puis retour par `Update Device`, la compilation de `PRG_02_Acquisition` échoue sur huit entrées de `Local_Digital_IO`.

## 2. 🎯 Symptôme

Compilation impossible sur Control Win : les identifiants d'E/S physiques et l'objet device `Local_Digital_IO` ne sont pas définis.

## 3. 🧩 Indices / historique

- Changement récent : cible du projet remplacée par Control Win.
- Les huit identifiants sont consommés dans la section `HwReal` de `PRG_02_Acquisition`.
- Ils ne sont pas déclarés dans `CODE/*.st` : ils proviennent de la configuration et du mapping d'E/S de la cible VEICHI réelle.
- `AF_Partie-06_Acquisition_Qualification_IO_v2.4.md` associe ces signaux au module physique `Local_Digital_IO`.
- Après `Update Device`, l'erreur sur l'objet `Local_Digital_IO` lui-même a disparu : le module est restauré, mais pas ses huit noms de mapping d'entrée.
- Le build signale aussi `Direct I/O Access via Symbol Configuration is enabled` avec 36 symboles publiés en écriture : téléchargement sur le PLC réel interdit avant désactivation ou revue explicite.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Preuve | Verdict |
|---|---|---|---|
| 1 | Défaut du code métier M3/SimBench | Les erreurs visent exclusivement des symboles matériels `HwReal` | ❌ |
| 2 | Redémarrage ou changement de langue | Aucun lien avec la résolution des symboles à la compilation | ❌ |
| 3 | Le retour de cible a restauré le module mais pas son mapping d'entrées | `Local_Digital_IO.GetDeviceState()` compile désormais ; seules les huit variables de ses bits 0..7 restent inconnues | ✅ Cause |

## 5. 📊 Arbre vertical

```text
Cible VEICHI réelle
  → arbre matériel Local_Digital_IO
  → mappings symboliques M1/M2/M3
  → PRG_02_Acquisition compile

Cible revenue sur VEICHI après Update Device
  → objet Local_Digital_IO restauré
  → mapping des bits d'entrée 0..7 absent
  → C0046 dans PRG_02_Acquisition
```

**Résumé une ligne** : `[VEICHI restauré] → [Local_Digital_IO présent] → [mapping DI0..DI7 absent] → [8 × C0046]`

## 6. 📊 Lectures & essais

- Lecture statique `PRG_02_Acquisition` : les symboles en erreur alimentent `HwReal` aux lignes sources 146–193 ; `Local_Digital_IO.GetDeviceState()` est lu ligne 211.
- Recherche dans `CODE/*.st` : usages trouvés, aucune déclaration globale de ces symboles.
- Documentation AF06 : mapping confirmé sur `Local_Digital_IO` physique.
- Build utilisateur après `Update Device` : 16 erreurs (deux diagnostics par variable), aucune erreur sur l'objet `Local_Digital_IO`.

## 7. 🏁 Conclusion

- **Cause racine** : le passage Control Win puis le retour par `Update Device` a laissé vide/perdu le mapping symbolique des huit entrées intégrées `Local_Digital_IO`.
- **Statut** : cause confirmée ; stratégie de banc à choisir avant toute modification.

## 8. 🛠️ Proposition de correction

- **Option immédiate recommandée** : rouvrir la sauvegarde fraîche `PRJ_CODESYS/v0.7.27_SimBench_AvantOpcUA_20260927.project` (12:47, avant conversion), compiler hors ligne, puis repartir d'une nouvelle copie sans changer de Device. Cette restauration est plus sûre qu'une reconstruction manuelle des mappings.
- **Option de secours** : restaurer dans l'onglet de mapping de `Local_Digital_IO` les huit noms canoniques définis par AF06, uniquement si la sauvegarde échoue.
- **Sécurité** : désactiver/revoir `Direct I/O Access` dans `Symbol Configuration` avant toute connexion ou téléchargement sur le PLC réel.
- **Option POC Control Win** : conserver une copie séparée contenant une couche d'adaptation simulée ; ne plus convertir le projet réel dans les deux sens.
- **À ne pas faire** : supprimer les lectures `HwReal` ou télécharger tant que le mapping et les droits d'écriture OPC UA ne sont pas vérifiés.
- **⚠️ Validation requise** : humaine avant création de la couche d'adaptation.

## 9. ✅ Vérification attendue

- ✅ La copie Control Win compile sans `C0046` : **0 erreur, 1 avertissement**.
- ✅ Le projet source est byte-identique : SHA-256 `c6e12a7a8a09da7981c82ad26d79d8409f4f27ae8f75aa366b8cf5e0805b7ab5` avant/après.
- ✅ L'adaptateur est limité à `Application_from_source.export` dans `%LOCALAPPDATA%`.
- ⏳ Le projet réel conserve son arbre matériel ; aucun téléchargement réel n'a été tenté.
- `SimulationModeActive = FALSE` maintient l'absence d'effet de la simulation sur la machine réelle.

## 10. 📝 Journal

- 2026-09-27 : journal CODESYS reçu ; analyse statique effectuée ; cause établie sans modification du code PLC.
- 2026-09-27 : second build après `Update Device` reçu ; diagnostic affiné au mapping DI0..DI7 de `Local_Digital_IO` ; alerte `Direct I/O Access` relevée.
- 2026-09-27 : inventaire des projets effectué ; sauvegarde pré-OPC UA identifiée à 12:47 (`v0.7.27_SimBench_AvantOpcUA_20260927.project`, 15 271 840 octets).
- 2026-09-27 20:05 : premier adaptateur dérivé testé ; erreurs réduites de 293 à 8.
- 2026-09-27 20:10 : ajout des quatre canaux analogiques restants ; compilation Control Win **0 erreur / 1 avertissement**. Aucun déploiement.
- 2026-09-27 20:14 : seconde compilation bout-en-bout de confirmation : **0 erreur / 1 avertissement** ; état `PREPARED`.
- 2026-09-27 20:15 : 30 artefacts `candidate_*` historiques déplacés sans suppression vers `%LOCALAPPDATA%\TwinBenchControlWin\Archives\20260927_201518_candidate_cleanup` ; garde-fou runner **46/46 PASS**.
