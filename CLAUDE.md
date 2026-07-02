# Excavatrice de Dragage — Guide Claude Code

Automate CODESYS 3.5 pour machine de dragage en carrière noyée.

---

## 🎯 **Avant de coder : LIRE CECI**

### 1. **[Convention de Nommage](DOC/NAMING_CONVENTION.md)** ← ESSENTIEL
- **PascalCase partout**, aucun hongrois (`bFlag` ❌, `iCounter` ❌)
- Préfixes : `ST_` (struct), `E_` (enum), `FB_` (function block)
- Booléens entrée = verbe (`Enable`, `Start`), sortie = état (`Ready`, `Done`)
- Suffixes unité si besoin : `_M` (mètres), `_Pct` (%), `_Ms` (ms)

### 2. **[Analyse Fonctionnelle Partie 3](DOC/AF_Partie3_Template_FB_Commun_v1.3.md)** ← Contrat FB
Chaque Function Block **métier** doit respecter :
- Interface : `Enable`, `Reset`, `EmergencyStopOk`, `Mode` (entrées) — **FB de mouvement en plus** : `StartStop` (accel/decel normale) + `SafeStop` (decel rapide, sortie du bloc safety métier concerné)
- Sorties : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`
- `ErrorId` = bitfield (max 16 défauts)
- **Reset = front obligatoire** : cause disparue + appui reset pour effacer
- Jamais autoriser le redémarrage automatique après défaut
- **Précédence `Enable` > `SafeStop` > `StartStop`** : `Enable=FALSE` → neutralisation (sorties coupées) ; `SafeStop=TRUE` → rampe rapide (`Enable` maintenu) ; `StartStop=FALSE` → rampe normale. **`CoupeEnable` n'existe pas** (jamais une variable — vocabulaire abandonné).

### 3. **[Architecture](DOC/AF_Partie2_Architecture_Programme_v2.7.md)** ← Pour comprendre
Tâches, arborescence CODESYS, flux données. **v2.7 = référence** (modèle `SafeStop`/`StartStop`,
`SafeStop` **par métier** — pas de signal global ; pas de `GVL_BusHealth`/`E_DegradationLevel`/
`FB_Watchdog` [fonction système] ; conserve mapping M1/M2/M3, SpeedStep masque 4 bits, `PowerCutOff` ;
câble mécanique de position haute retiré de la chaîne AU matérielle, géré par l'automate via
`PowerCutOff` — voir Partie1 v1.4 §Sécurité électrique).

### 4. **Specs détaillées**
- **[Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md)** — Cycle & séquenceur (`E_CycleStep`, INIT, synchro, frein, chariot, grappin, rampes).
- **[Partie 5](DOC/AF_Partie5_Modes_Maintenance_v1.2.md)** — Modes & maintenance (N1/N2, AU/`SafeStop`/`PowerCutOff`, limite légale — gérée par `FB_Modes` uniquement).
- **[Partie 6](DOC/AF_Partie6_IO_Conditioning_v1.2.md)** — Conditionnement E/S (`FB_Input_Digital`, `FB_Output_Relay`).
- **[Partie 8](DOC/AF_Partie8_Fonction_Joystick_v1.2.md)** — Fonction métier Joystick (docs métier par FB numérotées 8+).

---

## 📋 **Principes Clés**

| Règle | Pourquoi |
|-------|----------|
| Sémantique > Typage | Le type se lit en déclaration, le nom parle du **rôle** |
| Reset = front | Évite réarmement accidentel, garantit conscient du défaut |
| `Enable` > `SafeStop` > `StartStop` | `Enable=FALSE` = neutralisation ; `SafeStop` (par métier) = rampe rapide, `Enable` maintenu ; `StartStop=FALSE` = rampe normale |
| AU physique + `PowerCutOff` | Chaîne matérielle indépendante ; **seul l'AU coupe brutalement** ; `PowerCutOff` coupe la puissance amont si contacteur collé |
| 1 FB = 1 responsabilité | Composition > héritage, clair et maintenable |

---

## 🛠️ **Workflow Édition**

Toute modif passe par la skill **[`codesys-workflow`](.claude/skills/codesys-workflow.md)** (chargement auto) :

0. 📚 Lire règles `DOC/` + STOP si spec incomplète
1. 🔍 Comprendre architecture + devices (`Device.export`)
2. 🔬 Analyser variables / PRG / FB existants
3. 🧩 Plan **groupé par concept** → validation user
4. 💻 Code ST commenté FR + emoji + **note d'application manuelle**
5. 🔁 REX → maj specs `DOC/` versionnées `vX.X`
6. 🔄 Nouvel export user → rebouclage

⚠️ L'utilisateur applique **tout manuellement** dans CODESYS 3.5 (copie du ST).

---

## 🏗️ **Arborescence CODESYS**

```
PLC_PRG_MAIN (MainTask 10 ms — orchestration séquentielle : diag PUIS métier)
├── _COMMON      (FB_FilterPT1, FB_Brake, FB_Input_Digital, FB_Output_Relay)
├── _TYPES       (ST_*, ST_SpeedStepTable, ST_ContactorCheck, ST_LimitLegal, E_Mode/State/CycleStep)
├── _DIAG        (FB_DiagCanOpen, FB_DiagEthercat ×3 — appelés dans PLC_PRG_MAIN, pas de GVL)
├── JOYSTICK     (FB_Joystick — compose FB_AxisScale/FB_FilterPT1/FB_Ramp/FB_CycleTime en interne)
├── WINCH        (FB_Winch M1/M2 — StartStop/SafeStop, FB_SpeedStep masque 4 bits, FB_WinchSync)
├── ENCODER      (FB_Encoder_Abs COD1/COD2 → Scale → Safety)
├── CHARIOT      (FB_Chariot — variateur AC600 / M3 — StartStop/SafeStop)
├── GRAPPIN      (FB_Grappin)
├── SAFETY       (FB_Safety_<Metier> → SafeStop propre au métier + PowerCutOff)
└── SEQUENCE     (FB_Modes — dont limite légale, FB_Cycle)
```
👉 **Pas de `FB_Watchdog`** : périodicité des tâches surveillée par la fonction système CODESYS
(config tâche, seuil 200 ms), pas un FB applicatif.
👉 Mapping : **M1**=treuil1+COD1, **M2**=treuil2+COD2, **M3**=chariot AC600. Pas de `GVL_BusHealth` :
chaque FB lit directement la sortie du FB producteur (appel séquentiel).

---

## 📐 **Tâches Cadencées**

| Tâche | Priorité | Cadence | Contenu |
|-------|----------|---------|---------|
| **EtherCatTask** | à définir | **4 ms** | Codeurs M1/M2 (COD1/COD2), variateur AC600 (M3) |
| **CanTask** | à définir | **20 ms** | Joystick Hall |
| **MainTask** | à définir | **10 ms** | `PLC_PRG_MAIN` : diag bus **puis** logique métier, cycle |

👉 Tâches bus rafraîchissent l'image process → `PLC_PRG_MAIN` consomme. Traitement `FB_Joystick`
dans `MainTask` (10 ms), même si l'acquisition CAN est à 20 ms.
⏲️ Surveillance périodicité tâches : **fonction système CODESYS**, seuil **200 ms** (pas de FB
dédié). Priorités **à définir** en config CODESYS (TBD).

---

## 🔄 **Cycle de Dragage** (`E_CycleStep` — détail Partie 4)

`INIT` → `WORK_POS_SELECT` → `DESCENDING_OPEN` → `BOTTOM_TOUCH_WAIT` → `SYNCHRO_ADJUST`
→ `CTRL_ASCENDING` → `ASCENDING_LOADED` → `DRAINING_PAUSE` → `CHARIOT_MOVE`
→ `DESCENDING_OPEN_DUMP` → `RETURN_WORK_POS` → `READY` (reboucle). `ERROR_HOLD` sur défaut.

👉 Pseudo-Grafcet : chaque étape = une mémoire. Tout mouvement validé au joystick (homme-mort).

---

## 📖 **Documentation Complète**

Tous les docs dans **`DOC/`** :
- [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md) — Nommage strict
- [AF_Partie1_Analyse_Fonctionnelle_v1.4.md](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.4.md) — Équipements & fonctions
- [AF_Partie2_Architecture_Programme_v2.7.md](DOC/AF_Partie2_Architecture_Programme_v2.7.md) — Architecture détaillée (**v2.7**)
- [AF_Partie3_Template_FB_Commun_v1.3.md](DOC/AF_Partie3_Template_FB_Commun_v1.3.md) — Contrat FB & sécurité
- [AF_Partie4_Cycle_Sequenceur_v1.2.md](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md) — Cycle, synchro, frein, grappin, rampes
- [AF_Partie5_Modes_Maintenance_v1.2.md](DOC/AF_Partie5_Modes_Maintenance_v1.2.md) — Modes, maintenance N1/N2, AU, limite légale
- [AF_Partie6_IO_Conditioning_v1.2.md](DOC/AF_Partie6_IO_Conditioning_v1.2.md) — Conditionnement E/S
- [AF_Partie8_Fonction_Joystick_v1.2.md](DOC/AF_Partie8_Fonction_Joystick_v1.2.md) — Fonction métier Joystick (8+ = métier par FB)
- [AF_Partie9_Fonction_Winch_v1.1.md](DOC/AF_Partie9_Fonction_Winch_v1.1.md) — Fonction Winch (M1/M2, safety mou de câble/thermique)
- [AF_Partie10_Fonction_Encoder_Homing_v1.5.md](DOC/AF_Partie10_Fonction_Encoder_Homing_v1.5.md) — Codeur & Homing
- [AF_Partie11_Fonction_Chariot_v1.2.md](DOC/AF_Partie11_Fonction_Chariot_v1.2.md) — Fonction Chariot (M3, ex-Translation)
- [AUDIT_Coherence_Documentaire_v1.0.md](DOC/AUDIT_Coherence_Documentaire_v1.0.md) — Historique des décisions de conception (`SafeStop`, `StartStop`, `EmergencyStopOk`…)

### 📐 Plan de numérotation
- **1–3** = fondations · **4–6** = specs transverses (Cycle/Modes/E-S) · **8+** = fonctions métier par FB (Joystick…).

---

## 🔒 **GUARDRAILS OBLIGATOIRES — AVANT TOUTE MODIF CODE/**

**Si l'utilisateur demande modification CODE/, FB_, PRG_, ou "codesys" :**

1. ✅ **Charger automatiquement** la skill `.claude/skills/codesys-workflow.md`
2. ✅ **Lire docs pertinentes** : NAMING_CONVENTION.md, AF_Partie3_Template_FB_Commun_v1.3.md (ajuster selon métier concerné : Winch=Partie9, Chariot=Partie11, Homing=Partie10)
3. ✅ **Vérifier spec complète** → Sinon demander clarifications
4. ✅ **Auditer conformité** : nommage PascalCase, interface FB, sécurité
5. ✅ **Tracer checklist** avant génération
6. ✅ **Refuser code non-conforme** → Ne JAMAIS approximer

**Cas d'arrêt (refuse génération) :**
- Nommage ambigu ou non-PascalCase
- Interface FB incomplète (voir profils Partie 3 §1bis : FB standard vs FB de mouvement vs briques réduites)
- Reset pas sur front
- `SafeStop`/`StartStop` ajoutés à un FB qui n'est **pas** un FB de mouvement (ex. `FB_Joystick`, briques E/S/diag) — voir Partie 3 §1bis
- `CoupeEnable` réintroduit (vocabulaire abandonné — n'a jamais été une variable, voir Partie 2 §0)
- `FB_Watchdog` réintroduit comme FB applicatif (surveillance = fonction système CODESYS)
- Redémarrage auto après défaut
- Spec manquante/incomplète

---

### 📖 **Skill Obligatoire**

Workflow défini dans [`.claude/skills/codesys-workflow.md`](.claude/skills/codesys-workflow.md) (chargement auto).

Demande simplement :
```
Modifier FB_Joystick pour [description]
Créer nouveau FB_ pour [description]
Analyser [partie] du programme automate
```

L'IA charge les règles DOC + valide avant de générer.

---

## ✅ **Checklist Avant de Coder**

- [ ] Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)
- [ ] Lire [AF_Partie3](DOC/AF_Partie3_Template_FB_Commun_v1.3.md) si nouveau FB
- [ ] Vérifier que le nom suit : **PascalCase, sémantique, sans hongrois**
- [ ] `ErrorId` = bitfield ? Reset = front obligatoire ?
- [ ] Précédence `Enable` > `SafeStop` > `StartStop` respectée ? `StartStop`/`SafeStop` uniquement si FB de mouvement ?

### Avant de demander modification code

1. **Décrire** : spec complète du besoin
2. **L'IA charge guardrails** : audit nommage, interface, sécurité
3. **L'IA valide** : conform spec
4. **Si doute** : signale + demande clarification
5. **Sinon** : génère code + checklist
6. **Réimporter dans CODESYS** (manuel)

---

**État du projet :** Main branch clean, documentation complète, guardrails actifs. Nouvelle procédure en cours. 🚀
