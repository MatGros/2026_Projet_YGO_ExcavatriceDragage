# 🗂️ Registre d’actions — Translation M3 (v1.0)

> **Rôle** : sas local entre les audits Translation M3 et `DOC/PLAN_TASK_v1.0.md`.
> **Ce document n’est pas une spec ni une autorisation de modifier `CODE/`.**
>
> Cycle : `Audit → Registre local → décision + impact verrouillés → PLAN_TASK global → codesys-change`.

---

## 🚦 Règles de pilotage

- 🟡 Toute ligne commence **à analyser** : une recommandation d’audit n’est pas une exigence validée.
- ✅ Promotion vers `PLAN_TASK` uniquement si : décision explicite, impact connu, périmètre borné, préconditions disponibles, tests définis.
- 🛑 Si une donnée métier/chantier/constructeur manque : rester en **attente externe** ; aucun code approximatif.
- 🧩 1 changement cohérent = 1 tâche. Si transversal, découper en phases compilables/testables.
- 📌 `PLAN_TASK` ne reçoit que les tâches validées ; l’historique des hypothèses reste ici.

---

## A. 🟡 Actions à analyser

| ID local | Sujet / origine audit | Décision attendue | Impact initial à confirmer | Stratégie pressentie | Préconditions | Statut |
|---|---|---|---|---|---|---|
| M3-A01 | Pérennité / généralisation éventuelle de `FB_Ramp` | Conserver `FB_Ramp` ; décider seulement si une évolution est nécessaire et alors compatible avec **tous** ses usages | `FB_Joystick` (X/Y), `FB_Winch` (M1/M2), `FB_Translation`, tests et docs liées | Analyse globale avant toute évolution de la brique commune | Inventaire usages + cas signés/non signés + tests de non-régression | 🟡 À analyser |
| M3-A02 | Vestiges du mode relais dans `GVL_Translation_M3_Stub` | Vérifier le constat audit ; l’export lu ne contient déjà que `PosPV_DI` et `StubTranslationPositionSelect_IHM` | GVL Stub, PRG_07, simulation, mapping | Aucune modification si la recherche confirme l’absence des anciennes variables | Recherche d’usages + nouvel export CODESYS si besoin | ✅ Déjà couvert à confirmer export |
| M3-A03 | Paramètres Translation IHM + bornage | Paramètres utilisés directement, modifiables pendant mouvement ; IHM masque selon utilisateur/mode, PLC mappe et borne | FB Translation, IHM, persistance, Modes, Partie 11, tests | Lot cohérent après politique PLC/IHM et bornes métier | Liste exhaustive, bornes, autorisation PLC MAINT_N2, comportement à chaque changement en mouvement | 🟡 À analyser |
| M3-A04 | Heartbeat bidirectionnel IHM↔PLC machine complète | Perte IHM → `SafeStop`; `PowerCutOff` général seulement si arrêt non confirmé | IHM, supervision, Modes, Safety M1/M2/M3, Cycle, Benne, AU, tests, docs | Phases H0→H3 validées | H1 à préparer ; mapping IHM réel à confirmer | ✅ Prêt à promouvoir |

---

## B. 🏗️ En attente données chantier / constructeur / BE

| ID local | Sujet | Donnée attendue | Fonction potentiellement concernée | Aucun changement avant | Responsable | Statut |
|---|---|---|---|---|---|---|
| M3-E01 | Seuil Méca A : fréquence résiduelle à l’arrêt | Mesure fréquence/vitesse pont réelle après arrêt | `FB_Safety_Translation` | Mesure chantier + critère métier | Mise en service | 🏗️ Attente chantier |
| M3-E02 | Temporisation Méca B : confirmation arrêt frein/variateur | Temps réel commande arrêt → frein collé + retour variateur | `FB_Safety_Translation`, `FB_Brake` | Mesure chantier + critère métier | Mise en service | 🏗️ Attente chantier |
| M3-E03 | STO AC600 non câblé : glissement transitoire | Temps coupure amont → frein collé ; distance/vitesse résiduelle en charge | Architecture électrique/mécanique, Partie 11 | Essai sécurité encadré + validation BE | BE + mise en service | 🏗️ Attente chantier |
| M3-E04 | Protocole/diagnostics/thermique AC600 | Manuel constructeur, PDO réellement mappés, disponibilités défaut/thermique | EtherCAT, `PRG_00_Inputs`, Safety M3, IHM | Validation constructeur + schéma électrique | Constructeur / BE | 🏗️ Attente externe |
| M3-E05 | Conformité machine globale | Analyse risques, PLr, architecture matérielle, calculs MTTFd/DCavg/CCF, validation site | Dossier sécurité machine ; pas le seul code PLC | Dossier BE + essais | BE / client | 🏗️ Attente BE |

