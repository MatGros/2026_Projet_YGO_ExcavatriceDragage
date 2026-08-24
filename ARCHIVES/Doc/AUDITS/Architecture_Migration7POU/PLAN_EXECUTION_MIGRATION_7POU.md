# Plan d'exécution — Migration vers l'architecture 7 POU

> **Décision source :** `DOC/WFLOW/AUDITS/Architecture/RU_C4_ARCHITECTURE_PROCEDES.md` (actée).
> **Architecture cible :** `DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.
> **Statut :** plan de pilotage. Chaque lot exige la validation utilisateur avant lancement.

---

## 1. Principe d'ordonnancement des lots

L'ordre n'est pas négociable : il découle d'une seule règle de sécurité.

> **On ne renomme jamais avant d'avoir supprimé les cycles.**
> Renommer d'abord transformerait silencieusement un flux critique en valeur du scan précédent.

```text
M0  audit gel de l'état        (lecture seule, aucune écriture)
     ↓
M1  fusion Acquisition         (supprime les instances dupliquées)
     ↓
M2  fusion Modes + Cycle       (regroupe autorisations et séquences)
     ↓
M3  Treuils + safety M1/M2     (supprime le cycle Safety ↔ Treuils)
     ↓
M4  Translation + safety M3    (supprime le cycle Safety ↔ Translation)
     ↓
M5  Outputs + agrégation       (PowerCutOff agrégé par la barrière finale)
     ↓
M6  Supervision + Troubleshoot (lecture seule stricte)
     ↓
M7  renumérotation 01..07      (uniquement quand plus aucun cycle)
     ↓
