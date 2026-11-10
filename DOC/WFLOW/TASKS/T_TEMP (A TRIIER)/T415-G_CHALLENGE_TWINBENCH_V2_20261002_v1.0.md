# 🧪 Challenge expert — Proposition TwinBench v2 (2026-10-02)

> Revue lecture seule par sous-agent CC02 (persona : automatisme industriel, IHM, recette, sécurité machine, ergonomie).
> Objet : `PROPOSITION_TWINBENCH_V2_2026-10-02.md`. « vérifié » = fichier:ligne ; sinon **hypothèse**.

## 1. Verdict
🟠 **GO avec réserves** : socle juste (projet unique + `Device_CtrlWinSim`, fin de la copie réécrite), mais 5 défauts ExtLink à corriger avant l'essai UDP Control Win, un risque sécurité réseau terrain non traité (P01), et un parcours qui s'arrête à « lien prêt » au lieu de « chariot qui bouge ».

## 2. Problèmes

| Id | Gravité | Thème | Constat | Recommandation |
|---|---|---|---|---|
| P01 | BLOQUANT | Sécurité | Masters EtherCAT/CANopen conservés dans `Device_CtrlWinSim` ; la v1 les neutralisait (HW_SIM, `codesys_headless.py:91-99`). PC câblé au réseau machine ⇒ Control Win peut démarrer le bus et piloter des esclaves réels (**hypothèse**). | Désactiver les masters (Disable device) ; vérifié par le guide à chaque session. |
| P02 | MAJEUR | Robustesse | ExtLink lit 1 datagramme/scan (`FB_Sim_Translation_ExtLink.st:188`), passerelle 1 réponse/commande (`udp_m3_fmu_gateway.py:72`) : après une gigue Windows, retard permanent. | Vider la file (N lectures max, garder la dernière trame valide). |
| P03 | MAJEUR | Sécurité test | Bascule ST↔FMU en niveau (`PRG_02:326`, `FB_SimBench:656`) : en marche, saut d'image vers P1 ou position FMU. Contredit « jamais de saut capteurs ». | Bascule sur front, acceptée à l'arrêt uniquement (fréq. 0, frein fermé) ; sinon refus + diag. |
| P04 | MAJEUR | Sécurité test | « Redémarrer à P1 » pendant que le PLC tourne : ExtLink accepte la nouvelle plante après >1 s (`:203`) ⇒ téléportation X→P1. Idem Enable off/on. | ID de session plante dans la réponse (octets 36-38) ; changement ⇒ `LinkInvalid` + Enable 0→1 requis. |
| P05 | MAJEUR | Sécurité / cohérence | `FB_SimBench` fait `RETURN` (`:281`) si `SimulationModeActive=FALSE` ⇒ ExtLink jamais rappelé avec Enable=FALSE : socket ouvert, `SimM3LinkReady` figé (TRUE possible simulation coupée, `PRG_02:408`). | Appeler `ExtLink(Enable:=FALSE)` en §1 ou forcer les 4 GVL à FALSE. |
| P06 | MAJEUR | Robustesse | FIONBIO non vérifié (`:145`) ; échec ⇒ `RecvFrom` bloquant ⇒ gel MainTask/watchdog. | `LastResult` ≠ OK ⇒ fermer le socket, rester non prêt. |
| P07 | MAJEUR | Robustesse / ergonomie | `Start_T409_FmuGateway.ps1:63-64` : `[OK]` après `Sleep 5` fixe, sans vérifier port lié ni « FMU M3 prete ». | Readiness réelle (port + ligne lue, timeout 30 s), sinon `[ECHEC] cause`. |
| P08 | MAJEUR | Sécurité processus | « port + nom de script, quel que soit le dossier » est plus faible que le garde actuel (chemin exact + exe, `:29-46`) ; `app.py` est générique. | Argument marqueur `--twinbench-id <guid>` + fichier PID + port. |
| P09 | MAJEUR | Fidélité | Temps plante = trames × 10 ms (`engine.py:11`) ; temporisations PLC en temps réel. Juste si MainTask = 10 ms (`AF-02:517`) sans perte. | Mesurer et afficher la dérive temps plante / temps réel. |
| P10 | MAJEUR | Test | Bandeau « PLC RELIÉ » = vue passerelle : vert possible alors que le PLC rejette les réponses. | Le PLC renvoie `RxCount`/`LinkReady` dans les octets libres 15..31 de la commande ; le bandeau les affiche. |
| P11 | MAJEUR | Cohérence doc/code | ExtLink dans `CODE/` mais absent d'AF-13. | Fiche « POC » minimale maintenant, complète après validation. |
| P12 | MAJEUR | Ergonomie | Parcours arrêté à `LinkReady` ; manquent front OFF→ON (`PRG_02:86`), `SimChainOk:=FALSE` à la ré-entrée (`:115`), mode, joystick simulé. | Voir §4. |
| P13 | MAJEUR (hyp.) | Robustesse | `SysSockCreateUdp(29061, 29062, …)` : si le 1er paramètre est le port lié, collision avec la passerelle sur 29061. | Vérifier `Get-NetUDPEndpoint -LocalPort 29061,29062` sous Control Win. |
| P14 | MINEUR | Fidélité | Status word sur 1 octet (`m3_binary_protocol.py:36`, `ExtLink:208`) : bits 8-15 perdus. | Schéma 2 du protocole. |
| P15 | MINEUR | Cohérence | Seuil « périmé » 0,25 s (`plc_readonly_adapter.py:37`) vs 1 s ailleurs. | Un seul seuil documenté. |
| P16 | MINEUR | Test | Override `SimM3SensorsWord` écrasé en mode externe (`FB_SimBench:617` puis `:656`). | Documenter + diag « override inopérant ». |
| P17 | MINEUR | Maintenance | §3.7 oublie `check_twinbench_m3_poc_results.py` ; `app.py`, `test_readonly_backend.py` référencent `90_PROTOTYPES`. | Compléter la liste. |
| P18 | MINEUR (hyp.) | Robustesse | Venv unique : OMSimulator pip doit correspondre à `omc` ; Python 3.14 : roues PySide6/OMSimulator à vérifier. | Diagnostic de versions dans État. |
| P19 | MINEUR (hyp.) | Robustesse | `resultFile .mat` continu, dossiers `Runtime_<pid>` jamais nettoyés (`engine.py:79-91`). | Désactiver la sortie résultat ou signaler la taille. |
| P20 | MINEUR | Maintenance | Dossiers vides `PlcLogic/`, `visu/`, `_cnc/` dans `controlwin_runner/` : runtime lancé avec le dépôt comme dossier de travail (**hyp.**). | Dossier de travail hors dépôt. |
| P21 | MINEUR | Ergonomie | Menus/README en anglais. | Tout en français. |

