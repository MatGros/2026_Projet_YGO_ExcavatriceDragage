## 🟡 ADVISORY — Cadre de reclassement M3 livré ; clôture « exacte » conditionnée au fichier `.trace` réel

**Verdict :** le mapping type-de-donnée → bornes est défini et exploitable immédiatement. L'« ordre exact des 30 variables » et la correction physique du fichier ne peuvent pas être certifiés : la liste intégrale des 30 variables (nom, type PLC, Min/Max actuels, Visible) et le contenu du `.trace` ne sont pas fournis dans la mission.
**Impact :** on peut appliquer la grille de bornes dès réception de la liste ; aucune génération à l'aveugle, aucune variable inventée.
**Horodatage :** instantané, hors exécution machine.

> Note courte : le gabarit de délégation en tête est resté non renseigné (champs `[…]` vides). Exécution traitée en direct côté coordinateur, sans sous-agent.

---

### Niveau 1 — Invariants

1. **[⚪ N/A]** Groupe A booléens à borner `0/1` — 5 masquées connues (`DeadmanArmed`, `Error`, `PositionReached`, `ActiveTremie`, `ActiveMaintenance`), liste complète des booléens non fournie.
2. **[⚪ N/A]** Groupe B positions `m` — la plage axe M3 réelle n'est pas donnée ; l'échelle `-12/12` peut être correcte **si** la course est ±12 m (à confirmer), sinon à recalibrer.
3. **[⚪ N/A]** Groupe B code cible — nombre de positions `N` inconnu (borne entière `0..N-1`).
4. **[⚪ N/A]** Groupe C consignes vitesse `%` / `Hz` + `Step` + `ErrorId` — unités signées ou non et plages non fournies.
5. **[✅ PASS]** Groupe D `ActualFrequencyHz` — `Min=0`, `Max=5000` (échelle `0.01 Hz` → `0.00..50.00 Hz`), cohérent avec l'énoncé.
6. **[⚪ N/A]** Remise en `Visible=True` des 5 masquées — action identifiée, non exécutable sans fichier.
7. **[⚪ N/A]** Injection des 4 manquantes (`M3_PosPV_DI`, `TranslationState.ErrorId`, `TranslationState.EstimatedPosM3_M`, `GVL_Simulation.SimM3ObsPositionTrue_M`) — chemins identifiés, non exécutable sans fichier.
8. **[✅ PASS]** Principe d'ordre par groupe de type/d'échelle — défini ci-dessous.

---

### Niveau 1 bis — Argumentaire technique

Le défaut racine est une échelle unique `-12/12` appliquée à des populations hétérogènes : écrasement des booléens (0/1 dans 24 unités) et saturation des grandeurs `0..100` / `0..5000`. La correction consiste à **segmenter par domaine physique** et à rattacher chaque variable à son groupe avant d'assigner `Min/Max`. Le groupe D est le seul entièrement spécifié (`0..5000`). Les groupes A/B/C exigent les métadonnées réelles : sans la plage mécanique de l'axe (B) ni le nombre de pas/codes (B, C), toute borne chiffrée serait une inférence non prouvée — je la marque explicitement comme hypothèse.

---

### Niveau 2 — Plan d'action chirurgical

1. **Groupe A — Booléens (commande, capteur, frein M3)**
   - *Localisation :* entrées bool du `.trace` (`DeadmanArmed`, `Error`, `PositionReached`, `ActiveTremie`, `ActiveMaintenance` + booléens commande/frein/capteurs restants).
   - *Ancre :* attribut `Scale`/`Min`/`Max` de chaque entrée.
   - *Action :* `Min=0`, `Max=1` ; `Visible=True` pour les 5 masquées ; ordre = commandes → capteurs → état (`PositionReached`, `Error`).
   - *Outil déterministe :* parseur Python du `.trace` (liste `nom,type,Min,Max,Visible`) + assertion `Max==1 and Min==0` sur sous-ensemble booléen.
   - *Risque si ignoré :* booléens invisibles/écrasés → diagnostic frein et sécurité (Deadman) illisible.

2. **Groupe B — Positions & cible**
   - *Localisation :* `M3_PosPV_DI`, `TranslationState.EstimatedPosM3_M`, `GVL_Simulation.SimM3ObsPositionTrue_M`, cible/code cible.
   - *Ancre :* `Min/Max` de ces entrées.
   - *Action :* positions `m` → conserver `-12/12` **uniquement si course = ±12 m**, sinon `Min/Max = course mécanique réelle` ; code cible entier → `Min=0`, `Max=N-1`.
   - *Outil déterministe :* script de contrôle cohérence `Min ≤ valeur ≤ Max` sur un échantillon + rappel des constantes d'axe du projet.
   - *Risque si ignoré :* recouvrement visuel des courbes de position vs consigne.

3. **Groupe C — Vitesses, `Step`, `ErrorId`**
   - *Localisation :* consignes vitesse `%` et `Hz`, `Step`, `TranslationState.ErrorId`.
   - *Ancre :* `Min/Max` de ces entrées.
   - *Action :* `%` → `0..100` (ou `-100..100` si signé, à confirmer) ; `Hz` (consigne) → `0..50` (à confirmer) ; `Step` → `0..nb_étapes` ; `ErrorId` → `0..nb_codes`.
   - *Outil déterministe :* parseur Python + validation des bornes selon unité déclarée.
   - *Risque si ignoré :* saturation `Step`/`ErrorId` et consignes illisibles.

4. **Groupe D — Fréquence brute variateur**
   - *Localisation :* `ActualFrequencyHz`.
   - *Ancre :* `Min/Max`.
   - *Action :* `Min=0`, `Max=5000` (`0.01 Hz`).
   - *Outil déterministe :* assertion `Min==0 and Max==5000`.
   - *Risque si ignoré :* fréquence réelle tronquée au-delà de `0.12 Hz` avec l'échelle actuelle.

5. **Ordre global du `.trace`** : Groupe A → B → C → D ; au sein de chaque groupe, ordre = commande/capteur → état → cible.

---

**Information minimale manquante pour passer en 🟢 PASS :**
- la liste des 30 variables avec `nom`, `type PLC (BOOL/REAL/INT/…)`, `Min/Max actuels`, `Visible`, `unité` ;
- la course mécanique de l'axe M3 (`m`) et le nombre de pas/codes (`N`) ;
- l'unité des consignes vitesse (`%` signé ou non, plage `Hz`).

Fournis ces éléments (ou le `.trace` + le DUT type M3), et je livre l'ordre exact + bornes certifiées variables par variables.