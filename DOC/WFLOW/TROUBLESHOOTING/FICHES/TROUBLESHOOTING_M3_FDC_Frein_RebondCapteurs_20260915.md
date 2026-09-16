# 🕵️ Session de Troubleshooting — M3 : défaut frein aux FDC et rebond capteurs

> 📅 2026-09-15/16 · 🧊 Situation : SITE MACHINE RÉELLE + SIMULATION CODESYS · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé

Rapport opérateur du 2026-09-15 : le défaut de séquence frein M3 réapparaît aux positions Trémie
et P1, comme lors de la mise en service précédente. Le mode exact, l'ErrorId et la trace associée
restent à fournir. Aucun changement de code n'est autorisé sur cette seule observation.

## 2. 🎯 Symptômes

1. Défaut de séquence/retour frein M3 lors d'une arrivée sur Trémie ou P1.
2. Le bouton d'acquittement n'est pas animé malgré le défaut actif.
3. La simulation M3 actuelle ne reproduit pas les transitions rapides observées sur les capteurs.

## 3. 🧩 Faits et indices

- 🟡 Mesure terrain rapportée : un capteur peut commuter rapidement entre 0 et 1 pendant environ 1 s.
- 🟢 Code : `FB_Sim_Translation` ne publie que des mots capteurs valides, sans rebond.
- 🟢 Code : `FB_SimBench` recopie instantanément `M3_BrakeCmd` dans `M3_BrakeIsOpen_DI`.
- 🟢 Code : le chemin IHM `GVL_IHM.IoHw.In.Hardware` recopiait `HwReal` en dur ; il ne pouvait donc
  jamais montrer les DI dynamiques du SimBench, même lorsque `HwIn` était simulé.
- 🟢 Test CI : `TC-T300-SEN-011` confirme que `M3_PosPV_DI` passe de 0 à 1 au franchissement
  du seuil synthétique 5 m en allant de P1 vers Trémie ; vers Maintenance, ce capteur reste à 0.
- 🟢 Code : `AnyFaultActive` inclut `M3Translation.Safety.Error`, mais pas
  `M3Translation.State.Error` ni `M3Translation.State.FinalInterlockError`.
- 🟢 Code : le watchdog final du frein déclenche après 500 ms si l'ouverture commandée n'est pas confirmée.
- 🟢 Code : les jetons `AtTremie` et `AtP1` sont alimentés par les fronts individuels des capteurs.

## 4. 🌳 Arbre des causes

| # | Hypothèse | Variable de décision | Attendu | Lu | Verdict |
|---|---|---|---|---|---|
| 1 | Retour frein physique trop lent ou instable | `BrakeCmd`, `BrakeFeedback`, `FinalBrakeTimeoutElapsed` | Confirmation avant 500 ms | Trace requise | ❓ |
| 2 | Rebond capteur recrée plusieurs fronts `AtPosition` | capteurs M3 + `AtTremie/AtP1` | Un seul événement qualifié | Trace requise | ❓ |
| 3 | Mot capteurs transitoirement incohérent | `Idx307_PositionDecoderIncoherent` | FALSE | Snapshot/trace requis | ❓ |
| 4 | Arrêt FDC et séquence frein s'interrompent mutuellement | demande, rampe, fréquence, frein, interlock final | Chronologie cohérente | Trace requise | ❓ |
| 5 | SimBench masque le défaut | modèle capteurs/frein idéal | Dynamique physique représentative | Idéal confirmé par code | ✅ |
| 6 | Animation acquittement oublie un domaine de défaut M3 | `AnyFaultActive` | OR de tous les défauts acquittables | Deux sources M3 absentes | ✅ |

## 5. 📊 Arbre vertical

```text
Arrivée M3 sur Trémie ou P1
  ├─ capteur physique commute / rebondit pendant ~1 s ❓
  │    └─ fronts AtPosition multiples possibles ❓
  ├─ rampe M3 tombe à zéro
  │    └─ séquence de fermeture/réouverture frein ❓
  ├─ retour frein non confirmé avant watchdog 500 ms ❓
  │    └─ FinalInterlockError / RestartInhibit
  └─ AnyFaultActive
       ├─ M3Translation.Safety.Error inclus ✅
       ├─ M3Translation.State.Error absent ❌
       └─ M3Translation.State.FinalInterlockError absent ❌
```