M8  conversion CFC natif .xml  (une page à la fois, import humain)
```

⛔ **M7 est verrouillé** tant que `check_linkage.py` signale un cycle inter-programme.
⛔ **M8 est verrouillé** tant que M7 n'est pas validé et importé dans CODESYS.

---

## 2. Table des lots, agents et évaluation

| Lot | Objet | Criticité | Stratégie | Agent producteur | Revue |
|---|---|---|---|---|---|
| **M0** | Audit de gel : inventaire exhaustif avant/après par POU | C1 | lecture seule | `worker` (doc) | aucune |
| **M1** | Acquisition absorbe codeurs, diagnostics, auxiliaires, AU | C4 | rebuild | `worker` fort | double A/B |
| **M2** | Modes absorbe le séquenceur Cycle | C3 | patch | `worker` fort | 1 reviewer |
| **M3** | Treuils/Benne absorbe la safety M1/M2 | C4 | rebuild | `worker` fort | double A/B |
| **M4** | Translation absorbe la safety M3 | C4 | rebuild | `worker` fort | double A/B |
| **M5** | Outputs agrège `PowerCutOff` | C4 | patch | `worker` fort | double A/B |
| **M6** | Supervision absorbe Troubleshooting | C2 | patch | `worker` | 1 reviewer |
| **M7** | Renumérotation `PRG_01..07` + fichiers | C3 | patch | `worker` | 1 reviewer |
| **M8** | Conversion CFC natif `.xml`, page par page | C3 | patch | `worker` | 1 reviewer par page |

### Règle multi-modèle appliquée (`AGENT_ROLES.md`)

- **C4** → double revue A/B parallèle obligatoire, reviewers en contexte frais, sans se voir.
- **C2-C3** → 1 reviewer read-only, advisory.
- Le producteur ne valide **jamais** son propre travail.
- L'orchestrateur lit le `git diff` réel avant de déclarer un lot terminé.

---

## 3. Grille d'évaluation d'un agent (identique pour tous les lots)

Chaque restitution d'agent est notée sur 6 axes. **Un seul axe rouge = lot refusé.**

| Axe | Question | Preuve exigée | Rouge si |
|---|---|---|---|
| **A1 — Périmètre** | L'agent a-t-il touché uniquement `scope.allowed` ? | `git diff --name-only` | Un fichier hors périmètre modifié |
| **A2 — Critères** | Chaque `AC` du contrat est-il satisfait et prouvé ? | Sortie de commande citée par `AC` | Un `AC` déclaré sans preuve exécutée |
| **A3 — Conservation** | Chaque `must_survive` est-il vérifiable dans le code final ? | Ligne de code citée | Une garantie perdue silencieusement |
| **A4 — Liaison** | `check_linkage.py --report` PASS et bloc collé ? | Bloc `Auto-vérification liaison` | KO, ou bloc absent/recopié d'un run antérieur |
| **A5 — Producteur unique** | Aucune donnée n'a deux écrivains actifs ? | `check_linkage.py` L10 + diff | Ancien et nouveau producteur coexistent |
| **A6 — Devoir d'alerte** | Les incohérences rencontrées ont-elles été remontées ? | Section « risques résiduels » | Un blocage contourné par une hypothèse inventée |

### Verdicts possibles

| Verdict | Signification | Suite |
|---|---|---|
| ✅ **PASS** | 6 axes verts, revue indépendante d'accord | Lot suivant |
| ⚠️ **MAJOR** | Écart corrigeable dans le même contrat | Correction, puis re-revue |
| 🚨 **BLOCK** | Écart safety, ou spec manquante | Rollback du lot, arbitrage utilisateur |

### Règle de rollback

Un lot `BLOCK` est **entièrement annulé**, jamais corrigé partiellement.
Précédent : le patch C4.1a avait été rollbacké car `CmdReset` n'avait plus de producteur — un
reset serait devenu inopérant. Un demi-lot safety est plus dangereux qu'un lot absent.

---

## 4. Séquence d'exécution détaillée par lot

### M0 — Audit de gel *(C1, lecture seule)*

**But :** photographier l'état exact avant migration, pour pouvoir prouver la conservation.

Produit un inventaire par POU : instances déclarées, variables publiques produites, variables
lues chez les autres, et la liste des consommateurs de chacune. Sans cette photo, aucun
`must_survive` des lots suivants n'est vérifiable.

Aucune écriture dans `CODE/`.

### M1 — Acquisition unifiée *(C4, rebuild)*

**Absorbe :** `PRG_01_Diagnostics`, `PRG_02_Encoders`, `PRG_AUXILIARY_CFC`.

Points durs :
1. Six instances dupliquées à unifier (`instEncoderAbsM1/M2`, `instEncoderScaleM1/M2`, `instHomingM1/M2`) et `instJoystick`.
2. ~~Le homing lit aujourd'hui le mode de marche → dépendance vers un POU aval.~~ **TRANCHÉ (A-01)** : le
   homing migre en M3 avec les treuils (option C) — il ne reste donc pas ici, la dépendance vers
   Modes (rang 03) est lue depuis Treuils (rang 04). La mesure reste en Acquisition, le recalage
   part avec le mouvement qu'il recale. Preuve : REGISTRE_ARBITRAGES_MIGRATION §A-01.
3. L'état AU devient un fait d'entrée qualifié ici (RU §3.3), l'action reste en `Outputs`.

⚠️ Point 2 résolu par conception (A-01). Au lancement de M1, appliquer aussi A-16 (DUT orphelins/
doublons : `ST_Diag_Device`, `ST_DeviceDiagnostics`, DUT IHM-only) et le contrat DUT
`ST_EncoderMeasurements` (AF06 §2ter) comme squelette d'échange inter-blocs.

### M2 — Modes + Cycle *(C3, patch)*

`FB_Cycle` reste une machine d'état ST encapsulée, instanciée dans la page Modes/Cycle.
Le séquenceur produit des demandes ; il ne commande aucune sortie.

### M3 — Treuils + Benne + safety M1/M2 *(C4, rebuild)*

**C'est le lot qui supprime le cycle Safety ↔ Treuils.**

`FB_Safety_Winch` M1 et M2 sont instanciés dans la page Treuils, câblés en parallèle des blocs
métier. Les lectures croisées disparaissent : la safety et ce qu'elle surveille sont sur la
même page, donc dans le même ordre topologique CFC.

`must_survive` critique : chaque mécanisme Méca A→E, les bits 14/15, `ForbidAscent`,
`ForbidDescent`, et la demande `PowerCutOff` M1/M2.

### M4 — Translation + safety M3 *(C4, rebuild)*

**Supprime le cycle Safety ↔ Translation.** Même principe que M3.

`must_survive` : Méca A/B M3, bit 6 butées extrêmes, bit 7 mot capteurs incohérent, et la
demande `PowerCutOff` M3.

### M5 — Outputs agrégateur *(C4, patch)*

`PRG_06_Outputs_LD` agrège les demandes `PowerCutOff` publiées par M3, M4 et la chaîne AU.
Reste l'unique producteur de chaque commande physique.

⚠️ `PRG_SAFETY_CFC` lit aujourd'hui `GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd`,
soit un accès à une instance interne d'Outputs. Ce lien doit devenir un contrat public
explicite, ou être supprimé, avant clôture de M5.

### M6 — Supervision + Troubleshooting *(C2, patch)*

Fusion des deux pages d'observation. Lecture seule stricte : aucune écriture de commande,
configuration ou interlock. C'est le critère d'acceptation principal.

### M7 — Renumérotation *(C3, patch)*

Renommage fichiers + POU vers `PRG_01_Inputs_LD` … `PRG_07_Supervision`.
Contrainte structurelle : nom de fichier = nom de POU, suffixe = langage généré dans le bundle.

**Précondition bloquante :** zéro cycle inter-programme prouvé.

### M8 — Conversion CFC natif *(C3, patch, itératif)*

Une page `.xml` à la fois, sur le modèle
`TOOLS/SAMPLES_XML_CODESYS/PRG_CFC_3FB.xml`.

Après chaque page : bundle → linkage → import CODESYS manuel → validation utilisateur.
Jamais deux pages converties dans le même lot : l'import CODESYS est manuel et doit rester
diagnosticable page par page.

---

## 5. Contrats de tâche

Un fichier `TASK_CONTEXT` par lot, dans `DOC/CHECKLISTS/TASK_CONTEXT/` :

| Lot | Contrat |
|---|---|
| M0 | `TASK_CONTEXT_M0_AUDIT_GEL.yaml` |
| M1 | `TASK_CONTEXT_M1_ACQUISITION_UNIFIEE.yaml` |
| M2 | `TASK_CONTEXT_M2_MODES_CYCLE.yaml` |
| M3 | `TASK_CONTEXT_M3_TREUILS_SAFETY.yaml` |
| M4 | `TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml` |
| M5 | `TASK_CONTEXT_M5_OUTPUTS_POWERCUTOFF.yaml` |
| M6 | `TASK_CONTEXT_M6_SUPERVISION.yaml` |
| M7 | `TASK_CONTEXT_M7_RENUMEROTATION.yaml` |
| M8 | `TASK_CONTEXT_M8_CFC_NATIF.yaml` |

Validation d'un contrat avant lancement :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/CHECKLISTS/TASK_CONTEXT/<fichier>.yaml
```

---

## 6. Invariants opposables à tous les lots

Aucun agent ne peut les contourner, quelle que soit sa consigne :

- `Outputs` est l'unique producteur de chaque commande physique.
- Aucun redémarrage automatique après défaut.
- `Reset` sur front : cause disparue **et** appui conscient.
- Aucun retard d'un scan pour `Reset`, `SafeStop`, `PowerCutOff`, une commande ou une sortie.
- Une page CFC ne contient ni `IF`, ni calcul inline, ni fusion de commandes.
- Le troubleshooting n'écrit jamais une commande, une configuration ou un interlock.
- Aucun commit sans validation humaine explicite.
- Spec manquante ou ambiguë → **arrêt et remontée**, jamais d'hypothèse inventée.
