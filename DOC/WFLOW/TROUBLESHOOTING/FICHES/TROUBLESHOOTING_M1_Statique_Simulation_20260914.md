# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — M1 statique en simulation

📅 Date : 2026-09-14 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [OUVERTE]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Session de travail sur T292/T293 (simulation Kobold auto + modèle M2 calé sur M1 en descente
couplée), fichiers modifiés : `CODE/L_SIMULATION/FB_SimBench.st`,
`CODE/L_SIMULATION/GVL_Simulation.st`, `CODE/M_MAIN/PRG_02_Acquisition.st`. Utilisateur teste en
simulation CODESYS (import bundle PLCopenXML complet). Symptôme rapporté : `M1TreuilRetenue.
State.Position_M` reste figé (ne bouge jamais) lors de tests en descente couplée, y compris
après réimport du bundle complet le plus récent. Utilisateur affirme que c'est causé par les
modifications de l'agent sur ce lot.

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Position M1 | `M1TreuilRetenue.State.Position_M` | statique (ne bouge pas) | rapporté par utilisateur, non horodaté précisément |

## 2. 🎯 Symptôme

`M1TreuilRetenue.State.Position_M` reste totalement statique pendant des tests de descente
couplée en simulation, malgré commande joystick — permanent sur les essais rapportés depuis
l'introduction du lot T292/T293.

## 3. 🧩 Indices / historique

- Derniers changements : ajout modèle M2=f(M1) (T293) + mode auto Kobold (T292) dans
  `FB_SimBench.st`/`GVL_Simulation.st`/`PRG_02_Acquisition.st`.
- Déjà essayé : réimport bundle complet (persiste), bornage de la divergence M2 à ±0.6m
  (CST_M2CoupledModelMaxDivergence_M) appliqué mais pas encore retesté au moment de la fiche.
- Conditions d'apparition : tests avec joystick en descente couplée M1+M2, mode simulation.
- Alarmes : `[BENNE] ErrorID:02 - dépassement écart max autorisé` observée avant le bornage
  (probablement liée à la divergence M2 non bornée, désormais corrigée).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Régression directe : l'agent a écrit sur la chaîne M1 | diff exhaustif du lot sur M1_RelayFwd/Rev, Winch.COD1_PosValue, instSimEncoderM1 | aucune écriture attendue | diff confirmé : aucune écriture sur M1 (voir §5) | ❌ éliminée par preuve diff |
| 2 | Plantage tâche PLC par débordement numérique (REAL_TO_DINT) dans le modèle M2 non borné (avant fix) | comportement task CODESYS (reset/exception) | pas d'exception attendue après bornage ±0.6m | à confirmer par retest utilisateur post-fix | ❓ à vérifier |
| 3 | `SimulationModeActive` déjà TRUE au boot → pas de front → `SimWinchActive` resté FALSE → routage HwReal (M1 réel non câblé = figé) | `GVL_Simulation.SimWinchActive` | TRUE si front OFF→ON observé | non vérifié | ❓ à vérifier |
| 4 | Bug pré-existant chaîne joystick→arbitrage M1 (sans rapport avec le lot) | `PRG_06_Outputs.Data.M1RelayFwd/Rev` | doit suivre la commande joystick | non vérifié | ❓ à vérifier |
| 5 | Bundle réimporté n'est pas réellement le dernier (cache CODESYS, mauvais fichier) | horodatage bundle vs date de génération | doit correspondre | non vérifié | ❓ à vérifier |
| 6 | Watch/vue figée sur une valeur en cache (pas un vrai blocage) | rafraîchissement de la vue | doit évoluer si on force un scroll/reconnect | non vérifié | ❓ à vérifier |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
[Joystick opérateur] --consigne descente--> [FB_Joystick / arbitrage M1]
    --> [PRG_04_Treuils_Benne : EffectivePermitM1_Descend, StartStop, StepNumber]
    --> [PRG_06_Outputs.Data.M1RelayFwd/Rev] ✅ AUCUNE écriture du lot ici (diff vérifié)
    --> [FB_SimBench.M1_RelayFwd/M1_RelayRev (VAR_INPUT, lu seul)] ✅ non modifié
    --> [instSimEncoderM1 (FB_Sim_Encoder)] ✅ appel non modifié, mêmes paramètres qu'avant
    --> [Winch.COD1_PosValue := instSimEncoderM1.RawPosOut] ✅ ligne non touchée
    --> [HwSim.Winch.COD1_PosValue] --sélecteur WinchInputSourceSimulated--> [HwIn.Winch.COD1_PosValue]
    --> [instEncoderM1 (FB_Encoder facade)] --> [Data.EncoderM1.Measurement.CablePosM]
    --> [FB_WinchStateProjection : WinchM1State.Position_M] --> [GVL_IHM / IHM : M1TreuilRetenue.State.Position_M]
