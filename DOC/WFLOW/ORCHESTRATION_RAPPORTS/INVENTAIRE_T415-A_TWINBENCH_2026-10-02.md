# 🧭 T415-A — Inventaire TwinBench

> État : **proposition à valider** · 2026-10-02
> Portée : inventaire documentaire uniquement. Aucun fichier technique déplacé, supprimé ou modifié.

## Décision à retenir

TwinBench n'a pas encore de parcours utilisateur unique. Les POC sont utiles, mais leurs lanceurs
se superposent et certains annoncent « PLC » sans correspondre au même niveau d'intégration.

| Usage humain | Point d'entrée à conserver | État réel | Décision proposée |
|---|---|---|---|
| Copier / ouvrir une application PLC isolée | `controlwin_runner/Lancer_TwinBench_ControlWin.cmd` | ✅ Recette humaine T404 documentée | **Référence unique Control Win** |
| Ouvrir le modèle M3 dans OMEdit | `Lancer_POC_M3.bat` | 🟡 POC autonome, sans PLC | **Conserver : apprentissage/modèle** |
| Faire varier la plante FMU locale | `Lancer_POC_M3_Live.bat` | 🟡 POC local ; fidélité non qualifiée | **Conserver : développement physique** |
| Chaîne FMU ↔ copie Control Win | `udp_m3_link/Start_T409_M3_Integration.cmd` | 🔴 Instable/non qualifiée ; conflit de port déjà rencontré | **Geler comme recette technique, ne pas présenter comme point d'entrée** |

## Carte des briques existantes

| ID / dossier | Responsabilité réelle | Preuve disponible | Classement proposé |
|---|---|---|---|
| T400 · fiche M3 | Faits, hypothèses, inconnues de modélisation | Fiche documentée | **Référence à conserver** |
| T401 · `modelica_poc_m3/M3_POC.mo` | POC OpenModelica autonome, capteurs et butées hypothétiques | README + validation `omc` déclarée | **Conserver, non fidèle terrain** |
| T402 · ScriptEngine | Probe / impulsion dans l'IDE CODESYS | Recette manuelle ancienne | **Historique, hors boucle cyclique** |
| T403 · aiguillage SimBench | Sélecteur image M3 interne / OM | Code et contrat existants | **Référence d'architecture à auditer sous T415-B** |
| T404 · `controlwin_runner/` | Copie isolée et déploiement local Control Win | Recette humaine documentée | **Socle à conserver** |
| T405 · `live_poc/` | FMU locale + interface QML | Tests locaux déclarés | **Conserver comme banc physique isolé** |
| T406 · contrat liaison | Images, cadence, validité, reprise | Contrat existant | **Entrée de T415-B : consolider, ne pas dupliquer** |
| T407 · UDP ScriptEngine | Connectivité loopback lente | Mesure ~217 ms/échange | **Archiver plus tard comme preuve d'exclusion performance** |
| T408 · UDP natif | Benchmark 10/50 ms, sans M3 | Mesures humaines rapportées | **Conserver comme banc de transport** |
| T409 · `udp_m3_link/` | POC FMU + pont SimBench Control Win | Tests locaux et incidents humains contradictoires | **Geler : audit/requalification obligatoire** |
| T414 · shadow CPU réel | Visualisation lecture seule future | Non démarré | **Hors urgence ; conserver séparé de la simulation** |

## Lanceurs : problème et règle cible

### Problème constaté

- Racine `TOOLS/TWINBENCH/` : quatre lanceurs visibles (`Lancer_POC_M3`, `Lancer_POC_M3_Live`,
  `Lancer_M3_Live_PLC_Lecture`, `Start_M3_PLC_Demo`).
- T409 ajoute son propre lanceur d'intégration, son gateway et ses scripts de test.
- T407/T408 ajoutent encore leurs propres lanceurs. Aucun catalogue utilisateur ne dit clairement
  lequel est un test, une démo, ou une intégration PLC qualifiée.

### Règle proposée pour validation humaine

1. **Un seul point d'entrée par usage**, documenté dans un guide court.
2. Un lanceur utilisateur ne peut annoncer « Control Win » ou « PLC » que s'il indique : copie
   isolée, prérequis, données lues/écrites et état de qualification.
3. Les scripts `test_*`, `check_*`, `Start_T407_*`, `Start_T408_*`, gateway et démos restent
   internes à leur dossier ; jamais recommandés comme première action utilisateur.
4. Aucun renommage, déplacement ou archivage avant validation explicite de ce tableau.

## Parcours cible proposé — pas encore implémenté

```text
1. Control Win isolé          -> T404 uniquement
2. Modèle physique hors PLC   -> T401 / T405 uniquement
3. Intégration M3 qualifiée   -> T415-D puis T415-E3, pas T409 directement
4. CPU réel lecture seule     -> T415-F / T414, futur hors chemin critique
```

## Risques qui bloquent une présentation « simulation fiable »

| Risque | Fait observé | Traitement prévu |
|---|---|---|
| Démarrage ambigu | Plusieurs lanceurs et modes PLC | Décision de parcours avant refactor |
| T409 non stabilisé | Port occupé et comportement capteurs/position contesté | Audit de frontière et recette sous T415-B/D/E |
| Fidélité physique | Réducteur, frein, rampes et positions mécaniques incomplètement mesurés | Hypothèses marquées ; qualification terrain dans T415-E |
| CPU réel | Control Win n'est pas le CPU réel | T415-F lecture seule, aucun stimulus simulé |

## Décisions humaines demandées avant toute opération fichier

- Valider les quatre usages et points d'entrée ci-dessus.
- Autoriser ou non le futur regroupement des lanceurs internes hors racine.
- Dire si T407 doit être archivé comme preuve historique après audit de ses références.
- Dire si T409 doit être réparé après T415-B, ou conservé uniquement comme prototype de référence.

## Preuves de l'inventaire

- `DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md` : `FB_SimBench` est la frontière unique ;
  la simulation produit une image matériel plausible, sans bypass de sécurité.
- `TOOLS/TWINBENCH/controlwin_runner/README.md` : T404 isole une copie et cible uniquement
  `CODESYS Control Win V3 x64` local.
- `TOOLS/TWINBENCH/modelica_poc_m3/README.md` et `live_poc/README.md` : T401/T405 sont hors PLC.
- `TOOLS/TWINBENCH/native_udp_poc/README.md` : T408 est un benchmark de transport sans M3.
- `TOOLS/TWINBENCH/udp_m3_link/README_T409.md` : T409 est une intégration expérimentale,
  non une preuve de fidélité globale.
