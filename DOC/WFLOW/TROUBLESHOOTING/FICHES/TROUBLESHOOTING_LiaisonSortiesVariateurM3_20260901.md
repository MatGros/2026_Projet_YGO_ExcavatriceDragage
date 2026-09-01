# 🕵️ Session de Troubleshooting — Liaison sorties variateur M3 (mot de commande non abouti)

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/`
> 📅 Date : 2026-09-01 · 🧊 Situation : [CODE STATIQUE] · 📄 Statut : [OUVERTE — en cours de prise en charge T217/Codex]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Analyse statique de `CODE/M_MAIN/PRG_06_Outputs.st` (rapport QC orchestrateur, suite signal utilisateur
sur l'interdiction de déclarer des sorties hardware en `VAR_OUTPUT` d'un PROGRAM — règle §3bis).

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Source</nobr> |
|---|---|---|---|
| Commande variateur M3 (locale PRG_06) | `M3_DriveControlWord` (VAR_OUTPUT L47, L266) | écrite, jamais reliée au matériel | PRG_06_Outputs.st |
| Consigne fréquence M3 (locale PRG_06) | `M3_DriveFreqCmdWord` (VAR_OUTPUT L48, L267) | écrite, jamais reliée au matériel | PRG_06_Outputs.st |
| Sortie variateur M3 (matériel, CSV) | `M3_CommandWord` (0x3101, %QW6) | **jamais assignée dans CODE/** | Device_IO_20260831.csv:190 |
| Sortie variateur M3 (matériel, CSV) | `M3_SetpointFrequencyHz` (0x3100, %QW7) | **jamais assignée dans CODE/** | Device_IO_20260831.csv:207 |
| Stub linter | `M3_CommandWord`, `M3_SetpointFrequencyHz` | cohérents avec CSV | GVL_Device_IO.st:88-89 |

## 2. 🎯 Symptôme

Le mot de commande variateur M3 sort de `PRG_06` dans des variables locales `M3_DriveControlWord`/
`M3_DriveFreqCmdWord`, mais les points matériels réels `M3_CommandWord`/`M3_SetpointFrequencyHz`
ne sont **jamais écrits** → le variateur M3 risque de ne pas recevoir sa commande (câblage abouti
par mapping CODESYS manuel à vérifier sur export frais).

## 3. 🧩 Indices / historique

- G200 (L9) : `M3_DriveControlWord` et `M3_DriveFreqCmdWord` — « Not found in I/O map by exact name ».
- G350 (collision noms HW) : PASS → les noms `M3_Drive*` ne collisionnent pas (CSV utilise `M3_CommandWord`).
- grep `M3_CommandWord`/`M3_SetpointFrequencyHz` dans CODE/ : 0 assignation.
- Règles : `CODE_QUALITY_STANDARDS.md:459-461` — un PROGRAM ne déclare jamais de variable portant
  le nom exact d'un point matériel (sauf PRG_02_Acquisition).

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | `M3_Drive*` sont des noms locaux arbitraires, pas des points matériels | grep CSV | absent du CSV | absents | ✅ |
| 2 | La commande variateur M3 aboutit via un mapping CODESYS manuel (non vérifiable en ST) | export CODESYS frais | `M3_CommandWord` mappé | **à vérifier (export périmé non lu)** | ❓ |
| 3 | Le câblage variateur M3 est rompu | assignation `M3_CommandWord` dans CODE/ | présente | 0 | ❌ |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
instTranslationOutputInterlockM3.DriveControlWord
  → [M3_DriveControlWord : WORD] (VAR_OUTPUT PRG_06 L266)   // écrite
      → ??? nulle part côté matériel                        ❌
M3_CommandWord (0x3101, %QW6, CSV)                          // jamais écrite ❌
M3_SetpointFrequencyHz (0x3100, %QW7, CSV)                  // jamais écrite ❌
```

**Résumé une ligne** : `Interlock.DriveControlWord → M3_DriveControlWord (locale) ✗ M3_CommandWord (sortie variateur non écrite)`

## 6. 📊 Données / interactions & chronogramme

### Lectures & essais
- grep `M3_DriveControlWord|M3_DriveFreqCmdWord|M3_CommandWord|M3_SetpointFrequencyHz` dans CODE/ : seuls les 2 `M3_Drive*` (PRG_06 L47-48, L266-267).
- G200 --report : 2× [WARN L9] sur `M3_Drive*` + 2× [WARN L11] commentaire polarité manquant.
- CSV Device_IO_20260831 : `M3_CommandWord` (L190), `M3_SetpointFrequencyHz` (L207).

## 7. 🏁 Conclusion

- **Cause racine (probable)** : chaîne variateur M3 coupée entre la logique (`M3_Drive*` locales) et
  les points matériels (`M3_CommandWord`/`M3_SetpointFrequencyHz`). **Le lien physique final dépend
  d'un mapping CODESYS manuel — à confirmer sur export frais** (l'export du dépôt est périmé, non lu).
- **Statut** : OUVERTE — prise en charge T217 (contrat validé APPROVED, exécution Codex).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : vérifier sur export CODESYS frais si le variateur M3 reçoit
  réellement sa commande (mapping manuel). Impact : confirme/découvre la rupture.
- **Option 2 (définitif, conforme §3bis)** : PRG_06 écrit **directement** dans les globals matériels
  `M3_CommandWord := instTranslationOutputInterlockM3.DriveControlWord;` et
  `M3_SetpointFrequencyHz := instTranslationOutputInterlockM3.DriveFreqCmdWord;`, suppression des
  variables locales `M3_Drive*`. ⚠️ Validation requise : [humaine] + [mapping EtherCAT inchangé].

## 9. ✅ Vérification de la correction / non-régression

- Lien : suppression de `M3_Drive*` → grep 0 occurrence + G350/G200 PASS + essai variateur réel.
- Ne pas casser : frein M3 (`M3_BrakeRelease_RQ`), AU (`PowerKeepAlive_*`), M1/M2, bus Data.

## 10. 📝 Journal (chronologique)

- 2026-09-01 : signature rapport QC orchestrateur (suite signal utilisateur §3bis) → fiche créée ;
  contrat T217 déjà présent (validé APPROVED, exécution Codex) → pas de nouvelle tâche.

---

📖 Documentation : `GUIDE_Troubleshooting.md`