```

**Résumé une ligne** : `[Joystick] → [Arbitrage/PRG_04] → [PRG_06.M1RelayFwd/Rev] ✅non touché → [FB_SimBench(lu seul)] ✅ → [instSimEncoderM1] ✅ → [HwSim/HwIn selecteur] ❓à vérifier → [IHM] ❌ figé`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Diff exhaustif du lot (`git diff` sur FB_SimBench.st/GVL_Simulation.st/PRG_02_Acquisition.st) :
  aucune ligne touchant M1_RelayFwd, M1_RelayRev, Winch.COD1_PosValue, ou l'appel
  `instSimEncoderM1(...)` — confirmé par grep ciblé (voir journal).
- `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` : PASS 0 erreur après
  chaque modification de ce lot — élimine une rupture de câblage structurel silencieuse.
- Bundle régénéré et frais (`generate_codesys_bundle.py` → PASS) à chaque étape.

### Chronogramme
Non disponible — aucun snapshot CSV `GVL_Troubleshooting` acquis à ce stade (variable
`M1TreuilRetenue.State.Position_M` / `SimWinchActive` à vérifier dans la liste avant de
demander un snapshot, cf. Étape 4bis de la méthode).

## 7. 🏁 Conclusion

- **Cause racine** : NON CONFIRMÉE À CE STADE. Le diff exhaustif élimine formellement toute
  écriture directe du lot sur la chaîne M1. Deux hypothèses restent ouvertes et doivent être
  vérifiées par l'utilisateur avant d'aller plus loin : (H2) effet de bord d'un plantage tâche
  par l'ancien modèle M2 non borné — déjà corrigé, à retester ; (H3) absence de front
  OFF→ON sur `SimulationModeActive` empêchant l'armement de `SimWinchActive` (routage vers
  HwReal, non câblé, donc figé) — comportement documenté et **pré-existant**, sans rapport
  avec ce lot.
- **Statut** : OUVERTE — en attente de vérification H2/H3 par l'utilisateur.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : vérifier `Device.Application.GVL_Simulation.SimWinchActive`
  dans le Watch. Si `FALSE` pendant que `SimulationModeActive=TRUE` : forcer un vrai front
  OFF→ON de `SimulationModeActive` (repasser à 0 puis 1) pour ré-armer les 4 domaines Sim*Active
  — comportement documenté `AF_Partie-13 §5` et commenté dans `PRG_02_Acquisition.st:83-84`,
  aucun code à toucher.
- **Option 2 (définitif)** : si H2/H3 sont écartées par la vérification et que M1 reste figé
  même avec un vrai front + bornage M2 actif, il faudra un snapshot `GVL_Troubleshooting` ciblé
  (ajout de `SimWinchActive`, `M1_RelayFwd/Rev`, `instSimEncoderM1.RawPosOut` si absents de la
  liste actuelle) pour trancher par preuve plutôt que par inférence.
- **⚠️ Validation requise** : [humaine] — aucune modification de code tant que H2/H3 ne sont
  pas vérifiées.

## 9. ✅ Vérification de la correction / non-régression

En attente du retest utilisateur.

## 10. 📝 Journal (chronologique)

- 2026-09-14 : Fiche créée. Diff exhaustif du lot confirmant zéro écriture sur M1. Hypothèses
  H2 (plantage tâche, désormais corrigé par bornage ±0.6m) et H3 (absence de front
  SimulationModeActive) proposées comme pistes prioritaires à vérifier par l'utilisateur avant
  toute nouvelle modification de code.
