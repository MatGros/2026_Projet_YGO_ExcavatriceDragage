# Analyse Fonctionnelle - Partie 6 : Acquisition & Qualification I/O (v2.0)

> Role : definir la frontiere d'acquisition de `PRG_ACQUISITION_CFC` (ST actuel).
> Cible : `PRG_02_Acquisition_CFC`, rang 02 de la `MainTask` — voir §2bis.
> Les decisions de mouvement restent hors de ce document.
> 🗺️ Architecture cible faisant foi : `DOC/AF_Partie-02_Architecture_Programme_v3.0.md` §2 et §4.

La page `PRG_INPUTS_LD` (Ladder) est associee a cette frontiere : elle affiche les 21 entrees TOR
qualifiees via `FB_Input`, sans logique metier et sans decision.

## 🧭 Sommaire

1. Role
2. Chaine d'acquisition
3. Diagnostics bus
4. Polarites et noms
5. Sorties physiques
6. Preflight (qualification machine arrêtée)
7. TBD

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
Modes/Cycle → procedes (Treuils/Benne, Translation) avec leur safety → Outputs → Supervision
```

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | Aucun FB metier ne lit une E/S brute device. |
| 🧪 Simulation | La bascule reel/simule se fait une seule fois, par domaine, dans `FB_SimBench`. |
| 🔒 Polarite | Normalisee une seule fois a l'acquisition (`FB_Input` / DUT de normalisation). |
| ✍️ Producteur unique | L'acquisition est le seul ecrivain des donnees qualifiees d'entree (`PRG_ACQUISITION_CFC` actuel, `PRG_02_Acquisition_CFC` cible). |
| 🪜 Affichage TOR | `PRG_INPUTS_LD` expose les 21 entrees TOR qualifiees via `FB_Input`, en lecture seule. |

Le detail homing/vitesse codeur reste proprietaire de la Partie 09. AF06 porte seulement leur acquisition et leur publication.

### Repartition CFC / Ladder (resolution du TBD §6)

| Type de signal | Programme | Langage | Bloc / DUT |
|---|---|---|---|
| Devices, simulation, joystick, codeurs, position M3 | `PRG_ACQUISITION_CFC` | CFC | Instances `FB_*`, structures `HwReal` / `HwIn` |
| 21 E/S TOR qualifiees (affichage) | `PRG_INPUTS_LD` | Ladder | `FB_Input` : contact → bobine |

> 📌 La frontiere acquisition utilise donc **CFC pour le flux device/simulation/FB complexes**, et **Ladder (`PRG_INPUTS_LD`) uniquement pour l'affichage des 21 entrees TOR** via `FB_Input`. Aucune logique metier n'est ecrite dans `PRG_INPUTS_LD`.

---

## 🧩 2bis. Integration programme — cible `PRG_02_Acquisition_CFC`

**Principe :** acquerir une mesure physique, la mettre a l'echelle, en deduire une vitesse et juger
sa validite est **une seule responsabilite**. La cible reunit donc dans une page unique ce que le
code actuel eclate en quatre POU — ce qui supprime les instances codeurs et joystick dupliquees.

| Ce qui est absorbe par `PRG_02_Acquisition_CFC` | POU actuel | Contenu concerne |
|---|---|---|
| Frontiere E/S, selection reel/simule, joystick | `PRG_ACQUISITION_CFC` | `HwReal` / `FB_SimBench` / `HwIn`, `instJoystick` |
| Chaine codeurs complete M1/M2/M3 | `PRG_02_Encoders` | absolu, echelle, vitesse, validite, homing (⚠️ arbitrage — voir AF09) |
| Diagnostics devices et bus | `PRG_01_Diagnostics` | `instDiagCanOpen`, `instDiagEthercat`, `instIhmHeartbeat` |
| Retours auxiliaires qualifies | `PRG_AUXILIARY_CFC` | retour thermique centrale hydraulique |
| **Etat AU qualifie** | chaine AU | ⚠️ **acquisition de l'etat seulement** |

### 🛑 Etat AU : acquis ici, agissant en sortie

L'etat de la chaine d'arret d'urgence est un **fait d'entree qualifie**, acquis avec les autres
entrees pour etre visible des l'acquisition par la maintenance.

⚠️ **Cela ne change rien a son action.** Le FB de gestion AU agit sur les sorties via la barriere
finale `PRG_06_Outputs_LD`. **Acquisition de l'etat ≠ lieu d'action.** La chaine materielle AU, sa
polarite fail-safe, son auto-test et son rearmement restent proprietaires de la **Partie 01** : le
PLC ne remplace jamais cette chaine.

### ⚠️ Ce que l'acquisition n'absorbe pas

- Aucune decision `SafeStop`, mode, interdiction ou commande actionneur. La safety de chaque
  procede vit **dans la page de son procede** (`PRG_04_Treuils_Benne_CFC`, `PRG_05_Translation_CFC`),
  pas ici et pas dans un POU safety global — qui n'existe pas dans la cible.
- Aucune sortie physique : elles restent produites uniquement par `PRG_06_Outputs_LD`.

📌 Lot de migration : **M1** de `DOC/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C4, rebuild).
⚠️ Ce lot porte un point d'arbitrage ouvert : le homing lit aujourd'hui le mode de marche, donc une
donnee produite par un POU aval. Faits et options : `DOC/AF_Partie-09_Fonction_Encoder_v2.1.md` §4bis.

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
- la safety de chaque procede, **dans la page de son procede** : interlock ou `SafeStop` ;
- Modes : refus de semi-auto ou permission ;
- IHM : affichage diagnostic.

