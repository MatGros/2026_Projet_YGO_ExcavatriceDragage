# Analyse Fonctionnelle - Partie 5 : Modes & Maintenance (v2.1)

> La tracabilite des versions programme/document est portee par `DOC/VERSION_HISTORY.md`.

## 🎯 Rôle et périmètre

- **Rôle** : définir les modes machine, les droits et les arbitrages de source.
- **Périmètre** : `E_Mode`, bus `Auth : ST_Modes_Autorisations`, sélection de commande,
  limite légale. Les sorties physiques et la chaîne AU restent hors de ce document (Parties 01/06).
- **Type de composant** : `FB_Modes` (contrat AF03 `standard`) — Transverse.

## 📑 Sommaire

1. [🧪 Points de validation](#1--points-de-validation)
2. [🎚️ Modes machine](#2--modes-machine)
3. [🧩 Fonctions et petits cycles](#3--fonctions-et-petits-cycles)
4. [🎮 Sélection de commande](#4--sélection-de-commande)
5. [📐 Bus d'autorisations](#5--bus-dautorisations)
6. [📏 Limite légale](#6--limite-légale)
7. [🛡️ Défauts et reprise](#7--défauts-et-reprise)
8. [📜 Suivi historique](#8--suivi-historique)
9. [❓ TBD](#9--tbd)
10. [📚 Documents liés](#10--documents-liés)

## 🧪 1 · Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P05-001</code></nobr> | Modes machine restreints (`DISABLE`, `MAINT_N1`, `MAINT_N2`, `SEMI_AUTO`) | `SyncEnable`, Diving, Extraction hors `E_Mode` | `💻 AUTO` | <small>§2-3</small> |
| <nobr><code>TC-P05-002</code></nobr> | Mode nominal : joystick pilote M1+M2 conjointement | M1 et M2 reçoivent la même intention | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P05-003</code></nobr> | Mode MAINT_N2 M1 seul : M2 bloqué, frein serré | Safety reste active sur M2 | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P05-004</code></nobr> | Refus mode SEMI_AUTO si codeurs invalides | Bascule refusée + message IHM | `💻 AUTO` | <small>§7</small> |
| <nobr><code>TC-P05-005</code></nobr> | Limite légale = blocage exploitation, pas safety | Pas de `PowerCutOff` sur simple limite légale | `💻 AUTO` | <small>§6</small> |
| <nobr><code>TC-P05-006</code></nobr> | Pas de redémarrage automatique après défaut | `Reset` + nouvel ordre explicite requis | `💻 AUTO` | <small>§7</small> |

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
- le bus d'autorisations `Auth : ST_Modes_Autorisations` (mode arbitré, SyncEnable, InhibitM1/2, sélection joystick, homing approach, cible maintenance).

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
- Elle est pilotée via `Auth.InhibitM1/2` (bus `Auth : ST_Modes_Autorisations`).
- Matrice complete des bypass : **TBD**.

> 📌 **Authentification** : gérée côté IHM (visibilité des actions selon niveau utilisateur).
> L'automate reçoit uniquement le mode arbitré (`MAINT_N1` / `MAINT_N2` / `SEMI_AUTO`).
> Aucun garde-fou mot de passe côté PLC — `FB_Modes` accepte `SelMode` tel quel.

---

## 📐 5 · Bus d'autorisations

`FB_Modes` (via `PRG_MODES_CFC` actuel, `PRG_03_Modes_Cycle_CFC` en cible) produit le bus typé `Auth : ST_Modes_Autorisations` :

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
| v2.1 | 2026-08-26 | Mise en conformite `GUIDE_EDITION_AF_v1.0` : Sommaire lié, section `🎯 Rôle et périmètre` explicite, section « Bus d'autorisations » intégrée à la numérotation (§5, était orpheline), Suivi historique ajouté, renumérotation complète + réfs `§N` cascadées. Correctif de fond (review sous-agent expert automatisme, vérifié contre `FB_Modes.st`) : §5 citait `TglMaintenanceZoneAccess`, nom inexistant dans le code — corrigé en `SelMaintenanceZoneAccess` (variable réelle, ligne 165). Struct `ST_Modes_Autorisations`, `E_Mode`, logique booléenne `MaintenanceM3TargetEnable`, absence de garde mot de passe PLC (§4) et propriété `FB_Safety_Winch` de la limite légale (§6) tous vérifiés conformes au code |
| v2.0 | — | Version precedente (voir `ARCHIVES/Doc/`) |

## ❓ 9 · TBD

- Matrice exhaustive des bypass N1/N2 et tracabilite.
- Detail complet des effets de `SyncEnable` par defaut safety.
- Eventuel contrat unique d'intention de conduite entre joystick, boutons et cycle.

## 📚 10 · Documents liés

- Partie 01 : AU et rearmement.
- Partie 02 : architecture cible — page `PRG_03_Modes_Cycle_CFC` (modes, autorisations et sequenceur `FB_Cycle` reunis).
- Partie 03 : contrats et precedence.
- Partie 04 : cycle et assistants.
- Partie 07 : interface IHM modes.
