# 🕵️ Session de Troubleshooting — Continuité joystick AX3 → AX4

> 📅 Date : 2026-09-05 · 🧊 Situation : SITE · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé

Cycle `SEMI_AUTO` sur machine réelle. L'opérateur maintient le joystick poussé pendant
l'ouverture de la benne et souhaite conserver l'armement jusqu'au départ couplé M1/M2.
Les essais précédents ont provoqué soit un départ désynchronisé, soit un déroulement M2
excessif suivi d'un défaut.

## 2. 🎯 Symptôme

À la fin d'ouverture benne en AX3, le cycle exige actuellement un retour joystick au neutre
puis un nouveau front de déflexion avant AX4 ; supprimer ce geste sans autre barrière expose
à un départ M1/M2 non atomique.

## 3. 🧩 Indices / historique

- 🟡 Rapport opérateur : solutions précédentes non fiables, désynchronisation ou déroulement M2.
- 🟢 Code : AX3 attend `JoyDeflectedEdge.Q` après `BucketOpenStabTimer.Q`.
- 🟢 Code : ouverture benne et plongée utilisent le sens descente de M2.
- 🟢 Code : l'atomicité aval ne teste que `DirectionChangePending` et les défauts latched.
- 🟢 Trace 37 : M2 agit seul pendant la phase benne ; les départs suivants sont distincts ;
  `M1M2Sync.State.ErrorId=1` apparaît ensuite.
- 🔴 CI : harnais `FB_CycleSemiAuto` non compilable (`TopPositionSensor` obsolète).
- 🟢 Code courant relu après challenge : `instFault` et le gate Abort/Reset sont restaurés.
  La mention T256 observée dans le catalogue était périmée par rapport au source courant.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Attendu | Preuve / verdict |
|---|---|---|---|---|
| 1 | Perte d'homme-mort au maintien | `DeadmanArmed` | TRUE | Non démontré comme cause ; traces montrent des plages maintenues |
| 2 | Front joystick imposé par G7 | `JoyDeflectedEdge.Q` | Nouveau front | ✅ Confirmé dans AX3 |
| 3 | Pause fixe seule suffisante | vitesses + contacteurs | arrêt confirmé | ❌ Non démontré : timer sans feedback mécanique |
| 4 | Verrou aval garantit l'atomicité | `DirectionChangePending` M1/M2 | reflète tout axe non prêt | ❌ Même sens M2 : peut rester FALSE |
| 5 | Départ direct AX3→AX4 sûr | sorties M1/M2 | simultanées physiquement | ❌ Non prouvé ; historique et trace contraires |
| 6 | Transition sur arrêt mécanique | vitesses, freins, contacteurs | tous arrêtés et stables | ✅ Architecture testable, validation à construire |

## 5. 📊 Arbre vertical

```text
Joystick poussé + DeadmanArmed
└─ AX3 : ReqBucket.ReqOpen
   └─ PRG_04 / FB_Bucket : M2 seul en descente
      └─ Benne_IsOpen / Busy retombe
         ├─ actuel : TON 1 s + nouveau JoyDeflectedEdge ❌ pénible
         └─ suppression brute du front
            └─ AX4 : ReqDescend M1 + M2
               ├─ M2 même sens => DirectionChangePending peut rester FALSE ❌
               └─ M1 part depuis repos => risque écart mécanique / défaut sync ❌
```

**Résumé** : `[Joystick maintenu] → [M2 benne seule] → [Busy=0] → [arrêt mécanique non prouvé] → [Both AX4] ❌`

## 6. 📊 Données / interactions

- Trace `Suivi_CycleDiveError_20260905_37.trace` : M2 descend seul avant les séquences
  couplées ; erreur synchro `ErrorId=1` observée à environ 102,8 s.
- Snapshot 16:07:50 : `ErrorMecaE=TRUE` sur M1 et M2 et SafeStop actif ; contexte post-défaut,
  utile pour confirmer l'issue mais pas le chronogramme AX3→AX4.
- CI `FB_CycleSemiAuto` : FAIL de compilation du harnais sur `TopPositionSensor` obsolète.

## 7. 🏁 Conclusion

- **Cause de l'obligation de relâcher** : front `JoyDeflectedEdge.Q` explicitement exigé en AX3.
- **Cause du risque lors de sa suppression** : aucune preuve d'arrêt mécanique M2 entre la
  manœuvre benne et le départ couplé ; le verrou aval `DirectionChangePending` ne couvre pas
  une reprise dans le même sens.
- **Statut** : cause statique confirmée ; correction non qualifiable tant que les harnais
  CI ne sont pas restaurés et que le contrat d'arrêt/départ atomique n'est pas complété.

## 8. 🛠️ Proposition de correction à qualifier

- Conserver `DeadmanArmed` et la déflexion joystick sans demander de retour au neutre.
- Insérer une phase explicite entre AX3 et AX4 : commandes M1/M2/benne à zéro ; attente de
  l'arrêt mécanique M1 et M2 (vitesse sous seuil, contacteurs retombés, freins appliqués),
  confirmé pendant une courte durée stable.
- Une fois cette condition vraie, émettre les deux demandes AX4 au même scan ; conserver
  l'atomicité aval comme seconde barrière.
- Ajouter un timeout de transition vers repli sûr, jamais un départ au terme d'un timer seul.
- ⚠️ Validation humaine requise avant toute édition ou essai puissance.

## 9. ✅ Vérification requise

- Réparer le harnais CI obsolète.
- Test scan-par-scan AX3→attente arrêt→AX4 avec joystick maintenu.
- Prouver : aucune sortie durant attente ; M1/M2 partent au même scan ; aucun déroulement M2 ;
  abandon, défaut, perte homme-mort et timeout neutralisent toutes les sorties.
- Puis bundle, G200, palier C et trace terrain à puissance maîtrisée.

## 10. 📝 Journal

- 2026-09-05 : analyse statique G7→PRG_04→FB_Winch→sorties, lecture snapshots/traces,
  tentative CI ; aucun code machine modifié.
