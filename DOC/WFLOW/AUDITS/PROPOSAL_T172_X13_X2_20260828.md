# 📋 PROPOSAL T172 — Rebouclage X13 → X2 (homing conservé)

**Date** : 2026-08-28 · **Auteur** : DeepSeek (DSH) · **Réf** : T172-A
**Statut** : 🟠 Proposé — **validation humaine requise avant application**
**Criticité** : C3 (mouvement machine)

> ⚠️ **Aucune modification `CODE/` n'a été appliquée.** Ce document est le diff proposé
> pour validation. L'application se fera après visa P5 de l'orchestrateur.

---

## 🎯 Intention (décision utilisateur 2026-08-28)

À la fin du cycle (X13), la machine est **à la trémie**, treuils en position haute,
**homing déjà réalisé**. Le rebouclage doit enchaîner directement vers
**X2_WORK_POS_SELECT** (sélection de la position de travail suivante) **sans attendre
StartCycle** et **sans repasser par X0/X1** (pas de re-homing). StartCycle reste réservé
à l'initialisation complète du graphe depuis X0.

---

## 🔧 Diff 1 — `CODE/G_CYCLE/FB_Cycle.st` (bloc X13_DONE_SYNC)

```diff
         IF NOT SampleCountDone THEN
             SampleCount := SampleCount + 1;
             SampleCountDone := TRUE;
         END_IF;

-        IF StartEdge.Q THEN
-            SampleCountDone := FALSE;
-            Lifecycle.Done := FALSE;
-            State := E_CycleStep.X0_PREPARATION;
-        END_IF;
+        // T172 : rebouclage direct X13 -> X2 (homing conservé, machine à la trémie).
+        // Pas d'attente StartCycle : enchaînement vers la sélection de position de travail.
+        SampleCountDone := FALSE;
+        Lifecycle.Done := FALSE;
+        State := E_CycleStep.X2_WORK_POS_SELECT;
```

**Effet** : X13 devient une étape transitoire (1 scan) — le compteur SampleCount est
incrémenté une fois (front F2), puis le graphe enchaîne vers X2.

---

## 🔧 Diff 2 — `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` (ligne 58)

```diff
-| 🏁 Début de graphe | À la TRÉMIE, treuils en position HAUTE — rebouclage sur `X0_PREPARATION`. |
+| 🏁 Début de graphe | À la TRÉMIE, treuils en position HAUTE — rebouclage sur `X2_WORK_POS_SELECT` (homing conservé, pas de re-homing). |
```

---

## 🛡️ Considération sécurité (devoir d'alerte)

X13 → X2 déclenche un **mouvement automatique** (translation vers la position de travail)
en fin de cycle, **sans action opérateur**. Ceci est un choix utilisateur explicite.
À confirmer par l'orchestrateur au regard d'ISO 13849 / des principes du projet :
- ✅ Ce n'est **pas** une reprise après défaut (le principe « pas de redémarrage auto
  après défaut » reste intact).
- ⚠️ C'est un **mouvement auto de fin de cycle** — si non acceptable, prévoir un garde
  (ex. `DeadmanArmed` maintenu) avant l'enchaînement.

---

## 🔁 Impact chaîne (automatique après application)

1. `generate_trace_cycle.py` → trace avec séquence `X13 → X2`
2. `embed_trace_in_animation.py` → HTML à jour
3. `guard_animation_no_business_logic.py` → PASS (fraîcheur SHA)
4. `run_all_gates.py --palier C` → 17/17 (dont G460)
5. Harnais : TC-P04-100 étendu (AC1 : X13 → X2 sans StartCycle)

---

## ✅ Pour valider

- [ ] Visa P5 de l'orchestrateur (lecture du diff réel)
- [ ] Confirmation du mouvement auto de fin de cycle (ou garde DeadmanArmed)
- [ ] Application des 2 diffs + régénération trace/animation + gates
