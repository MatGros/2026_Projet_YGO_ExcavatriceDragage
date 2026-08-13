# 🧪 FICHE MÉMO — Essais simulation et diagnostic des modules DI

> 🎯 **But :** aide-mémoire général pour vérifier la chaîne d'acquisition des 22 entrées TOR,
> la simulation, le diagnostic des modules DI et la réaction de sécurité des mouvements.
> 📅 2026-08-04 · Version v1.0
> 🔗 Code concerné : `PRG_02_Acquisition`, `PRG_04_Treuils_Benne`, `PRG_05_Translation`,
> `PRG_07_Supervision`
> 📖 Référence : `DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.2.md` §3bis

---

## ⚠️ Règles avant tout essai

- Essai **machine arrêtée**, zone dégagée, arrêt d'urgence accessible et personnel autorisé.
- Aucun essai de défaut réel, débranchement ou forçage matériel sans procédure de consignation.
- Cette fiche est un mémo de vérification ; elle ne remplace ni l'analyse de risques, ni la
  procédure de mise en service, ni la validation de la chaîne d'arrêt d'urgence.
- Un défaut de diagnostic ne doit **jamais** être masqué par un bypass pour obtenir un mouvement.
- Après un défaut : corriger la cause, acquitter par un **nouvel appui/front Reset**, puis vérifier
  l'autorisation. Il ne doit pas y avoir de redémarrage automatique.
- L'homme-mort, l'arrêt d'urgence et la chaîne de puissance restent prioritaires, y compris en
  simulation.

---

## 1. 🧭 Ce qui est testé

Les 22 TOR sont regroupées par carte matérielle :

| Module | Nombre de TOR | Signaux généraux concernés | Diagnostic IHM |
|---|---:|---|---|
| `Local_Digital_IO` | 8 | contacteurs, thermiques, câble tendu, Kobold, position haute | `Network.InputModules.LocalDigitalIoOk` |
| `VH_0800END` | 7 | freins, thermique freins, phases, contacteur puissance, chaîne AU | `Network.InputModules.Vh0800EndOk` |
| `VH_0808ETP` | 7 | positions M3, thermique hydraulique, disponibilité crible | `Network.InputModules.Vh0808EtpOk` |

**Important :** le diagnostic est au niveau **module**, pas au niveau de chaque canal. On vérifie
les trois états de carte et l'agrégat `Network.InputModules.Fault`; on ne conclut pas qu'un canal
individuel est bon uniquement parce que son bit change.

---

## 2. ✅ État initial à relever

| Point | Valeur / observation |
|---|---|
| Date, version logiciel, opérateur | ______________________________ |
| Banc ou machine réelle | Valeur relevée : __________________ |
| Machine à l'arrêt / zone sûre | Valeur relevée : __________________ (**STOP si zone non sûre**) |
| `SimulationModeActive` | Valeur relevée : __________________ |
| `SimWinchActive` | Valeur relevée : __________________ |
| `SimTranslationActive` | Valeur relevée : __________________ |
| `SimOperatorActive` | Valeur relevée : __________________ |
| `SimMachineActive` | Valeur relevée : __________________ |
| Mode avant essai | Valeur relevée : __________________ |
| `Network.InputModules.LocalDigitalIoOk` | Valeur relevée : __________________ |
| `Network.InputModules.Vh0800EndOk` | Valeur relevée : __________________ |
| `Network.InputModules.Vh0808EtpOk` | Valeur relevée : __________________ |
| `Network.InputModules.Fault` | Valeur relevée : __________________ |
| Défauts déjà présents | ______________________________ |

### Verdict de départ

Reporter le statut dans la colonne suivante : `OK` / `NOK` / `À CONFIRMER`.

| Vérification | Statut et observation |
|---|---|
| Les trois cartes sont opérationnelles et `Fault = FALSE` | ______________________________ |
| Une carte est indisponible : le mouvement reste interdit ou s'arrête | ______________________________ |
| État compris et cause connue | ______________________________ |

⚠️ État incompris : **arrêt de l'essai**, ne pas bypasser, demander analyse.

> ℹ️ Sur un PC ou un banc où les modules CODESYS ne sont pas présents, il est possible que
> `GetDeviceState()` indique une carte non opérationnelle. Dans ce cas, c'est un résultat à
> consigner : les mouvements doivent rester sécurisés. Ce n'est pas une raison pour forcer
> `InputModuleFault` à FALSE.

---

## 3. 🖥️ Mise en route de la simulation

Procéder progressivement, un domaine à la fois :

1. Machine arrêtée : mettre `SimulationModeActive := TRUE`.
2. Vérifier qu'aucun mouvement ne démarre spontanément.
3. Activer d'abord **un seul** domaine : `SimWinchActive`, `SimTranslationActive`,
   `SimOperatorActive` ou `SimMachineActive`.
