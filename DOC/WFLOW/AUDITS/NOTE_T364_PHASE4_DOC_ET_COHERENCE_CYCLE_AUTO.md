# NOTE TECHNIQUE T364 — PHASE 4 : DOCUMENTATION & COHÉRENCE CYCLES

**Auteur** : Antigravity (Expert Senior Automatisme & Séquenceurs)  
**Date** : 2026-09-21  
**Référence** : `DOC/WFLOW/CONTRACTS/BRIEF_T364_DOC_ET_COHERENCE_CYCLE_AUTO.md`  
**Objets audités** : `FB_CycleMachineHoming.st` (T364) vs `FB_CycleSemiAuto.st` (Mature)

---

## 1. Tableau Comparatif Architectural (Homing vs Cycle Auto)

| Axe de conception | Cycle Automatique (`FB_CycleSemiAuto`) | Cycle Homing (`FB_CycleMachineHoming`) | Statut & Justification terrain |
|---|---|---|---|
| **Nomenclature des étapes** | `AX0`..`AX18` (PascalCase préfixé) | `HX0`..`HX7` (PascalCase préfixé) | 🟢 **Aligné** (cohérence visuelle IHM) |
| **Geste opérateur (Homme-mort)** | Homme-mort permanent requis (`DeadmanArmed`). Mouvement sous permis. | Homme-mort permanent requis (`DeadmanArmed`). Mouvement sous permis. | 🟢 **Aligné** (sécurité ISO 13849 catégorie 3) |
| **Geste joystick (Continuité)** | Poussé continu du début à la fin (doctrine "sans à-coup"). | Manche tiré en HX1 (fermeture), puis tiré en HX2 (montée), relâché en HX5 (validation). | 🟢 **Justifié** : le homing exige des étapes de validation visuelle (fermeture benne, neutre final) distinctes du dragage continu. |
| **Doctrine des Timeouts** | **Zéro timeout de mouvement arbitraire**. L'opérateur prend son temps. | **Zéro timeout en HX1** (8s supprimé). Garde physique de montée (300s, G511). Timeout d'inattention HX5 (30s). | 🟢 **Aligné** : aucun timeout bloquant artificiel ne punit l'opérateur en cours d'action. |
| **Modes de référencement** | N/A (consomme `MachineHomed`) | **Dual mode A / B** : Mode A au vol (nominal) + Repli automatique Mode B à l'arrêt. | 🟢 **Spécifique Homing** : robustesse face aux variations de latence réseau et aux presets codeurs. |
| **Forçage de step (Mise en service)** | Forçage encadré par `Cmd.SetForceStepTgt` | Forçage encadré `CfgCommissioningEnable`, `CfgForceStepTarget`, `CfgForceStepApply` | 🟢 **Aligné** : même philosophie de diagnostic sur banc/chantier. |
| **Textes opérateur** | `CycleStateStr` (STRING 80) : court, clair, français, sans jargon. | `MachineHomingInstruction` (STRING 120) : court, clair, sans jargon ("datum" banni). | 🟢 **Aligné** (voir §2 ci-dessous). |

---

## 2. Tableau Officiel des Textes Opérateur Homing (`HX0` ➔ `HX7`)

| Étape | Nom Enum | Rôle physique | Texte Opérateur IHM (`MachineHomingInstruction`) |
|---|---|---|---|
| **HX0** | `HX0_REPOS` | Attente initiale pure, aucun actionneur sollicité | Hors N2 : `'HX0 - Attente mode N2'`<br>En N2 : `'HX0 - Pret - Lancer sur IHM'` |
| **HX1** | `HX1_BUCKET_PREPARE` | Fermeture lente de la benne, validation visuelle | `'HX1 - Fermer benne (joystick), valider sur IHM'` |
| **HX1a** | `HX1A_COUPLING_INTERLOCK` | Bascule sélecteur treuil couplé M1+M2 (WinchSel=0), dwell 300 ms | `'HX1a - Verification couplage M1+M2'` |
| **HX2** | `HX2_CLIMB_COUPLED` | Montée couplée vitesse palier 1 vers le capteur haut | `'HX2 - Tirer le manche en montee vers capteur haut'` |
| **HX3** | `HX3_FLYING_REFERENCE` | Prise de référence conjointe capteur haut | Mode A (au vol) : `'HX3 - Prise de reference au vol'`<br>Mode B (à l'arrêt) : `'HX3 - Repli arret : attente arret treuils'` puis `'HX3 - Repli arret : prise de reference stationnaire'` |
| **HX4** | `HX4_STABILIZATION_CHECK` | Contrôle d'inertie et de cohérence géométrique M1/M2 | `'HX4 - Controle stabilisation et ecart treuils'` |
| **HX5** | `HX5_RELEASE_CLEARANCE` | Dégagement zone haute et attente retour manche au neutre | `'HX5 - Relacher le joystick au neutre'` |
| **HX6** | `HX6_HOMED_SUCCESS` | Machine qualifiée (`MachineHomed:=TRUE`), commit atomique benne | `'HX6 - Machine referencee avec succes'` |
| **HX7** | `HX7_FAILED` | Échec séquence unifié, attente acquittement conscient | `'HX7 - Homing interrompu - Acquitter Reset N2'` |

---

## 3. Justification des Écarts Légitimes

1. **Relâchement joystick en HX1 et HX5** :
   - Dans le cycle automatique (`FB_CycleSemiAuto`), le joystick est poussé en continu pour exécuter la passe complète de dragage (doctrine de productivité).
   - Dans le cycle homing (`FB_CycleMachineHoming`), l'opérateur doit impérativement regarder sa benne se fermer en HX1 puis relâcher le joystick pour appuyer sur le bouton de confirmation IHM. De même en HX5, la libération du manche est la confirmation physique que l'opérateur a repris le contrôle avant de donner le permis automatique.
   - *Verdict* : Écart **pleinement justifié** par la sécurité machine.

2. **Absence d'auto-reprise en HX7** :
   - Le cycle automatique autorise une pause/reprise sur réarmement homme-mort.
   - Le homing en échec (`HX7_FAILED`) exige un appui conscient sur `Reset` en mode `MAINT_N2`. Cela empêche tout redémarrage intempestif de treuils à proximité du capteur haut du portique.
   - *Verdict* : Écart **non négociable** (sécurité des biens et des personnes, ISO 13849).
