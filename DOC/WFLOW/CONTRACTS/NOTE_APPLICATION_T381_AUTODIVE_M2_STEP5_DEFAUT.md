# 🧾 Note d'application — T381 · Profil de plongée M2 palier 5 par défaut au démarrage à froid

> **Lot** : T381 (C3) · **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T381_AUTODIVE_M2_STEP5_DEFAUT.yaml`
> **Demande exploitant** : 2026-09-22 (« CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial = 1 par defaut »)
> **Fichier modifié** : `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st` (1 ligne)
> **Porteur** : AGY01 · **Date** : 2026-09-22 · **Statut** : Appliqué (non commité sans validation)

---

## 1. 🎯 Contexte et Motivation

L'essai machine `T291-A` a validé le profil de plongée automatique asymétrique :
- **M1** reste au palier 4 (vitesse standard de retenue).
- **M2** descend au palier 5 pendant les étapes de plongée `AX4..AX7`.

Le retour d'essai client (Mail GCAM du 15/09/2026) confirmait :
> *« Descente cycle auto : testé en réel avec M1 palier 4 et M2 palier 5. Le gain est léger mais présent. Actuellement, l’option doit être activée à chaque démarrage ; si le fonctionnement se confirme, elle passera en fonctionnement nominal. »*

La présente note trace le passage formel de ce fonctionnement de **« mode d'essai »** à **« profil nominal par défaut »**.

---

## 2. ⚙️ Modification appliquée

Dans `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st` (ligne 15) :

```st
// AVANT :
TglAutoDiveM2Step5Trial : BOOL := FALSE; (* Essai T291-A : en SEMI_AUTO AX4..AX7, M1 reste palier 4 et M2 peut monter au palier 5. NON persiste. *)

// APRES :
TglAutoDiveM2Step5Trial : BOOL := TRUE; (* T381 (ex T291-A) : en SEMI_AUTO AX4..AX7, profil nominal avec M1 palier 4 et M2 palier 5. Debrayable IHM. NON persiste. *)
```

### Impacts et garanties :
1. **Démarrage à froid** : Le bit `TglAutoDiveM2Step5Trial` est désormais initialisé à `TRUE` dès la mise sous tension.
2. **Débrayabilité conservée** : Ce bit reste une variable de commande IHM (`GVL_IHM.CycleSemiAuto.Cmd`). L'opérateur peut à tout moment décocher la case sur l'écran IHM pour revenir au profil historique uniforme (M1=P4 / M2=P4).
3. **Capture au départ de plongée** : La capture du profil est effectuée au départ de la plongée (`FB_CycleSemiAuto.st:1058`) et verrouillée jusqu'à la fin de `AX4..AX7`, évitant tout à-coup en cours de plongée si l'IHM est modifiée.
4. **Zéro régression sur le cycle** : `FB_CycleSemiAuto.st` et `PRG_04_Treuils_Benne.st` possédaient déjà toute la logique de consigne (`DiveM2StepTgt := 5`) et de concordance contacteurs (`WinchBothFinalStep45Coherent`). Aucune ligne d'automate exécutif n'a été modifiée.