## 3. Sécurité machine

| Risque | Mesure | Vérification |
|---|---|---|
| Esclaves réels pilotés par Control Win (P01) | Masters désactivés dans `Device_CtrlWinSim` | PC câblé, Login ⇒ aucun bus OP |
| Download vers le mauvais automate | Application de simulation renommée (ex. `App_SIM_CtrlWin`) ; comm settings Control Win en localhost | Essai croisé Login dans les deux sens ⇒ refus |
| Divergence des deux Applications | Constante d'empreinte du bundle générée par `generate_codesys_bundle.py`, lue en ligne dans les deux | Empreintes identiques avant recette |
| Confusion réel / simulé | Vue « SANS PLC — joystick écran » vs « PILOTÉE PAR PLC » | Capture dans le guide |
| Perte de liaison | Gel fidèle (sans trame, la plante ne pas) ; restent P02/P05/P06 | EL-03/04/05 |
| État initial P1 | Image initiale 00011 = mot initial FMU (`initialPosition_M`) à prouver | EL-07 |
| Processus tués à tort | P08 | LN-06 |
| Licence Control Win démo ~2 h (**hyp.**) | Affichage dans État | CW-03 |

## 4. Ergonomie — parcours jusqu'à « le chariot bouge »
Proposition complétée ≈ **16 actions dont 4 à deviner**. Cible **6 actions** : `TwinBench.cmd` → 1 (démarre aussi le service Control Win, sans download) ; CODESYS Login → Run ; watch list livrée `TB_M3_START` → Ctrl+F7 ; le lanceur attend la 1re trame PLC et affiche `[OK] PLC relié` ou `[ATTENTE] … → action`. État = en-tête live, OMEdit en sous-menu Outils, « Arrêter la simulation PC (CODESYS non touché) », messages `[ECHEC] cause → action chiffrée`.

## 5. Recette (O = automatisable, P = partiel, N = manuel)
LN-01..07, GW-01..03, EL-01..09, BS-01..02, CW-01..04, E2E-01 — repris intégralement dans le contrat `TASK_CONTRACT_T415-G_TWINBENCH_V2.yaml`.

## 6. Oublis
Plan de retour arrière (garder `controlwin_runner` jusqu'à E2E-01 vert) · critères d'acceptation / contrat · licence et version Control Win · dossier de travail hors dépôt · persistants séparés Control Win / CPU · protocole M3B1 schéma 2 · signalement du gel sur incohérence dans la vue.

## 7. Questions à l'utilisateur
1. Le PC de simulation peut-il être câblé au réseau EtherCAT/CAN machine ? (oui/non)
2. Bascule ST↔Modelica autorisée seulement à l'arrêt, sur front ? (OK/non)
3. Passer M3B1 en schéma 2 (écho PLC + ID session plante) ? (oui/non)
4. Control Win sous licence ou démo 2 h ? (licence/démo)
5. Garder `controlwin_runner` jusqu'à E2E-01 vert ? (oui/non)
