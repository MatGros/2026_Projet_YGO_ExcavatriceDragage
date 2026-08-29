# CONSIGNE D'EXÉCUTION — T181-11 : Cadrage matrice de maintenance N1/N2

**Pour : Codex Terra ou Claude (tâche doc/analyse).** À coller tel quel.
**ARRÊT VALIDATION HUMAINE** en fin de tâche — aucune écriture `CODE/`, aucun commit.

---

## 1 · Rôle & règles

- Expert Senior Automatisme + sécurité machine (bypass de sécurité en maintenance = zone critique). FR, concis.
- Lis **d'abord** : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
- Livrable = **note de cadrage** + **section AF-05**. Aucune écriture `CODE/`.
- Un `Bypass*` sans mode d'appartenance clair, un conflit avec une autre limite (butée mécanique) → **remonter**, ne pas trancher seul.

## 2 · Contrat

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-11_MATRICE_MAINT_N1_N2.yaml` — **AC1 à AC8**.

## 3 · Documents de référence

| # | Document | Pour |
|---|---|---|
| 1 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md` §1 (D15), §7 Phase C | contexte, décisions Q8 |
| 2 | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T175.yaml` (AC4) | MAINT_N1/N2 confirm benne — à aligner |
| 3 | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` (bloc `Bypass*` l.61-95) | les ~18 bypass actuels |
| 4 | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (zone bypass ~l.554-627) | usage des bypass |
| 5 | `CODE/F_MODES/FB_Modes.st`, `CODE/F_MODES/E_Mode.st` | modes MAINT_N1 / MAINT_N2 / DISABLE |
| 6 | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` (`InReferencingMode`, `TopLimitM`, `BypassTopLimitSoftware`) | override FDC logiciel |
| 7 | `DOC/AF/AF_Partie-05_*` (la plus haute version) | format AF-05 |
| 8 | `DOC/STDS/NAMING_CONVENTION.md` §Variables IHM (NC-060) | noms boutons IHM |

## 4 · Objectif mesurable

Note de cadrage — à créer : `CADRAGE_T181-11_MATRICE_MAINT.md` dans le dossier `DOC/WFLOW/AUDITS/DESIGN/` :

1. **Inventaire exhaustif** des `Bypass*` du périmètre treuil (`FB_Safety_Winch`, `PRG_04`, `FB_Modes`) : nom, fichier:ligne, condition d'activation actuelle. Attendu : ~18-20 lignes.
2. **Matrice cible mode × bypass** : chaque `Bypass*` rattaché à `MAINT_N1`, `MAINT_N2`, aux deux, ou **RETIRÉ** (avec justification). **Aucun bypass sans mode.**
3. **Colonne « N1 momentané / N2 latché »** par bypass concerné : N1 = bouton IHM maintenu (relâche → bypass retombe) ; N2 = latché jusqu'à sortie de mode.
4. **Règle de bascule de mode** : expression booléenne — passage en/hors N1/N2 refusé si contacteurs non retombés **ET** frein non serré (même composite que l'arrêt confirmé Méca B, `FB_Safety_Winch.st:247`).
5. **Override FDC logiciel** : N1 momentané, N2 latché, plafond physique = **capteur homing haut 8,5 m** ; fonctionnement normal arrêt **7,5 m** ; comportement au relâchement (retour immédiat 7,5 m). Spécifier le champ `DriveRequest.TopLimitM` alimenté par `PRG_04` (7,5 / 8,5).
6. **Re-homing obligatoire** au retour d'un mode ayant utilisé un override FDC : condition + déclenchement.
7. **Alignement T175 AC4** : trancher « MAINT_N1 **et** N2 » ou « N2 seul » pour confirm/ouvre benne (TC-P10-030) et le renvoyer explicitement à l'implémentation T181-14.
8. **Section AF-05** rédigée (matrice de maintenance treuil), cohérente avec la note.

## 5 · Restitution

- Les 2 fichiers.
- `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T181-11_MATRICE_MAINT_N1_N2.yaml` (PASS).
- `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py`.
- Points d'interprétation → orchestrateur.
- **STOP validation humaine.** Aucun commit.
