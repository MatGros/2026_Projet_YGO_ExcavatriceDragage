# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.0)

> Role : definir la frontiere d'acquisition de `PRG_ACQUISITION_CFC`.
> Les decisions de mouvement restent hors de ce document.

## 🧭 Sommaire

1. Role
2. Chaine d'acquisition
3. Diagnostics bus
4. Polarites et noms
5. Sorties physiques
6. TBD

## 🧪 Points de validation

| ID | Attendu | Preuve | Type | Détail |
|---|---|---|---|---|
| TC-P06-001 | Aucun FB metier ne lit une E/S brute device | consommateurs = donnees qualifiees seulement | AUTO | §2 |
| TC-P06-002 | Polarite normalisee une seule fois en acquisition | pas de reinversion dans FB metier | AUTO | §2 |
| TC-P06-003 | Bascule reel/simulation par domaine a la frontiere unique | `HwIn` source unique | AUTO | §2 |
| TC-P06-004 | Diag CANopen/EtherCAT publie online/operational | faits dispo pour Modes/Safety/IHM | AUTO | §3 |
| TC-P06-005 | Noms puissance confirmes device | `PowerKeepAlive_A/B_RQ`, `EmergencyChainClosed_DI`, `PowerContactorEngaged_DI` | SITE | §4 |
| TC-P06-006 | Sorties finales seulement via `PRG_OUTPUTS_LD` | barrieres finales uniques productrices | AUTO | §5 |

---

## 🎯 1. Role

`PRG_ACQUISITION_CFC` qualifie les donnees d'entree avant tout usage metier.

Il publie des **faits qualifies** :
- E/S TOR et PDO conditionnes ;
- disponibilite des devices ;
- image reelle ou simulee selectionnee ;
- mesures codeurs brutes/qualifiees selon frontiere validee.

Il ne decide ni `SafeStop`, ni mode, ni commande actionneur.

---

## 🏗️ 2. Chaine d'acquisition

```text
Materiel / PDO
   ↓
Image brute
   ↓
Selection reel / simulation par domaine
   ↓
Filtrage + normalisation polarite
   ↓
Donnees qualifiees publiees
   ↓
Modes / Safety / Cycle / Mouvements / IHM
```

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | Aucun FB metier ne lit une E/S brute device. |
| 🧪 Simulation | La bascule reel/simule se fait ici, par domaine. |
| 🔒 Polarite | Normalisee une seule fois a l'acquisition. |
| ✍️ Producteur unique | L'acquisition est le seul ecrivain des donnees qualifiees d'entree. |

Le detail homing/vitesse codeur reste proprietaire de la Partie 10. AF06 porte seulement leur acquisition et leur publication.

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

`PowerContactorEngaged_DI` confirme le contacteur de puissance et alimente le portail `EmergencyStopOk`.  
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

- Representation CFC exacte des instances d'acquisition et codeurs.
- Durees de filtrage par signal apres qualification terrain.
- Statut definitif de `FB_Output` non instancie.
- Contrat exact des structures de publication internes vers les pages CFC.

## 📚 Documents lies

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : page `PRG_ACQUISITION_CFC` et `PRG_OUTPUTS_LD`.
- Partie 08 : traitement joystick.
- Partie 10 : homing et vitesse codeur.
- Partie 13 : simulation.
