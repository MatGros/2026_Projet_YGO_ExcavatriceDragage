# 📋 PLAN D'EXÉCUTION — Permits directionnels M3 & cohérence IHM/Troubleshooting

> Version 1.0 — 2026-08-31 · Orchestrateur DSH · Décisions D1-D4 actées par l'utilisateur.

## Contexte

Constats consolidés (T184 avancé/committé, T204 reporté, vérification cohérence) :
- ✅ Remontée IHM des permits M3 cohérente (`FB_Safety_Translation:262/265` → `PRG_05:453-454` → `PRG_07:401` → `GVL_IHM.TranslationM3.Safety`).
- ❌ **3 trous d'acquisition** troubleshooting/snapshot : raquette `TranslationPontM3.Safety_300` (aucun champ permit), trace `TraceTranslation` (agrégat seul), snapshot `troubleshooting_variables.txt` (ni TremiePermit ni MaintenancePermit).
- ⚠️ **Divergence de niveau** : M3 expose le Safety brut, les treuils exposent l'Effectif.
- ⚠️ **Contrat T184 périmé** : dit `FwdPermit/RevPermit`, le code utilise `TremiePermit/MaintenancePermit`.
- ⚠️ **`MaintenancePermit` ambigu** : mélange autorisation cible + limite safety.

## 🎯 Décisions actées (utilisateur 2026-08-31)

| # | Décision | Choix | Conséquence |
|---|---|---|---|
| **D1** | Niveau exposé M3 | **Effectif** (fusion Process), aligné treuils | Phase 3 |
| **D2** | `MaintenancePermit` | **Permit effectif « pouvoir bouger »** (NON pur directionnel) — reflète les conditions réelles (défauts, fin de course, autorisation cible) ; quand l'axe est en défaut, tous les sens sont bloqués ; au retour en condition, un sens peut être permis et pas l'autre | Phase 4 |
| **D3** | Trou d'acquisition | **Combler** (Idx + snapshot) | Phase 2 |
| **D4** | Contrat T184 | **Mettre à jour** (plus de Fwd/Rev → Tremie/Maintenance) | Phase 1 |

## 🛠️ Phases d'exécution

> ENTRE CHAQUE PHASE : tests de non-régression + gates + commit + challenge par agent externe.
> Règle d'incrémentation : petits motifs testables/compilables, jamais de refactor géant.

### Phase 1 — Clôturer T184 (prérequis, débloque T204)
- 1.1 Mettre à jour le contrat T184 (`FwdPermit/RevPermit` → `TremiePermit/MaintenancePermit`).
- 1.2 Clôturer T184 (statut `✅` + contrat `VALIDATED` + retrait lock).
- Validation : `check_task_contract.py` + relecture diff + validation humaine.

### Phase 2 — Combler le trou d'acquisition troubleshooting (D3)
- 2.1 Ajouter `Idx318_TremiePermit`/`Idx319_MaintenancePermit` dans `ST_Chain_Translation_Safety.st`.
- 2.2 Câbler dans `FB_TroubleshootingView.st` (raquette TranslationPontM3.Safety_300).
- 2.3 Ajouter les permits par sens dans `ST_TraceTranslation.st` (aligner `ST_TraceWinch`).
- 2.4 Régénérer `troubleshooting_variables.txt` (`generate_variable_list_from_code.py`).
- Validation : compile + G200 + grep des nouveaux champs.

### Phase 3 — Aligner le niveau exposé M3 sur Effectif (D1) + AF §3bis
- 3.1 Fusionner Process dans le permit exposé M3 (niveau Effectif, aligné treuils).
- 3.2 Aligner `AF_Partie-11 §3bis` (retirer « modèle identique » trompeur).
- Validation : compile + G200 + G340.

### Phase 4 — Clarifier `MaintenancePermit` (D2) + T204 enforcement en gate
- 4.1 Redéfinir `MaintenancePermit` comme permit effectif « pouvoir bouger » (conditions réelles : défauts, fin de course, autorisation cible).
- 4.2 **T204** — Enforcement en gate (`FB_Translation`, modèle `FB_Winch.st:163` EffectiveSafeStop).
- Validation : TC-P11 + gates.

### Phase 5 — Validation finale
- 5.1 Bundle frais + G200 + gates palier C + tests CI.
- 5.2 Vérif diagnostic sur banc sim (blocage visible via bits permits).

## 🔒 Règle d'or
Aucune écriture de code sans validation humaine. Chaque phase validée avant la suivante.
