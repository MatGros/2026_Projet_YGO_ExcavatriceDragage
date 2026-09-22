# 🔎 Rapport court — Coupure AX11 M1/M2

> **Date :** 22/09/2026 · **Contexte :** simulation CODESYS · **Statut :** cause non encore isolée

## 🎯 Symptôme recherché

À la transition **AX10 → AX11**, `MotorRequest M2` et les relais de montée M1/M2 pouvaient retomber pendant environ **0,8 à 0,9 s**, malgré l’homme mort actif et le joystick tiré.

## 🧪 Comparaison des essais

| Essai | Programme | Résultat AX11 | Preuve |
|---|---|---|---|
| Référence défaut | Programme utilisé pour `Suivi_77/79` | ❌ Trou de 0,8–0,9 s : paliers M1/M2 = 0 et `MotorRequest M2 = 0` | `Suivi_77`, `Suivi_79` |
| Variante B | Base matin `8ec1fa28` + seule modification MécaB | ✅ Fluide : aucun échantillon AX11 avec `MotorRequest M2 = 0` | `Suivi_81` |
| Variante C | Base matin `8ec1fa28` + homing machine inhibé | ✅ Fluide : aucun échantillon AX11 avec `MotorRequest M2 = 0` | `Suivi_83` |

### Chronologie de `Suivi_83` — variante C

- **126,557 s :** entrée AX11, M1/M2 au palier 1, deux relais montée actifs, `MotorRequest M2 = 1`.
- **127,401 s :** passage commun au palier 2, sans interruption.
- **128,463 s :** passage AX12, commandes toujours actives.
- **140,309 s :** retombée en AX13, conforme à l’arrêt normal de séquence.

## ✅ Ce qui est établi

- Les variantes **B et C passent AX10→AX11 sans coupure** sur les essais enregistrés.
- La modification MécaB n’est **pas suffisante** pour provoquer le trou : B contient cette modification et reste fluide.
- La coupure observée dans `Suivi_77/79` est coordonnée sur M1/M2 et compatible avec la garde de couplage liée à `DirectionChangePending`.

## ⚠️ Ce qui n’est pas encore prouvé

- C ne prouve pas que le homing était le coupable : B fonctionne également sans inhibition du homing.
- Un essai réussi par variante ne démontre pas encore une correction permanente.
- Les traces ne contiennent pas les internes décisifs de T325 : `StoppedTimer.ET`, `CapturedStoppedTime`, `RemainingDelay` et `WinchBothMotionReady`.

## 📌 Conclusion et prochain essai

La cause la plus crédible reste un **état intermittent du délai directionnel D18/T325 au transfert AX10→AX11**, plutôt qu’un défaut MécaB ou moteur M2. Répéter **3 cycles identiques avec la variante B**. Si un trou réapparaît, tracer les internes T325 ci-dessus. La variante C reste réservée à la simulation car elle inhibe des fonctions du homing machine.

## 🛠️ Solution privilégiée — conserver le maximum de fonctions

1. **Conserver le cycle de homing actif** et son calcul complet de `MachineHomed` : qualification des axes, offset/commit benne, acquittement après perte de datum, verrou M3 et `HomingLossSafeStop`.
2. **Conserver les réglages T330** et leurs invariants TOP/FDC : ils sont indépendants du trou AX11.
3. **Conserver MécaB active**, sans bypass automatique. Son éventuel défaut doit être qualifié séparément ; le masquer retire une protection de confirmation d’arrêt.
4. **Corriger uniquement T325/D18** si la prochaine trace confirme que M1 reçoit 800 ms malgré un arrêt physique déjà supérieur au délai : réparer la reconnaissance/crédit de cet arrêt, sans supprimer D18 lorsqu’un arrêt réel n’est pas prouvé.

➡️ **Base conservatrice : variante A (matin)** tant que B n’a pas été répétée et qualifiée. B et C restent des variantes de discrimination. **Choix final : programme complet + correctif ciblé D18 prouvé par trace**, jamais C comme solution machine.

### ⚖️ Revue critique du scénario D18

- AX10 ferme la benne par **M2 en montée**, pas en descente (`FB_Bucket : M2_ReqAscent=TRUE`). M2 poursuit donc le même sens vers AX11.
- M1 peut conserver `LastDescend=TRUE` lorsque le cycle saute AX9 (`AX8→AX10`). Mais M1 reste alors arrêté pendant toute la fermeture AX10 : T325 devait justement créditer cet arrêt réel avant la demande de montée.
- Ajouter systématiquement un nouveau dwell de 800 ms au Grafcet arrêterait aussi M2, qui est volontairement maintenu en montée P1 par AX10B. Cela recréerait une retombée puis un redémarrage et ne corrigerait pas la raison pour laquelle l’arrêt déjà long de M1 n’a pas été crédité.
- Le dwell ne sera retenu que si l’analyse mécanique exige un arrêt commun explicite. Pour le défaut observé, la priorité reste de mesurer les conditions de crédit T325.