---

## 📝 Capture brute — Réponses opérateur (session courante)

> **Source** : utilisateur · **Contexte** : arbitrage initial des ID locaux.  
> **Règle** : capture sans interprétation ; les décisions/critères ne sont pas encore verrouillés.

| ID | Réponse brute synthétisée |
|---|---|
| M3-A01 | Conserver `FB_Ramp`; l’adapter légèrement si nécessaire afin de généraliser la fonction. |
| M3-A02 | Plus aucune commande E/S câblée vers le variateur : les vestiges du mode relais n’ont plus lieu d’être. |
| M3-A03 | La plupart des paramètres doivent être accessibles IHM ; bornages/limites réglables en MAINT_N2 ; gestion utilisateurs portée par IHM ; PLC doit mapper les paramètres. |
| M3-A04 | Heartbeat bidirectionnel IHM↔PLC requis pour toute la machine ; perte IHM au même niveau que perte joystick : arrêts rapides et contrôles safety. |
| M3-E01 | Valeur initiale envisagée pour Méca A : 1 Hz ; paramètre à définir précisément plus tard. |
| M3-E02 | Valeur initiale envisagée Méca B : 3 s. |
| M3-E03 | STO non câblé ; générer un arrêt rapide et envisager l’usage des rampes variateur. |
| M3-E04 | Mapping commande/état considéré déjà fourni ; thermique = entrée TOR issue du disjoncteur ; retour frein = entrée TOR automate. |
| M3-E05 | Mis de côté pour l’instant. |
| M3-R01/R02/R03 | Accord avec les décisions existantes. |
| M3-R04 | Il existe un disjoncteur thermique ; pas de thermique dédié sur le moteur. |
| D1 | Perte heartbeat : `SafeStop` immédiat ; `PowerCutOff` général seulement si un indice confirme un mouvement/arrêt non confirmé. |
| D2 | PLC : accepte les paramètres au minimum sous `MAINT_N2`; IHM gère les droits utilisateur, sans être l’unique protection. |
| D3 | Futur retour disjoncteur thermique M3 : `SafeStop` + `PowerCutOff`. |

### Décisions qualifiées — à intégrer dans les fiches d’impact

| Décision | Formulation verrouillée à ce stade | Reste à définir |
|---|---|---|
| Heartbeat machine | Perte heartbeat → arrêt rapide (`SafeStop`) des domaines concernés. M3 : après délai de confirmation, `PowerCutOff` général si `DriveActualFreqHz` dépasse le seuil Méca A **OU** si `DriveStatusWord.0` est actif **OU** si le frein est déclaré desserré. | Délai d’escalade, équivalents M1/M2, domaines concernés, comportement hors mouvement, test de perte heartbeat. |
| Paramètres MAINT_N2 | Écriture directe possible pendant mouvement ; IHM gère les droits utilisateur ; PLC borne les valeurs et exige au minimum `Mode = MAINT_N2`. | Liste paramètres, bornes métier, signal d’autorisation PLC éventuel au-delà du mode, effet exact de chaque changement en mouvement. |
| Thermique disjoncteur M3 | Futur défaut TOR disjoncteur M3 → `SafeStop` + `PowerCutOff`. | Mapping, adresse, polarité fail-safe, filtrage, cause réelle surveillée, simulation et tests. |

