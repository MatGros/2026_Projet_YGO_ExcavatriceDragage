# FB_Winch — fiche composant cible (v2.0, T181)

> Statut : **cadrage cible, non implémenté — visa humain requis**.  
> Source normative de cette fiche : `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T181-06_DRIVEREQUEST.md` et `AF10_INTERFACE_TREUIL_CIBLE_T181.md`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface cible
3. Composition et limites de responsabilité
4. Contrats d'intégration
5. Validation
6. Historique

## 1. Rôle et profil

`FB_Winch` est un FB de mouvement générique, instancié pour M1 retenue et M2 benne. Il transforme une demande déjà arbitrée et bornée en relais directionnels et contacteurs par paliers. Précédence : `Enable > SafeStop > StartStop` ; aucun redémarrage automatique après défaut.

Il ne choisit jamais le producteur, le mode ou la synchronisation. Ces responsabilités restent `PRG_04`; la sécurité paire reste `FB_Safety_Winch`.

## 2. Interface cible

<table>
<thead><tr><th>Port</th><th>Type</th><th>Responsabilité</th></tr></thead>
<tbody>
<tr><td>IN</td><td><code>Enable, Reset, PowerContactorEngaged</code></td><td>profil mouvement</td></tr>
<tr><td>IN</td><td><code>DriveRequest : ST_fbWinch_DriveRequest</code></td><td>ordre, palier, bornes et limites effectives</td></tr>
<tr><td>IN</td><td><code>Sensors : ST_fbWinch_Sensors</code></td><td>position, référencement, contacteurs, vitesse m/s</td></tr>
<tr><td>IN</td><td><code>Config : ST_fbWinch_Cfg</code></td><td>configuration statique seulement</td></tr>
<tr><td>IN</td><td><code>SafeStop, PermitUp, PermitDown</code></td><td>sorties déjà arbitrées de <code>FB_Safety_Winch</code></td></tr>
<tr><td>OUT</td><td><code>RelayFwd_Up, RelayRev_Down, Contactor1..4</code></td><td>commandes envoyées à la barrière finale</td></tr>
<tr><td>OUT</td><td><code>SpeedStepReq_Decoded, StepNumber, StepRampElapsed</code></td><td>cible clampée et palier temporisé</td></tr>
<tr><td>OUT</td><td><code>ContactorsCheck, Fault, Ready</code></td><td>diagnostic ; <code>ContactorStuck</code> publié mais produit par Safety</td></tr>
</tbody></table>

Les DUT et chaque champ sont définis dans le cadrage T181-06 §2. `SyncCoupled` est diag-only : une revue/garde interdit sa lecture logique dans ce FB.

## 3. Composition et limites de responsabilité

| Élément | Règle cible |
|---|---|
| `FB_SpeedStep` | applique le plafond puis `LIMIT(1, MinStepNumber, MaxStepClamped)` ; `MinStepNumber` modifie `RequestedStep`, pas `StepNumber` |
| Interlock direction | front montant `Enable` armé avec temps mort ; ne pas capturer une direction au premier scan |
| Rampe palier | extrait en `FB_WinchStepShaper` (IN TargetStep/StepRampDelay -> OUT ShapedStep), cadence dédiée, découple D10 |
| `FB_WinchRateInterlock` | gouverne en nominal ; seuils locaux safety+marge |
| `FB_Safety_Winch` | propriétaire unique de la détection `ContactorStuck`, SafeStop et permis |
| `PRG_04` | producteur unique de `DriveRequest`, sync, clamp commun et branche M2-only |

`TopLimitM`/`BottomLimitM` sont des données du cycle dans `DriveRequest`, pas de la configuration. La mesure vitesse est `MeasuredSpeedMps`, pas une bande entière.

## 4. Contrats d'intégration

- Cycle, joystick, IHM et benne restent arbitrés dans `PRG_04 §3`.
- `FB_DiveSearch → PRG_03 → PRG_04 → MinStepDown` est intra-cycle MainTask 10 ms et s'annule avec `DescentActive` ou `StartStop=FALSE`.
- `SyncDeviationWarn` plafonne M1 et M2 ; `FB_Winch_Symmetry` est passif et hors interface.
- Le jog benne utilise `BucketJogStep : INT` (palier, défaut 1) et son plafond est M2-only. Le `15.0` % codé en dur (`PRG_04:288`) est retiré (grep `15.0` = 0 après T181-10) — le jog est un **palier**, jamais un % (P1).
- **D13 (tranché T181-06)** : la reconstruction de table `M2_SpeedStepTableActive` (`PRG_04:405-429`) est **supprimée** — le clamp unifié (`M2_BucketJogLimit` → `MaxStepUp/Down := 1`) suffit, appliqué aux deux sens.
- `PRG_04` produit `ST_WinchFinalInterlockReq`; `PRG_06` reste la barrière finale.

## 5. Validation attendue

| Preuve | Objet |
|---|---|
| <nobr><code>TC-P10-011</code></nobr>, <nobr><code>TC-P10-017</code></nobr>, <nobr><code>TC-P10-018</code></nobr>, <nobr><code>TC-P10-019</code></nobr> | sens, configuration, contacteur collé et ordre programme |
| TC clamp dédié | plafond gagne sur plancher : 3 + 1 → 1 |
| HARN-T181 paire | Grafcet, joystick, plongée, régression M1/M2, sync et interlocks |
| garde revue | `FB_Winch` ne lit jamais `SyncCoupled` |
| G200 + bundle + gates | liaison et non-régression après phase d'implémentation |

Ces preuves ne valent pas qualification terrain : l'import CODESYS et les seuils de cadence nécessitent un essai site signé.

## 6. Historique

| Version | Date | Changement |
|---|---|---|
| v2.0 | 2026-08-29 | Fiche cible T181-06 : interface struct, palier discret, clamp par instance et arrêt visa humain. |
| v2.0 (additif) | 2026-08-29 | Décisions T181-06 intégrées : D13 (suppression `M2_SpeedStepTableActive`), jog benne = palier `BucketJogStep` (retrait du `15.0` %), clamp M2-only. |
| v1.0 | antérieure | Interface actuelle, conservée comme référence historique jusqu'à implémentation validée. |
