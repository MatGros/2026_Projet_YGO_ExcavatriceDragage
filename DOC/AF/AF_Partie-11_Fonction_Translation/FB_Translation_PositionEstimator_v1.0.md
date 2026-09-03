# FB_Translation_PositionEstimator — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-11_Fonction_Translation_v2.3.md`](../AF_Partie-11_Fonction_Translation_v2.3.md) §3 — couvre le calcul odométrique et le recalage absolu du chariot M3.
> Rôle de **ce** document : intégration temporelle vitesse/fréquence AC600, gestion de la persistance reboot (ColdStart) et recalage absolu sur franchissement des 5 cames inductives fixes.
> Source code : [`CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st`](../../../../CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st) · instance dans `PRG_05_Translation`.

---

## 🧭 Sommaire

1. [🎯 Périmètre et composition](#1-périmètre-et-composition)
2. [🧪 Table des points de validation (détail)](#2-table-des-points-de-validation-détail)
3. [🔌 Contrats d'interface](#3-contrats-dinterface)
4. [⚙️ Algorithme odométrique et recalage](#4-algorithme-odométrique-et-recalage)
5. [🔗 Intégration programme](#5-intégration-programme)
6. [🖥️ IHM et diagnostics](#6-ihm-et-diagnostics)
7. [🧬 Simulation](#7-simulation)
8. [📜 Suivi historique](#8-suivi-historique)
9. [📚 Documents liés](#9-documents-liés)

---

## 1 · 🎯 Périmètre et composition

### Responsabilité

Le bloc `FB_Translation_PositionEstimator` calcule la position linéaire continue estimée du chariot de translation M3 en mètres ($0.0\text{ m}$ à la Trémie $\rightarrow +30.0\text{ m}$ à la Maintenance).
Il combine une intégration continue (odométrie par mesure de fréquence variateur et direction) avec un recalage absolu instantané sur fronts montants des 5 capteurs inductifs fixes.

### Principes Clés :
- 📐 **Odométrie Continue** : Intégration temporelle $\Delta x = \text{FreqHz} \times \text{GainMetersPerHzSec} \times \Delta t$ selon le sens commandé (`ReqMaintenance` = $+$, `ReqTremie` = $-$).
- 📍 **Recalage Absolu Instantané** : Au front montant (`R_TRIG`) d'une des 5 cames fixes, la position est recalée immédiatement à la cote exacte calibrée, avec émission d'un pulse `Recalibrated` d'un scan.
- 💾 **Reprise Reboot / ColdStart** : Restauration transparente de la position depuis `PersistedPositionM` au premier cycle utile si `PersistedInitialized=TRUE`.
- 🛡️ **Anti-Faux Recalage à l'Allumage** : Les capteurs déjà actifs au démarrage automate ne génèrent pas de faux saut de recalage (`FirstScanDone`).

---

## 2 · 🧪 Table des points de validation (détail)

> Décline la table des tests de calcul de position, recalage et persistance de `FB_Translation_PositionEstimator`.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-EST-01</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Reprise</b><br>ColdStart</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 1 (Initialisation à froid)</b> : Démarrage sous <code>Enable=TRUE</code> avec <code>PersistedPositionM=12.5</code> et <code>PersistedInitialized=TRUE</code>.<br>
        🎯 <b>Étape 2 (Restauration immédiate)</b> : <code>PositionEstimatedM</code> prend immédiatement la valeur <code>12.5m</code> dès le 1er cycle.<br>
        🔒 <b>Étape 3 (Verrouillage état)</b> : <code>Initialized=TRUE</code>, aucun saut parasite de recalage émis (<code>Recalibrated=FALSE</code>, <code>RecalibratedSensorId=-1</code>).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.1</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-EST-02</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Recalage</b><br>Came P1</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        🚗 <b>Étape 1 (Mouvement avec dérive)</b> : Position estimée courante à <code>19.2m</code>.<br>
        📍 <b>Étape 2 (Franchissement physique P1)</b> : Front montant <code>SensorP1: FALSE ➔ TRUE</code> (cote calibrée <code>PosP1M=20.0m</code>).<br>
        🎯 <b>Étape 3 (Recalage instantané)</b> : <code>PositionEstimatedM</code> saute instantanément à <code>20.0m</code>, pulse <code>Recalibrated=TRUE</code> pendant 1 cycle avec <code>RecalibratedSensorId=1</code> (P1).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P11-EST-03</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Intégration</b><br>Odométrique</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚡ <b>Étape 1 (Commande Maintenance)</b> : <code>ReqMaintenance=TRUE</code> sous <code>DriveActualFreqHz=50.0 Hz</code> (vitesse $0.416\text{ m/s}$).<br>
        ⏱️ <b>Étape 2 (Progression temporelle)</b> : Exécution continue pendant $1.0\text{ s}$ $\rightarrow$ la position progresse de manière monotone de $+0.416\text{ m}$.<br>
        🛑 <b>Étape 3 (Neutralisation)</b> : <code>Enable=FALSE</code> $\rightarrow$ arrêt strict de l'intégration, maintien de la dernière valeur estimée.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 3 · 🔌 Contrats d'interface

```pascal
FUNCTION_BLOCK PUBLIC FB_Translation_PositionEstimator
VAR_INPUT
    Enable               : BOOL;   // --> [CMD] Active le calcul
    Reset                : BOOL;   // --> [CMD] Front d'acquittement / réinitialisation
    DriveActualFreqHz    : REAL;   // --> [HW] Fréquence réelle variateur en Hz (ex: 50.0 Hz)
    ReqTremie            : BOOL;   // --> [CMD] Demande explicite vers Trémie (sens négatif)
    ReqMaintenance       : BOOL;   // --> [CMD] Demande explicite vers Maintenance (sens positif)
    
    // 5 Capteurs de position fixes
    SensorMaintenance    : BOOL;   // --> [HW] Capteur Maintenance (30.0 m)
    SensorP1             : BOOL;   // --> [HW] Capteur P1 (20.0 m)
    SensorP2             : BOOL;   // --> [HW] Capteur P2 (15.0 m)
    SensorPV             : BOOL;   // --> [HW] Capteur PV (5.0 m)
    SensorTremie         : BOOL;   // --> [HW] Capteur Trémie (0.0 m)

    // Positions de référence calibrées (mètres) depuis GVL_PERSISTENT
    PosMaintenanceM      : REAL := 30.0;   // --> [CFG] Position Maintenance
    PosP1M               : REAL := 20.0;   // --> [CFG] Position P1
    PosP2M               : REAL := 15.0;   // --> [CFG] Position P2
    PosPVM               : REAL := 5.0;    // --> [CFG] Position PV
    PosTremieM           : REAL := 0.0;    // --> [CFG] Position Trémie

    // Gain de vitesse : mètres parcourus par Hz par seconde
    GainMetersPerHzSec   : REAL := 0.008333; // --> [CFG] Gain odométrie (50 Hz = 0.416 m/s)

    // Reprise après reboot
    PersistedPositionM   : REAL := 0.0;     // --> [CFG] Position persistée
    PersistedInitialized : BOOL := FALSE;   // --> [CFG] Initialisation persistée
END_VAR

VAR_OUTPUT
    PositionEstimatedM   : REAL;   // <-- [STAT] Position continue estimée en mètres
    Initialized          : BOOL;   // <-- [STAT] Exposé pour recopie persistante côté appelant
    Recalibrated         : BOOL;   // <-- [STAT] Pulse 1 cycle lors d'un recalage sur capteur
    RecalibratedSensorId : INT;    // <-- [DIAG] 0=Maint, 1=P1, 2=P2, 3=PV, 4=Trémie, -1=Aucun
END_VAR
```

---

## 4 · ⚙️ Algorithme odométrique et recalage

```text
[Mesure temps de cycle FB_CycleTime (DeltaT)]
                   │
                   ▼
[Détection front montant 5 cames fixes (TrigMaintenance .. TrigTremie)]
      │                                       │
      ├─► (Front détecté) ───────────────────►│ Saut instantané : PositionEstimatedM := PosRefM
      │                                       │ Recalibrated := TRUE, RecalibratedSensorId := ID
      │
      └─► (Pas de front — Odométrie) ────────►│ Vitesse := DriveActualFreqHz * GainMetersPerHzSec
                                              │ Si ReqMaintenance : Pos := Pos + Vitesse * DeltaT
                                              │ Si ReqTremie      : Pos := Pos - Vitesse * DeltaT
                                              │ Bornage strict : [0.0m .. 30.0m]
```

---

## 5 · 🔗 Intégration programme

- **POU Appelant** : `PRG_05_Translation`.
- **Tâche d'exécution** : `Task_PRG_05` (périodicité 20 ms).
- **Persistance** : L'appelant recopie `PositionEstimatedM` et `Initialized` vers `GVL_PERSISTENT` à chaque cycle pour reprise automatique sur redémarrage à froid.

---

## 6 · 🖥️ IHM et diagnostics

- **Vue IHM Chariot** : Affichage d'une jauge linéaire continue de 0 à 30 m avec repères visuels des 5 cames.
- **Diagnostic Recalage** : Clignotement de l'indicateur de recalage sur détection de came avec affichage du dernier capteur franchi (`RecalibratedSensorId`).

---

## 7 · 🧬 Simulation

En banc d'essai de simulation (`CODE/L_SIMULATION/FB_Sim_Translation.st`), le chariot virtuel simule l'avance mécanique continue et active successivement les 5 cames matérielles pour valider la chaîne d'estimation sans variateur physique.

---

## 8 · 📜 Suivi historique

| Version | Date | Auteur | Changements majeurs |
|---|---|---|---|
| `v1.0` | 2026-09-03 | Ingénierie MES / Antigravity | Création initiale complète, alignement strict gabarit AF-01 v1.4, formalisation TC-P11-EST-01..03. |

---

## 9 · 📚 Documents liés

- [`AF_Partie-11_Fonction_Translation_v2.3.md`](../AF_Partie-11_Fonction_Translation_v2.3.md) : Spécification de la translation machine.
- [`FB_Translation_PositionDecoder_v1.0.md`](FB_Translation_PositionDecoder_v1.0.md) : Décodeur discret des 5 capteurs.

