# 📐 Standard Universel de Sortie Agent (TDAH-Friendly, Zéro Tableau, Évaluable)

> **Document de Référence** : Norme de communication des agents du projet Excavatrice de Dragage.  
> **Objectif** : Zéro surcharge cognitive, absorption visuelle en 5 secondes, traçabilité temporelle et traitement automatisable déterministe.  
> **Règle Typographique** : **ZÉRO TABLEAU MARKDOWN** pour les listes d'invariants (proscrit sur mobile et console CLI) ➔ Utiliser exclusivement une liste numérotée avec statuts émojis entre crochets.

---

## 🧭 Règle des 3 Niveaux d'Absorption Visuelle

Tout agent (spécialiste FB, reviewer, challenger ou orchestrateur) structure impérativement sa restitution selon ces 3 niveaux :

```text
Niveau 0 (1 seconde)   ➔ BANNIÈRE VISUELLE TDAH (Émoji géant + Verdict + 1 phrase d'impact + Durée/Horodatage)
Niveau 1 (10 secondes)  ➔ LISTE NUMÉROTÉE D'INVARIANTS (1) 2) avec statut [✅ PASS / ❌ FAIL / ⚪ N/A] + Ancrage)
Niveau 1 bis (Option)   ➔ 💬 ARGUMENTAIRE TECHNIQUE (Concis ~3-4 lignes par défaut, extensible si justification physique requise)
Niveau 2 (30 secondes)  ➔ PLAN D'ACTION CHIRURGICAL (Quoi, Où, Comment + Outils Déterministes + Risque si ignoré)
```

---

## 📤 1. Format Markdown Visuel (Pour l'Humain & le Chat)

```markdown
========================================================================
🛑 VERDICT : BLOCK — Risque de mouvement intempestif en reprise secteur
========================================================================
> 🎯 **Agent** : `FB_Agent_Safety` | 📂 **Cible** : `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | 🏷️ **Tâche** : `T429`
> ⏱️ **Durée d'exécution** : 1.42s | 🕒 **Horodatage** : 2026-11-11T14:25:00Z | 🛠️ **Outil Déterministe** : `G521`

### 📋 Invariants Clés & Vérifications (Zéro Tableau — Liste Numérotée)
1. `INV-SAF-01` [✅ PASS] — AU Matériel Indépendant : Ligne KA1 câblée hors cycle CPU.
2. `INV-SAF-02` [❌ FAIL] — Réarmement sur front montant : L210 Reset câblé sur DI haut statique (`TRUE`).
3. `INV-SAF-06` [✅ PASS] — Preuve de couple frein : `TorqueProving` validé avant ouverture.
4. `INV-SAF-07` [⚪ N/A]  — Détection mou de câble : Pas d'axe vertical sur ce bloc spécifique.

### 💬 Argumentaire Technique
> [!NOTE]
> Le réarmement câblé sur un état statique (`DI_Reset`) viole l'invariant de réarmement conscient ISO 13849 : en cas d'effacement du défaut amont alors que le commutateur reste maintenu ou bloqué, la benne redémarrera immédiatement sans action volontaire de l'opérateur.
> *(Si une démonstration complexe est nécessaire, développer sans contrainte artificielle dans un sous-paragraphe technique ci-dessous).*

### 🛠️ Outil Déterministe Associé
- 🚀 **Script exécuté / requis** : `python TOOLS/AGENT_WORKFLOW/scripts/G521_check_fault_reset_not_hw_triggered.py`
- 🎯 **Preuve mécanique** : Script validé à 100 % sans recours à une interprétation LLM subjective.

