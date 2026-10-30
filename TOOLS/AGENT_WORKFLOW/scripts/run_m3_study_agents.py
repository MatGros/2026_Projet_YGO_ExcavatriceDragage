#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Lancement parallèle des 3 sous-agents Ollama pour l'étude T417 (Translation M3).
Modèles : deepseek-v4.1-flash:cloud et glm-5.3-flash:cloud.
"""

import os
import sys
import json
import urllib.request
import concurrent.futures

sys.stdout.reconfigure(encoding='utf-8')

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")

def read_file(path):
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    return ""

def call_ollama(name, model, system_prompt, prompt, output_path):
    print(f"[{name}] Démarrage sur modèle '{model}' (prompt {len(prompt)} car)...")
    url = f"{OLLAMA_HOST}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": system_prompt,
        "stream": False,
        "options": {
            "num_ctx": 16384
        }
    }
    req_data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=req_data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=360) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            resp_text = data.get("response", "")
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as out:
                out.write(resp_text)
            print(f"[{name}] ✅ Terminé ({len(resp_text)} car) -> {output_path}")
            return name, len(resp_text), None
    except Exception as e:
        print(f"[{name}] ❌ Erreur : {e}")
        return name, 0, str(e)

def main():
    preamble = read_file("TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md")

    # 1. Préparation Agent A : Audit Code ST
    code_sim_trans = read_file("CODE/L_SIMULATION/FB_Sim_Translation.st")
    code_sim_brake = read_file("CODE/L_SIMULATION/FB_Sim_TranslationBrake.st")
    code_simbench = read_file("CODE/L_SIMULATION/FB_SimBench.st")
    # Extraire la section M3 de SimBench (lignes ~660 à 760)
    lines_sb = code_simbench.splitlines()
    m3_simbench_snippet = "\n".join(lines_sb[655:760]) if len(lines_sb) > 760 else ""

    prompt_a = f"""# MISSION AGENT A : AUDIT CRITIQUE DU CODE ST DE SIMULATION TRANSLATION M3 (T417)

## Objectif
Analyser le code actuel de simulation de la translation M3 pour identifier les faiblesses, manques physiques et incohérences.

## Extraits de Code Sources
### 1. Extrait CODE/L_SIMULATION/FB_Sim_Translation.st
```pascal
{code_sim_trans[:6000]}
```

### 2. Extrait CODE/L_SIMULATION/FB_Sim_TranslationBrake.st
```pascal
{code_sim_brake[:4000]}
```

### 3. Extrait §3 M3 de CODE/L_SIMULATION/FB_SimBench.st
```pascal
{m3_simbench_snippet}
```

## Questions à traiter :
1. Quels sont les manques physiques majeurs dans FB_Sim_Translation ? (Inertie réelle, traînée, glissement roue libre vs freinage).
2. FB_Sim_TranslationBrake est-il fidèle à un frein à manque de courant ? Comment retombe-t-il ?
3. Le câblage des capteurs inductifs et du StatusWord dans SimBench est-il réaliste ou artificiellement figé ?
4. Proposer des recommandations architecturales concrètes pour rendre la simulation réaliste sans sur-complexifier.
"""

    # 2. Préparation Agent B : Analyse Trace Réelle
    trace_raw = read_file("TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27_wide.csv")
    # Prendre les lignes significatives (ex. début, montée consigne, apparition du bug)
    trace_lines = trace_raw.splitlines()
    trace_sample = "\n".join(trace_lines[:120]) + "\n...\n" + "\n".join(trace_lines[240:350])
    fiche_t400 = read_file("DOC/WFLOW/CONTRACTS/FICHE_T400_MODELISATION_TRANSLATION_M3.md")

    prompt_b = f"""# MISSION AGENT B : EXTRACTION CINÉMATIQUE DE LA TRACE RÉELLE TERRAIN M3 (2026-09-04)

## Objectif
Extraire précisément les métriques réelles de la trace de terrain pour calibrer le modèle fonctionnel de simulation.

## Référence FICHE_T400
{fiche_t400[:3500]}

## Extrait de la Trace Réelle (Suivi_TranslationM3bug_20260904_27_wide.csv)
```csv
{trace_sample}
```

## Questions à traiter :
1. Quelles sont les dynamiques mesurées de M3_ActualFrequencyHz par rapport à M3_SetpointFrequencyHz (rampe en Hz/s, temps de montée/descente) ?
2. À quels timestamps exacts le frein M3 s'ouvre-t-il et se ferme-t-il (M3_BrakeIsOpen_DI) ? Quelle est la fréquence à la retombée ?
3. Quelles valeurs prend M3_StatusWord et quels bits commutent lors du déclenchement du défaut ?
4. Quels sont les ErrorId Safety et State apparaissant dans la trace, à quel timestamp, et quelle en est la cause apparente ?
5. Synthétiser les constantes physiques à retenir pour le simulateur SimBench M3.
"""

    # 3. Préparation Agent C : Défauts Réels & Phénomènes Physiques
    trouble_t334 = read_file("DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md")
    trouble_fdc = read_file("DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_M3_FDC_Frein_RebondCapteurs_20260915.md")

    prompt_c = f"""# MISSION AGENT C : CARTOGRAPHIE DES DÉFAUTS RÉELS M3 & ÉMERGENCE NATURELLE (T417)

## Objectif
Identifier comment structurer la simulation pour que les anomalies constatées sur machine émergent naturellement de la physique sans artifice.

## Extraits Fiche Troubleshooting T334 (Dépassement P1 en cycle auto vs arrêt manuel)
{trouble_t334[:4000]}

## Extraits Fiche Troubleshooting FDC / Frein / Rebond Capteurs
{trouble_fdc[:3000]}

## Questions à traiter :
1. Pourquoi l'arrêt sur FDC fonctionnait en manuel mais échouait en cycle semi-auto (P1/Trémie) ? (Divergence de traitement de l'ordre d'arrêt).
2. Comment modéliser les cames inductives avec leur hystérésis et longueur finie pour qu'un dépassement de consigne produise naturellement la perte du capteur ?
3. Comment modéliser l'inertie du chariot et le temps de réponse du frein pour qu'un arrêt tardif provoque un glissement ou un choc en butée ?
4. Quels garde-fous stricts respecter pour que SimBench M3 ne perturbe jamais la logique automate de production (PRG_05, Safety, GVL_PERSISTENT) ?
"""

    tasks = [
        ("Agent_A_AuditCode", "deepseek-v4.1-flash:cloud", preamble, prompt_a, "DOC/WFLOW/ETUDES/ANALYSES_T417/RAPPORT_AGENT_A_AUDIT_CODE.md"),
        ("Agent_B_TraceReelle", "glm-5.3-flash:cloud", preamble, prompt_b, "DOC/WFLOW/ETUDES/ANALYSES_T417/RAPPORT_AGENT_B_TRACE_REELLE.md"),
        ("Agent_C_DefautsPhysiques", "deepseek-v4.1-flash:cloud", preamble, prompt_c, "DOC/WFLOW/ETUDES/ANALYSES_T417/RAPPORT_AGENT_C_DEFAUTS_PHYSIQUES.md"),
    ]

    print("🚀 Lancement parallèle des 3 sous-agents Ollama...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(call_ollama, *t) for t in tasks]
        for f in concurrent.futures.as_completed(futures):
            name, length, err = f.result()
            print(f"-> Résultat {name} : {length} caractères, erreur: {err}")

if __name__ == "__main__":
    main()
