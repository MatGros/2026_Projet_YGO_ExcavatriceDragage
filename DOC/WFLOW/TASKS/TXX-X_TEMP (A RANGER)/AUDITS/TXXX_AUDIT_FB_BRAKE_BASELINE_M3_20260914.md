# Baseline `FB_Brake` — comportement M3

> 📅 2026-09-14 · 🧪 Exécution sur le code actuel · 🔒 Aucun fichier `CODE/` modifié

## Résultat de référence

Commande exécutée :

```text
python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_Brake --fast
```

| Indicateur | Résultat |
|---|---:|
| Tests | **5/5 PASS** |
| Conversion ST → IEC | 0,27 s |
| Compilation STruCpp/g++ | 16,76 s |
| Assertions | 0,04 s |
| Total FB | **17,10 s** |
| Scratch | `TOOLS/TEST_AUTO_CI/.scratch/FB_Brake/44078b238fc0` (conservé, nettoyage humain) |

## Dynamique figée

Réglages utilisés par les tests actuels :

| Paramètre | Valeur | Comportement observé |
|---|---:|---|
| `DelayContactClose` | 100 ms | inclus dans le délai d'ouverture |
| `DelayMagnetise` | 300 ms | ouverture après environ 400 ms cumulés |
| `DelayMotorDecel` | 500 ms | **sans effet actuellement** ; fermeture immédiate |
| `FeedbackTimeout` | 1 s | défaut si le retour contacteur reste incohérent |

Invariants M3 à préserver :

1. `Enable=FALSE` ⇒ `Ready=FALSE`, `BrakeCmd=FALSE`, aucune temporisation active.
2. `MovementRequested=TRUE` ⇒ `BrakeCmd` ne passe à TRUE qu'après `DelayMagnetise + DelayContactClose`.
3. `MovementRequested` retombe à FALSE ⇒ `BrakeCmd` repasse à FALSE au même scan ; aucune attente de `DelayMotorDecel` dans l'implémentation actuelle.
4. Retour contacteur incohérent pendant `FeedbackTimeout` ⇒ défaut latched, sortie frein sûre à FALSE.
5. Réarmement ⇒ cause disparue **et** front `Reset`; jamais de redémarrage automatique.

## Règle avant toute évolution

Toute modification d'un paramètre ou de la séquence doit repasser ces 5 scénarios et démontrer
que la dynamique M3 est inchangée, à l'exception du délai explicitement ciblé et validé.

⚠️ `DelayMotorDecel` est un réglage déclaré mais non câblé dans la séquence actuelle. Il ne doit
pas être rendu actif par inadvertance : son activation modifierait matériellement la dynamique
de collage du frein et nécessite une validation séparée.

