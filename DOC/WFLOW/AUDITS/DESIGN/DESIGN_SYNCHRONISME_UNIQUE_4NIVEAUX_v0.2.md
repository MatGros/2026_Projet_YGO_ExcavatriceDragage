# ⚖️ T55 — Stratégie synchronisme unique (info / mineur / majeur / critique)

> 📄 **ÉTUDE DE CONCEPTION (zéro code)** · v0.2 (corrigé après revue indépendante 2026-08-24)
> · 📅 2026-08-24 · 🎯 T55 — formaliser une **échelle unique de gravité** pour le synchronisme
> treuils M1/M2, à la place des niveaux Warn/Fault éparpillés. Source : `FB_WinchSync.st` +
> `FB_SyncDeviation.st` + `FB_SyncContactor.st` + `FB_Safety_Winch.st` + `AF_Partie-10`.
> 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T55.
>
> 🟠 **v0.2** : intègre les 8 corrections de la revue indépendante (verdict « À CORRIGER »).

---

## 1. Constat — état actuel (valeurs vérifiées code)

`FB_WinchSync` n'expose que **2 niveaux binaires** (pas une échelle unique) :

| Signal | Bit ErrorId | Seuil | **Délai (vérifié)** | Conséquence |
|---|---|---|---|---|
| `SyncDeviationWarn` | bit0 | 0.10 m (`CfgSyncToleranceM`) | ⚠️ **instantané + latch, SANS timer** | `SyncWarn` IHM **seul** (pas de SafeStop) |
| `ContactorMismatch` | bit1 | incohérence commande | **500 ms** | SafeStop fast (via treuils) |
| `SyncDeviationFault` | bit2 | 0.50 m (`CfgSyncCriticalToleranceM`) | ⚠️ **800 ms** (`DeviationFaultTimer`) | block signal (couplage coupé) |

Et en **défense en profondeur niveau 2** (`FB_Safety_Winch`, Méca E) : `CriticalSyncToleranceM`
= **2.5 m** (le code est à jour ; la spec fiche `FB_WinchSync_v1.0` disait 2.0 m/3 s — **désuet**,
corrigé en v1.1), bit12 → SafeStop seul, bit13 → +PowerCutOff.

> 🔴 **Erreur v0.1 corrigée** : le **800 ms est sur le `Fault` (0.50 m)**, PAS sur le `Warn` (0.10 m)
> qui est **instantané + latch** (`FB_SyncDeviation` : `SyncDeviationWarn := WarnActive OR WarnLatched`,
> sans temporisation). Cette erreur avait contaminé TC-014 et la spec fiche.

**Problème** : pas de nomenclature de gravité homogène — « Warn », « Fault », « SafeStop »,
« PowerCutOff » coexistent sans échelle explicite `info → mineur → majeur → critique`. Difficile
d'expliquer à l'IHM « à quel point c'est grave » et quelle action de l'opérateur est attendue.

---

## 2. Stratégie cible — échelle unique à 4 niveaux (DIAG-ONLY)

> Convention **transverse** (même esprit que C0–C4 des tâches), appliquée au **diagnostic machine**.
> ⚠️ **`E_SyncSeverity` est un AFFICHAGE / DIAGNOSTIC uniquement — il ne pilote JAMAIS une coupure.**
> Les décisions machine restent sur les bits dédiés (`SyncDeviationWarn/Fault`, `ContactorMismatch`,
> et Méca E côté `FB_Safety_Winch`). Risque sinon : un consommateur traite « un niveau → une action »
> et **dilue la coupure rapide du `ContactorMismatch`** (500 ms → SafeStop fast).

| Niveau | Nom | Sens | Action opérateur | Exemple synchro (diag) |
|---|---|---|---|---|
| **1** | **info** | Aucune conséquence | Aucune | écart < 0.10 m, synchro active nominale |
| **2** | **mineur** | Avertissement, pas d'arrêt | Surveiller | écart 0.10–0.50 m (`SyncDeviationWarn`, **latch**) — palier 1 |
| **3** | **majeur** | Défaut synchro, arrêt de manœuvre | Diagnostic avant redémarrage | `SyncDeviationFault` (0.50 m / 800 ms) **ou** `ContactorMismatch` (500 ms) |
| **4** | **critique** | Défaut Méca E — arrêt + coupe | Maintenance, cause racine | écart ≥ 2.5 m (Méca E bit13) |

> ⚠️ **« majeur » agrège 2 sous-états à consignes machine DIFFÉRENTES** : `ContactorMismatch`
> (SafeStop fast) ≠ `SyncDeviationFault` (block signal, pas forcément SafeStop). **L'énum ne doit
> jamais transformer ces 2 consignes en une seule action** — pour l'affichage ils partagent un
> libellé « majeur », mais la logique garde les bits distincts (rule `fix:` + `guard:`).

### Correspondance avec la hiérarchie de mouvement

| Niveau | Effet (réel, porté par les bits) |
|---|---|
| info / mineur | aucun arrêt — palier 1 / blocage directionnel |
| majeur | `ContactorMismatch` → SafeStop fast ; `SyncDeviationFault` → block signal |
| critique | Méca E : SafeStop + PowerCutOff (chaîne matérielle, `FB_Safety_Winch`) |

### Contradiction `SyncActive` — résolue

