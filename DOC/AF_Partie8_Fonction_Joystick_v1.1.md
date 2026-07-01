# 📋 Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v1.1)

> **Version 1.1** — Suite audit documentaire : `SafeStop` **retiré** de l'interface `FB_Joystick`
> — ce FB **n'est pas un FB de mouvement** (Partie 3 v1.2 §1bis), il n'a donc pas `StartStop`/
> `SafeStop` ; sa neutralisation passe uniquement par `Enable`. `SafetyOk`/`EStopOk` fusionnés en
> **`EmergencyStopOk`** (plus de composition `NOT SafeStop AND EStopOk`). `FB_Filter_PT1` renommé
> **`FB_FilterPT1`**. Lien mort vers l'ancienne Partie 4 corrigé. Cadencement clarifié : traitement
> dans `MainTask` (10 ms), la tâche CAN (20 ms) ne fait que rafraîchir l'image process.
> Terminologie `PRG_JOY1` : voir note §6bis (1 seul POU `PLC_PRG_MAIN`, Partie 2 §0).
>
> 🔢 Renumérotée **Partie 4 → Partie 8** : les docs de **fonctions métier par FB** sont numérotées **8+**
> (les Parties 4–6 sont réservées aux specs transverses Cycle/Modes/E-S).

> **Fonction métier** : acquisition et conditionnement de la commande opérateur (joystick Hall → CANopen).
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔗 Dépend de : [P1 équipements](AF_Partie1_Analyse_Fonctionnelle_v1.2.md), [P3 contrat FB](AF_Partie3_Template_FB_Commun_v1.2.md).

---

## 🎯 1. Rôle métier

Traduire le **geste opérateur** (2 axes + bouton) en une **consigne normalisée en %** exploitable par les treuils et la translation.

- 🕹️ 2 axes analogiques bruts (0..10000 pts) via nœud **CANopen**.
- 🔘 1 bouton.
- 📤 Sortie : vitesse **0..100 %** + **sens** (-1 / 0 / +1) par axe.

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
RawX/Y ──► FB_AxisScale ──► FB_FilterPT1 ──► FB_Ramp ──► ST_AxisCmd (SpeedRef %, Direction)
           calib + deadband   filtre PT1       accel/decel
```

| Étape | Bloc | Rôle métier |
|-------|------|-------------|
| 🎯 Calibration | `FB_AxisScale` | Recale le neutre, applique la zone morte, sort en % signé (-100..+100) |
| 〰️ Filtrage | `FB_FilterPT1` | Lisse le bruit du signal Hall (filtre 1er ordre), cadencé via `FB_CycleTime` |
| 📈 Rampe | `FB_Ramp` | Accel/décel anti-à-coups (retour zéro plus rapide) |
| 📤 Normalisation | `ST_AxisCmd` | SpeedRef (%) + Direction |

> ♻️ **Réutilisation** : tous ces blocs **existent déjà** dans le projet — aucune brique réinventée (conforme P3 §0).
> 🧩 **Composition** (POO partielle, Partie 3 §Règles socle) : `FB_AxisScale`, `FB_FilterPT1`,
> `FB_Ramp` et `FB_CycleTime` sont des **instances composées à l'intérieur** de `FB_Joystick`
> (pas des FB de premier niveau appelés séparément dans l'arborescence — voir Partie 2 §3).
> `FB_CycleTime` fournit la base de temps utilisée par `FB_FilterPT1` pour son filtrage.
> ⚠️ `FB_Joystick` **n'a pas** de `StartStop`/`SafeStop` : ce n'est **pas** un FB de mouvement
> (Partie 3 v1.2 §1bis) — il produit une consigne, il ne pilote pas directement un actionneur.

---

## 🔌 3. Interface `FB_Joystick`

**📥 Entrées clés**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | Active la logique. `FALSE` → sorties neutralisées (0). |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Conditions globales OK (chaîne AU réarmée) — anciennement `SafetyOk` |
| `CanOnline` / `CanOperational` | BOOL | État du nœud CANopen |
| `RawX` / `RawY` | INT | Axes bruts (0..10000) |
| `RawButton` | BOOL | Bouton brut |
| `Calibrate` | BOOL | Demande recalage neutre (front) |
| `InvertX/Y`, `Deadband`, `FilterTime`, `AccelRate`, `DecelRate` | — | Paramétrage |

> ⚠️ **Pas d'entrée `SafeStop`** sur ce FB (v1.1) : `FB_Joystick` n'est pas un FB de mouvement.
> Son unique gate de sécurité est `Enable`/`EmergencyStopOk` (comme tout FB standard, Partie 3 §1).

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `AxisCmdX` / `AxisCmdY` | `ST_AxisCmd` | Consigne normalisée (SpeedRef %, Direction) |
| `Button` | BOOL | Bouton filtré |
| `NeutralXAct` / `NeutralYAct` | INT | Neutres calibrés (IHM) |
| `Ready`/`Busy`/`Done`/`Error`/`ErrorId` | — | État FB (`ErrorId 16#0003` = calib hors plage) |

🎯 Neutre mémorisé en **`VAR RETAIN`** (persiste à la coupure). Plage de calibration valide : 2000..8000.

---

## 🛡️ 4. Sécurité

- 🛑 **Gate** : sans `Enable`, ou CAN non opérationnel → toutes sorties forcées à **0**.
- 🔑 **Reset sur front** : défaut calibration non auto-réarmé (conforme P3 §5).
- 🔌 **CAN down** → joystick neutralisé (pas de commande fantôme).
- 🧭 Le geste opérateur reste de toute façon **revalidé en aval** par `FB_Cycle`/`FB_Modes`
  (homme-mort) avant d'atteindre un FB de mouvement — voir Partie 4 §0.

