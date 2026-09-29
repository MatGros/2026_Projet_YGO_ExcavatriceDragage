# T409 — État du POC M3 FMU ↔ Control Win

## ✅ Validé automatiquement

- **Protocole UDP binaire** : trames fixes, bornes et fréquences consigne/mesure contrôlées.
- **Échange FMU local** : 100 réponses / 100, aucun timeout.
- **Cadence** : échanges nominaux à **10 ms** ; reprise après reconnexion validée.
- **Cinématique M3** : frein fermé = pas de mouvement ; directions Trémie/Maintenance correctes ; vitesse limitée à environ 1 m/s.
- **Fins de course FMU** : butées à environ **−0,30 m** et **30,30 m** ; arrêt aux limites validé.
- **AUTO-CYCLE FMU** : trajet P1→Trémie→P1 ; ralentissement anticipé, vitesse nulle, frein confirmé fermé et capteur actif avant les pauses ≥ 1 s ; le trajet se termine à P1 entre **19,97 et 20,00 m**. Relance manuelle explicite, sans départ automatique vers Maintenance.
- **Protection passerelle** : trames invalides et valeurs hors bornes rejetées sans arrêt du gateway.
- **Test Control Win isolé** : déplacement vers Trémie observé, arrêt quelques centimètres avant la butée. Les retours provenaient de la plante FMU, pas de la machine réelle.
- **Vue commune** : animation, joystick FMU, capteurs, frein, Hz, butées et trace locale disponibles. En lecture PLC, les commandes sont neutralisées et la trace n'ajoute un point que sur réception d'une trame UDP.

## ⚠️ Partiel / à corriger

- **Capteurs** : chaîne cumulative 11111 → 01111 → 00111 → 00011 → 00001 → 00000 implémentée conformément au ST actuel. Validation terrain et AF-11 à confirmer : hypothèse POC affichée.
- **Validation Control Win** : CW-00 départ P1 par mémoire reste à exécuter sur la copie.

## ❌ Non validé

- **Comportement M8 en timeout** : décision automate séparée encore ouverte ; voir plus bas.
- **Données machine réelles** : non validées. La vue PLC actuelle lit une télémétrie issue de la copie Control Win ; l'adaptateur est réutilisable avec une source matérielle validée, mais ne la remplace pas.
- **Matériel réel** : hors scope T409-T413. Le miroir actuel lit exclusivement le bridge FMU et GVL_Simulation ; hors simulation ses mesures ne décrivent pas la machine.

## 🔧 Suite prioritaire

1. Exécuter CW-00 dans la copie Control Win et conserver le verdict de la sonde.
2. Exécuter le soak réseau 30 min si le test court reste stable.
3. Décider M8 séparément avant toute évolution du code automate.

> 🛡️ Règle : aucune modification du PLC réel, de `PRG_02` ou de l’IHM existante tant que la copie Control Win n’est pas validée.

## ⚠️ Décision humaine M8 — perte FMU côté SimBench

Constat : le bridge force le mot capteurs 00000 après timeout. Dans la chaîne
cumulative M3, 00000 est aussi la zone Maintenance ; un consommateur PLC doit
donc obligatoirement lire LinkInvalid ou Timeout.

- Option A : conserver le comportement actuel pour le POC et documenter cette
  obligation dans chaque consommateur. **Recommandée pour ce POC**, car elle ne
  modifie aucune logique PLC existante.
- Option B : introduire un état capteur invalide explicite dans l'interface
  SimBench/PLC. Cela nécessite un lot métier séparé, une spécification AF-11 et
  une validation humaine : non réalisé ici.

## 🧪 Preuves locales exécutées