Le doc v0.1 disait « couplage coupé » (Fault) ET « SyncActive indépendante ». **Vérifié code** :
`SyncActive` est **indépendant** (L62/L101-109, calculé selon Mode, jamais coupé par l'écart). Le
**problème est porté par `SyncDeviationWarn/Fault` + blocage directionnel**, pas par `SyncActive`.
→ **`SyncActive` reste l'autorisation de couplage, jamais affecté par la gravité.**

---

## 3. Implémentation proposée (hors périmètre code ici)

> 🔴 **Faisabilité corrigée** : `FB_WinchSync` **ne peut pas calculer `critique` (≥2.5 m) tout seul**
> — il n'a **aucune entrée Méca E** (`CriticalSyncToleranceM`=2.5 m et bit13 vivent dans
> `FB_Safety_Winch`, FB séparé). Pour produire `E_SyncSeverity` complet il faut **une entrée
> supplémentaire** (ex. `CritMecaE : BOOL` depuis `FB_Safety_Winch`) OU **restreindre l'énum à
> info/mineur/majeur** et laisser `critique` à l'IHM via Méca E directement.

1. **Exposer `SyncSeverity : E_SyncSeverity`** (enum `info/mineur/majeur`) **calculée par
   `FB_WinchSync`** à partir de ses 3 bits (Warn latché, Mismatch, Fault). Le `critique` (Méca E)
   reste porté par `FB_Safety_Winch` (entrée `CritMecaE` à ajouter **ou** géré hors FB).
2. **Poursuivre la suppression booléens** : soit l'énum **remplace** réellement les 2 booléens
   Warn/Fault en logique (migrer la consommation vers l'énum + masques), soit il est **IHM-additif**
   et on garde les bits. 🟠 v0.1 était auto-contradictoire (disait « remplace » ET « les bits
   restent ») — **à trancher** : une seule option.
3. **`SyncActive` indépendant** de la gravité (inchangé).
4. **IHM** : libellé du niveau au lieu de Warn/Fault génériques (cohérence
   `FB_Hmi_BannerFormatter`). La gravité reste **diag-only**.
5. **Documenter** correspondance niveau → action dans AF10 (§Alertes) + **corriger la spec fiche
   `FB_WinchSync_v1.0`** (2.0 m/3 s → 2.5 m ; 800 ms sur Fault) — **fait en v1.1 (2026-08-24)**.

---

## 4. Points de validation proposés (renumetés, hors collisions)

> ⚠️ **Correction revue** : les IDs `TC-P10-017..020` étaient **déjà pris** par `FB_Winch`
> (017/018/019) et `FB_WinchOutputInterlock` (020) dans AF10 v2.0. → **renumetés** ci-dessous.

| ID | Comportement attendu | Note latch / Reset |
|---|---|---|
| `TC-P10-037` | écart < 0.10 m → `info` | nécessite **Reset** (Warn latché retombe sur front) |
| `TC-P10-038` | `SyncDeviationWarn` (0.10 m) → `mineur` | **explicitement gérer le latch + Reset** avant chaque passage (sinon non-déterministe) |
| `TC-P10-039a` | `SyncDeviationFault` (≥0.50 m strict `>`, 800 ms) → `majeur` | scindé de Mismatch |
| `TC-P10-039b` | `ContactorMismatch` (500 ms) → `majeur` | scindé de Fault |
| ~~`TC-P10-020`~~ | ~~≥2.5 m → critique + PowerCutOff~~ | ❌ **supprimé** — hors scope `FB_WinchSync`, déjà couvert par Méca E `FB_Safety_Winch` (TC-P10-001..010) |

- **Frontière de seuil** : code utilise **`>` strict** (`DeltaPosM > 0.50`) — les TC doivent écrire
  `> 0.50 m`, pas `≥`. Aligner.
- **Latch Warn** : le `Warn` reste `mineur` tant qu'un `Reset` n'a pas coupé le latch → tout scénario
  de test multi-seuil doit injecter un **front `Reset`** entre deux passages.

---

## 5. Décision en attente (avant implémentation)

- [ ] **« majeur »** : l'énum garde-t-il les 2 sous-états (Mismatch/Fault) sous 1 libellé, ou
  faut-il **2 libellés distincts** (majeur_SafeStop / majeur_block) ? (recommandation : 1 libellé
  d'affichage + bits distincts, jamais d'unification d'action)
- [ ] **remplacement vs addition** : `E_SyncSeverity` remplace réellement Warn/Fault en logique,
  ou est additif (diag-only) ? (recommandation : diag-only — garder les bits de décision)
- [ ] **critique** : entrée `FB_Safety_Winch` dans `FB_WinchSync`, ou restreindre l'énum à
  info/mineur/majeur ? (recommandation : restreindre, laisser `critique` à Méca E)
- [ ] **`processAndSafety` variables mortes** (`ProcessPermitM1_Ascent`/`M2_Ascent`) : supprimer
  (NC-090) — **nécessite validation humaine** (code).
- [ ] Échelle généralisable à tout le diag (`FB_FbStatus`, lié T147/T149) ?

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T55 |
| FB_WinchSync | `CODE/H_TREUILS_BENNE/FB_WinchSync.st` |
| Sous-blocs | `FB_SyncDeviation.st` · `FB_SyncContactor.st` |
| Méca E (défense en profondeur) | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md` · `FB_Safety_Winch` |
| Revue indépendante | revue T55 (2026-08-24) — 8 corrections intégrées |
| Contrats FB / sévérité | `DOC/STDS/CODE_QUALITY_STANDARDS.md §2/2bis` |
