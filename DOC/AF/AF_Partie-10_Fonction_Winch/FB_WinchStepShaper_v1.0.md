# FB_WinchStepShaper — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-10_Fonction_Winch_v2.1.md`](../AF_Partie-10_Fonction_Winch_v2.1.md) §5 — couvre `F10.05` & `F10.06`.
> Rôle de **ce** document : cadencement de montée de palier, asymétrie de décélération, défense en profondeur (plancher dur interlock) et **détail complet** des `TC-P10-SHAPER-*`.
> Source code : [`CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st`](../../../../CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st) · sous-instance de `FB_Winch` (M1/M2).

---

## 🧭 Sommaire

1. [🎯 Périmètre et composition](#1-périmètre-et-composition)
2. [🧪 Table des points de validation (détail)](#2-table-des-points-de-validation-détail)
3. [🔌 Contrats d'interface](#3-contrats-dinterface)
4. [⚙️ Comportement et séquence](#4-comportement-et-séquence)
5. [🛡️ Défense en profondeur (plancher dur interlock)](#5-défense-en-profondeur-plancher-dur-interlock)
6. [🔗 Intégration programme](#6-intégration-programme)
7. [🖥️ IHM et diagnostics](#7-ihm-et-diagnostics)
8. [🧬 Simulation](#8-simulation)
9. [📜 Suivi historique](#9-suivi-historique)
10. [📚 Documents liés](#10-documents-liés)

---

## 1 · 🎯 Périmètre et composition

### Responsabilité

Répond au besoin fonctionnel `F10.05`-`F10.06` (AF10 §5) : transforme une consigne brute de palier (`TargetStep` 0..5) en consigne temporisée (`ShapedStep` 0..5).
Il protège l'appareillage électromécanique (moteurs à bagues, contacteurs de résistances rotoriques) contre l'enclenchement instantané et simultané des contacteurs de puissance.

### Principes Clés :
- 🚀 **Départ Immédiat $0 \rightarrow 1$** : Le palier 1 (résistances rotoriques max, aucun contacteur de vitesse fermé) s'établit dès le premier scan pour libérer immédiatement le frein et la direction.
- 🪜 **Montée Cadencée ($1 \rightarrow 2 \rightarrow 3 \rightarrow 4 \rightarrow 5$)** : Progression cadencée à $+1\text{ cran} / \text{StepRampDelay}$ ($1000\text{ ms}$ en montée, $500\text{ ms}$ en descente).
- 🎚️ **Descente Asymétrique Immédiate** : Toute réduction de palier ($5 \rightarrow 2$, $5 \rightarrow 0$) est appliquée immédiatement au scan courant pour garantir la réactivité d'arrêt et de décélération.

---

## 2 · 🧪 Table des points de validation (détail)

> Décline la table des tests d'échelonnement et de cadencement vitesse de `FB_WinchStepShaper`.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-SHAPER-01</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Montée</b><br>1000 ms</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0 (Repos)</b> : <code>Enable=TRUE</code>, <code>TargetStep=0</code>, <code>ShapedStep=0</code>, <code>StepDelay.Q=FALSE</code>.<br>
        🚀 <b>Étape 1 (Départ immédiat Palier 1)</b> : Injection consigne <code>TargetStep=5</code>, <code>StepRampDelay=T#1000ms</code> ➔ Au scan 0 exact ($t=0\text{ ms}$), <code>ShapedStep=1</code> immédiatement (aucun contacteur vitesse, frein/sens autorisés).<br>
        ⏱️ <b>Étape 2 (Attente P1➔P2)</b> : À $t=500\text{ ms}$, <code>StepDelayElapsed=500ms</code>, <code>ShapedStep=1</code>.<br>
        ⚡ <b>Étape 3 (Franchissement P2)</b> : À $t=1000\text{ ms}$, <code>StepDelay.Q=TRUE</code> ➔ <code>ShapedStep=2</code>.<br>
        🔄 <b>Étape 4 (Réarmement timer)</b> : Au scan suivant ($t=1010\text{ ms}$), <code>NOT StepDelay.Q</code> réarme le timer <code>TON</code>, <code>StepDelayElapsed=0ms</code>.<br>
        ⚡ <b>Étape 5 (Paliers P3..P5)</b> : Passage <code>ShapedStep=3</code> à $t=2000\text{ ms}$, <code>ShapedStep=4</code> à $t=3000\text{ ms}$, <code>ShapedStep=5</code> à $t=4000\text{ ms}$ exacts.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.1</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-SHAPER-02</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Descente</b><br>500 ms</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        🚀 <b>Étape 1 (Départ Palier 1)</b> : <code>TargetStep=5</code>, <code>StepRampDelay=T#500ms</code> (sens descente) ➔ <code>ShapedStep=1</code> à $t=0\text{ ms}$.<br>
        ⚡ <b>Étape 2 (Cadence rapide 500 ms)</b> : <code>ShapedStep=2</code> à $t=500\text{ ms}$, <code>ShapedStep=3</code> à $t=1000\text{ ms}$, <code>ShapedStep=4</code> à $t=1500\text{ ms}$, <code>ShapedStep=5</code> à $t=2000\text{ ms}$ exacts.<br>
        ✅ <b>Étape 3 (Contrôle dynamique)</b> : Temps total d'établissement = $2.0\text{ s}$ (2× plus vif que la montée pour descente benne).
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P10-SHAPER-03</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Asymétrie</b><br>Arrêt direct</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚡ <b>Étape 1 (Régime établi P5)</b> : <code>TargetStep=5</code>, <code>ShapedStep=5</code>.<br>
        🛑 <b>Étape 2 (Chute partielle)</b> : Réduction consigne <code>TargetStep:=2</code> ➔ Au scan 0 exact, <code>ShapedStep:=2</code> immédiatement sans aucune temporisation.<br>
        ⛔ <b>Étape 3 (Arrêt franc)</b> : Annulation consigne <code>TargetStep:=0</code> ➔ Au scan 0 exact, <code>ShapedStep:=0</code>, <code>StepDelay(IN:=FALSE)</code> remis à zéro.
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4.3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11px; font-weight: bold;">TC-P10-SHAPER-04</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Rejet hors</b><br>plage</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚠️ <b>Étape 1 (Consigne négative)</b> : Injection <code>TargetStep:=-3</code> ➔ <code>ShapedStep=0</code> (aucun palier négatif).<br>
        ⚠️ <b>Étape 2 (Consigne supérieure à 5)</b> : Injection <code>TargetStep:=9</code> ➔ Plafonnement strict à <code>ShapedStep=5</code> après écoulement de la rampe nominale.<br>
        🔒 <b>Étape 3 (Coupure Enable)</b> : <code>Enable:=FALSE</code> en pleine rampe ➔ Forçage immédiat <code>ShapedStep=0</code> et <code>StepDelay(IN:=FALSE)</code>.
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
FUNCTION_BLOCK PUBLIC FB_WinchStepShaper
VAR_INPUT
    Enable        : BOOL;   // --> [CMD] Autorisation générale FB (TRUE = actif, FALSE = forçage ShapedStep=0)
    TargetStep    : INT;    // --> [CMD] Palier cible demandé (0..5)
    StepRampDelay : TIME;   // --> [CFG] Délai de cadence montée de palier (1000ms montée / 500ms descente)
END_VAR
VAR_OUTPUT
    ShapedStep       : INT;   // <-- [DIAG] Palier métier temporisé actif (0..5)
    StepDelayElapsed : TIME;  // <-- [DIAG] Écoulé temporisation montée de palier courante
END_VAR
VAR
    StepDelay : TON;          // . [LOC] Temporisation montée de palier
END_VAR
```

---

## 4 · ⚙️ Comportement et séquence

### Équations Logiques & Machine d'Échelonnement :

```pascal
// Échelonnement conditionné et réarmement inter-crans
StepDelay(IN := (TargetStep > ShapedStep) AND (ShapedStep > 0) AND NOT StepDelay.Q,
          PT := StepRampDelay);
StepDelayElapsed := StepDelay.ET;

IF NOT Enable THEN
    ShapedStep := 0;
ELSIF TargetStep = 0 THEN
    ShapedStep := 0;
ELSIF TargetStep < ShapedStep THEN
    ShapedStep := TargetStep;                        // Descente : immédiate
ELSIF ShapedStep = 0 THEN
    ShapedStep := 1;                                 // 1er cran : immédiat
ELSIF StepDelay.Q THEN
    ShapedStep := MIN(5, ShapedStep + 1);            // +1 cran par temporisation
END_IF;
```

---

## 5 · 🛡️ Défense en profondeur (plancher dur interlock)

En aval de `FB_WinchStepShaper`, la barrière de sécurité finale [`FB_WinchOutputInterlock`](FB_WinchOutputInterlock_v1.0.md) implémente une garde plancher matérielle :
- **Constante** : `CST_StepRampFloorDelay : TIME := T#700ms;`.
- **Règle de filtrage** : $\text{Contactor}_N := \text{RequestedContactor}_N \text{ AND } (\text{AuthorizedStep} \ge N+1)$.
- Si `StepRampDelay` venait à être écrasé à $0\text{ ms}$ (défaillance logicielle amont), l'interlock bride physiquement la fermeture des contacteurs de vitesse à $1\text{ contacteur} / 700\text{ ms}$.

---

## 6 · 🔗 Intégration programme (architecture cible)

- **POU Appelant** : `PRG_04_Treuils_Benne` (intégré dans l'instance `instWinchM1` et `instWinchM2`).
- **Tâche d'exécution** : `Task_PRG_04` (périodicité 20 ms).

---

## 7 · 🖥️ IHM et diagnostics

- **Affichage IHM** : `GVL_IHM.M1Treuil.StepAct` / `M2Treuil.StepAct` reflète directement `ShapedStep`.
- **Monitoring** : La barre de progression vitesse suit les transitions franches $1 \rightarrow 2 \rightarrow 3 \rightarrow 4 \rightarrow 5$.

---

## 8 · 🧬 Simulation

En mode simulation numérique (`FB_SimWinch`), la réponse cinématique simule les crans de résistances rotoriques en accord avec le timing de `ShapedStep`.

---

## 9 · 📜 Suivi historique

| Version | Date | Auteur | Changements majeurs |
|---|---|---|---|
| `v1.0` | 2026-09-02 | Ingénierie MES / Antigravity | Création formelle, alignement template standard AF-01 v1.4, formalisation TC-P10-SHAPER-01..04. |

---

## 10 · 📚 Documents liés

- [`AF_Partie-10_Fonction_Winch_v2.1.md`](../AF_Partie-10_Fonction_Winch_v2.1.md) : Spécification macro treuils.
- [`FB_WinchOutputInterlock_v1.0.md`](FB_WinchOutputInterlock_v1.0.md) : Barrière de sécurité et plancher dur aval.
