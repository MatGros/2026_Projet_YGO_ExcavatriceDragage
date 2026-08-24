# 🟡 T110 — Clarifier sémantique `DriveStatusWord.0` AC600 (Power Ready vs Mouvement)

> 📄 **ÉTUDE / CLARIFICATION (zéro code)** · 📅 2026-08-24 · 🎯 T110 — lever l'ambiguïté de
> `DriveStatusWord.0` du variateur AC600 : « Power Ready » ou « Mouvement » ?
> Source : `FB_Safety_Translation.st`, `FB_Translation.st`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T110.

---

## 1. Constat — usage actuel du bit 0

| Usage | Fichier | Ligne |
|---|---|---|
| `DriveStatusWord.0` = indicateur **« mouvement non commandé »** (Méca B, `UncommandedActiveB`) | `FB_Safety_Translation.st` | L180-182 |
| `DriveStatusWord.0` dans condition de dépassement (Fdc + Direction + mouvement) | `FB_Safety_Translation.st` | L216-217 |
| `DriveStatusWord.4` = **« défaut variateur »** | `FB_Translation.st` | L321 |

**Ambiguité** : `DriveStatusWord.0` est interprété comme « il y a du mouvement » (→ Méca B :
« absence confirmation arrêt »). Mais selon la doc AC600, le bit 0 du StatusWord peut être
« **Power Ready** » (alimentation prête) et non « mouvement réel ». Si c'est le cas, l'utiliser
comme preuve de mouvement est **faux** → faux Méca B (arrêt non confirmé) à l'arrêt.

---

## 2. Clarification nécessaire

| Question | Réponse requise |
|---|---|
| Que signifie réellement `DriveStatusWord.0` sur l'AC600 ? | « Power Ready » ou « mouvement » ? |
| Le bit utilisé comme preuve de mouvement (Méca B) est-il le bon ? | Vérifier le bit « en mouvement / motor running » du variateur |

**Hypothèses** (à confirmer par la doc AC600 / le câblage) :
- si `.0` = Power Ready → **ne pas** l'utiliser seul comme preuve de mouvement ; Méca B doit se
  baser sur la **consigne** (DriveActualFreqHz) et/ou le bon bit d'état variateur ;
- `DriveActualFreqHz > 0.5` (déjà utilisé, L180) est une **meilleure** preuve de mouvement réel.

**Proposition** (design) : baser Méca B Translation sur `ABS(DriveActualFreqHz) > 0.5` + un bit
d'état variateur explicitement « mouvement » (documenté), pas sur `DriveStatusWord.0` seul.

---

## 3. Points à valider (avant correction)

| # | Question |
|---|---|
| 1 | Doc AC600 : que signifie réellement `DriveStatusWord.0` ? (Power Ready / mouvement) |
| 2 | Faut-il corriger `FB_Safety_Translation` (Méca B) pour ne pas dépendre de ce bit ambigu ? |
| 3 | Implémentation (code) → **validation humaine** (C4 sécurité) |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T110 |
| FB | `CODE/I_TRANSLATION/FB_Safety_Translation.st` (L180-182, L216) · `FB_Translation.st` (L321) |
| Variateur AC600 | doc constructeur / câblage EtherCAT |
