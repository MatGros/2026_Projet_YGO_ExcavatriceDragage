# 🕵️ Session de Troubleshooting — Benne non référencée : ErrorID 02/05

> 📅 Date : 2026-09-19 · 🧪 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🎯 Symptôme

Lorsque la benne n'est pas référencée, deux défauts apparaissent immédiatement :

- `ErrorID:02` — dépassement écart maximum autorisé ;
- `ErrorID:05` — codeurs treuils non référencés.

Après référencement par les boutons IHM, l'état référencé n'est visible qu'après acquittement manuel des alarmes.

## 2. 🔍 Cause code confirmée

Dans `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` :

### ErrorID 02

Le calcul de l'écart est exécuté dès que le FB est actif :

```pascal
OffsetMaxViolNow := (CablePosM2 > (CablePosM1 + MaxAllowedOffset))
                 OR (CablePosM2 < (CablePosM1 + MinAllowedOffset));
```

Il n'est pas conditionné par `HomedM1`, `HomedM2` ni par `BucketReferenced`. Des positions non qualifiées peuvent donc produire un faux défaut.

### ErrorID 05

Le défaut est mémorisé dès qu'un codeur n'est pas référencé :

```pascal
IF NOT HomedM1 OR NOT HomedM2 THEN
    HomingFaultLatched := TRUE;
END_IF;
```

Il n'est remis à zéro que par `ResetEdge` ou `BypassGlobal`. Le référencement réussi ne l'efface pas automatiquement.

## 3. 🌳 Chaîne observée

```text
Codeur non référencé
  ├─> calcul écart actif             → ErrorID 02 possible ❌
  └─> HomingFaultLatched := TRUE     → ErrorID 05 ✅
                                      ↓
                              FB_FaultCore reste latched
                                      ↓
                         état référencé masqué jusqu'au Reset
```

## 4. 🏁 Conclusion

Le comportement observé est cohérent avec le code actuel, mais il n'est pas cohérent avec le besoin opérateur :

- avant référencement : état **non référencé**, pas défaut benne 02/05 ;
- pendant le référencement : procédure autorisée, pas défaut latched ;
- après référencement réussi : état visible immédiatement, sans Reset d'alarme résiduelle.

## 5. 🛠️ Correction à valider humainement

1. Inhiber le calcul ErrorID 02 tant que les deux codeurs et la référence benne ne sont pas qualifiés.
2. Transformer ErrorID 05 en condition de blocage uniquement lorsqu'une manœuvre benne normale est demandée hors homing.
3. Purger automatiquement la cause 05 lorsque `HomedAndReliableM1 AND HomedAndReliableM2` devient vrai, sous réserve que la référence benne soit effectivement validée.
4. Conserver le Reset manuel pour les défauts mécaniques réels (écart persistant, timeout, glissement).

⚠️ À ne pas faire : effacer tous les défauts sur le simple référencement. Les défauts mécaniques déjà confirmés doivent rester latched.

## 6. 📝 Journal

- 2026-09-19 : symptôme opérateur recueilli.
- 2026-09-19 : lecture statique de `FB_Bucket.st`, cause ErrorID 02/05 confirmée.
- 2026-09-19 : aucune modification de code effectuée.
