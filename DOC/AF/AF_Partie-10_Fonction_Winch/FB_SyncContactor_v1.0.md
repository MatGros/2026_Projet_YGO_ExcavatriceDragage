# FB_SyncContactor — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-10_Fonction_Winch_v2.1.md`](../AF_Partie-10_Fonction_Winch_v2.1.md) §4 & [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md).
> Rôle de **ce** document : détection de discordance commandes/contacteurs M1/M2, réponse graduée (SafeStop -> PowerCutOff bit 13) et **détail complet** des `TC-P10-SYNC-*`.
> Source code : [`CODE/H_TREUILS_BENNE/FB_SyncContactor.st`](../../../../CODE/H_TREUILS_BENNE/FB_SyncContactor.st) · instances dans `FB_WinchSync` et `PRG_06_Outputs`.

---

## 🧭 Sommaire

1. [🎯 Périmètre et composition](#1-périmètre-et-composition)
2. [🧪 Table des points de validation (détail)](#2-table-des-points-de-validation-détail)
3. [🔌 Contrats d'interface](#3-contrats-dinterface)
4. [⚙️ Comportement et réponse graduée](#4-comportement-et-réponse-graduée)
5. [🔗 Intégration programme](#5-intégration-programme)
6. [🖥️ IHM et diagnostics](#6-ihm-et-diagnostics)
7. [🧬 Simulation](#7-simulation)
8. [📜 Suivi historique](#8-suivi-historique)
9. [📚 Documents liés](#9-documents-liés)

---

## 1 · 🎯 Périmètre et composition

### Responsabilité

Le bloc `FB_SyncContactor` surveille la stricte symétrie des ordres de commande et retours contacteurs entre les treuils M1 et M2.
Indépendant des codeurs rotatifs, il détecte les collages de contacteur, défaillances de bobines ou dérives logiques asymétriques en amont des mouvements mécaniques.

### Principes Clés :
- 🔍 **Surveillance Transverse** : Comparaison directionnelle (relais montée/descente) et vitesse (contacteurs 1 à 4).
- ⚖️ **Condition d'Activation** : Active dès que les 2 treuils sont commandés (`BothCommanded`) OU que le synchronisme est requis (`SyncEnable`).
- 🛑 **Réponse Graduée en 2 Niveaux** :
  - **Niveau 1 (SafeStop)** : Discordance confirmée après debounce $500\text{ ms}$ ➔ arrêt rapide sans coupure puissance.
  - **Niveau 2 (PowerCutOff)** : Discordance persistante au-delà de $3\text{ s}$ ➔ escalade coupure d'urgence générale (bit 13).

---

## 2 · 🧪 Table des points de validation (détail)

> Décline la table des tests de concordance contacteurs et réponse graduée de `FB_SyncContactor`.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-SYNC-01</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Discordance</b><br>Niveau 1</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0 (Régime symétrique)</b> : M1 et M2 en montée Palier 2 (<code>RelayFwdM1=RelayFwdM2=TRUE</code>, <code>Contactor1_M1=Contactor1_M2=TRUE</code>), <code>ContactorMismatch=FALSE</code>, <code>Diag.MismatchLevel=0</code>.<br>
        🚀 <b>Étape 1 (Apparition discordance)</b> : M1 passe en Palier 3 (<code>Contactor2_M1=TRUE</code>) alors que M2 reste en Palier 2 (<code>Contactor2_M2=FALSE</code>) ➔ <code>Diag.Step2Mismatch=TRUE</code>, <code>MismatchActive=TRUE</code>.<br>
        ⏱️ <b>Étape 2 (Filtrage transitoire 500 ms)</b> : À $t=250\text{ ms}$, <code>MismatchTimer.ET=250ms</code>, <code>ContactorMismatch=FALSE</code> (aucun arrêt sur transitoire).<br>
        ⚡ <b>Étape 3 (Déclenchement SafeStop)</b> : À $t=500\text{ ms}$, <code>MismatchTimer.Q=TRUE</code> ➔ <code>ContactorMismatch=TRUE</code>, <code>Diag.MismatchLevel=1</code> (déclenchement SafeStop amont sans coupure AU).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.1</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-SYNC-02</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Escalade</b><br>Niveau 2</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚡ <b>Étape 1 (Niveau 1 actif)</b> : <code>ContactorMismatch=TRUE</code> établi depuis $t=500\text{ ms}$, <code>EscalationTimer</code> armé (PT = 3000 ms).<br>
        ⏱️ <b>Étape 2 (Persistance discordance)</b> : Maintien de l'asymétrie sans rétablissement pendant 3.0 s supplémentaires.<br>
        🚨 <b>Étape 3 (Escalade PowerCutOff)</b> : À $t=3500\text{ ms}$ total, <code>EscalationTimer.Q=TRUE</code> ➔ <code>ContactorMismatchEscalated=TRUE</code>, <code>Diag.MismatchLevel=2</code> (escalade bit 13 <code>MecaEEscaladeFaultLatched</code>, chute immédiate AU).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P10-SYNC-03</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Jog unitaire</b><br>Inhibition</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        🔧 <b>Étape 1 (Sélection unitaire M1)</b> : Mode Maintenance N2 ou jog M1 seul (<code>SyncEnable=FALSE</code>, M1 commandé <code>RelayFwdM1=TRUE</code>, M2 au repos <code>RelayFwdM2=FALSE</code>).<br>
        ✅ <b>Étape 2 (Vérification neutralisation)</b> : <code>BothCommanded=FALSE</code> ➔ <code>MismatchActive=FALSE</code>, <code>ContactorMismatch=FALSE</code>.<br>
        🔓 <b>Étape 3 (Mouvement libre M1)</b> : M1 monte librement tous paliers sans générer d'alarme de synchronisme pour permettre le recalage mécanique.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P10-SYNC-04</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Bypass</b><br>Global</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        🛠️ <b>Étape 1 (Activation bypass banc)</b> : <code>BypassGlobal:=TRUE</code>.<br>
        ⚡ <b>Étape 2 (Injection discordance totale)</b> : M1 en montée P5, M2 en descente P1.<br>
        ✅ <b>Étape 3 (Neutralisation immédiate)</b> : Sorties forcées <code>ContactorMismatch=FALSE</code>, <code>ContactorMismatchEscalated=FALSE</code>, <code>Diag.MismatchLevel=0</code>.
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
FUNCTION_BLOCK PUBLIC FB_SyncContactor
VAR_INPUT
    Enable                          : BOOL;                           // --> [CMD] Validation surveillance globale
    Reset                           : BOOL;                           // --> [CMD] Acquittement défaut sur front
    SyncEnable                      : BOOL;                           // --> [CMD] Autorisation utilisateur synchro
    RelayFwdM1, RelayFwdM2          : BOOL;                           // --> [HW] Ordre/retour montée M1/M2
    RelayRevM1, RelayRevM2          : BOOL;                           // --> [HW] Ordre/retour descente M1/M2
    Contactor1_M1..4_M1             : BOOL;                           // --> [HW] Contacteurs paliers 1..4 M1
    Contactor1_M2..4_M2             : BOOL;                           // --> [HW] Contacteurs paliers 1..4 M2
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Neutralisation pour essais banc
END_VAR
VAR_OUTPUT
    ContactorMismatch               : BOOL;                           // <-- [SAFE] Niveau 1 (SafeStop après 500ms)
    ContactorMismatchEscalated      : BOOL;                           // <-- [SAFE] Niveau 2 (PowerCutOff après 3s)
    Diag                            : ST_SyncContactorDiag;           // <-- [DIAG] Détail des contacteurs divergents + MismatchLevel
END_VAR
VAR CONSTANT
    MismatchDebounce                : TIME := T#500ms;                // Filtre transitoires/rampes avant confirmation Niveau 1
    CST_SyncEscalationTime          : TIME := T#3s;                   // Persistance discordance avant escalade Niveau 2
END_VAR
```

---

## 4 · ⚙️ Comportement et réponse graduée

```text
[Discordance Commandes/Contacteurs M1 <> M2]
                     │
                     ▼ (MismatchDebounce = 500 ms)
[Niveau 1 : ContactorMismatch = TRUE] ➔ SafeStop Treuils (Mouvement bloqué, PUISSANCE MAINTENUE)
                     │
                     ▼ (CST_SyncEscalationTime = 3000 ms)
[Niveau 2 : ContactorMismatchEscalated = TRUE] ➔ Escalade PowerCutOff (Chute générale AU, bit 13)
```

---

## 5 · 🔗 Intégration programme

- **Instances** :
  - `instSyncContactorLogic` dans `FB_WinchSync` (comparaison des demandes amont).
  - `instSyncContactorFinal` dans `PRG_06_Outputs` (comparaison des vecteurs de sorties physiques finales).

---

## 6 · 🖥️ IHM et diagnostics

- **Structure `Diag : ST_SyncContactorDiag`** :
  - `RelayFwdMismatch`, `RelayRevMismatch` : drapeaux booléens de sens.
  - `Step1Mismatch` à `Step4Mismatch` : drapeaux booléens de contacteurs vitesse.
  - `MismatchLevel` : `0` = Sain, `1` = SafeStop, `2` = PowerCutOff.
- **Message Bandeau** : `[M1/M2] Discordance contacteurs vitesse (K2)` orientant la maintenance.

---

## 7 · 🧬 Simulation

En simulation, le bloc vérifie l'absence de divergence lors des rampes simulées de `FB_SimWinch` M1 et M2.

---

## 8 · 📜 Suivi historique

| Version | Date | Auteur | Changements majeurs |
|---|---|---|---|
| `v1.0` | 2026-09-02 | Ingénierie MES / Antigravity | Création formelle, alignement template standard AF-01 v1.4, formalisation TC-P10-SYNC-01..04. |

---

## 9 · 📚 Documents liés

- [`AF_Partie-10_Fonction_Winch_v2.1.md`](../AF_Partie-10_Fonction_Winch_v2.1.md) : Spécification macro treuils.
- [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md) : Contrats d'interfaces.
