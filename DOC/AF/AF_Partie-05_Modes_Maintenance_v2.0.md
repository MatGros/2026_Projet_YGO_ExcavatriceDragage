# Analyse Fonctionnelle - Partie 5 : Modes & Maintenance (v2.0)

> Role : definir les modes machine, les droits et les arbitrages de source.
> Les sorties physiques et la chaine AU restent hors de ce document.

## 🧭 Sommaire

1. Modes machine
2. Fonctions et petits cycles
3. Selection de commande
4. Limite legale
5. Defauts et reprise
6. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>TC-P05-001</code></nobr> | Modes machine restreints (`DISABLE`, `MAINT_N1`, `MAINT_N2`, `SEMI_AUTO`) | `SyncEnable`, Diving, Extraction hors `E_Mode` | `💻 AUTO` | <small>§1-2</small> |
| <nobr><code>TC-P05-002</code></nobr> | Mode nominal : joystick pilote M1+M2 conjointement | M1 et M2 reçoivent la même intention | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P05-003</code></nobr> | Mode MAINT_N2 M1 seul : M2 bloqué, frein serré | Safety reste active sur M2 | `💻 AUTO` | <small>§3</small> |
| <nobr><code>TC-P05-004</code></nobr> | Refus mode SEMI_AUTO si codeurs invalides | Bascule refusée + message IHM | `💻 AUTO` | <small>§5</small> |
| <nobr><code>TC-P05-005</code></nobr> | Limite légale = blocage exploitation, pas safety | Pas de `PowerCutOff` sur simple limite légale | `💻 AUTO` | <small>§4</small> |
| <nobr><code>TC-P05-006</code></nobr> | Pas de redémarrage automatique après défaut | `Reset` + nouvel ordre explicite requis | `💻 AUTO` | <small>§5</small> |

---

## 🎚️ 1. Modes machine

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

## 🧩 2. Fonctions et petits cycles

Ces elements ne sont **pas** des modes machine.

| Element | Nature | Role |
|---|---|---|
| ⚖️ `SyncEnable` | Fonction / autorisation | Active la logique de synchronisation M1/M2. |
| 🌊 Diving | Petit cycle ST | Plongee et recherche de fond Kobold. |
| ⛏️ Extraction | Petit cycle ST | Fermeture benne et montee de controle. |

Diving et Extraction sont utilisables en maintenance et reutilises par le cycle semi-auto.

---

## 🎮 3. Selection de commande

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

## 📐 Bus d'autorisations

`FB_Modes` (via `PRG_MODES_CFC` actuel, `PRG_03_Modes_Cycle_CFC` en cible) produit le bus typé `Auth : ST_Modes_Autorisations` :

| Champ | Rôle |
|---|---|
| `Mode` | Mode arbitré (DISABLE/N1/N2/SEMI_AUTO) |
| `SyncEnable` | Synchro M1/M2 (logique positive) |
| `InhibitM1/2` | Inhibition treuil M1/M2 (MAINT_N2 only) |
| `JoystickWinchSelectArbitrated` | 0=M1+M2 couplés nominal, 1=M1, 2=M2 (unitaires MAINT_N2 uniquement) |
| `HomingApproachEnable` | Dépassement butée haut (N2) |
| `MaintenanceM3TargetEnable` | Cible Translation Maintenance — (N1 **OU** N2) **ET** bit IHM dédié `TglMaintenanceZoneAccess` (🆕 2026-08-06, autorisation consciente, le mode seul ne suffit jamais) |

Ce bus est consommé par Cycle, Safety, Treuils, Translation, Supervision, Acquisition.

---

## 📏 4. Limite legale

La limite legale est une **interdiction d'exploitation**, pas une fonction safety.

> 📌 **Propriétaire** : la limite légale de dragage est implémentée dans le domaine Treuils
> (`AF_Partie-10`, `FB_Safety_Winch`). `FB_Modes` ne fait que fournir le mode contextuel ;
> le blocage effectif est arbitré par la safety métier du treuil concerné.

| Contexte | Comportement cible |
|---|---|
| SEMI_AUTO | Peut interdire une descente hors cote autorisee. |
| Maintenance | Signalisation a minima ; blocage eventuel selon regle validee. |

---

## 🛡️ 5. Defauts et reprise

| Evenement | Effet |
|---|---|
| Perte device / commande pertinente | Le domaine concerne passe par `SafeStop` ou refus de mode. |
| SEMI_AUTO sans codeurs valides | Refuse ou quitte le semi-auto. |
| Hold apres defaut | Pas de redemarrage automatique. |
| Reprise | Cause disparue + Reset front + nouvel ordre selon le mode. |

La chaine AU, `PowerKeepAlive` et le rearmement sont proprietaires de la Partie 01.

---

## ❓ 6. TBD

- Matrice exhaustive des bypass N1/N2 et tracabilite.
- Detail complet des effets de `SyncEnable` par defaut safety.
- Eventuel contrat unique d'intention de conduite entre joystick, boutons et cycle.

## 📚 Documents lies

- Partie 01 : AU et rearmement.
- Partie 02 : architecture cible — page `PRG_03_Modes_Cycle_CFC` (modes, autorisations et sequenceur `FB_Cycle` reunis).
- Partie 03 : contrats et precedence.
- Partie 04 : cycle et assistants.
- Partie 07 : interface IHM modes.