---

## 🔎 Vérifications techniques initiales (read-only)

| Sujet | Fait observé dans l’export actuel | Conséquence |
|---|---|---|
| `FB_Ramp` | Instancié dans `FB_Joystick` (X/Y), `FB_Winch` et `FB_Translation` ; la brique est déjà transverse | Toute évolution impacte la machine, pas M3 seule. |
| GVL Stub M3 | `GVL_Translation_M3_Stub.st` ne contient déjà que `PosPV_DI` et `StubTranslationPositionSelect_IHM` | Le constat « variables relais orphelines » semble historique ; pas de tâche nettoyage sans nouvel export montrant ces variables. |
| Perte joystick M3 actuelle | Dans `FB_Safety_Translation`, toute erreur donne `SafeStop`; le masque `PowerCutOff` actuel ne couvre pas le bit0 joystick | La demande `SafeStop + PowerCutOff` sur perte IHM est une **nouvelle décision safety**, plus forte que le comportement M3 actuel de perte joystick. |
| Thermique M3 actuel | Entrée présente : `BrakeThermalFeedback` commun freins M1/M2/M3 ; aucune entrée disjoncteur/thermique variateur M3 dédiée dans l’export lu | Prévoir l’E/S dédiée reste une exigence à mapper/valider chantier. |
| Commandes AC600 actuelles | Interface documentée/code : commande `0/1/2/7`, fréquence de référence ; aucune commande « rampe rapide variateur » démontrée dans l’export lu | Identifier la fonction exacte dans le manuel AC600 avant de concevoir la stratégie arrêt rapide variateur. |

---

## C. ✅ Prêtes à promouvoir vers `PLAN_TASK`

> Vide tant qu’aucune analyse d’impact n’est explicitement validée.

| ID local | Future TASK | Périmètre verrouillé | Tests / critères | Décision |
|---|---|---|---|---|
| M3-A04 | Heartbeat IHM↔PLC machine complète | Plan corrigé validé, ST préparé localement | Compile/import CODESYS + simulation + revue export requis ; aucune reprise automatique | 🟠 En validation CODESYS |

---

## D. 📦 Rejetées / remplacées / déjà couvertes

| ID local | Sujet | Décision / preuve | Statut |
|---|---|---|---|
| M3-R01 | Restaurer automatiquement le mode après perte `EmergencyStopOk` | Rejeté : `FB_Modes` force `DISABLE` pour empêcher le redémarrage automatique. Toute évolution nécessiterait une exigence normative/métier sourcée. | 📦 Rejeté |
| M3-R02 | Affirmer absence d’arrêt logiciel/IHM | Rejeté : `ST_ModesHMI` expose déjà `CmdEmergencyCutOff`; le mouvement M3 exige `DeadmanArmed`. Besoin d’un heartbeat éventuel reste séparé en M3-A04. | 📦 Rejeté |
| M3-R03 | Déclarer PL-d Cat.3 démontré par le code | Rejeté : preuve impossible par dépôt PLC seul ; traité comme donnée BE externe (M3-E05). | 📦 Rejeté |
| M3-R04 | Classer l’absence thermique moteur M3 comme défaut certain | Requalifié : aucune entrée TOR thermique M3 n’est spécifiée ; clarification constructeur en M3-E04. | 📦 Requalifié |

---

## 🧠 Fiche d’impact à compléter avant promotion

```md
### M3-AXX — <titre>

**Décision validée :**
**But / risque traité :**
**À ne pas faire :**

| Domaine | Impact vérifié |
|---|---|
| FB / PRG propriétaire | |
| Producteurs d’entrées | |
| Consommateurs de sorties | |
| IHM / GVL | |
| EtherCAT / E/S | |
| Cycle / Modes | |
| Simulation / PLC tests | |
| Safety (`Enable`, `SafeStop`, `PowerCutOff`, Reset) | |
| DOC impactée | |

**Stratégie** : lot unique / phases (justification).

**Préconditions :**
**Tests intermédiaires :**
**Critères d’acceptation :**
**Condition de promotion vers `PLAN_TASK` :**
```

