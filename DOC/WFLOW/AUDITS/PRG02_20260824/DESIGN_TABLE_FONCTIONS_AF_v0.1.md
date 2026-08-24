# 🎯 Design — Table des Fonctions dans les documents AF (traçabilité Fonction → Test)

📅 2026-08-24 · 🧑‍💻 Proposition (pas encore implémentée, pas de code/doc modifié) · 🚫 Aucune
modification appliquée à ce stade — soumis à challenge indépendant avant toute exécution.

## 🎯 Constat (remonté par l'utilisateur)

Les documents `AF_PartieNN` ont une section **« 🧪 Points de validation »** (`TC-Pxx-nnn`) —
c'est une liste de **tests**, pas une liste de **fonctions**. Rien ne dit de façon exhaustive
« voici toutes les fonctions que la machine doit remplir dans ce domaine » avant de vérifier
qu'elles sont testées. Résultat : impossible de répondre vite à *« ai-je bien un test critique
sur CHAQUE fonction identifiée, ou seulement sur celles dont on s'est souvenu ? »*.

C'est un manque classique de traçabilité **Fonction → Exigence → Test** (Requirements
Traceability Matrix), pratique standard en ingénierie sûreté machine (ISO 13849, IEC 61508) et
FAT/SAT industriel — l'AF documente la logique et les contrats FB, mais pas le catalogue des
fonctions en tant que tel.

## 💡 Proposition

### 1. Nouvelle section **« 🎯 Table des fonctions »** dans chaque `AF_PartieNN`, avant
« Points de validation »

Un identifiant par fonction : `F<NN>.<seq>` où `NN` = numéro de la Partie AF (`08` pour
Joystick), `seq` = compteur `01`, `02`, ... **sans catégorisation a priori** (pas de distinction
"principale"/"contrainte" imposée dans l'ID — conforme à la demande explicite : un simple index
plat, la nature de la fonction se lit dans sa description, pas dans un préfixe).

| Colonne | Contenu |
|---|---|
| `ID` | `F08.01`, `F08.02`, ... |
| `Fonction` | Nom court, verbe d'action (« Armer l'homme-mort par maintien ») |
| `Description` | 1-3 phrases — **niveau de détail progressif dans le temps** : au démarrage d'un domaine, texte général ; affiné au fil des lots jusqu'à devenir aussi précis que le contrat FB |
| `Réalisée par` | FB/composant(s) qui l'implémentent (`FB_Joystick`, `FB_AxisScale`) |
| `Criticité` | Échelle **déjà existante** dans `TASKS.yaml` (`C0`-`C4`) — pas de nouvelle échelle à inventer |
| `TC couvrants` | Liste des `TC-Pxx-nnn` qui valident cette fonction (traçabilité inverse) |
| `Statut` | ✅ couverte / ⚠️ partielle / ❌ non couverte (dérivé, pas saisi à la main si outillé — voir §3) |

### 2. Exemple rempli — AF-08 Joystick

| ID | Fonction | Description | Réalisée par | Criticité | TC couvrants | Statut |
|---|---|---|---|---|---|---|
| `F08.01` | Acquérir les axes bruts + bouton | Lit `RawX`/`RawY`/`RawButton` depuis le bus CANopen (ou l'image simulée) | `FB_Joystick` | C2 | — | ❌ |
| `F08.02` | Mettre à l'échelle proportionnellement | Convertit le compte brut ADC en % signé ±100, avec deadband centrée | `FB_AxisScale` | C2 | `TC-P08-007`, `TC-P08-014` | ✅ |
| `F08.03` | Armer l'homme-mort par maintien | Appui continu `DeadmanArmHoldTime` (100ms) requis avant armement | `FB_Joystick` | **C4** (sécurité) | `TC-P08-002` | ✅ |
| `F08.04` | Désarmer sur relâchement prolongé | Neutre > `NeutralHoldTime` désarme, neutre bref conserve l'armement | `FB_Joystick` | **C4** | `TC-P08-004` | ✅ |
| `F08.05` | Désarmer sur perte de permission | `ArmingPermit=FALSE` ⇒ désarmement immédiat, axes à 0 | `FB_Joystick` | **C4** | `TC-P08-001`(partiel) | ⚠️ *(trou identifié séparément — voir `QUESTIONS_OUVERTES_PRG02_v0.1.md` Q1)* |
| `F08.06` | Détecter un défaut capteur hors plage | `RawX`/`RawY` hors plage ⇒ arrêt + `ErrorId` bit1, pas de commande à pleine vitesse | `FB_Joystick` | C3 | `TC-P08-007` | ✅ |
| `F08.07` | Calibrer le neutre capteur | Bouton calibration mémorise le neutre courant, alarme si hors plage | `FB_Joystick` | C2 | `TC-P08-006` | ✅ |

**Ce que révèle déjà l'exemple** : `F08.01` (acquisition brute) n'a **aucun TC dédié** — testée
seulement indirectement à travers `F08.02`. Et `F08.05` (désarmement sur perte permission) a un
TC qui couvre la logique du FB, mais **pas le câblage réel** (`ArmingPermit` figé à `TRUE` en
production, cf. revue PRG_02) — la table rend ce trou **visible structurellement**, ce qu'aucune
liste de TC seule ne permettait de voir avant d'y penser explicitement.

### 3. Outillage — phase 2, pas maintenant

Une fois la convention validée et appliquée à quelques AF pilotes, un script (non existant à ce
jour — nom proposé : `extract_functions_matrix.py`, à créer dans `TOOLS/AGENT_WORKFLOW/scripts/`
si validé) pourrait parcourir tous les `DOC/AF/AF_Partie-NN_*.md`, extraire les tables `🎯 Table
des fonctions` + `🧪 Points de validation`, et produire un YAML/CSV consolidé — pour un audit
rapide sans ouvrir chaque doc. **Non demandé pour ce lot** — noté pour arbitrage ultérieur (cf.
question Q-TF3 ci-dessous).

## ❓ Questions pour arbitrage humain (ne bloque pas le travail — listées, pas posées maintenant)

| # | Question |
|---|---|
| Q-TF1 | Rétrofit : applique-t-on la table à **tous** les AF d'un coup, ou domaine par domaine en commençant par un pilote (Joystick AF-08, déjà en partie designé ci-dessus) ? |
| Q-TF2 | Qui assigne la `Criticité` par fonction — reprise mécanique de la criticité du FB porteur, ou jugement au cas par cas (une fonction non-sécurité peut vivre dans un FB par ailleurs critique) ? |
| Q-TF3 | La moulinette d'extraction (§3) : à openifier maintenant en tâche `TASKS.yaml`, ou différée sans ticket tant que la convention n'est pas stabilisée sur au moins 2-3 AF ? |
| Q-TF4 | Le champ `Statut` (✅/⚠️/❌) : saisi à la main à chaque mise à jour de TC, ou dérivé automatiquement dès que la moulinette existe (risque de dérive si saisie manuelle) ? |

## ❓ Questions complémentaires (ajoutées par le challenge indépendant)

| # | Question |
|---|---|
| Q-TF5 | Comment représenter une fonction portée par un **PRG de collage inter-composants**, pas un FB unique (ex. `TC-P08-008` : le gate `DeadmanArmed` vérifié dans `PRG_04_Treuils_Benne.st`, pas dans `FB_Joystick`) ? Le champ `Réalisée par: FB` ne le permet pas — élargir à `FB/PRG/gate` ? |
| Q-TF6 | Comment la table s'articule avec le pattern **multi-fiches déjà en place** sur AF-09+ (Encoder : 6 sous-fiches, chacune propriétaire unique d'une plage `TC-P09-*`) ? Table au niveau chapeau (perd la granularité par fiche) ou dupliquée par sous-fiche (double maintenance) ? |

