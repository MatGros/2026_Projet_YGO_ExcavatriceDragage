from pathlib import Path

BASE = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
ARCH = BASE / "DOC/WFLOW/TASKS/T000-AGY02_GEMINI_4_HYDRO_CHALLENGE_SIMU_M3/ARCHIVES"
ARCH.mkdir(parents=True, exist_ok=True)

def read_text(rel: str, start: int = 1, end: int | None = None) -> str:
    p = BASE / rel
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    if end is None:
        end = len(lines)
    chunk = lines[start - 1 : end]
    return "\n".join(f"{i+start}: {l}" for i, l in enumerate(chunk))

# 1. Prompt Tri Historique
t417_dir = BASE / "DOC/WFLOW/TASKS/T_TEMP (A TRIER)/T417_ANALYSES"
files_t417 = sorted([p.name for p in t417_dir.iterdir()]) if t417_dir.exists() else []
passation = read_text("DOC/WFLOW/TROUBLESHOOTING/FICHES/PASSATION_T417_SimM3_20261030.md", 1, 213)
reprise = read_text("DOC/WFLOW/TASKS/T_TEMP (A TRIER)/T417_ANALYSES/REPRISE_PREUVES_20261030.md", 1, 140)

p1 = f"""# Mission 1 — Tri Historique T417 & Plan d'Echantillonnage (Lecture Seule)

Tu es un Expert QA & Audit Historique.
Regle absolue : Clause Zero Confiance. Ne prends AUCUNE affirmation narrative pour vraie sans preuve code/trace.

## Symptôme cible
Le chariot M3 depasse parfois la butee electrique a petite vitesse jusqu'au choc mecanique — mais la simulation actuelle s'arrete proprement.

## Inventaire des artefacts existants dans T417_ANALYSES ({len(files_t417)} entrees)
{chr(10).join('- ' + f for f in files_t417)}

## Extrait PASSATION_T417_SimM3_20261030.md
```markdown
{passation}
```

## Extrait REPRISE_PREUVES_20261030.md
```markdown
{reprise}
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Tri des pistes deja testees** : classe-les en 3 categories (`Verifie avec preuve`, `Hypothese non prouvee`, `Contredit / Obsolete`).
2. **Angles morts sur la petite vitesse & choc butee** : qu'est-ce que l'historique T417 n'a PAS encore teste ou a melange (Auto vs Manu, petite vitesse 5-10 Hz, coupure frein, chariot libre) ?
3. **Plan d'echantillonnage (10-20%)** : quels 3 a 5 fichiers precis parmi les `INTEGRATION_M3_CYCLE_REJEU_*` et `REVIEW_*` faut-il auditer en priorite pour verifier s'il y a des faux verts ?
"""
(ARCH / "PROMPT_OLLAMA_1_TRI_HISTORIQUE.md").write_text(p1, encoding="utf-8")

# 2. Prompt Audit Chaine Automate Reelle
prg05 = read_text("CODE/M_MAIN/PRG_05_Translation.st", 470, 760)
prg06 = read_text("CODE/M_MAIN/PRG_06_Outputs.st", 405, 470)

p2 = f"""# Mission 2 — Audit Chaine Automate Reelle M3 (Lecture Seule)

Tu es un Expert Automatisme Industriel CODESYS ST & Securite Machine.
Regle : cite toujours `fichier:ligne` pour chaque affirmation. Zero complaisance.

## Probleme etudie
En reel, le chariot M3 depasse parfois la butee electrique (ex. Tremie ou Maintenance) a petite vitesse jusqu'au choc mecanique.
Note de trace reelle (trace 27 du 2026-09-04) :
- 26353 ms : Tremie=0, ContactFrein=1, Freq=1000 (10.00 Hz), Cmd=1, ErrorId=0
- 26438 ms : Tremie=1, ContactFrein=0, Freq=1000 (10.00 Hz), Cmd=0, ErrorId=64
- 26553 ms : Tremie=0 (perdu!), ContactFrein=0, Freq=913, Cmd=0, ErrorId=64

## Code reel PRG_05_Translation.st (lignes 470-760)
```iecst
{prg05}
```

## Code reel PRG_06_Outputs.st (lignes 405-470)
```iecst
{prg06}
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Chemin exact de coupure en butee** (variateur + frein + safety) en petite vitesse (Manu vs SEMI_AUTO).
2. **Failles ou latences possibles** dans ce code reel qui pourraient laisser le chariot franchir la butee electrique a petite vitesse (ex. scan delay, conditionnement de `M3_TremieHardStopActive`, `DelayMotorDecel`, hysteresis/perte capteur, sens Maintenance non protege par HardStop ?).
3. **Points a verifier dans `FB_Translation.st` et `FB_Safety_Translation.st`** (liste ciblee, max 5 points).
"""
(ARCH / "PROMPT_OLLAMA_2_AUDIT_CHAINE_AUTOMATE.md").write_text(p2, encoding="utf-8")

# 3. Prompt Audit Simulateur Physique
fb_sim_tr = read_text("CODE/L_SIMULATION/FB_Sim_Translation.st", 240, 420)
fb_sim_brk = read_text("CODE/L_SIMULATION/FB_Sim_TranslationBrake.st", 1, 96)
fb_sim_drv = read_text("CODE/L_SIMULATION/FB_Sim_TranslationDrive.st", 1, 62)

p3 = f"""# Mission 3 — Audit Modele Physique SimBench M3 (Lecture Seule)

Tu es un Expert Cinématique / Physique Industrielle & Simulation Temps Reel.
Regle : prouve par les equations du code fourni. Zero approximation.

## Probleme etudie
Le chariot M3 reel depasse parfois la butee electrique a petite vitesse jusqu'au choc mecanique.
Or la simulation actuelle s'arrete proprement avant le choc.

## Code reel FB_Sim_TranslationBrake.st
```iecst
{fb_sim_brk}
```

## Code reel FB_Sim_TranslationDrive.st
```iecst
{fb_sim_drv}
```

## Code reel FB_Sim_Translation.st (lignes 240-420 : dynamique + butee)
```iecst
{fb_sim_tr}
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Calcul exact de distance d'arret du modele actuel** en petite vitesse (5 Hz et 10 Hz, avec `Gain=0.02 m/(Hz.s)`, `DecelRate=25 Hz/s`, `CloseDelay=0.09 s`, `BrakeDecel=2.0 m/s^2`, `EndStopMargin=0.5 m`). Montre pourquoi la simu s'arrete proprement loin de la butee.
2. **Pourquoi `ObsCartFree` (chariot libre) ne se declenche pas ou s'arrete trop tot** dans le scenario de coupure en butee.
3. **Registre des hypotheses physiques manquantes ou sur-idealisees** (max 6 hypotheses classees par impact probable sur un depassement a petite vitesse : ex. retard ouverture/fermeture frein, couple de freinage reel, inertie/glissement rail, maintien ordre marche, latence capteur/scan, pente/charge suspendue).
"""
(ARCH / "PROMPT_OLLAMA_3_AUDIT_SIMU_PHYSIQUE.md").write_text(p3, encoding="utf-8")

print("Prompts generated successfully.")
