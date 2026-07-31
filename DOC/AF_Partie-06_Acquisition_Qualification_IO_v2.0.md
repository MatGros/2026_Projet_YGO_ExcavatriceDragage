# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.0)

> Role : definir la frontiere d'acquisition de `PRG_ACQUISITION_CFC`.
> Les decisions de mouvement restent hors de ce document.

La page `PRG_INPUTS_LD` (Ladder) est associee a cette frontiere : elle affiche les 21 entrees TOR
qualifiees via `FB_Input`, sans logique metier et sans decision.

## 🧭 Sommaire

1. Role
2. Chaine d'acquisition
3. Diagnostics bus
4. Polarites et noms
5. Sorties physiques
6. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| TC-P06-001 | Aucune lecture d'E/S brute dans les FB métier | Consommateurs lisent des faits qualifiés | `💻 AUTO` | §2 |
| TC-P06-002 | Polarité normalisée une seule fois à l'acquisition | Zéro ré-inversion dans les FB métier | `💻 AUTO` | §2 |
| TC-P06-003 | Bascule réel/simulation centralisée | `HwIn` source unique par domaine | `💻 AUTO` | §2 |
| TC-P06-004 | Diag CANopen/EtherCAT publié en ligne | Statuts dispos pour Modes/Safety/IHM | `💻 AUTO` | §3 |
| TC-P06-005 | Noms des signaux de puissance validés | `PowerKeepAlive_A/B_RQ`, `EmergencyChainClosed_DI` | `🟢 SITE` | §4 |
| TC-P06-006 | Écriture des sorties physiques centralisée | `PRG_OUTPUTS_LD` seul producteur final | `💻 AUTO` | §5 |

---

## 🎯 1. Role

`PRG_ACQUISITION_CFC` qualifie les donnees d'entree avant tout usage metier.

Il publie des **faits qualifies** :
- E/S TOR et PDO conditionnes via la chaine `HwReal` → `FB_SimBench` → `HwIn` ;
- disponibilite des devices (diagnostics CANopen/EtherCAT) ;
- image reelle ou simulee selectionnee par domaine ;
- mesures codeurs brutes/qualifiees selon frontiere validee ;
- joystick, homme-mort et codeurs traites par des FB dedies (`FB_Joystick`, `FB_Encoder_*`, `FB_Translation_PositionDecoder`).

`PRG_INPUTS_LD` affiche en Ladder les 21 entrees TOR apres qualification (`FB_Input`) :
- polarite normalisee (`TRUE` = etat vrai) ;
- mots de force/test rejetes en dehors de cette page ;
- aucune decision `SafeStop`, mode ou commande actionneur n'y est prise.

L'acquisition ne decide ni `SafeStop`, ni mode, ni commande actionneur.

---

## 🏗️ 2. Chaine d'acquisition

```text
Materiel / PDO
   ↓
HwReal (image brute device)
   ↓
FB_SimBench (selection reel / simule par domaine)
   ↓
HwIn (faits qualifies)
   ↓
FB complexes d'acquisition (Joystick, Codeurs, PositionDecoder M3)
   ↓
Modes / Safety / Cycle / Mouvements / IHM
```

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | Aucun FB metier ne lit une E/S brute device. |
| 🧪 Simulation | La bascule reel/simule se fait une seule fois, par domaine, dans `FB_SimBench`. |
| 🔒 Polarite | Normalisee une seule fois a l'acquisition (`FB_Input` / DUT de normalisation). |
| ✍️ Producteur unique | `PRG_ACQUISITION_CFC` est le seul ecrivain des donnees qualifiees d'entree. |
| 🪜 Affichage TOR | `PRG_INPUTS_LD` expose les 21 entrees TOR qualifiees via `FB_Input`, en lecture seule. |

Le detail homing/vitesse codeur reste proprietaire de la Partie 09. AF06 porte seulement leur acquisition et leur publication.

### Repartition CFC / Ladder (resolution du TBD §6)

| Type de signal | Programme | Langage | Bloc / DUT |
|---|---|---|---|
| Devices, simulation, joystick, codeurs, position M3 | `PRG_ACQUISITION_CFC` | CFC | Instances `FB_*`, structures `HwReal` / `HwIn` |
| 21 E/S TOR qualifiees (affichage) | `PRG_INPUTS_LD` | Ladder | `FB_Input` : contact → bobine |

> 📌 La frontiere acquisition utilise donc **CFC pour le flux device/simulation/FB complexes**, et **Ladder (`PRG_INPUTS_LD`) uniquement pour l'affichage des 21 entrees TOR** via `FB_Input`. Aucune logique metier n'est ecrite dans `PRG_INPUTS_LD`.

---

## 📡 3. Diagnostics bus

Les diagnostics font partie de l'acquisition qualifiee.

| Bus | Devices a minima |
|---|---|
| 🟧 CANopen | Joystick / reseau operateur. |
| 🟦 EtherCAT | COD1, COD2, variateur AC600. |

Faits publies :
- presence / online ;
- operationalite ;
- defauts de communication pertinents ;
- synthese de disponibilite si utile.

Les consommateurs decident ensuite :
- Safety : interlock ou `SafeStop` ;
- Modes : refus de semi-auto ou permission ;
- IHM : affichage diagnostic.

---

## 🔌 4. Polarites et noms

Le nom d'une E/S dit ce que signifie `TRUE`.

| Famille | Exemples confirmes |
|---|---|
| ⚡ Puissance | `PowerContactorEngaged_DI`, `EmergencyChainClosed_DI` |
| 🔁 Maintien / rearmement | `PowerKeepAlive_A_RQ`, `PowerKeepAlive_B_RQ`, `EmergencyArming_RQ` |
| 🛑 Freins | `M*_BrakeIsOpen_DI`, `M*_BrakeRelease_RQ` |
| 🪨 Kobold | `M1_M2_KoboldContactFond_DI`, `M1_M2_KoboldMeasureEnable_DQ` |

`PowerContactorEngaged_DI` confirme le contacteur de puissance et alimente le portail `PowerContactorEngaged`.  
`EmergencyChainClosed_DI` confirme la boucle AU.  
`PowerKeepAlive_*=TRUE` maintient la puissance ; sa retombee ouvre la chaine.

---

## ⚡ 5. Sorties physiques

Les sorties finales restent dans `PRG_OUTPUTS_LD` en Ladder.

| Regle | Exigence |
|---|---|
| 🧱 Barrieres finales | Uniques productrices des commandes physiques autorisees. |
| 🛡️ SafeStop | Laisse la deceleration metier se terminer. |
| 🔴 Coupure finale | `Enable=FALSE`, perte contacteur, timeout ou defaut final. |
| 🧨 PowerCutOff | Demande safety agregee puis canaux A/B fail-safe. |

Le detail de la chaine AU/rearmement est proprietaire de la Partie 01.

---

## ❓ 6. TBD

- Durees de filtrage par signal apres qualification terrain.
- Statut definitif de `FB_Output` non instancie.
- Contrat exact des structures de publication internes vers les pages CFC.

## 📚 Documents lies

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : page `PRG_ACQUISITION_CFC` et `PRG_OUTPUTS_LD`.
- Partie 08 : traitement joystick.
- Partie 09 : homing et vitesse codeur.
- Partie 13 : simulation.
