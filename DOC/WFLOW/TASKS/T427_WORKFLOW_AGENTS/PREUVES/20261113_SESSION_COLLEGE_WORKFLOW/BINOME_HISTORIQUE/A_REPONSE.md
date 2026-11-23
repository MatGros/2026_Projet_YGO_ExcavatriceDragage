🟡 ADVISORY — Verdict : aucune preuve citée d'affaiblissement de la **lecture obligatoire** ; l'affaiblissement cité porte sur le **devoir d'alerte** qui l'accompagne. Lecture seule, pas de durée mesurable.

**FAITS (cités)**
1. AGENTS.md, § Démarrage, 2026-11-02 : « Lire ce fichier comme source commune des règles… Ne pas dérouler un briefing complet… » ; au 2026-11-13 : « même paragraphe », tableau « Références à charger selon le besoin » « inchangé ». → Lecture obligatoire non retirée ni affaiblie sur cette fenêtre documentée. [✅ PASS]
2. CLAUDE.md : « @AGENTS.md » présent au 2026-11-04 comme aujourd'hui (import inchangé). → Pas de contournement de l'import. [✅ PASS]
3. Commit **b671a890** (2026-11-03, AGENTS.md) : retire « l'agent DOIT interpeller et poser des questions » ; ajoute « 4 | Inhibition procédurale | … la faire, sans question pour gagner du temps ». → Affaiblit le devoir d'alerte, **pas** la lecture. [✅ PASS pour le constat]
4. Commit **4b8038f3** (2026-11-03, AGENTS.md) : reformule la même règle 4, ajoute la portée « ne modifie jamais CODE/ ». → Ne touche pas la lecture. [✅ PASS pour le constat]
5. Diff AGENTS.md 2026-11-04→2026-11-13 (hash non fourni) : ajoute superviseur/arène dialectique/règle des 2 écarts ; Ollama « uniquement sur demande explicite » → « utilisable par défaut » ; retire liste des modèles locaux. → Aucun de ces points ne concerne la lecture obligatoire. [✅ PASS pour le constat]

**HYPOTHÈSES (non citées)**
6. La suppression de « DOIT interpeller et poser des questions » (b671a890) pourrait vider la lecture obligatoire de son effet (lire sans devoir signaler). Non démontré par les citations.
7. L'ajout de sections (superviseur, arène, 2 écarts) pourrait augmenter la charge de lecture et diluer l'obligation. Non cité.

**NON VÉRIFIÉ**
8. Contenu des commits non décrits parmi les 14 (0ae6aaaf, d5c5ba3f, 2a6814e3, f11d8de7, f4c2b237, 5da5721a, 0f9a3fd4, 3c052204, 2f4dc174, 208c5d47, 4e833051, 447c8e46) : impossible de statuer sur 2026-09-01→2026-11-02.
9. Hash exact du diff 2026-11-04→2026-11-13 : non fourni.
10. État de AGENTS.md § Démarrage entre 2026-09-01 et 2026-11-02 : non fourni.

**Décision recommandée** : ne pas conclure à un affaiblissement de la lecture obligatoire ; seul le devoir d'alerte est affaibli (b671a890/4b8038f3). Vérifier les hashes restants avant toute conclusion sur la fenêtre complète.