---

## 🧠 Fiche d’impact — M3-A04 Heartbeat IHM↔PLC machine

**Décision validée :** heartbeat bidirectionnel IHM↔PLC. Sa perte demande un `SafeStop` immédiat. Le `PowerCutOff` général est une escalade, uniquement si l’arrêt n’est pas confirmé après délai.

**But / risque traité :** perte de communication IHM alors qu’une commande/paramètre peut rester figé ou qu’un opérateur ne peut plus superviser/arrêter la machine via l’IHM.

**À ne pas faire :**
- pas de `SafeStop` global : chaque `FB_Safety_<Metier>` reste propriétaire de sa sortie ;
- pas de `PowerCutOff` immédiat sur la seule perte Ethernet ;
- pas de nouveau bit Winch : le bit0 existant est élargi/documenté « perte communication opérateur » (joystick CAN ou Heartbeat IHM) ;
- pas de confiance sécurité dans le seul masquage IHM ou dans les droits IHM ;
- pas de modification CODE avant protocole, délais et critères d’arrêt confirmés.

| Domaine | Impact vérifié / à traiter |
|---|---|
| Producteur heartbeat | Nouvelle fonction/brique transverse à définir : acquiert le heartbeat IHM et expose un état de communication PLC↔IHM. |
| IHM / GVL | `ST_CommunHMI` est le conteneur adapté pour les données communes. Ajouter échange bidirectionnel : toggle IHM reçu + clignotant/état PLC retourné + diagnostics. |
| Supervision | `PRG_09_Supervision` est le point actuel de mapping `GVL_IHM`; il devra surveiller/propager l’état sans devenir propriétaire des réactions Safety métier. |
| Safety M3 | `FB_Safety_Translation` : nouvelle cause Heartbeat. Perte → `SafeStop`; après délai, `PowerCutOff` si fréquence > seuil Méca A **OU** `DriveStatusWord.0=TRUE` **OU** frein desserré. |
| Safety M1/M2 | `FB_Safety_Winch` : nouvelle cause Heartbeat. Perte → `SafeStop`; après délai, confirmation arrêt basée sur `FwdRevSpeedFeedbackOff AND BrakeFeedback`; non-confirmation → `PowerCutOff` général via OR existant dans `PRG_10_Outputs`. |
| Cycle / Benne | Vérifier le repli explicite du cycle (`ERROR_HOLD`) et l’arrêt des commandes Benne/Kobold lors de la cause Heartbeat. Ne pas le supposer : lecture ciblée `FB_Cycle`/`FB_Bucket` requise au moment du changement. |
| AU / coupure puissance | `PRG_10_Outputs` agrège déjà les `PowerCutOff` M1/M2/M3. Aucun nouveau contacteur ni nouveau chemin de coupure à inventer. |
| Modes | Heartbeat indépendant du mode : la perte d’IHM est surveillée en MANUEL, MAINT_N1, MAINT_N2 et SEMI_AUTO. |
| Paramètres IHM | Écriture possible pendant mouvement en MAINT_N2 : bornage PLC obligatoire et gate minimal `Mode = MAINT_N2`; les droits IHM ne sont pas un contrôle safety PLC. |
| Simulation / tests | Ajouter stimuli perte/reprise heartbeat ; vérifier SafeStop immédiat, absence de coupure immédiate, puis escalade si retours arrêt non confirmés. |
| DOC impactée | Parties 2 (architecture/tâches), 3 (contrats safety), 5 (modes), 7 (IHM), 11 (M3), 14 (tests) ; checklist chantier à créer/compléter après décision. |

### Stratégie de livraison proposée