| Point | Commande | Exit | Sortie clé |
|---|---|---:|---|
| FMU, butées, protocole, horizon, wrap, reprise | `powershell -ExecutionPolicy Bypass -File TOOLS/TWINBENCH/udp_m3_link/Run_T409_Verification.ps1` | 0 | 100/100 UDP, butées -0,30 / 30,30 m, horizon 1 000 000 000 s, 50 cycles. |
| Endurance AUTO-CYCLE FMU | `& "$env:LOCALAPPDATA\TwinBenchM3Live\Python\Scripts\python.exe" TOOLS/TWINBENCH/udp_m3_link/test_auto_cycle.py` | à relancer | 50 trajets P1→Trémie→P1 ; vérifie arrêts, frein, capteurs, pauses et immobilisation finale P1. |
| AUTO-CYCLE interface + joystick prioritaire | `& "$env:LOCALAPPDATA\TwinBenchM3Live\Python\Scripts\python.exe" TOOLS/TWINBENCH/modelica_poc_m3/live_poc/test_auto_cycle_backend.py` | 0 | AUTO-CYCLE limité au mode FMU ; joystick l'interrompt ; inactif en mode PLC lecture. |
| Trace interface bornée | `& "$env:LOCALAPPDATA\TwinBenchM3Live\Python\Scripts\python.exe" TOOLS/TWINBENCH/modelica_poc_m3/live_poc/test_trace_bounded.py` | 0 | 201 points après 1 000 pas. |
| Sonde CW-00 : garde-fous verdicts | `python TOOLS/TWINBENCH/udp_m3_link/check_t409_probe_static.py` | 0 | PASS_FRONT contrôle le mot capteurs 00011 ; LinkInvalid est vérifié aux deux lectures. |
| Suite T409 complète | `TOOLS/TWINBENCH/udp_m3_link/Run_T409_Verification.ps1` | 0 | Toutes les vérifications protocole, cinématique, 50 cycles, UDP 10 ms et reprise passent. |
| Soak loopback court | `python test_t409_gateway_soak.py --duration-s 5` | 0 | 500/500 réponses, 0 timeout. |
| Contrat C2 | `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/T409_T413_M3_VISUALISATION.yaml` | 0 | 0 erreur ; 1 avertissement informatif : PyYAML absent, vérification en mode texte dégradé. |

## ⏳ À prouver Control Win

- CW-00 départ P1 par mémoire : suivre [T409_CONTROLWIN_TEST_RECIPE.md](CONTRACTS/T409_CONTROLWIN_TEST_RECIPE.md). La sonde est lecture seule et rend exactement PASS_MEMOIRE, PASS_FRONT_ORDRE_KO ou FAIL.
- Soak réseau 30 min : `python TOOLS/TWINBENCH/udp_m3_link/test_t409_gateway_soak.py --duration-s 1800`. Non exécuté dans ce lot.
- Tenue visuelle 1 h : la deque est structurellement bornée et testée localement ; l'essai longue durée de l'IHM reste à effectuer humainement.

## 🧭 Décisions et besoins fonctionnels

| Choix / besoin | État |
|---|---|
| Travailler d’abord sur une copie **Control Win** isolée | ✅ En place |
| Ne pas modifier la logique PLC existante ; aiguillage par bits de simulation | ✅ Principe retenu |
| Utiliser le même bloc SimBench / mêmes variables GVL | ✅ Principe retenu |
| FMU OpenModelica comme plante M3 externe | ✅ POC fonctionnel |
| Liaison locale UDP binaire, avec flux rapide/cyclique/événement | ✅ POC 10 ms validé |
| Capteurs, frein, fréquence consigne/mesurée et butées mécaniques | ✅ FMU + bridge testés localement |
| Animation fluide et détaillée sans matériel | ✅ POC livré |
| Même animation avec données PLC réel | 🟡 Interface lecture seule prête ; source matérielle à valider |
| Joystick réaliste pour commander le chariot | ✅ Seulement en simulation FMU |
| Zoom dédié capteurs / butées / frein et trace temporelle | ✅ POC livré |
| Affichage court des hypothèses et incertitudes par tags | ✅ Tags POC livrés |
| Couverture des scénarios M3 et validation Control Win complète | 🟡 Tests terrain encore nécessaires |
| Validation sécurité machine réelle | ❌ Hors périmètre de ce POC |