## 🕵️ Challenge indépendant — verdict (2026-08-24)

Un sous-agent indépendant a vérifié l'exemple F08.01-F08.07 ligne à ligne contre le code réel
(`FB_Joystick.st`, `PRG_02_Acquisition.st`) et testé mentalement la généralisation à AF-09.

**Verdict : ⚠️ Adopter avec modifications substantielles — ne pas rétrofit tel quel.**

### Ce qui est confirmé bon
- Le principe (traçabilité Fonction→Test) est standard et légitime en sûreté machine.
- F08.05 (désarmement sur perte permission) confirmé exact et vérifié en dur dans le code —
  la table **rend visible structurellement** un vrai trou de sécurité (Q1 de la revue PRG_02).

### Défauts trouvés dans l'exemple (corrections à faire si adopté)
- F08.02/F08.06 : un même TC (`TC-P08-007`) compté sur 2 fonctions sans note — faux sentiment
  de couverture.
- F08.03/F08.04 : descriptions incomplètes (`ArmingPermit`, `DeadmanArmGraceTime` omis).
- F08.07 : `TC-P08-009`/`TC-P08-010` (persistance, accès HMI) omis alors qu'ils relèvent de la
  même fonction.
- **Omission structurelle** : `TC-P08-008` (gate `DeadmanArmed` vérifié dans un PRG, pas un FB)
  n'a **aucune** fonction associée dans l'exemple — révèle une limite réelle du format
  (`Réalisée par: FB` ne couvre pas les fonctions inter-PRG), pas une erreur de saisie.

### Verdict industriel
Pertinent dans l'intention, **prématuré dans l'implémentation proposée** : une table Markdown
saisie à la main, sans outillage de validation livré en même temps, reproduit exactement le type
de dérive documentaire déjà vécu 2 fois sur ce projet (drift `CLAUDE.md`/`AGENTS.md`, bug
`PRG_10_Outputs_LD` — REX 2026-07-29 cité dans `AGENTS.md`). **AF-08 elle-même s'est révélée un
mauvais pilote** : son §3/§4 documente une interface (`Mode`, `BenneBusy`,
`PreserveArmingAfterBucket`) qui n'existe plus dans `FB_Joystick.st` réel (déjà signalé
séparément — `REVUE_PRG02_ACQUISITION_v0.1.md` signalement #1).

### Redondance confirmée
Chevauchement réel avec AF §1 « Rôle et périmètre » — fusionner plutôt qu'ajouter une couche.
`TASKS.yaml.objectifs` est vide sur toutes les tâches actuelles : pas de redondance active
aujourd'hui, mais à clarifier quelle source fait foi.

### 5 conditions avant tout rétrofit (recommandation du challenge)
1. Resynchroniser AF-08 (§3/§4) avec le code réel **avant** de construire la table dessus.
2. Élargir `Réalisée par` à `FB/PRG/gate` (cas `TC-P08-008`).
3. Trancher Q-TF6 (multi-fiches AF-09+) **avant** le pilote, pas après.
4. Livrer l'outillage d'extraction/validation **avec** le lot pilote, pas en phase 2 différée.
5. Fusionner avec §1 plutôt qu'ajouter une couche redondante.

---
*Proposition non appliquée. Clôture de la phase de design/challenge — arbitrage humain requis
sur Q-TF1 à Q-TF6 et les 5 conditions ci-dessus avant toute exécution.*