4. Observer `HwReal`, `HwSim` et `HwIn` si disponibles dans la vue CODESYS.
5. Vérifier que les valeurs utilisées par le programme correspondent au domaine choisi.
6. Ajouter les autres domaines un par un et relever toute évolution inattendue.
7. Ne pas mélanger réel et simulation sur un même domaine sans décision explicite et traçée.

### À chaque activation de domaine, attendre

Reporter `OK`, `NOK` ou `À CONFIRMER` dans le tableau :

| Vérification | Statut et observation |
|---|---|
| Aucun mouvement intempestif | ______________________________ |
| Les commandes simulées apparaissent seulement après l'action demandée | ______________________________ |
| Les entrées simulées ont la polarité attendue | ______________________________ |
| Les diagnostics bus/module restent compréhensibles | ______________________________ |
| Un défaut conserve la priorité sur une demande de mouvement | ______________________________ |

---

## 4. 🎚️ Modes à utiliser pendant les essais

| Mode | Usage dans cette fiche | Attendu général |
|---|---|---|
| `DISABLE` | État initial, défaut ou doute | Aucun mouvement autorisé ; les défauts restent visibles |
| `MAINT_N1` | Essais manuels généraux treuil/translation | Commande maintenue, homme-mort requis, pas de redémarrage seul |
| `MAINT_N2` | Essais de maintenance ciblés / sélection M1 ou M2 / fonctions autorisées | Seulement les fonctions explicitement permises ; aucune autorisation implicite |
| `SEMI_AUTO` | Essai final, uniquement après état sain | Refusé si défaut module, codeur, sécurité ou incohérence active |

Pour chaque changement de mode, reporter `OK`, `NOK` ou `À CONFIRMER` :

| Vérification | Statut et observation |
|---|---|
| Le mode affiché suit la demande réelle | ______________________________ |
| Une transition vers un mode plus permissif est refusée si un défaut persiste | ______________________________ |
| Le retour vers `DISABLE` arrête/interdit le mouvement | ______________________________ |
| Le retour d'un défaut à l'état sain ne redémarre pas le mouvement sans nouvelle commande | ______________________________ |

---

## 5. 🪝 Essais fonctionnels généraux — treuils M1/M2

En simulation, domaine `SimWinchActive := TRUE`, mode conseillé `MAINT_N1`.

| # | Action | Entrées / conditions à simuler | Réaction attendue |
|---:|---|---|---|
| 1 | Demander une montée avec homme-mort | Joystick ou commande simulée active | Mouvement uniquement avec autorisations valides |
| 2 | Demander une descente | Direction opposée, homme-mort maintenu | Mouvement dans le bon sens, sans inversion parasite |
| 3 | Relâcher l'homme-mort | Bouton opérateur à FALSE | Arrêt contrôlé, freinage ; aucun redémarrage seul |
| 4 | Faire varier les retours contacteurs/freins/thermiques simulés | Un signal à la fois | L'état vu par `HwIn` suit la simulation et la réaction reste cohérente |
| 5 | Atteindre / simuler la position haute | Capteur haut actif | Mouvement interdit dans le sens dangereux ; diagnostic lisible |
| 6 | Introduire un défaut de carte DI | Carte `Local_Digital_IO` ou `VH_0800END` non opérationnelle | `InputModules.Fault = TRUE`, `SafeStop` M1 **et** M2, pas de reprise automatique |

---

## 6. ↔️ Essais fonctionnels généraux — translation M3

En simulation, domaine `SimTranslationActive := TRUE`, mode conseillé `MAINT_N1`.

| # | Action | Entrées / conditions à simuler | Réaction attendue |
|---:|---|---|---|
| 1 | Demander une cible de translation | P1, P2, PV, Trémie ou Maintenance selon autorisation | Trajet vers la cible, arrêt à la position attendue |
| 2 | Vérifier le ralentissement | Passage dans la zone de pré-ralentissement | Vitesse réduite avant l'arrêt, sans à-coup anormal |
| 3 | Simuler une position incohérente | Combinaison de capteurs invalide | Défaut, arrêt sécurisé, aucune poursuite du mouvement |
| 4 | Introduire un défaut de carte DI | Carte `VH_0808ETP` ou `VH_0800END` non opérationnelle | `InputModules.Fault = TRUE`, `SafeStop` M3, pas de reprise automatique |
| 5 | Relâcher la commande / repasser `DISABLE` | Commande absente ou mode désactivé | Arrêt et inhibition ; une nouvelle action est requise après acquittement |

> ⚠️ Vérifier spécialement que `SafeStop` M3 produit bien la rampe rapide attendue et non une
> coupure brutale non prévue. Ce point est un changement de comportement à qualifier sur banc.

