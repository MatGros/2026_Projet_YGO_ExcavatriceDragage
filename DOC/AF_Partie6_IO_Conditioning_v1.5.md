# 📋 Analyse Fonctionnelle — Partie 6 : Conditionnement Entrées/Sorties (v1.5)

> 📌 **v1.5 (2026-07-07)** — REX terrain (voir Partie 9) : l'exemple d'instance §5 citait encore
> `M1ContactorFeedbackFwd` (retour individuel par sens) — ce signal est **supprimé côté câblage
> réel** pour les treuils M1/M2, remplacé par un retour unique par treuil `M1/M2FwdRevSpeedFeedbackOff`.
> Exemple mis à jour en conséquence. Détail complet : `DOC/AF_Partie9_Fonction_Winch_v1.5.md`.
>
> 📌 **v1.4** — Correctif documentaire (voir Partie 13) : l'extrait `instEmergencyStopOk` (§ci-dessous)
> référençait encore `GVL_DEBUG.DBG_EmergencyStopOkBypass_TEST` (supprimé) — remplacé par
> `GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EmergencyStopChain_IsReal`. Aucun
> autre changement vs v1.3.
>
> 📌 **v1.3 (2026-07-04)** — Alignement sur le modèle « Programmes ST Autonomes »
> ([Partie2 v2.8](AF_Partie2_Architecture_Programme_v2.8.md)) : `GVL_IN`/`GVL_OUT` et les FB
> composites `FB_InputsMachine`/`FB_OutputsMachine` **ont disparu**, remplacés par deux
> `PROGRAM` numérotés — `PRG_0_Inputs` (position 0, `VAR_OUTPUT`) et `PRG_10_Outputs`
> (position 10, `VAR_INPUT`). Le principe de brique (`FB_Input`/`FB_Output`) et leur
> comportement interne **ne changent pas** — seul le conteneur qui les instancie change de
> forme : **instances nommées individuellement** (`instEmergencyStopOk`, `instM1RelayFwd`…),
> **pas de tableau** `ARRAY[1..n] OF FB_Input` comme envisagé en v1.0/v1.1 (les tableaux restent
> une option valable pour un futur lot à plus grand nombre de voies, mais ce n'est pas ce qui a
> été implémenté). Voir §5 réécrit.
>
> **v1.2** — Renommage terminologique (Translation→Chariot dans les exemples, préfixe I/O
> physique M3 inchangé). Historique GVL_IN/GVL_OUT/FB_InputsMachine/FB_OutputsMachine
> (2026-07-03 et antérieur) **périmé** — voir Archives.
>
> 🔗 Dépend de : [Partie 2 v2.8](AF_Partie2_Architecture_Programme_v2.8.md) (architecture), Partie 3 v1.3 (contrat FB, §1bis interface réduite).

---

## 🎯 0. But

Faciliter l'implémentation des E/S, **surtout à la mise en service**, quand il faut
**inverser** une logique (NO/NC), **filtrer** un rebond, vérifier un **retour d'état**, etc.

L'idée : des briques **réutilisables** (`FB_Input`/`FB_Output`, dossier `_COMMON`),
instanciées individuellement dans `PRG_0_Inputs`/`PRG_10_Outputs`, qui centralisent le
traitement bas niveau et remontent un **diagnostic**.

> 🧭 **Interface réduite** (Partie 3 v1.3 §1bis) : ces briques n'ont **pas** l'interface standard
> complète (`Enable`/`StartStop`/`Mode`/`State`/`StateAtError`) — elles ont **leurs propres types
> de données**, dédiés à leur rôle de conditionnement bas niveau.

---

## 📥 1. `FB_Input` — Entrée TOR conditionnée

### Interface (implémentée, `CODE/_COMMON/FB_Input.st`)
```codesys
FUNCTION_BLOCK PUBLIC FB_Input
VAR_INPUT
    InputRaw    : BOOL;         (* Signal brut carte d'entrée *)
    InvertLogic : BOOL;         (* TRUE = NC (logique inversée) *)
    FilterTime  : TIME;         (* Tempo anti-rebond (filtrage) *)
    ChannelOk   : BOOL := TRUE; (* Diag voie/carte OK — TRUE par défaut si pas de diag dispo *)
END_VAR
VAR_OUTPUT
    State   : BOOL;     (* Signal conditionné, prêt à l'emploi *)
    Error   : BOOL;     (* Voie en défaut (ChannelOk faux) *)
    ErrorId : WORD;     (* bit0 : voie/carte HS *)
END_VAR
```

### Comportement
```
1. value := InputRaw XOR InvertLogic        (* inversion NO/NC *)
2. filtrage anti-rebond sur FilterTime → State
3. si ChannelOk = FALSE → Error, ErrorId.0, State forcé état sûr
```

> 🔒 **Polarité** : un signal de sécurité (`EmergencyStopOk`, mou de câble, rotation de phase…)
> est câblé fail-safe — `TRUE`=OK, `FALSE`=défaut. Détail complet + bugs réels rencontrés :
> `DOC/NAMING_CONVENTION.md` §"Polarité des booléens I/O".

---

## 📤 2. `FB_Output` — Sortie relais + feedback

### Interface (implémentée, `CODE/_COMMON/FB_Output.st`)
```codesys
FUNCTION_BLOCK PUBLIC FB_Output
VAR_INPUT
    Command         : BOOL;            (* Ordre logique, déjà résolu/rampé par le FB métier appelant *)
    InvertLogic     : BOOL;            (* TRUE = NC *)
    FeedbackRaw     : BOOL;            (* Retour d'état actionneur (optionnel) *)
    UseFeedback     : BOOL;            (* Activer le contrôle de rétroaction *)
    Blink1Hz        : BOOL;            (* Option : clignotement 1 Hz *)
    FeedbackTimeout : TIME := T#500ms; (* Délai max cohérence cmd/retour *)
    ChannelOk       : BOOL := TRUE;    (* Diag voie/carte sortie OK *)
END_VAR
VAR_OUTPUT
    State     : BOOL;    (* Vers la carte de sortie *)
    FeedbackOk    : BOOL;    (* Retour cohérent avec la commande *)
    Error         : BOOL;
    ErrorId       : WORD;    (* bit0: feedback incohérent ; bit1: voie/carte HS *)
END_VAR
```