| Phase | Portée | Condition de sortie |
|---|---|---|
| H0 — Spécification | Protocole heartbeat, période, timeout, délai escalade, comportement boot/reconnexion, critères M1/M2/M3 | Décisions métier/safety signées ; aucun code |
| H1 — Échange/diagnostic | GVL/IHM + brique de surveillance + affichage diagnostic, **sans** raccorder aux sorties Safety | Communication et timeout observables en simulation/IHM |
| H2 — Réaction Safety complète | Raccordement simultané Safety M1/M2/M3 + cycle/benne si nécessaire + agrégation `PowerCutOff` existante | Tests simulation de tous les domaines ; aucun domaine oublié |
| H3 — Validation chantier | IHM réelle : perte réseau, repli, confirmation arrêt, escalade ; mesures de temps | Checklist chantier signée |

**H0 validée :**
- toggle IHM : toutes les **500 ms** ;
- perte déclarée après **2 s sans front** ;
- escalade `SafeStop` → `PowerCutOff` après **3 s** si arrêt non confirmé ;
- boot PLC sans IHM : **machine bloquée** ;
- reconnexion IHM : **reset manuel + nouvel ordre obligatoire** ;
- la liaison Ethernet IHM est une surveillance fonctionnelle ; elle ne démontre pas à elle seule un niveau de performance matériel ;
- mapping chantier du futur disjoncteur thermique M3 : sujet M3-E04 indépendant, à confirmer.

**Tests minimum H2 :**
1. Heartbeat perdu pendant mouvement M1/M2/M3 → `SafeStop` dans le délai défini.
2. Heartbeat perdu, tous retours arrêt confirmés → aucun `PowerCutOff`.
3. Heartbeat perdu, un retour M3 actif (fréquence / Operation / frein desserré) après délai → `PowerCutOff` général.
4. Heartbeat perdu, contacteurs/frein M1 ou M2 non confirmés → `PowerCutOff` général.
5. Reconnexion heartbeat → aucun redémarrage automatique ; reset + nouvel ordre restent requis.
6. Boot IHM/PLC et heartbeat absent au démarrage → comportement sûr, sans faux réarmement.

**Condition de promotion vers `PLAN_TASK` :** H0 entièrement renseignée et validée humainement.

**Décision opérateur :** stratégie H0 → H3 validée. H0 est renseignée ; choix actuel : préparer H1 dans ce registre local avant promotion vers `PLAN_TASK`.

### ✅ Plan unique — Lot Heartbeat complet (une seule validation avant ST)

> H1/H2/H3 deviennent des jalons de test internes. Le lot ci-dessous est préparé, généré et testé comme un ensemble cohérent.

| Groupe | Fichiers / objets concernés | Contenu |
|---|---|---|
| 1. Contrat IHM | `ST_CommunHMI`, `GVL_IHM` | Toggle IHM 500 ms, toggle PLC 500 ms, diagnostics `HeartbeatIhmOk`/timeout/temps depuis front. |
| 2. Moniteur Heartbeat | **Nouveau** `FB_IhmHeartbeat` (brique réduite) + appel `PRG_01_Diagnostics` | Détecte boot/perte/reprise IHM ; expose `HeartbeatOk`, timeout, temps depuis front et toggle PLC. Aucun `SafeStop`/`PowerCutOff` global. Appelé avant `PRG_03_Safety`. |
| 3. Repli par métier | `FB_Safety_Winch` M1/M2, `FB_Safety_Translation`, appels `PRG_03_Safety` | Chaque Safety métier consomme `HeartbeatOk=FALSE` comme perte de communication opérateur, via son bit0 déjà réservé. `SafeStop` reste produit par chaque Safety métier. |
| 4. Confirmations arrêt | Méca B existantes de chaque Safety métier | M1/M2 : étendre la condition Méca B à la perte Heartbeat ; `FwdRevSpeedFeedbackOff AND BrakeFeedback` confirme l’arrêt. M3 : armer Méca B aussi sur perte Heartbeat ; fréquence ≤ seuil Méca A **ET** variateur non Operation **ET** frein serré confirment l’arrêt. Échec > 3 s → `PowerCutOff` existant. |
| 5. Cycle / sorties | `FB_Cycle`/`PRG_05_Cycle` à vérifier, `PRG_10_Outputs` | Cycle vers repli sûr/`ERROR_HOLD`. `PRG_10_Outputs` conserve son agrégation `PowerCutOff` existante : aucun nouveau contacteur ni nouvelle source globale. |
| 6. Supervision | `PRG_09_Supervision`, IHM | Mapping diagnostics, alarme timeout, aucune reprise automatique à reconnexion. |
| 7. Simulation / tests | `GVL_PLC_Tests`, suite Safety/Winch/Translation, Partie 14 | Perte/reprise heartbeat, arrêt confirmé, échec confirmations M1/M2/M3, escalade, boot sans IHM. |
| 8. Documentation | Parties 2/3/5/7/11/14, checklist chantier, `VERSION_HISTORY` | Contrat, séquence, mapping, tests et REX. |

