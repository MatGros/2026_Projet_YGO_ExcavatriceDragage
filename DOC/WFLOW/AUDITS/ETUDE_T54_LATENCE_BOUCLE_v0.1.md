# ⏱️ T54 — Intégrer latence boucle automate (~10 ms) au calcul temps d'arrêt

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T54 — intégrer la **latence boucle
> automate (~10 ms)** au calcul du temps d'arrêt des treuils.
> Source : `ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md §3.2 (P1.2)`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T54.

---

## 1. Constat (audit archivé, P1.2)

L'audit Winch §3.2 (P1.2 « Ordre d'exécution et latence d'un scan », `AUDIT_Winch_v1.0.md` L128-148) :

> Ordre actuel (MainTask 10 ms) : … Safety lit commandes/états du **scan précédent (~10 ms de
> retard)**. **Action** : documenter la latence, **l'intégrer au calcul temps d'arrêt**, tester
> avec inertie/charge.

**Conséquence** : tout calcul de distance/temps d'arrêt qui ignore les ~10 ms de latence
d'acquisition **sous-estime la distance d'arrêt réelle** — un risque en sécurité (butée, fin de
course).

---

## 2. Design — intégrer la latence au calcul temps d'arrêt

| Élément | Aujourd'hui | Avec latence |
|---|---|---|
| Temps d'arrêt `Tstop` | basé sur rampe/décél + frein | `Tstop + Tscan` (Tscan ≈ 10 ms MainTask) |
| Distance d'arrêt `Dstop` | `Dstop = f(V, Tstop)` | `Dstop = f(V, Tstop + Tscan)` |

**Modification proposée (design)** :
- Ajouter une **constante** `CST_ScanLatencyMs := T#10ms` (la période de la tâche, T121 anti-magique).
- Majorer les temps de décélération / confirmation d'arrêt de cette latence dans le calcul
  (FB_Brake `DelayMotorDecel`, FB_Winch rampes, seuils Méca).
- ⚠️ **Ne pas augmenter les DÉLAIS de sécurité réels** (timeouts Méca) de 10 ms — la latence s'ajoute
  au **calcul de distance**, pas aux timeouts (sinon on retarde la coupure).

---

## 3. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Où injecter `CST_ScanLatencyMs` ? (calcul de distance d'arrêt, pas les timeouts de coupure) |
| 2 | Quelle tâche référence (MainTask 10 ms ? EtherCAT 4 ms ?) — à préciser |
| 3 | Impact sur les **seuils Méca** (distance de butée) — ne pas les dégrader |
| 4 | Implémentation (code) → **validation humaine** (C4 sécurité) |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T54 |
| Audit source | `ARCHIVES/Doc/AUDITS/Winch/AUDIT_Winch_v1.0.md §3.2 (P1.2)` |
| Contexte | `FB_Brake` (DelayMotorDecel) · `FB_Winch` (rampes) · `FB_Safety_Winch` (Méca) |