> 🧭 Ce FB est un **relais de commande bas niveau** : il transmet fidèlement `Command`
> (après inversion/blink) et **ne décide pas** d'un arrêt de mouvement. La logique de rampe
> (`StartStop`/`SafeStop`) est résolue **en amont**, dans `FB_Winch`/`FB_Chariot`
> (`PRG_6_WinchControl`/`PRG_7_ChariotControl`), qui pilote `Command` déjà « rampé ».

> 🧷 **Constat d'implémentation** : les instances actuelles de `FB_Winch`/`FB_Chariot` gèrent
> **elles-mêmes** la double vérification commande/retour contacteur (`ST_ContactorCheck`,
> `TonFwdFeedback`/`TonRevFeedback` en interne) — `FB_Output.UseFeedback` n'est **pas activé**
> dans `PRG_10_Outputs` à ce jour (appels `instX(Command := ...)` sans `FeedbackRaw`/
> `UseFeedback`). Les deux mécanismes de double vérification **coexistent sans conflit**
> (celui de `FB_Winch`/`FB_Chariot` fait foi pour la sécurité), mais `FB_Output` reste pour
> l'instant un simple conditionneur NO/NC dans ce projet — pas encore le point unique de
> contrôle de feedback envisagé en v1.0/v1.1.

---

## 🗂️ 3. Déclaration — instances individuelles (pas de tableau, constat d'implémentation)

Contrairement à la déclaration en tableau envisagée en v1.0/v1.1 (`ARRAY[1..16] OF FB_Input`),
`PRG_0_Inputs`/`PRG_10_Outputs` déclarent **une instance nommée par signal** :

```codesys
// PRG_0_Inputs (extrait réel)
VAR
    instEmergencyStopOk    : FB_Input;
    instSlackCableSwitch   : FB_Input;
    instTopPositionSensor  : FB_Input;
    instM1FwdRevSpeedFeedbackOff : FB_Input;    (* 🔧 v1.5 — remplace instM1ContactorFwd/Rev *)
    (* ... une instance par signal ... *)
END_VAR

instEmergencyStopOk(InputRaw := EmergencyStopOk_DI OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.EmergencyStopChain_IsReal), FilterTime := T#20MS);
EmergencyStopOk := instEmergencyStopOk.State;
```

```codesys
// PRG_10_Outputs (extrait réel)
VAR
    instM1RelayFwd : FB_Output;
    (* ... une instance par signal ... *)
END_VAR

instM1RelayFwd(Command := M1RelayFwd);
M1_RelayFwd_DQ := instM1RelayFwd.State;
```

> ✅ Avantage conservé malgré l'absence de tableau : chaque signal reste **nommé
> explicitement** (lisible en vue instance CODESYS), paramètres de filtrage/inversion
> **par signal**. ⚠️ Contrepartie : pas de boucle `FOR`, chaque nouveau signal = une nouvelle
> ligne de déclaration + une ligne d'appel (pas de gain de compacité pour un grand nombre de
> voies homogènes — à reconsidérer en tableau si le nombre de voies croît significativement).

---

## 🩺 4. Diagnostic automate & cartes E/S

Inchangé (v1.2) : `ChannelOk` par voie **non exploité à ce jour** (toutes les instances
observées dans `PRG_0_Inputs`/`PRG_10_Outputs` utilisent la valeur par défaut `TRUE`) — pas de
diagnostic carte/voie remonté pour l'instant. Mapping précis **à définir** à la configuration
matérielle si ce besoin se confirme.

---

## 🧭 5. Place dans l'architecture (réécrit v1.3)

```
MainTask (10 ms) — liste d'appel séquentielle, voir Partie2 v2.8 §3
 0. PRG_0_Inputs           → instX(InputRaw := ..., FilterTime := ...) pour chaque signal,
                              expose en VAR_OUTPUT (EmergencyStopOk, M1FwdRevSpeedFeedbackOff, ...)
 1..9. (diag, codeurs, safety, modes, cycle, winch/chariot/aux control, supervision)
       → consomment PRG_0_Inputs.<Signal> directement (lecture, même cycle)
       → chaque FB de mouvement (FB_Winch/FB_Chariot) résout SON StartStop/SafeStop en interne
10. PRG_10_Outputs        → reçoit les commandes déjà rampées en VAR_INPUT (M1RelayFwd, ...),
                              instX(Command := ...) pour chaque signal, écrit les canaux Q réels
                              + PowerCutOff_A_RQ/PowerCutOff_B_RQ (redondance, Partie2 §5)
```

🧷 Il n'y a **pas** de coupure globale des sorties relais sur `SafeStop` : c'est le FB de
mouvement qui, en interne, applique sa rampe et produit progressivement les commandes
correctes. Le seul cas de coupure **immédiate** est la **neutralisation** (`Enable=FALSE`) ou
l'**AU physique**.

---

## 📚 Documents liés
- **Partie 2 v2.8** — Architecture (modèle « Programmes ST Autonomes », `PRG_0_Inputs`/`PRG_10_Outputs`).
- **Partie 3 v1.3** — Contrat FB (interface, §1bis interface réduite briques E/S).
- **Partie 4 / 5** — Cycle, modes & défauts.