📌 Dans la cible, ces diagnostics sont produits **ici** et non plus dans un POU `PRG_01_Diagnostics`
separee : c'est ce qui supprime le cycle prouve `Acquisition ↔ Diagnostics` et la duplication de
`instJoystick`. Les FB et leurs seuils sont inchanges (Partie 12).

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

Les sorties finales restent dans `PRG_OUTPUTS_LD` en Ladder (cible `PRG_06_Outputs_LD`).

| Regle | Exigence |
|---|---|
| 🧱 Barrieres finales | Uniques productrices des commandes physiques autorisees. |
| 🛡️ SafeStop | Laisse la deceleration metier se terminer. |
| 🔴 Coupure finale | `Enable=FALSE`, perte contacteur, timeout ou defaut final. |
| 🧨 PowerCutOff | Demande safety agregee puis canaux A/B fail-safe. |

Le detail de la chaine AU/rearmement est proprietaire de la Partie 01.

---

## 🩺 6. Preflight (qualification machine arrêtée)

| Fiche | FB | Contenu |
|---|---|---|
| [`FB_Acquisition_Preflight`](AF_Partie-06_Fonction_Acquisition_Qualification_IO/FB_Acquisition_Preflight_v1.0.md) | `FB_Acquisition_Preflight` | Verdict passif : 16 contrôles de cohérence E/S machine arrêtée |

`FB_Acquisition_Preflight` vérifie 16 conditions mécaniques/électriques quand la machine est
arrêtée. Observateur pur : aucune écriture de commande, sécurité ou mouvement.

Instance : `PRG_TROUBLESHOOTING_CFC.instPreflight` (ST actuel).
Cible : `PRG_07_Supervision_CFC`, qui absorbe le troubleshooting en lecture seule stricte.

### PreflightErrorId (16 bits)

| Bit | Contrôle |
|---|---|
| 0-2 | Frein M1/M2/M3 serré |
| 3-4 | Contacteurs M1/M2 retombés |
| 5-6 | Thermique M1/M2 OK |
| 7 | Thermique frein OK |
| 8 | Rotation phases OK |
| 9 | Câble M2 tendu |
| 10 | Capteurs M3 cohérents |
| 11 | Contacteur sans chaîne AU |
| 12-13 | Codeur M1/M2 opérationnel |
| 14-15 | Homé + position bornée M1/M2 |

---

## ❓ 7. TBD

- Durees de filtrage par signal apres qualification terrain.
- Statut definitif de `FB_Output` non instancie.
- Contrat exact des structures de publication internes vers les pages CFC.

## 📚 Documents lies

- Partie 01 : AU, `PowerKeepAlive`, rearmement.
- Partie 02 : architecture cible 7 POU — `PRG_02_Acquisition_CFC` et `PRG_06_Outputs_LD`.
- Partie 08 : traitement joystick.
- Partie 09 : homing et vitesse codeur.
- Partie 13 : simulation.