### 🎯 Plan d'Action Chirurgical
- 📍 **Localisation** : `CODE/M_MAIN/PRG_04_Treuils_Benne.st`
- ⚓ **Ancre** : `IF bResetButton AND NOT bFault THEN`
- 🔧 **Action exacte** : Remplacer `bResetButton` par `instResetTrig.Q` (instance de `R_TRIG`).
- ⚠️ **Impact si ignoré** : Si l'opérateur maintient le bouton enfoncé, la benne redémarre seule à l'effacement du défaut.
========================================================================
```

---

## 📦 2. Schéma YAML Canonique (Machine-Parsable)

Placé obligatoirement dans un bloc ```yaml ... ``` en fin de restitution pour les runners automatiques et les gates CI :

```yaml
agent_evaluation:
  version: "1.1"
  agent: "FB_Agent_Safety"
  verdict: "BLOCK" # [PASS | ADVISORY | BLOCK]
  badge: "🛑 BLOCK"
  impact_line: "Risque de mouvement intempestif en reprise secteur"
  target_files:
    - "CODE/M_MAIN/PRG_04_Treuils_Benne.st"
  task_id: "T429"
  metrics:
    execution_time_s: 1.42
    timestamp: "2026-11-11T14:25:00Z"

  deterministic_tool:
    script: "TOOLS/AGENT_WORKFLOW/scripts/G521_check_fault_reset_not_hw_triggered.py"
    status: "FAIL"

  invariants_checklist:
    - id: "INV-SAF-01"
      name: "AU Matériel Indépendant"
      status: "PASS"
      icon: "✅"
      evidence: "Ligne KA1 câblée hors cycle CPU"
    - id: "INV-SAF-02"
      name: "Réarmement sur front montant"
      status: "FAIL"
      icon: "❌"
      evidence: "L210 : bReset câblé sur niveau haut"

  technical_rationale: "Violation ISO 13849 : commutateur maintenu provoque un réarmement automatique non sollicité."

  remedy:
    file: "CODE/M_MAIN/PRG_04_Treuils_Benne.st"
    context_anchor: "IF bResetButton AND NOT bFault THEN"
    exact_change: "Remplacer bResetButton par instResetTrig.Q (R_TRIG)"
    consequence_if_ignored: "Redémarrage automatique non sollicité"
```

---

## 🛠️ Matrice des Outils Déterministes par Persona

Chaque persona spécialisé s'appuie en priorité sur les scripts déterministes existants plutôt que sur des conjectures LLM :

| Persona | Outils & Scripts Déterministes Clés |
|---|---|
| **🛡️ Safety** | `G521_check_fault_reset_not_hw_triggered.py` (vérification front montant `Reset`), `check_task_contract.py` (invariants sécurité). |
| **⚙️ PLC** | `G200_check_linkage.py --report` (liaison globale & producteur unique), `generate_codesys_bundle.py`, `generate_codesys_diff_bundle.py`. |
| **🖥️ HMI** | `T356_scan_alarm_candidates.py` (scan concordances bits décodeur), `ui_layout_check.mjs` (gabarit graphique & débordement). |
| **🧪 Testing** | `py -3.13 -m pytest` (suites unitaires et non-régression), `test_codesys_compile.py`, `run_all_gates.py`. |
| **📐 Standards** | `check_document_organisation.py` (règle 1 tâche = 1 dossier), `G340_check_doc_links.py` (liens actifs), `G530_check_contract_refs.py`. |
| **🥊 Challenger** | `challenge_runner.py --check-prompt` (audit étape 0 déterministe). |

---

## 🏷️ Sémantique des Verdicts & Émojis

| Verdict | Émoji | Signification | Comportement Runner / CI |
|---|:---:|---|---|
| **`PASS`** | 🟢 | Conforme à 100 % aux invariants et standards. Aucun risque résiduel. | Code sortie `0` (Autorise la suite). |
| **`ADVISORY`** | 🟡 | Remarque d'optimisation ou bonne pratique. Pas de blocage fonctionnel. | Code sortie `0` (Avertissement informatif). |
| **`BLOCK`** | 🔴 | Invariant violé, risque sécurité, non-respect outillage ou norme T279. | Code sortie `2` (Arrêt bloquant immédiat). |
| **`N/A`** | ⚪ | Non applicable au périmètre audité. | Neutre. |

---

## 🚫 Règles de Style

1. **Zéro prose narrative introductive** : Interdit d'écrire *« Bonjour, suite à votre demande... »*. On commence directement par la bannière de verdict Niveau 0.
2. **Zéro tableau Markdown** : Utiliser la liste numérotée `1. INV-XXX [STATUS] — Description : Preuve`.
3. **Argumentaire proportionné** : Concis par défaut (~3-4 lignes). Si une démonstration physique ou calculatoire complexe est nécessaire, la développer de manière structurée sans blocage artificiel.
4. **Appel déterministe obligatoire** : Si un script Python de contrôle existe dans le tableau ci-dessus, il doit être exécuté ou cité comme preuve première.
