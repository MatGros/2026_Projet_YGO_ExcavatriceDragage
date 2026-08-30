# Analyse Fonctionnelle - Partie 5 : Modes & Maintenance (v2.1)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🎯 Rôle et périmètre

- **Rôle** : définir les modes machine, les droits et les arbitrages de source.
- **Périmètre** : `E_Mode`, bus `Auth : ST_fbModes_Autorisations`, sélection de commande,
  limite légale. Les sorties physiques et la chaîne AU restent hors de ce document (Parties 01/06).
- **Type de composant** : `FB_Modes` (contrat AF03 `standard`) — Transverse.

## 📑 Sommaire

1. [🧪 Table des points de validation](#1-table-des-points-de-validation)
2. [🎚️ Modes machine](#2-modes-machine)
3. [🧩 Fonctions et petits cycles](#3-fonctions-et-petits-cycles)
4. [🎮 Sélection de commande](#4-sélection-de-commande)
4bis. [🛡️ Matrice de bypass maintenance — treuils M1/M2](#4bis-matrice-de-bypass-maintenance--treuils-m1m2)
5. [📐 Bus d'autorisations](#5-bus-dautorisations)
6. [📏 Limite légale](#6-limite-légale)
7. [🛡️ Défauts et reprise](#7-défauts-et-reprise)
8. [📜 Suivi historique](#8-suivi-historique)
9. [❓ TBD](#9-tbd)
10. [📚 Documents liés](#10-documents-liés)

## 🧪 1 · Table des points de validation

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 28px;">
    <col style="width: 50px;">
    <col style="width: calc(100% - 165px);">
    <col style="width: 45px;">
    <col style="width: 26px;">
    <col style="width: 36px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Intention</small></th>
      <th style="padding: 4px 8px;">Séquence &amp; Déroulé des étapes (Comportement attendu)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-001</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Modes machine restreints (<code>DISABLE</code>, <code>MAINT_N1</code>, <code>MAINT_N2</code>, <code>SEMI_AUTO</code>)</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SyncEnable</code>, Diving, Extraction hors <code>E_Mode</code></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2-3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-002</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Mode nominal : joystick pilote M1+M2 conjointement</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">M1 et M2 reçoivent la même intention</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-003</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Mode MAINT_N2 M1 seul : M2 bloqué, frein serré</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Safety reste active sur M2</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-004</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Refus mode SEMI_AUTO si codeurs invalides</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Bascule refusée + message IHM</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§7</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-005</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Limite légale = blocage exploitation, pas safety</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Pas de <code>PowerCutOff</code> sur simple limite légale</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§6</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P05-006</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Pas de redémarrage automatique après défaut</b></small></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Reset</code> + nouvel ordre explicite requis</td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§7</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 🎚️ 2 · Modes machine

> ⚠️ **« Manuel » n'est pas une valeur `E_Mode`** : `E_Mode` (`CODE/F_MODES/E_Mode.st`) ne compte
> que 4 valeurs — `DISABLE`, `MAINT_N1`, `MAINT_N2`, `SEMI_AUTO`. « Manuel » est un terme
> descriptif du **pilotage direct** offert par `MAINT_N1`/`MAINT_N2` (voir commentaires du code
> source : « Manuel Niveau 1 », « Manuel Niveau 2 »), pas un 5e mode distinct — corrigé le
> 2026-08-25, la table listait auparavant « Manuel » comme une entrée séparée.

| Mode | Role |
|---|---|
| ⛔ DISABLE | Désactivé / veille de sécurité, sorties bloquées. |
| 🔧 MAINT_N1 | Manuel niveau 1 : pilotage unitaire, toutes sécurités actives. |
| 🛠️ MAINT_N2 | Manuel niveau 2 : pilotage dégradé, droits étendus et bypasses conscients autorisés. |
| 🔄 SEMI_AUTO | Cycle séquencé ; mouvements toujours conditionnés par l'opérateur. |

`FB_Modes` / `PRG_MODES_CFC` (POU ST actuel ; cible `PRG_03_Modes_Cycle_CFC`, rang 03) arbitre :

- le mode actif ;
- le bus d'autorisations `Auth : ST_fbModes_Autorisations` (mode arbitré, SyncEnable, InhibitM1/2, sélection joystick, homing approach, cible maintenance).

Il ne produit aucune sortie physique.

⚠️ **Les Modes distribuent des autorisations, ils ne portent pas les interdictions metier.** Une
interdiction est portee par le procede qui la **subit** : interdire M3 selon un etat benne est une
regle de `PRG_05_Translation_CFC`, pas des Modes. Chaque commande metier recoit l'autorisation ou
non, et decide localement. Voir `AF_Partie-02` §2.

---

## 🧩 3 · Fonctions et petits cycles

Ces elements ne sont **pas** des modes machine.

| Element | Nature | Role |
|---|---|---|
| ⚖️ `SyncEnable` | Fonction / autorisation | Active la logique de synchronisation M1/M2. |
| 🌊 Diving | Petit cycle ST | Plongee et recherche de fond Kobold. |
| ⛏️ Extraction | Petit cycle ST | Fermeture benne et montee de controle. |

Diving et Extraction sont utilisables en maintenance et reutilises par le cycle semi-auto.

---

## 🎮 4 · Sélection de commande

### Nominal

- Le joystick pilote M1 et M2 ensemble.
- Les demandes restent maintenues : bouton/joystick + homme-mort.

### MAINT_N2 — pilotage unitaire

- Une selection explicite autorise M1 seul ou M2 seul.
- Le treuil non selectionne reste **non commande**.
- Frein serre, surveillances safety **actives**.
- Ce n'est **pas** une inhibition complete du FB safety.

### Inhibition

- L'inhibition d'un treuil est une action de maintenance distincte.
- Elle neutralise le mouvement de l'axe concerne et impose les consequences de synchro.
- Elle est pilotée via `Auth.InhibitM1/2` (bus `Auth : ST_fbModes_Autorisations`).
- Matrice complete des bypass : **§4bis** (treuils M1/M2, T181-11).

> 📌 **Authentification** : gérée côté IHM (visibilité des actions selon niveau utilisateur).
> L'automate reçoit uniquement le mode arbitré (`MAINT_N1` / `MAINT_N2` / `SEMI_AUTO`).
> Aucun garde-fou mot de passe côté PLC — `FB_Modes` accepte `SelMode` tel quel.

---

## 🛡️ 4bis · Matrice de bypass maintenance — treuils M1/M2

> **Source** : cadrage T181-11 (`DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T181-11_MATRICE_MAINT.md`), décision Q8 du plan de gel T181. Implémentation : T181-14.

### Principe

Un bypass de sécurité n'est **effectif que si `Mode = MAINT_N2`** (doctrine `ST_BypassWinch` /
`ST_BypassCommun` / `ST_BypassBucket`). Un bypass IHM activé hors N2 est **ignoré** (affiché
« inactif — passer en N2 »). Exception unique : l'**override FDC haut logiciel** est possible en
`MAINT_N1` via un **bouton maintenu** (momentané), borné par le capteur physique haut (≈ 8,5 m),
jamais franchi.

```
bypass_effectif := bypass_IHM AND (Mode = MAINT_N2)   (* pour tous les bypass, sauf override FDC N1 *)
```

### Matrice mode × bypass

| Famille | Bypass | N1 | N2 | Latence |
|---|---|---|---|---|
| Communication & aux. | `OperatorComm`, `EncoderFault`, `PhaseRotation`, `BrakeThermal`, `MotorThermal`, `ContactorFeedback` | ❌ | ✅ | latché (RETAIN) |
| Limites position | `TopLimitSwitch`, `CableLimitSwitch`, `LimitLegal`, `SlackCable` | ❌ | ✅ | latché |
| Limites position | `TopLimitSoftware` | ⚠️ momentané (bouton tenu) | ✅ | N1 : tant que tenu · N2 : latché |
| Méca A-E | `MecaA`, `MecaC`, `MecaD`, `MecaE` | ❌ | ✅ | latché |
| Méca A-E | `MecaB` | ❌ | ✅ | latché + bandeau d'avertissement fort |
| Groupés | `Safety`, `Process`, `Global` (axe / commun / benne) | ❌ | ✅ | latché (RETAIN) — **conservés** (homogène projet, idem translation M3) |

> **Total : 25 bascules** (18 axe `ST_BypassWinch` + 6 commun `ST_BypassCommun` + 1 benne
> `ST_BypassBucket`), toutes RETAIN, toutes mode-gated sur `MAINT_N2`. Aucun retrait de DUT
> (aucun impact IHM/SCADA). `MecaB` et `LimitLegal` restent bypassables en N2 (homogène) ; la
> traçabilité est assurée par le RETAIN + le journal de bypass existant.

### Override FDC haut logiciel (décision Q8)

| Contexte | `TopLimitM` (calculé `PRG_04`) | Butée physique |
|---|---|---|
| Fonctionnement normal (SEMI_AUTO, N1 sans override, N2 sans override) | **7,5 m** (`CfgCableLimitAscent_M`) | capteur `TopPositionSensor` ≈ 8,5 m (jamais atteint en nominal) |
| **N1 + bouton IHM « autoriser dépassement FDC » MAINTENU** | **8,5 m** (borne physique = capteur homing haut) | capteur `TopPositionSensor` — **jamais dépassé** (`BypassTopLimitSwitch` reste FALSE) |
| **N2 + bypass `TopLimitSoftware` latché** | 8,5 m | capteur `TopPositionSensor` (sauf si `TopLimitSwitch` aussi bypassé — acte N2 séparé) |

- **N1 momentané** : `OverrideTopSoftwareN1 := (Mode = MAINT_N1) AND GVL_IHM.<axe>.Cmd.BtnOverrideTopSoftware` (bouton, pas toggle). Relâche → `TopLimitM` **repasse à 7,5 m au cycle suivant**, le FDC logiciel redevient actif immédiatement.
- **La butée physique 8,5 m n'est jamais franchie en N1** : `BypassTopLimitSwitch` n'est **pas** ouvert par cet override. Si le capteur `TopPositionSensor` retombe, `AscentPermit` tombe (`FB_Safety_Winch.st:382-383`) → arrêt matériel.
- **N2 latché** : `TopLimitSoftware` classique, RETAIN, débit assumé jusqu'à sortie de N2.

### Bascule de mode

**Passage en / hors `MAINT_N1` ou `MAINT_N2` refusé tant que le treuil n'est pas à l'arrêt mécanique confirmé** — même composite que l'armement Méca B (`FB_Safety_Winch.st:247`) :

```
BasculeModeAutorisee := FwdRevSpeedFeedbackOff AND NOT BrakeFeedback
                        (* contacteurs retombés ET frein serré *)
                        AND (ABS(MeasuredSpeedMps) < MovementSpeedThresholdMps)   (* redondance mesure *)
```

- Tant que faux : `FB_Modes` maintient le mode courant, remonte `ModeChangePendingBlocked` à l'IHM (« arrêter le treuil avant de changer de mode »).
- S'applique aux **deux sens** (entrer et sortir de N1/N2).
- Décision et calcul dans **`FB_Modes`** (arbitrage de mode), pas dans `PRG_04`.

### Re-homing obligatoire

Après **toute** sortie d'un mode maintenance qui a **effectivement** utilisé :
- l'override FDC N1 momentané (`OverrideTopSoftwareN1` a été vrai au moins un cycle), **ou**
- un bypass de la famille position (`TopLimitSwitch`, `TopLimitSoftware`, `CableLimitSwitch`, `LimitLegal`, `MecaD`) latché en N2,

→ le treuil concerné est marqué `HomingRequired := TRUE` (drapeau persistant par axe).
- Tant que `HomingRequired` : SEMI_AUTO **interdit** pour cet axe (`FB_Modes` bloque l'arbitrage), N1 autorisé pour manœuvrer, `HomingSuspect` forcé côté diag.
- `HomingRequired` retombe uniquement sur **cycle de homing complet réussi** (`EncoderMx.HomingLifecycle.Done` + `Homed AND NOT HomingSuspect`).
- Raison : un dépassement des limites de position invalide la confiance dans `CablePosM` — la re-référence est la seule remise à zéro sûre.

### Référencement benne guidé (T184)

T175 AC4 : *« FB_Bucket confirme/ouvre sous MAINT_N1 ET N2 comme décrit (TC-P10-030), ou la fiche est corrigée MAINT_N2 seul — décision tracée »*.

**Décision T184 : MAINT_N2 seul pour confirmer la position visuelle de benne.** Cette confirmation n'est pas une commande d'ouverture/fermeture : elle engage une référence géométrique commune M1/M2/benne.

- Préconditions cumulatives : `MAINT_N2`, capteur haut commun actif, M1 et M2 arrêtés mécaniquement (contacteurs relâchés, freins serrés, vitesse sous seuil).
- L'opérateur choisit **Ouverte** ou **Fermée** selon ce qu'il voit ; l'état n'est jamais imposé par le PLC.
- `FB_ReferenceCycle` demande le homing conjoint M1/M2. `FB_Bucket` reste l'unique propriétaire de `IsOpen`/`IsClosed` et ne les commit qu'après les deux succès.
- `SEMI_AUTO` est refusé tant que `MachineReferenceReady = FALSE` ; `MAINT_N2` conserve les actions de récupération autorisées.
- Si une référence valide est perdue pendant le mouvement : `SafeStop` contrôlé, puis retour au guide de référence. Aucun redémarrage automatique.

---

## 📐 5 · Bus d'autorisations

`FB_Modes` (via `PRG_MODES_CFC` actuel, `PRG_03_Modes_Cycle_CFC` en cible) produit le bus typé `Auth : ST_fbModes_Autorisations` :

| Champ | Rôle |
|---|---|
| `Mode` | Mode arbitré (DISABLE/N1/N2/SEMI_AUTO) |
| `SyncEnable` | Synchro M1/M2 (logique positive) |
| `InhibitM1/2` | Inhibition treuil M1/M2 (MAINT_N2 only) |
| `JoystickWinchSelectArbitrated` | 0=M1+M2 couplés nominal, 1=M1, 2=M2 (unitaires MAINT_N2 uniquement) |
| `HomingApproachEnable` | Dépassement butée haut (N2) |
| `MaintenanceM3TargetEnable` | Cible Translation Maintenance — (N1 **OU** N2) **ET** bit IHM dédié `SelMaintenanceZoneAccess` (🆕 2026-08-06, autorisation consciente, le mode seul ne suffit jamais ; vérifié `FB_Modes.st` ligne 165, correction 2026-08-26 : le nom réel diffère de `TglMaintenanceZoneAccess` cité dans une version antérieure de ce document) |

Ce bus est consommé par Cycle, Safety, Treuils, Translation, Supervision, Acquisition.

---

## 📏 6 · Limite légale

La limite legale est une **interdiction d'exploitation**, pas une fonction safety.

> 📌 **Propriétaire** : la limite légale de dragage est implémentée dans le domaine Treuils
> (`AF_Partie-10`, `FB_Safety_Winch`). `FB_Modes` ne fait que fournir le mode contextuel ;
> le blocage effectif est arbitré par la safety métier du treuil concerné.

| Contexte | Comportement cible |
|---|---|
| SEMI_AUTO | Peut interdire une descente hors cote autorisee. |
| Maintenance | Signalisation a minima ; blocage eventuel selon regle validee. |

---

## 🛡️ 7 · Défauts et reprise

| Evenement | Effet |
|---|---|
| Perte device / commande pertinente | Le domaine concerne passe par `SafeStop` ou refus de mode. |
| SEMI_AUTO sans codeurs valides | Refuse ou quitte le semi-auto. |
| Hold apres defaut | Pas de redemarrage automatique. |
| Reprise | Cause disparue + Reset front + nouvel ordre selon le mode. |

La chaine AU, `PowerKeepAlive` et le rearmement sont proprietaires de la Partie 01.

---

## 📜 8 · Suivi historique

| Version | Date | Changement |
|---|---|---|
| v2.2 | 2026-08-29 | T181-11 : ajout §4bis « Matrice de bypass maintenance — treuils M1/M2 » (25 bascules mode-gated N2, override FDC N1 momentané 7,5/8,5 m, règle de bascule contacteurs retombés + frein serré, re-homing obligatoire, alignement T175 AC4 = N1 ET N2). Sommaire et TBD mis à jour. |
| v2.1 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lié, section `🎯 Rôle et périmètre` explicite, section « Bus d'autorisations » intégrée à la numérotation (§5, était orpheline), Suivi historique ajouté, renumérotation complète + réfs `§N` cascadées. Correctif de fond (review sous-agent expert automatisme, vérifié contre `FB_Modes.st`) : §5 citait `TglMaintenanceZoneAccess`, nom inexistant dans le code — corrigé en `SelMaintenanceZoneAccess` (variable réelle, ligne 165). Struct `ST_fbModes_Autorisations`, `E_Mode`, logique booléenne `MaintenanceM3TargetEnable`, absence de garde mot de passe PLC (§4) et propriété `FB_Safety_Winch` de la limite légale (§6) tous vérifiés conformes au code |
| v2.0 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 9 · TBD

- Matrice exhaustive des bypass N1/N2 et tracabilite : **résolue en §4bis** (treuils M1/M2, T181-11). Reste à étendre aux autres sous-systèmes (translation M3, commun) si besoin.
- Detail complet des effets de `SyncEnable` par defaut safety.
- Eventuel contrat unique d'intention de conduite entre joystick, boutons et cycle.

## 📚 10 · Documents liés

- Partie 01 : AU et rearmement.
- Partie 02 : architecture cible — page `PRG_03_Modes_Cycle_CFC` (modes, autorisations et sequenceur `FB_Cycle` reunis).
- Partie 03 : contrats et precedence.
- Partie 04 : cycle et assistants.
- Partie 07 : interface IHM modes.