---

## 🗺️ 5. Mapping E/S (extrait du CFC d'origine)

| Entrée `FB_Joystick` | Variable câblée | État |
|----------------------|-----------------|------|
| `RawX` | `JoyXRaw_ANA1` | ✅ |
| `RawY` | `JoyYRaw_ANA2` | ✅ |
| `RawButton` | `JoyBtnRaw` | ✅ |
| `CanOnline` | `diagCAN.IsOnline` | ✅ |
| `CanOperational` | `diagCAN.IsOperational` | ✅ |
| `Enable` | `GVL_DEBUG.DBG_True` | ⚠️ debug |
| `EmergencyStopOk` | `GVL_DEBUG.DBG_True` | ⚠️ debug |
| `Reset` | (non câblé) | ⚠️ |
| `Calibrate` | (non câblé) | ⚠️ |

> 🗑️ **Retiré (v1.1)** : la ligne `SafeStop := GVL_DEBUG.DBG_False` n'a plus lieu d'être —
> `FB_Joystick` n'a pas cette entrée (voir §3). Le code source `CODE/PRG_JOY1.st` actuel câble
> encore `SafeStop` : il devra être mis à jour lors d'une prochaine itération code (hors périmètre
> du présent audit documentaire, qui ne modifie pas `CODE/`).

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier (unique)** : 👉 [`CODE/PRG_JOY1.st`](../CODE/PRG_JOY1.st)
*(Pas de recopie ici — voir le fichier `CODE/` pour le corps ST complet, conformément à la règle anti-doublon.)*

**Câblage appliqué dans `CODE/PRG_JOY1.st`** (résumé, état actuel — voir §6bis pour les écarts) :
- Entrées physiques mappées selon §5 (CAN, RawX/Y, bouton).
- Entrées sécurité en **forçage debug** (à sécuriser, voir §7).
- Paramètres : deadband 5 %, filtre 100 ms, accel 50 %/s, décel 150 %/s.

**Sorties exposées** : `AxisCmdX/Y.SpeedRef` (%), `AxisCmdX/Y.Direction` (-1/0/+1), `Button`, `NeutralXAct/YAct`, `Ready/Busy/Done/Error/ErrorId`.

### 6bis. Écarts connus entre ce document (v1.1) et le code actuel

⚠️ Le présent audit documentaire **ne modifie pas** `CODE/PRG_JOY1.st`. Écarts à traiter lors
d'une prochaine itération de code (via le workflow `codesys-workflow`) :
1. Retirer le câblage `SafeStop := GVL_DEBUG.DBG_False` (entrée supprimée du contrat, §3/§5).
2. Renommer `SafetyOk` → `EmergencyStopOk` dans l'appel `FB_Joystick_0(...)`.
3. Le nom de programme `PRG_JOY1` est un **vestige** de l'ancienne architecture multi-`PRG_*`
   (Partie 2 abandonne ce découpage — 1 seul POU `PLC_PRG_MAIN`, appels séquentiels). À terme,
   l'appel de `FB_Joystick` devrait être **inline dans `PLC_PRG_MAIN`**, pas dans un sous-programme
   séparé — changement structurel à valider avec l'utilisateur avant application.
4. Corriger le commentaire d'en-tête du fichier `.st` qui référence l'ancien nom de doc
   (`AF_Partie4_Fonction_Joystick_v1.0.md`) → doit pointer vers **`AF_Partie8_..._v1.1.md`**.

---

## 📝 7. Note d'application CODESYS 3.5 (manuel)

### 🔧 Intégration
1. Le corps ST de `FB_Joystick` (déjà correct, inchangé) est appelé — **cible cible à terme** :
   directement dans `PLC_PRG_MAIN` (MainTask, 10 ms). Le nom historique `PRG_JOY1` (§6bis point 3)
   est à faire disparaître dans une prochaine itération code.
2. **Vérifier** que l'appel s'exécute bien dans **MainTask (10 ms)**, pas dans `CanTask` (20 ms) :
   `CanTask` ne fait que rafraîchir l'image process CANopen (Partie 2 v2.5 §2).

### ✅ Variables à vérifier (doivent exister)
- `JoyXRaw_ANA1`, `JoyYRaw_ANA2`, `JoyBtnRaw`
- `diagCAN` (`.IsOnline`, `.IsOperational`)
- `GVL_DEBUG.DBG_True`, `GVL_DEBUG.DBG_False`
- Type `ST_AxisCmd` ; FB `FB_CycleTime`, `FB_AxisScale`, `FB_FilterPT1`, `FB_Ramp`

### 🔒 À sécuriser après remise en service
| Entrée debug | Remplacer par |
|--------------|---------------|
| `Enable := GVL_DEBUG.DBG_True` | autorisation réelle (`FB_Modes`) |
| `EmergencyStopOk := GVL_DEBUG.DBG_True` | chaîne AU réarmée (source à définir, voir Partie 3 §1) |
| `Reset := FALSE` | bit acquittement IHM |
| `Calibrate := FALSE` | bouton calibration IHM (front) |

---

## 🔁 8. Retour d'expérience (à compléter après test)

- [ ] Calibration OK (front `Calibrate`, neutre 2000..8000) ?
- [ ] Sortie % cohérente (deadband 5 %, rampes douces) ?
- [ ] CAN coupé → sorties à 0 (gate OK) ?
- [ ] Suppression effective de `SafeStop` et renommage `EmergencyStopOk` dans `CODE/PRG_JOY1.st` (§6bis) ?
- [ ] Si validé → figer le mapping sécurité définitif dans `AF_Partie2_v2.x` + clôturer cette v1.1.
