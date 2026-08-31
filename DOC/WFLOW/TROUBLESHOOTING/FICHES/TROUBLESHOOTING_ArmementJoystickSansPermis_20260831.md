# 🕵️ TROUBLESHOOTING — Armement joystick sans permis de mouvement

**Date** : 2026-08-31
**Sujet** : Le joystick s'arme (DeadmanArmed=TRUE) même sans permis de mouvement sur les treuils / translation.

## 1 · Contexte figé
- **Situation** : simulation
- **Mode** : non armé (DeadmanArmed=FALSE)
- **Symptôme** : en manipulant le joystick, l'état passe « armé » alors qu'aucun mouvement n'est permis sur les treuils.

## 2 · Indices
- 🟢 Le joystick s'arme quand on le manipule, même sans permis de mouvement treuil.
- 🟢 L'utilisateur attendait que l'armement soit gaté par les permis de mouvement (treuils + translation M3).

## 3 · Caractérisation
- **Type** : état « armé » s'active alors qu'il ne devrait pas (sans permis de mouvement).

## 4 · Arbre des causes
- **Branche A — ArmingPermit** : `ArmingPermit` est-il FALSE quand aucun mouvement n'est permis ?
  - **FAIT** : `ArmingPermit := NOT instBucket.Lifecycle.Busy AND NOT BenneBusyFallEdge.Q` (PRG_04 §3bis).
  - **FAIT** : `ArmingPermit` n'est PAS gaté par les permis de mouvement treuil (EffectivePermitM1/M2_Ascent/Descend) ni translation M3.
  - **CONSÉQUENCE** : `ArmingPermit=TRUE` même sans permis de mouvement → le joystick s'arme.

## 5 · Cause racine
`ArmingPermit` (PRG_04 §3bis) est gaté uniquement par l'état benne (Option B), **pas** par les permis de mouvement des treuils/translation. Donc le joystick s'arme même quand aucun mouvement n'est permis.

## 6 · Preuve
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st:460` : `ArmingPermit := NOT instBucket.Lifecycle.Busy AND NOT BenneBusyFallEdge.Q;`
- `CODE/D_JOYSTICK/FB_Joystick.st:176` : `DeadmanArmTimer(IN := DeadmanArmPending AND NOT DeadmanArmed AND ArmingPermit, ...)` — l'armement dépend de `ArmingPermit`.
- `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md` §10 Q1 : Option B (combiné interlock benne) arbitré humain.

## 7 · Proposition de correction
- **Option 1 (immédiat, sans code)** : documenter que l'armement n'est pas gaté par les permis de mouvement (comportement actuel).
- **Option 2 (définitif)** : gater `ArmingPermit` par les permis de mouvement treuil + translation M3 :
  `ArmingPermit := (EffectivePermitM1_Ascent OR EffectivePermitM1_Descend OR EffectivePermitM2_Ascent OR EffectivePermitM2_Descend OR M3_MotionPermit) AND NOT instBucket.Lifecycle.Busy AND NOT BenneBusyFallEdge.Q;`
  → quand aucun mouvement n'est permis, `ArmingPermit=FALSE` → le joystick ne s'arme pas.
- **Validation requise** : décision humaine (changement de comportement vs AF §10 Q1 Option B).

## 8 · Non-régression
- À vérifier après correction : bundle + G200 + gates + compile CODESYS.
