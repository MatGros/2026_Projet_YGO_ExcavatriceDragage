# 📋 Analyse Fonctionnelle — Partie 6 : Conditionnement Entrées/Sorties (v1.2)

> 📌 **État d'implémentation (2026-07-03quindecies, AUDIT D63-D65)** : `FB_Input_Digital`/
> `FB_Output_Relay` renommés **`FB_Input`**/**`FB_Output`** (demande utilisateur — pas que des
> relais côté sortie). `FB_Output.OutputCmd` renommé **`State`** (cohérence avec
> `FB_Input.State`). `FB_InputsMachine` n'a plus de `VAR_OUTPUT` : il écrit directement
> **`GVL_IN.Xxx`** (noms courts, sans suffixe). `FB_OutputsMachine` n'a plus ni
> `VAR_INPUT` ni `VAR_OUTPUT` : il lit **`GVL_OUT.Xxx`** (écrit par `PRG_MAIN` par
> simples affectations juste après `FB_Winch`/`FB_Chariot`) et écrit directement les I/O
> réels. Les deux FB composites s'appellent désormais **sans aucun paramètre**
> (`instInputsMachine()`, `instOutputsMachine()`). Écart assumé à Partie2 §0 pour ces 2 GVL —
> choix pragmatique de lisibilité en LD (accès par tag global, pas d'instance à déplier).
> 🔧 **Renommage des GVL** (2026-07-03quindecies) : `GVL_Inputs`→**`GVL_IN`**,
> `GVL_Outputs`→**`GVL_OUT`** (demande utilisateur, noms courts).
>
> **v1.2** — Renommage terminologique (demande utilisateur, 2026-07-02) : Translation→Chariot
> dans les exemples (préfixe I/O physique M3 inchangé).
> 📌 **État d'implémentation (2026-07-03undecies, AUDIT D36/D37/D52/D53)** : `FB_Input.st`/
> `FB_Output.st` **codés et intégrés**, scindés en 2 FB composites **`FB_InputsMachine`**
> (entrées) / **`FB_OutputsMachine`** (sorties) — remplacent l'ancien `FB_IO_Machine` (double
> appel). Chacun **1 seule instance**, appelée **une seule fois** dans `PRG_MAIN` (entrées tôt,
> sorties tard). `FB_Input.OutputClean` renommé **`State`** (demande utilisateur).
> `FB_InputsMachine` référence désormais DIRECTEMENT les I/O réels en interne (plus de
> `*Raw`/`Invert*` câblés depuis `PRG_MAIN`) — devient un FB spécifique machine, pas une brique
> générique réutilisable ailleurs ; `InvertLogic`/`ChannelOk` de chaque sous-instance se forcent
> directement en vue CODESYS. Couvre TOUT le conditionnement I/O réel connu à ce jour :
> `EmergencyStopOk` (commun), mou de câble + capteur position haute (commun M1/M2), Winch M1
> (3 entrées + 7 sorties), Winch M2 (idem), Chariot M3 (4 capteurs position + `BrakeCmd`, seuls
> signaux réels — `RelayFwd/Rev/RelaySpeedGv` restent STUB logiciel). **Reste non intégré** :
> composition DANS `FB_Winch`/`FB_Chariot` eux-mêmes (choix d'architecture toujours en attente,
> `UseFeedback` reste `FALSE` partout). Prévu pour être implémenté en **LD** par l'utilisateur.
>
> **Version 1.1** — Suite audit documentaire : §5 corrigé — il n'y a **pas de coupure sèche**
> de la sortie relais sur défaut. Le passage en **rampe** (normale via `StartStop`, rapide via
> `SafeStop`) se résout **à l'intérieur** du FB de mouvement (`FB_Winch`/`FB_Chariot`) ; par le
> temps où `Output[i]` est appelé, la commande transmise est déjà la commande **rampée** correcte.
> Terminologie `PRG_IO` retirée (1 seul POU `PLC_PRG_MAIN`, pas de sous-`PRG_*` — voir Partie 2 §0).
>
> **Version 1.0** — Briques génériques de conditionnement E/S : `FB_Input` et
> `FB_Output`, déclaration en **tableaux d'instances**, contrôle de feedback et
> récupération du diagnostic automate / cartes E/S.
>
> 🔗 Dépend de : Partie 2 v2.5 (architecture), Partie 3 v1.2 (contrat FB, §1bis interface réduite).

---

## 🎯 0. But

Faciliter l'implémentation des E/S, **surtout à la mise en service**, quand il faut
**inverser** une logique (NO/NC), **filtrer** un rebond, **retarder** une sortie, vérifier un
**retour d'état**, etc. — sans rajouter des déclarations « à la va-vite » dispersées.

L'idée : des briques **réutilisables**, **paramétrables** (RETAIN), instanciables en **tableau**,
qui centralisent le traitement bas niveau et remontent un **diagnostic**.

> ⚠️ Liste **non exhaustive** : ces FB sont des canevas extensibles (d'autres options
> pourront être ajoutées : tempo retard, mémorisation, etc.).
>
> 🧭 **Interface réduite** (Partie 3 v1.2 §1bis) : ces briques n'ont **pas** l'interface standard
> complète (`Enable`/`StartStop`/`Mode`/`State`/`StateAtError`) — elles ont **leurs propres types
> de données**, dédiés à leur rôle de conditionnement bas niveau.

---

## 📥 1. `FB_Input` — Entrée TOR conditionnée

### Rôle
Conditionner une entrée tout-ou-rien : inversion NO/NC, filtrage anti-rebond (tempo de
filtrage par entrée), diagnostic.

### Interface (proposition)
```codesys
FUNCTION_BLOCK FB_Input
VAR_INPUT
    InputRaw    : BOOL;     (* Signal brut carte d'entrée *)
    InvertLogic : BOOL;     (* TRUE = NC (logique inversée) *)
    FilterTime  : TIME;     (* Tempo anti-rebond (filtrage) *)
    ChannelOk   : BOOL;     (* Diag voie/carte OK (voir §4) *)
END_VAR
VAR_OUTPUT
    State : BOOL;     (* Signal conditionné, prêt à l'emploi *)
    Error       : BOOL;     (* Voie en défaut (ChannelOk faux) *)
    ErrorId     : WORD;     (* bit0 : voie/carte HS *)
END_VAR
```

### Comportement
```
1. value := InputRaw XOR InvertLogic        (* inversion NO/NC *)
2. filtrage anti-rebond sur FilterTime → State
3. si ChannelOk = FALSE → Error, ErrorId.0, State forcé état sûr
```

> 🔒 **Polarité** : un signal de sécurité (`EmergencyStopOk`, mou de câble, rotation de phase…)
> est câblé fail-safe — `TRUE`=OK, `FALSE`=défaut — et doit toujours être initialisé à `TRUE`
> tant que le vrai capteur n'est pas câblé. Un capteur d'information classique (position atteinte…)
> suit la logique inverse (`FALSE`=repos, `TRUE`=déclenché), sans besoin d'initialisation
> particulière. Détail complet + 2 bugs réels rencontrés sur ce projet :
> `DOC/NAMING_CONVENTION.md` §"Polarité des booléens I/O".

---

## 📤 2. `FB_Output` — Sortie relais + feedback

### Rôle
Commander un actionneur (relais/contacteur) et **vérifier son retour d'état** : un actionneur
renvoie souvent une entrée de retour. En hébergeant le **contrôle de rétroaction** dans la
sortie, on récupère **directement un défaut de commande** (contacteur collé, ouvert, absent).

> 🧭 Ce FB est un **relais de commande bas niveau** : il transmet fidèlement `Command` (après
> inversion/blink) et **ne décide pas** d'un arrêt de mouvement. La logique de rampe
> (`StartStop`/`SafeStop`) est résolue **en amont**, dans `FB_Winch`/`FB_Chariot`, qui pilote
> `Command` déjà « rampé » (paliers de vitesse levés progressivement, sens coupé en dernier).

### Interface (proposition)
```codesys
FUNCTION_BLOCK FB_Output
VAR_INPUT
    Command      : BOOL;    (* Ordre logique, déjà résolu par le FB métier appelant *)
    InvertLogic  : BOOL;    (* TRUE = NC *)
    FeedbackRaw  : BOOL;    (* Retour d'état actionneur (optionnel) *)
    UseFeedback  : BOOL;    (* Activer le contrôle de rétroaction *)
    Blink1Hz     : BOOL;    (* Option : clignotement 1 Hz (diagnostic/visu) *)
    FeedbackTimeout : TIME; (* Délai max cohérence cmd/retour *)
    ChannelOk    : BOOL;    (* Diag voie/carte sortie OK *)
END_VAR
VAR_OUTPUT
    State    : BOOL;    (* Vers la carte de sortie *)
    FeedbackOk   : BOOL;    (* Retour cohérent avec la commande *)
    Error        : BOOL;
    ErrorId      : WORD;    (* bit0: feedback incohérent ; bit1: voie/carte HS *)
END_VAR
```

### Comportement
```
1. cmd := Command XOR InvertLogic
2. si Blink1Hz : moduler cmd à 1 Hz (diagnostic/visualisation)
3. State := cmd
4. si UseFeedback :
     comparer FeedbackRaw vs cmd ; au-delà de FeedbackTimeout incohérent
        → ErrorId.0 (contacteur collé / ne colle pas), FeedbackOk := FALSE
5. si ChannelOk = FALSE → ErrorId.1
```

> 🧷 Le contrôle de feedback est essentiel pour le scénario « contacteur de puissance collé »
> (voir Partie 2 §6 / Partie 5 §4) : la détection alimente le bloc safety métier concerné
> (`SafeStop`), voire déclenche l'AU via `PowerCutOff`.

---

## 🗂️ 3. Déclaration en tableaux d'instances (déclaration rapide)

Pour 8, 16… voies, instancier en **tableau** et configurer en boucle.

### Entrées
```codesys
VAR
    Input  : ARRAY[1..16] OF FB_Input;
END_VAR

(* Configuration (une fois, ex. à l'init) *)
Input[1].FilterTime := T#50MS;   Input[1].InvertLogic := FALSE;  (* Fond touché *)
Input[2].FilterTime := T#100MS;  Input[2].InvertLogic := FALSE;  (* Travail 1   *)
(* ... *)

(* Appel cyclique *)
FOR i := 1 TO 16 DO
    Input[i](InputRaw := DI[i], ChannelOk := DiagCarteDI[i]);
END_FOR
```

### Sorties
```codesys
VAR
    Output : ARRAY[1..16] OF FB_Output;
END_VAR

Output[1].InvertLogic := FALSE;  Output[1].UseFeedback := TRUE;   (* Relais M1 Fwd *)
Output[1].FeedbackTimeout := T#500MS;
(* ... contacteurs paliers, frein, etc. *)

FOR i := 1 TO 16 DO
    Output[i](Command := CmdRelais[i], FeedbackRaw := DI_Retour[i],
              ChannelOk := DiagCarteDO[i]);
    DO[i] := Output[i].State;
END_FOR
```

> ✅ Avantages : déclaration compacte, paramètres persistants (NO/NC, filtrage) modifiables
> **sans recompiler la logique métier**, diagnostic homogène, mise en service accélérée.

---

## 🩺 4. Diagnostic automate & cartes E/S

Les informations d'**état/diagnostic de l'automate et des cartes d'entrée-sortie** (voie HS,
carte absente/défaut, court-circuit/surcharge selon matériel) peuvent être **récupérées** et
injectées dans `ChannelOk` de chaque voie. Elles servent à :
- **valider le fonctionnement** d'une voie avant d'exploiter sa valeur ;
- remonter un **défaut E/S** distinct d'un défaut process ;
- contribuer, si critique, au bloc safety métier concerné (→ `SafeStop`).

> 🔎 La disponibilité exacte de ces diagnostics dépend du matériel (références cartes /
> coupleur). Mapping précis **à définir** à la configuration matérielle.

---

## 🧭 5. Place dans l'architecture

```
PLC_PRG_MAIN (1 seul POU, séquentiel — voir Partie 2 §0/§9)
 ├─ [IO IN]  Input[1..n]()   → valeurs conditionnées consommées par FB_Cycle, FB_Safety_<Metier>…
 ├─ ... (sécurité, modes, métier — chaque FB de mouvement résout SON StartStop/SafeStop en interne) ...
 └─ [IO OUT] Output[1..m]()  ← reçoit Command = sortie déjà rampée du FB métier appelant
                                (le FB de mouvement a déjà géré StartStop/SafeStop en amont)
```

🧷 Il n'y a **pas** de coupure globale des sorties relais sur `SafeStop` : c'est le FB de
mouvement qui, en interne, applique sa rampe (rapide sur `SafeStop`, normale sur
`StartStop:=FALSE`) et produit progressivement les `Command` corrects (paliers de vitesse
levés dans l'ordre, sens coupé en dernier). Le seul cas de coupure **immédiate** au niveau des
sorties est la **neutralisation** (`Enable=FALSE` du FB métier) ou l'**AU physique** (coupure
matérielle du contacteur général, indépendante du programme).

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (`SafeStop`/`StartStop`, PLC_PRG_MAIN).
- **Partie 3 v1.2** — Contrat FB (interface, §1bis interface réduite briques E/S).
- **Partie 4 / 5** — Cycle, modes & défauts.
