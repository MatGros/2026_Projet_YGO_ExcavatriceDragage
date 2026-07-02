# 📋 Analyse Fonctionnelle — Partie 3 : Template FB Commun (v1.2)

> 🔧 **2026-07-02** — Terminologie : godet → grappin, `FB_Bucket` → `FB_Grappin` (correction utilisateur).
> 🔧 **2026-07-02** — Terminologie : Translation → Chariot, `FB_Translation` → `FB_Chariot` (liste I/O réelle reçue de l'utilisateur, terminologie officielle du matériel) — voir Partie 11 v1.2.

> Contrat unique que **tout** `FB_*` **métier** respecte (voir §1bis pour les catégories).
> Interface + machine d'état + gestion défauts/reset/AU.
> Pas de code interne — règles et structure.
> **v1.2** — Suite audit documentaire : `CoupeEnable` retiré (n'a jamais existé comme variable) ;
> modèle d'arrêt à 3 niveaux `Enable` > `SafeStop` > `StartStop` (§1, §1bis, §9) ; `SafetyOk`
> renommé **`EmergencyStopOk`** ; `SafeStop` = **1 par bloc safety métier** (pas de signal global).
> **v1.1** — Ajout règle de réutilisation des librairies CODESYS + note sécurité électrique.
> POO par **composition** (pas de méthode/propriété).

---

## 🎯 Règles socle
- 🧩 POO par **composition** : pas de méthode/propriété.
- 1 FB = 1 responsabilité, périmètre net.
- Nommage sémantique, **sans hongrois**.
- Booléens : entrée = **verbe**, sortie = **état**.
- Le FB est **autonome et sûr** : sans `Enable`, il se neutralise (sorties coupées).
- 📚 **Réutiliser l'existant — NE PAS réinventer** (voir §0).

---

## 📚 0. Réutilisation des librairies CODESYS (OBLIGATOIRE)

⚠️ **Interdiction de réimplémenter** une fonctionnalité déjà fournie par une librairie standard CODESYS.

Avant d'écrire la moindre logique « brique » (scaling, rampe, filtre, hystérésis, limite…), **chercher d'abord** le bloc équivalent dans les librairies présentes — en particulier **`Util`**.

| Besoin | Bloc à réutiliser | Librairie |
|--------|-------------------|-----------|
| 📐 Mise à l'échelle linéaire (pts↔m, %↔variateur) | `LIN_TRAFO` | Util |
| 📈 Rampe anti-à-coups | `RAMP_REAL` / `RAMP_INT` | Util |
| 🎛️ Régulation / arrêt précis | `PID_FIXCYCLE` | Util |
| 🪜 Paliers / seuils anti-battement | `HYSTERESIS` | Util |
| 🚧 Bornes & alarmes de limite | `LIMITALARM` | Util |
| ⏱️ Temporisations, fronts | `TON`/`TOF`/`R_TRIG`/`F_TRIG` | Standard |

🧭 Règle pratique :
- ✅ Composer ces blocs dans `VAR` (instances) et les câbler.
- ❌ Pas de recalcul « maison » d'une interpolation, d'une rampe ou d'une hystérésis.
- 📝 Si aucun bloc standard ne convient, **justifier** en commentaire pourquoi une brique custom est créée.

---

## 🔌 1. Interface standard

**📥 VAR_INPUT — Commande**
| Nom | Type | Rôle |
|-----|------|------|
| `Enable` | BOOL | Active la logique. `FALSE` = FB **neutralisé** : toutes les sorties coupées. |
| `Reset` | BOOL | Acquittement défaut (front interne) |

**🛡️ VAR_INPUT — Sécurité / contexte**
| Nom | Type | Rôle |
|-----|------|------|
| `EmergencyStopOk` | BOOL | Chaîne de sécurité **AU** réarmée + conditions globales OK (ou retour contacteur de puissance — source exacte à définir par métier). `FALSE` → le FB se neutralise. |
| `Mode` | `E_Mode` | Mode courant (autorisations) |

> 🧭 **Renommage v1.2** : `SafetyOk` devient **`EmergencyStopOk`**, pour éviter toute confusion
> avec `SafeStop` (§1bis). `EStopOk` (ancien nom transitoire vu dans certains docs métier) est
> définitivement absorbé par `EmergencyStopOk`.

**📤 VAR_OUTPUT — État**
| Nom | Type | Rôle |
|-----|------|------|
| `Ready` | BOOL | Prêt à recevoir un ordre |
| `Busy` | BOOL | Action en cours |
| `Done` | BOOL | Action terminée |
| `Error` | BOOL | Miroir de `ErrorId <> 0` |
| `ErrorId` | WORD | Code défaut bitfield |
| `State` | `E_State` | Phase opérationnelle |
| `StateAtError` | `E_State` | 📸 Snapshot phase au défaut |

**💾 VAR RETAIN** → paramètres persistants (offsets, calibrations).
**🔒 VAR** → instances composées (`LIN_TRAFO`, `RAMP_REAL`…) + copies locales.

---

## 🧭 1bis. Profils d'interface selon catégorie de FB

Le contrat ci-dessus (§1) est la base **commune**. Deux extensions/exceptions existent :

### 🚗 FB de mouvement (`FB_Winch`, `FB_Chariot`)
En plus de l'interface standard, ils portent **deux entrées supplémentaires** :

| Nom | Type | Rôle |
|-----|------|------|
| `StartStop` | BOOL | `TRUE` = **rampe d'accélération** vers la consigne. `FALSE` = **rampe de décélération normale** (arrêt demandé). Piloté par `FB_Cycle` (semi-auto) ou les commandes IHM (manuel/maintenance), via la source légitime arbitrée par `FB_Modes`. |
| `SafeStop` | BOOL | Sortie d'un **bloc safety métier** (1 par domaine, pas de signal global — voir §7bis) : `TRUE` = **rampe de décélération rapide** (plus rapide que l'accélération), `Enable` **maintenu** pendant la rampe. |

**Hiérarchie de précédence** (du plus fort au plus faible) : **`Enable` > `SafeStop` > `StartStop`**.
- `Enable = FALSE` → neutralisation immédiate (sorties coupées), quel que soit `SafeStop`/`StartStop`.
- `Enable = TRUE`, `SafeStop = TRUE` → rampe de décélération **rapide**, quelle que soit la valeur de `StartStop`.
- `Enable = TRUE`, `SafeStop = FALSE`, `StartStop` pilote la rampe **normale** (accel/decel).

### 🧩 Briques E/S & diagnostics (`FB_Input_Digital`, `FB_Output_Relay`, `FB_DiagCanOpen`, `FB_DiagEthercat`)
Ces briques bas niveau **n'ont pas** l'interface standard complète : **pas de `StartStop`**, pas
nécessairement de `Mode`/`State`/`StateAtError`. Elles ont **leurs propres types de données**
dédiés à leur rôle (voir Partie 6). Le contrat « tout FB » (§ Règles socle) s'entend donc pour
les **FB métier** (Joystick, Winch, Chariot, Grappin, Modes, Cycle, Safety…) — pas pour ces
briques de conditionnement/diagnostic.

---

## 🚦 2. E_State — ENUM exclusif (phases SEULES)

⚠️ Valeurs ordinales, **pas** des bits → toujours **1 seul état** à la fois.
`Error` et l'arrêt par `SafeStop`/perte d'`Enable` sont **orthogonaux** à la phase : ils se superposent sans la polluer.

| Val | État | Sens |
|-----|------|------|
| 0 | `DISABLED` | Enable faux, neutralisé |
| 1 | `INIT` | Démarrage / vérifs |
| 2 | `READY` | Prêt, attend ordre |
| 3 | `BUSY` | Action en cours |
| 4 | `DONE` | Action terminée |
| 5 | `STOPPING` | Décél rampe avant arrêt *(`StartStop=FALSE` ou `SafeStop=TRUE` — Winch/Chariot)* |

---

## 🧾 3. ErrorId — bitfield

- `WORD` = **16 défauts max** par FB (→ `DWORD` si dépassement).
- 0 = pas de défaut ; bit n = défaut n. **Cumul possible.**
- Sans mnémonique : chaque bit **set à un seul endroit** dans le code + **commentaire FR** explicatif.
- 🔑 `Error := (ErrorId <> 0)`.

---

## 🧷 4. State vs Error → séparés

| Variable | Rôle | Sur défaut |
|----------|------|-----------|
| `State` | Phase opérationnelle | Continue (phase réelle) |
| `Error` | Flag défaut | Miroir `ErrorId <> 0` |
| `ErrorId` | Détail bitfield | Cumul des causes |
| `StateAtError` | 📸 Snapshot phase à l'instant du défaut | **Figé jusqu'à acquittement** |

🧭 `State` = "ce que je fais", `StateAtError` = "où ça a planté".
📌 `StateAtError` reste figé tant que l'alarme n'est pas acquittée → diagnostic préservé.

---

## 🔑 5. Logique Reset (cœur sécurité)

**Principe : l'acquittement n'est JAMAIS mémorisé. Front obligatoire.**

```
ResetEdge = R_TRIG(Reset)            // front uniquement, par FB

Pour chaque bit de ErrorId :
   SI (cause disparue) ET (ResetEdge actif ce cycle)
       → efface le bit
   SINON
       → le bit reste
```

🧭 Conséquences voulues :
- 🔴 Cause **toujours présente** + appui reset → **rien** (front gaspillé).
- 🟠 Cause disparue **toute seule** → alarme **reste** (pas d'appui = pas d'effacement).
- 🟢 Cause disparue **+ nouveau front** reset → efface.

⚠️ **Cas mains-dans-le-moteur** : défaut résolu seul → moteur **ne redémarre pas** → appui délibéré requis **après** disparition. ✅

📌 Acquittement IHM = **bouton général** → tente le reset de tous les FB.
📌 Tant que `StateAtError` figé → on peut **retenter** des reset jusqu'à acquittement effectif.
📌 Appliqué à **tous les FB métier** (cohérence maintenance), critique sur Winch / Brake / Chariot.

---

## 🛑 6. Acquitter ≠ redémarrer

```
Alarme effacée → State revient READY (pas BUSY)
Redémarrage   → exige un NOUVEL ordre explicite (StartStop, Cycle ou opérateur)
```

🧭 En semi-auto : un défaut (`SafeStop`) → Cycle va en **HOLD sûr**, ne reprend jamais en aveugle.

---

## 🟥 7. Arrêt d'Urgence — chaîne indépendante

| Élément | Nature | Action |
|---------|--------|--------|
| 🔴 Bouton AU + câble « montée excessive » | Physique câblé | Coupe le contacteur de puissance (moteurs OFF **brutalement**, freins collent) |
| 🔧 Réarmement AU | Bouton **physique** | Réautorise le mouvement |
| 🧨 `PowerCutOff` | Cmd PLC → relais | Coupure puissance amont si contacteur collé (voir §7bis) |
| 🟧 `SafeStop` | Sortie d'un bloc safety **métier** (1 par domaine) | Sur défaut process de ce domaine : rampe de décélération **rapide**, `Enable` maintenu — **≠ AU**, seul mécanisme non-brutal |
| ✅ `EmergencyStopOk` | Info (entrée FB) | =1 **quand AU réarmé + conditions globales OK** |

🧭 Règles strictes :
- 🔌 Réarmement AU = **physique**, pas IHM.
- 🚫 Réarmer l'AU **n'efface pas** les alarmes (2 actions distinctes).
- 🔗 L'arrêt logiciel passe par **`SafeStop`** (rampe rapide, `Enable` maintenu) — **jamais** de coupure sèche des sorties en dehors de la neutralisation (`Enable=FALSE`) ou de l'AU physique.

```
AU enfoncé              → contacteur puissance coupé BRUTALEMENT → sorties sûres (matériel)
AU réarmé physique      → EmergencyStopOk = 1 → mouvement réautorisable
Défaut process (métier) → SafeStop_<Metier> = 1 → rampe décélération RAPIDE (Enable maintenu)
Alarmes                  → toujours présentes → acquittement IHM séparé (reset front)
```

---

## 🔌 7bis. Sécurité électrique — automate jamais coupé (spécifique aux blocs safety)

⚠️ Le contrôleur **reste alimenté en permanence** : la sécurité ne peut pas reposer sur l'extinction de l'API.

Règle pour chaque `FB_Safety_<Metier>` (détail fonctionnel en Partie 2) :
- 🔁 Chaque contacteur de puissance a un **retour d'état câblé** (entrée TOR).
- 🔍 Le bloc safety compare en continu **commande vs retour** (`ST_ContactorCheck`).
- 🧨 Si l'API commande l'ouverture mais le contacteur **reste collé** (retour ≠ commande, persistant) ⇒ lever la **sortie de coupure puissance** (`PowerCutOff`) qui ouvre le **contacteur général amont** et coupe **électriquement** la puissance.
- 🧭 Cette coupure est **indépendante** de `SafeStop` logiciel : c'est le dernier rempart matériel, **seul mécanisme brutal** avec l'AU physique.
- 🗂️ **Granularité** : `SafeStop` est **propre à chaque métier** (un bloc safety par domaine : treuils, chariot, grappin…), car les surveillances ne portent pas sur les mêmes grandeurs. `PowerCutOff`, en revanche, agit sur le **contacteur général amont** (organe partagé).

---

## 🖥️ 8. Couplage IHM

Chaque FB porte **1 struct** d'échange écran :
```
Hmi : ST_<Objet>Hmi   // lecture (mesures, état, ErrorId, StateAtError)
                      // écriture (consignes manuel, reset)
```
→ L'intégrateur IHM mappe **une seule struct** par objet, jamais les internes. ✅

---

## 🧱 9. Squelette d'exécution (phases, pas de code)

```
1. 🛡️ GATE     → NOT Enable → sorties sûres (neutralisation) + RETURN
                  NOT EmergencyStopOk → sorties sûres + RETURN
2. 📥 ACQUIRE  → copies locales + range check entrées
3. 🚦 STATE    → avance la phase (DISABLED…DONE/STOPPING)
4. ⚙️ CORE     → briques métier composées (réutiliser libs §0, si autorisé)
                  FB de mouvement : arbitrage rampe — SafeStop=TRUE → rampe RAPIDE ;
                  sinon StartStop pilote la rampe NORMALE (accel/decel)
5. 🧾 ERROR    → set bits ErrorId + fige StateAtError
6. 🔑 RESET    → R_TRIG + efface bits dont cause disparue
7. 📤 OUTPUT   → mappe sorties + force sûr si Error / NOT Enable
8. 🖥️ HMI      → Error, ErrorId, State, StateAtError → écran
```

📌 Ordre **imposé** : sécurité d'abord, IHM en dernier.
📌 Sortie sûre (étape 7) **prioritaire** sur la phase : `State` peut dire BUSY, sorties coupées si `Error` / perte `Enable`. `SafeStop` **ne coupe pas** les sorties : il impose la rampe rapide (étape 4), les sorties restent actives le temps de la décélération.
📌 Copies locales = **intégrité** (jamais agir sur la donnée brute volatile).

---

## 📚 Documents liés
- **Partie 1 v1.2** — Présentation & équipements.
- **Partie 2 v2.5** — Architecture (flux `SafeStop`/`StartStop`, `PowerCutOff`).
- **Partie 4** — Cycle & séquenceur (usage `StartStop` par étape).
- **Partie 5** — Modes & maintenance (`EmergencyStopOk`, `SafeStop`, limite légale `FB_Modes`).
- **Partie 6** — Conditionnement E/S (interface réduite, §1bis).