**Invariants non négociables :**
- au boot sans IHM : mouvement bloqué ;
- perte IHM : `SafeStop` immédiat par métier ;
- `PowerCutOff` non immédiat : seulement après 3 s d’arrêt non confirmé ;
- reconnexion IHM : jamais de redémarrage automatique ; reset manuel + nouvel ordre ;
- IHM : droits utilisateur ; PLC : gate minimal `Mode = MAINT_N2` + bornage pour paramètres modifiables ;
- aucune sortie calculée (`SafeStop`, `PowerCutOff`) ne sera forcée en test : stimulation capteurs/heartbeat en amont uniquement.

**Gates avant génération ST :** structure validée ; style ST existant contrôlé ; revue safety read-only ; validation utilisateur unique du plan corrigé ci-dessous.

### 🔎 Revue Safety croisée — corrections intégrées

| Constat | Correction de plan |
|---|---|
| Reconnexion Heartbeat risquait de relâcher un `SafeStop` puis de reprendre sur une commande IHM mémorisée | La perte Heartbeat alimente le bit0 latched de chaque Safety métier ; disparition + **Reset front** requis avant disparition du SafeStop. Cycle doit aussi aller en repli sûr. |
| `FB_Safety_Winch.ErrorId` utilise déjà 16 bits | Aucun nouveau bit : bit0 devient « perte communication opérateur » et couvre joystick CAN **ou** Heartbeat IHM ; renommage IHM/doc associé obligatoire. |
| Seuil M3-E01 non étalonné chantier | Valeur initiale 1 Hz à rendre explicite/paramétrable ; validation chantier H3 obligatoire avant figer la valeur de mise en service. |
| Architecture Safety par métier | Le nouveau bloc est seulement un moniteur `FB_IhmHeartbeat`; les Méca B/bit0/PowerCutOff restent dans les Safety métiers existantes. |

---

### H1 — Paquet local de préparation (sans code)

**But H1 :** rendre le lien IHM↔PLC observable et testable, sans encore commander `SafeStop` ou `PowerCutOff`.

| Élément | Contrat H1 proposé |
|---|---|
| Signal IHM → PLC | `HeartbeatIhmToggle : BOOL` dans l’échange commun ; l’IHM inverse sa valeur toutes les 500 ms. |
| Signal PLC → IHM | `HeartbeatPlcToggle : BOOL` ; le PLC inverse sa valeur toutes les 500 ms, indépendamment du signal IHM. |
| Diagnostic PLC → IHM | `HeartbeatIhmOk : BOOL`, `HeartbeatIhmTimeout : BOOL`, temps depuis dernier front IHM. |
| État après boot PLC | `HeartbeatIhmOk := FALSE` tant qu’au moins un **nouveau front** IHM n’a pas été vu après boot. Une valeur `RETAIN` ne vaut jamais preuve de liaison. |
| Perte | Absence de front pendant 2 s → `HeartbeatIhmTimeout := TRUE`; H1 l’affiche seulement. H2 portera la réaction Safety. |
| Reprise | Un nouveau front efface le timeout de diagnostic ; aucun mouvement ni réarmement n’est généré par H1. |
| Clignotant PLC | Le toggle PLC est une information de vie pour l’IHM, pas un signal Safety autonome. |

