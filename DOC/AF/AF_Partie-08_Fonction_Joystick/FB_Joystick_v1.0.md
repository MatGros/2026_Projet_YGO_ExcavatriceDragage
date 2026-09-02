# FB_Joystick — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-08_Fonction_Joystick_v2.5.md`](../AF_Partie-08_Fonction_Joystick_v2.5.md) §3 — couvre `F08.01` à `F08.08`.
> Rôle de **ce** document : acquisition 2 axes Hall, gestion normative homme-mort (`ArmingPermit`), décodage des 5 paliers vitesse avec hystérésis, anti-inversion directe et **détail complet** des `TC-P08-JOY-*`.
> Source code : [`CODE/D_JOYSTICK/FB_Joystick.st`](../../../../CODE/D_JOYSTICK/FB_Joystick.st) · instance dans `PRG_03_Joystick`.

---

## 🧭 Sommaire

1. [🎯 Périmètre et composition](#1-périmètre-et-composition)
2. [🧪 Table des points de validation (détail)](#2-table-des-points-de-validation-détail)
3. [🔌 Contrats d'interface](#3-contrats-dinterface)
4. [⚙️ Pipeline de décodage et sécurités](#4-pipeline-de-décodage-et-sécurités)
5. [🔗 Intégration programme](#5-intégration-programme)
6. [🖥️ IHM et diagnostics](#6-ihm-et-diagnostics)
7. [🧬 Simulation](#7-simulation)
8. [📜 Suivi historique](#8-suivi-historique)
9. [📚 Documents liés](#9-documents-liés)

---

## 1 · 🎯 Périmètre et composition

### Responsabilité

Le bloc `FB_Joystick` est le point d'entrée unique de la commande manuelle machine.
Il convertit les signaux bruts CANopen des capteurs à effet Hall X/Y en consignes de vitesse normalisées (`SpeedTgt` 0..100%), en crans de vitesse discrets (`StepTgt` 1..5) et en bits de direction (`RelayFwd`/`RelayRev`).

### Principes Clés :
- 🔒 **Armement Homme-Mort Sécurisé (`ArmingPermit`)** : L'armement exige un appui maintenu au neutre ET la présence de l'autorisation externe `ArmingPermit`.
- 🪜 **Décodage Paliers Vitesse (1 à 5)** : Conversion déflexion % ➔ palier via 4 briques `HYSTERESIS` avec logique inversée corrigée (`NOT SpeedStepHyst.OUT`).
- ⚡ **Verrou Anti-Inversion Directe** : Bascule brutale de $+X$ à $-X$ sans temps d'arrêt au neutre ➔ commande bloquée à zéro jusqu'au retour effectif au neutre.

---

## 2 · 🧪 Table des points de validation (détail)

> Décline la table des tests d'acquisition, décodage et sécurité geste opérateur de `FB_Joystick`.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 13.5px;">
  <colgroup>
    <col style="width: 32px;">
    <col style="width: 55px;">
    <col style="width: calc(100% - 175px);">
    <col style="width: 45px;">
    <col style="width: 26px;">
    <col style="width: 36px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Intention</small></th>
      <th style="padding: 4px 8px;">Séquence & Déroulé des étapes (Comportement attendu & Signaux)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-JOY-01</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Décodage</b><br>Paliers 1..5</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0 (Repos neutre)</b> : Joystick au centre (<code>RawX=5000</code>, <code>AtNeutralXY=TRUE</code>, <code>StepTgt=0</code>, <code>SpeedTgt=0%</code>).<br>
        🔒 <b>Étape 1 (Armement homme-mort)</b> : Appui bouton <code>RawButton=TRUE</code> sous <code>ArmingPermit=TRUE</code> pendant 500 ms ➔ <code>DeadmanArmed=TRUE</code>.<br>
        🚀 <b>Étape 2 (Zone morte & Palier 1)</b> : Déflexion +5% (dans zone morte) ➔ <code>StepTgt=0</code> ; déflexion +15% ➔ <code>StepTgt=1</code>, <code>RelayFwd=TRUE</code> (vitesse minimale résistances rotoriques max).<br>
        ⚡ <b>Étape 3 (Montée progressive P2..P5)</b> : Déflexion +30% ➔ <code>StepTgt=2</code> ; +50% ➔ <code>StepTgt=3</code> ; +75% ➔ <code>StepTgt=4</code> ; +95% ➔ <code>StepTgt=5</code>, <code>SpeedTgt=100%</code> (contacteurs K1..K4 validés).<br>
        🔄 <b>Étape 4 (Hystérésis en descente)</b> : Relâchement progressif ➔ Le palier 4 reste tenu jusqu'à la limite basse de l'hystérésis (pas de battement autour du seuil).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.1</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-JOY-02</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Refus</b><br>ArmingPermit</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⛔ <b>Étape 1 (Permis refusé)</b> : Interlock en cours de tempo ou défaut machine ➔ <code>ArmingPermit=FALSE</code>.<br>
        🚀 <b>Étape 2 (Tentative opérateur)</b> : Appui <code>RawButton=TRUE</code> maintenu au neutre.<br>
        🛡️ <b>Étape 3 (Blocage strict & Warning)</b> : <code>DeadmanArmed</code> reste STRICTEMENT <code>FALSE</code>, levée de <code>ArmingPermitDenied=TRUE</code> (warning IHM non latché), aucune consigne générée lors de l'inclinaison.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P08-JOY-03</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Anti-inversion</b><br>directe</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚡ <b>Étape 1 (Déflexion positive établie)</b> : Joystick à +80% (Montée Palier 4).<br>
        💥 <b>Étape 2 (Bascule brutale inter-scan)</b> : Passage instantané à -80% (Descente) en 1 scan sans échantillon dans la zone morte neutre.<br>
        🔒 <b>Étape 3 (Verrouillage sûreté)</b> : Détection <code>FlipX=TRUE</code> ➔ Activation <code>InversionLockActive=TRUE</code>, consignes forcées à <code>StepTgt=0</code> et <code>SpeedTgt=0%</code>.<br>
        🔓 <b>Étape 4 (Libération au neutre)</b> : Retour physique du joystick au neutre (<code>AtNeutralXY=TRUE</code>) ➔ Réarmement, autorisation de repartir dans le nouveau sens.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P08-JOY-04</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Perte bus</b><br>CANopen</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        🚨 <b>Étape 1 (Déconnexion CAN)</b> : Perte nœud joystick (<code>BusCanOpenOP.NodePresent=FALSE</code> ou <code>JoystickOP.DeviceOperational=FALSE</code>).<br>
        ⛔ <b>Étape 2 (Repli immédiat)</b> : <code>Ready=FALSE</code>, <code>DeadmanArmed=FALSE</code>, retombée immédiate de toutes les consignes <code>AxisCmdX/Y</code> à zéro.<br>
        📊 <b>Étape 3 (Publication défaut)</b> : Levée du défaut standard <code>Fault.Error=TRUE</code> via le socle <code>FB_FaultCore</code>.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 3 · 🔌 Contrats d'interface

```pascal
FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    Enable             : BOOL;                   // --> [CMD] Validation générale bloc (TRUE = actif)
    Reset              : BOOL;                   // --> [CMD] Acquittement défaut (front, jamais conditionné)
    ArmingPermit       : BOOL;                   // --> [SAFE] Permission externe d'armement homme-mort (vue joystick)
    BusCanOpenOP       : ST_Diag_Device;         // --> [HW] État présence nœud CAN
    JoystickOP         : ST_Diag_Device;         // --> [HW] Mode esclave CANopen actif
    RawX               : INT;                    // --> [HW] Valeur brute axe X (0..10000)
    RawY               : INT;                    // --> [HW] Valeur brute axe Y (0..10000)
    RawButton          : BOOL;                   // --> [HW] État brut bouton homme-mort
    Calibrate          : BOOL;                   // --> [CMD] Front : recalage du point neutre
    Cfg                : ST_fbJoystick_Cfg;      // --> [CFG] Réglages groupés (deadband, filtres, marges ADC)
END_VAR
VAR_OUTPUT
    Ready              : BOOL;                   // <-- [STAT] FB opérationnel (Enable + bus OK + pas de défaut)
    Fault              : ST_Fault;               // <-- [DIAG] Brique défaut socle (live + latché)
    AxisCmdX           : ST_fbJoystick_AxisCmd;  // <-- [ACT] Consigne axe X : SpeedTgt, StepTgt (1..5), bits sens
    AxisCmdY           : ST_fbJoystick_AxisCmd;  // <-- [ACT] Consigne axe Y : SpeedTgt, StepTgt (1..5), bits sens
    DeadmanArmed       : BOOL;                   // <-- [STAT] Homme-mort armé (bouton tenu + ArmingPermit)
    ArmingPermitDenied : BOOL;                   // <-- [DIAG] Appui refusé (ArmingPermit=FALSE) - warning
    AtNeutralXY        : BOOL;                   // <-- [STAT] Les 2 axes en zone morte brute
    NeutralXAct        : INT;                    // <-- [STAT] Point neutre X calibré courant
    NeutralYAct        : INT;                    // <-- [STAT] Point neutre Y calibré courant
END_VAR
```

---

## 4 · ⚙️ Pipeline de décodage et sécurités

```text
[Signaux Bruts ADC CANopen RawX / RawY]
                  │
                  ▼
[FB_AxisScale : Normalisation [-100%..+100%] & Zone Morte Centrale]
                  │
                  ▼
[Porte Homme-Mort : DeadmanArmed (Bouton + AtNeutralXY + ArmingPermit)]
                  │
                  ▼
[Décodeur 5 Paliers Vitesse : Briques HYSTERESIS avec logique NOT SpeedStepHyst.OUT]
                  │
                  ▼
[Filtre Anti-Inversion Inter-Scan : Détection Flip sans passage par le neutre]
                  │
                  ▼
[Sorties Normalisées ST_fbJoystick_AxisCmd : SpeedTgt %, StepTgt 1..5, RelayFwd/Rev]
```

---

## 5 · 🔗 Intégration programme

- **POU Appelant** : `PRG_03_Joystick`.
- **Tâche d'exécution** : `Task_PRG_03` (périodicité 20 ms).

---

## 6 · 🖥️ IHM et diagnostics

- **Vue IHM** : Affichage dynamique de la déflexion curseur et du statut Homme-Mort (Vert = Armé, Orange = En attente, Rouge = Défaut).
- **Diagnostics** : Remontée du warning `ArmingPermitDenied` si l'opérateur appuie alors que le réarmement n'est pas permis.

---

## 7 · 🧬 Simulation

En simulation, `FB_SimBench` pilote les variables `RawX`/`RawY` et `RawButton` pour rejouer les trajectoires manuelles.

---

## 8 · 📜 Suivi historique

| Version | Date | Auteur | Changements majeurs |
|---|---|---|---|
| `v1.0` | 2026-09-02 | Ingénierie MES / Antigravity | Création formelle, alignement template standard AF-01 v1.4, formalisation TC-P08-JOY-01..04. |

---

## 9 · 📚 Documents liés

- [`AF_Partie-08_Fonction_Joystick_v2.5.md`](../AF_Partie-08_Fonction_Joystick_v2.5.md) : Spécification macro manipulateur.
- [`FB_AxisScale_v1.0.md`](FB_AxisScale_v1.0.md) : Mise à l'échelle des axes.