**Résumé** : `[arrivée FDC] → [capteur/frein transitoires à mesurer] → [défaut M3] → [AnyFault incomplet] ❌`.

## 6. 📊 Chronogramme à extraire de la trace réelle

| Événement | Capteurs M3 | AtPosition | Demande/sens | Fréquence | Frein Cmd/DI | Défauts |
|---|---|---|---|---|---|---|
| Approche | mot stable | 0 | actif | > 0 | ouvert | 0 |
| Premier front | transition | impulsion | actif | décroît | à mesurer | à mesurer |
| Rebond 0↔1 | ~300 ms par état | impulsions possibles | à mesurer | à mesurer | à mesurer | à mesurer |
| 500 ms | à mesurer | — | — | — | confirmation exigée | timeout possible |
| Fin 0,5–1,2 s | stable | jeton unique attendu | arrêt | 0 | serré | état final |

## 7. 🏁 Conclusions intermédiaires

- **Signalisation acquittement** : défaut statique confirmé dans l'agrégation `AnyFaultActive`.
- **Cause du défaut frein** : non confirmée sans la trace réelle ou un snapshot pris avant acquittement.
- **Comportement PV** : aucune panne de liaison ; le PV est un seuil situé côté Trémie et ne commute
  qu'après franchissement de 5 m dans ce sens.
- **Simulation** : couverture insuffisante confirmée ; elle ne peut pas reproduire le scénario terrain actuel.

## 8. 🛠️ Proposition de traitement phasé

### Correction appliquée le 2026-09-16 (pont d'observation)

`PRG_07_Supervision` recopie désormais `PRG_02_Acquisition.HwIn` vers
`GVL_IHM.IoHw.In.Hardware`. Le métier et l'IHM/Trace observent ainsi la même image arbitrée ;
aucune écriture directe de DI n'est ajoutée.

Validation statique : G502 PASS, G200 liaison PASS (0 erreur). Validation runtime CODESYS encore
requise avec `SimulationModeActive` puis un front OFF→ON et une commande M3 effective.

### Phase A — preuve terrain, sans code

- Convertir et analyser la trace réelle.
- Corréler capteurs, fronts/jetons, demande M3, fréquence, commande/retour frein et ErrorId.

### Phase B — SimBench déterministe

- Ajouter un scénario activable, sans modifier le nominal.
- À chaque franchissement configuré : premier front après 500 à 1200 ms.
- Pendant l'épisode : alternance 0/1 d'environ 300 ms, puis état final stable.
- Utiliser une séquence pseudo-aléatoire déterministe avec graine/numéro d'épisode publiés.
- Conserver l'override manuel existant prioritaire et empêcher tout effet hors simulation.
- Modéliser séparément le délai/retour frein ; ne pas mélanger rebond capteur et panne frein.

### Phase C — diagnostic et correction

- Inclure les défauts mouvement et interlock final M3 dans `AnyFaultActive`.
- Corriger la cause racine uniquement après preuve par Phase A/B.
- Ajouter tests scan-par-scan et garde-fou automatique de non-régression.

## 9. ✅ Non-régression attendue

- Simulation nominale inchangée lorsque le scénario est désactivé.
- Un rebond ne doit pas produire plusieurs positions stables ni une position incohérente persistante.
- Arrivée Trémie et P1 testées dans les deux sens.
- Aucun redémarrage automatique après défaut ; acquittement sur front uniquement.
- Le bouton d'acquittement s'anime pour Safety, mouvement M3 et interlock final M3.

## 10. 📝 Journal

- 2026-09-15 : récidive terrain rapportée aux positions Trémie et P1.
- 2026-09-15 : lacune SimBench et omission `AnyFaultActive` confirmées par analyse statique.
- 2026-09-15 : attente du chemin de la trace réelle avant conclusion sur la cause frein.