**Périmètre H1 envisagé :**
- `ST_CommunHMI` / `GVL_IHM` : contrat d’échange commun ;
- `PRG_09_Supervision` : acquisition, surveillance, publication diagnostic ;
- brique dédiée de surveillance à définir, sans `StartStop`/`SafeStop` (profil brique réduite Partie 3 §1bis) ;
- IHM : tâche cyclique 500 ms pour écrire/lire les toggles ;
- simulation/tests : injection arrêt/reprise heartbeat, sans toucher aux sorties Safety.

**Hors périmètre H1 :** `FB_Safety_Winch`, `FB_Safety_Translation`, `PRG_10_Outputs`, `FB_Cycle`, Benne, `PowerCutOff` et comportement machine bloquée. Ils seront traités ensemble en H2.

**Critères d’acceptation H1 :**
1. IHM active : `HeartbeatIhmOk=TRUE` après un front reçu.
2. IHM arrêtée/réseau coupé : timeout visible après 2 s ± 1 cycle MainTask.
3. Reconnexion : retour diagnostic après front, sans reset automatique ni commande mouvement.
4. Boot PLC : aucun état `RETAIN` ne peut rendre `HeartbeatIhmOk=TRUE` sans front post-boot.
5. H1 ne modifie aucune sortie Safety ou puissance.

**Gate H1 avant `codesys-change` :** ✅ confirmé : l’IHM sait exécuter le toggle périodique 500 ms et mapper les quatre champs prévus.

#### 📤 Contrat à transmettre à l’intégrateur IHM

| Variable prévue | Sens | Exigence IHM |
|---|---|---|
| `GVL_IHM.Commun.HeartbeatIhmToggle` | IHM → PLC | Inverser toutes les 500 ms, dès que la communication IHM est réellement opérationnelle. Ne pas écrire une valeur constante. |
| `GVL_IHM.Commun.HeartbeatPlcToggle` | PLC → IHM | Afficher facultativement l’activité PLC ; l’IHM peut diagnostiquer l’absence de changement. |
| `GVL_IHM.Commun.HeartbeatIhmOk` | PLC → IHM | Afficher l’état de liaison fonctionnelle PLC↔IHM. |
| `GVL_IHM.Commun.HeartbeatIhmTimeout` | PLC → IHM | Alarme visible et historisable : aucun front IHM reçu depuis 2 s. |

**Comportements obligatoires côté IHM :**
1. Au démarrage IHM, démarrer le toggle périodique sans attendre une commande PLC.
2. Après reconnexion réseau, reprendre le toggle ; ne jamais écrire de reset machine ni de commande mouvement automatiquement.
3. Afficher `HeartbeatIhmTimeout` comme défaut communication ; aucun bouton IHM ne doit masquer ou acquitter l’état PLC.
4. Les droits utilisateur IHM ne modifient pas le heartbeat : il reste actif pour tous les écrans/modes.

---

## 📚 Sources

- `AUDIT_TranslationM3_Consolidated_v1.0.md`
- `AUDIT_TranslationM3_Final_v2.0.md`
- `DOC/AF_Partie-11_Fonction_Translation_v1.9.md`
- `DOC/PLAN_TASK_v1.0.md`
- `AGENTS.md` / skill `codesys-change`

---

## 📋 Réponse opérateur — À copier-coller

> Pour chaque ID, indiquer : `À instruire` / `En attente` / `Rejeté` / `À reformuler` /
> `Prêt PLAN_TASK`, puis un commentaire court si utile.

```text
M3-A01 :
M3-A02 :
M3-A03 :
M3-A04 :

M3-E01 :
M3-E02 :
M3-E03 :
M3-E04 :
M3-E05 :

M3-R01 :
M3-R02 :
M3-R03 :
M3-R04 :
```

📌 Les `M3-Rxx` sont déjà rejetées/requalifiées : les renseigner seulement en cas de désaccord.