---

## 7. 🩺 Essai diagnostic des modules DI

### 7.1 État sain

1. Démarrer avec les trois modules opérationnels.
2. Vérifier les trois indicateurs IHM.
3. Vérifier `InputModules.Fault = FALSE`.
4. Faire une commande manuelle autorisée.
5. Vérifier que le mouvement est possible uniquement si toutes les autres sécurités sont saines.

**Résultat :** `OK` / `NOK` / `À CONFIRMER` — observation : ______________________________

### 7.2 Défaut d'un module

Pour chaque module, si le banc permet une simulation sûre de son indisponibilité :

1. Noter l'état sain initial.
2. Provoquer **un seul** défaut de module, selon la procédure autorisée.
3. Vérifier l'indicateur correspondant et `InputModules.Fault`.
4. Vérifier l'arrêt ou l'interdiction du procédé concerné.
5. Retirer la cause du défaut.
6. Vérifier que la machine **ne redémarre pas automatiquement**.
7. Produire un front `Reset` conscient, puis vérifier que l'autorisation revient seulement si toutes
   les conditions sont saines.

| Module testé | Indicateur passe en défaut | Agrégat Fault | Procédé arrêté/interdit | Pas de redémarrage auto | Reset requis |
|---|---|---|---|---|---|
| `Local_Digital_IO` | ____ | ____ | M1 ____ / M2 ____ | ____ | ____ |
| `VH_0800END` | ____ | ____ | M1 ____ / M2 ____ / M3 ____ | ____ | ____ |
| `VH_0808ETP` | ____ | ____ | M3 ____ | ____ | ____ |

Reporter `OK`, `NOK`, `N/A` ou `À CONFIRMER` dans chaque case.

**Observation / résultat inattendu :** _________________________________________________

### 7.3 Vérification de non-confusion canal/module

| Vérification | Statut et observation |
|---|---|
| Un changement d'un bit TOR ne change pas à lui seul l'état de santé de la carte | ______________________________ |
| Un défaut de carte est visible comme défaut global de module, pas comme « canal précis garanti » | ______________________________ |
| Aucun affichage ne prétend identifier une voie individuelle si le matériel ne la diagnostique pas | ______________________________ |

---

## 8. 🧨 Test arrêt d'urgence et chaîne de puissance

À réaliser selon la procédure de sécurité autorisée, jamais par simple forçage logiciel si un essai
physique est requis :

1. Machine immobile, mode `MAINT_N1` ou `DISABLE` selon procédure.
2. Vérifier la chaîne AU fermée et l'état de puissance nominal.
3. Actionner l'arrêt d'urgence / ouvrir la chaîne selon le protocole autorisé.
4. Vérifier la coupure de la puissance et l'arrêt des mouvements.
5. Vérifier qu'un Reset seul ne réarme pas une cause encore présente.
6. Réarmer physiquement, puis effectuer le Reset demandé et vérifier l'absence de redémarrage seul.

**Attendu absolu :** l'arrêt d'urgence physique reste indépendant de la simulation et prioritaire sur
les commandes, les modes et les diagnostics applicatifs.

---

## 9. 🔚 Fin d'essai et retour machine réelle

1. Arrêter toutes les commandes et repasser en `DISABLE`.
2. Désactiver les domaines simulés **un par un**.
3. Mettre `SimulationModeActive := FALSE`.
4. Vérifier les états `HwReal`/`HwIn` et les trois états de module.
5. Vérifier les bypass IHM : aucun bypass non voulu ne doit rester actif.
6. Vérifier `InputModules.Fault` et `Modes.State.AnyFaultActive`.
7. Ne réaliser un mouvement réel qu'après validation de l'état initial et de la zone.

### Critères de clôture

Reporter `OK`, `NOK` ou `À CONFIRMER` :

| Critère | Statut et observation |
|---|---|
| Simulation désactivée | ______________________________ |
| Aucun bypass non prévu | ______________________________ |
| Trois modules DI dans l'état attendu | ______________________________ |
| Aucun défaut non expliqué | ______________________________ |
| Aucun mouvement automatique au changement de mode, au Reset ou au retour réel | ______________________________ |
| Résultats consignés et anomalies transmises | ______________________________ |

---

## 📝 Compte-rendu rapide

| Élément | Note |
|---|---|
| Essai / scénario | ______________________________ |
| Mode utilisé | ______________________________ |
| Domaine simulé | ______________________________ |
| Entrée ou défaut injecté | ______________________________ |
| Réaction observée | ______________________________ |
| Réaction attendue respectée | `OK` / `NOK` / `À CONFIRMER` |
| Anomalie / capture / trace | ______________________________ |
| Décision : poursuivre / corriger / arrêter | ______________________________ |
| Signature opérateur / automaticien | ______________________________ |
