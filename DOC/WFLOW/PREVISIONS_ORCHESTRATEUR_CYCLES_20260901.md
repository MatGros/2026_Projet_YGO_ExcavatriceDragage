# 🗓️ Prévisions agents & phases — Orchestrateur des cycles (2026-09-01)

Registre des **prévisions** (travaux à venir, non code) et des **phases** de déroulement.
Structure pour suivi orchestrateur — chaque entrée = une action/phase planifiée.

---

| Phrase | Phase | Objet | Agent prévu | Dépend de | Statut |
|---|---|---|---|---|---|
| Phase A1 | Clôture T215 | **Revue indépendante** du refactor (diff réel) | Agent reviewer (différent) | — | ⏳ à lancer |
| Phase A2 | Clôture T215 | **Fiches de test T215** exécutées (+ remplissage) | Utilisateur + opérateur | A1 | ⏳ |
| Phase A3 | Clôture T215 | **Mapping IHM** (câbler Cycle* sur pupitre) | DSH/orchestrateur | A2 | ⏳ |
| Phase A4 | Clôture T215 | **Commit `test()` + push** (après accord explicite) | DSH | A2, A3 | ⏳ |
| Phase B1 | Brake M3 | **Appliquer BrakeDelayMagnetise=100ms** dans CODESYS + recompile | Utilisateur | — | ⏳ |
| Phase B2 | Brake M3 | **Fiche de test brake M3** exécutée | Utilisateur | B1 | ⏳ |
| Phase C1 | Décision plongée SEMI_AUTO | **Note de décision T202-E** lue + Option 1/2 tranchée | Utilisateur | — | ⏳ |
| Phase C2 | Décision plongée SEMI_AUTO | **Contrat T202-E** + plan (si Option 1) | DSH | C1 | ⏳ |
| Phase D1 | T211 terrain | **Plan T211** programmé (site) | Utilisateur/chef site | — | ⏳ |

---

## Prévisions par catégorie

### 📄 Documentation (zéro code)
- [x] Note de décision T202-E : `DOC/WFLOW/AUDITS/DESIGN/DESIGN_T202E_QUALIFICATION_FOND_SEMIAUTO_v0.1.md`
- [x] Fiche test T215 : `DOC/WFLOW/TESTS/FICHE_TEST_T215_REFACTOR_GVL_IHM.md`
- [x] Fiche test brake M3 : `DOC/WFLOW/TESTS/FICHE_TEST_BRAKE_M3_MAGNETISE.md`
- [x] Plan T211 : `DOC/WFLOW/TESTS/PLAN_T211_TEST_TERRAIN_PLONGEE_KOBOLD.md`
- [ ] Mapping IHM (tableau variable ↔ écran/bouton) — à produire en Phase A3

### 🧪 Tests
- [ ] Fiche test T215 (2 tests : persistance + fonctionnement)
- [ ] Fiche test brake M3 (2 tests : timing + sécurité)
- [ ] Plan T211 (4 scénarios terrain)

### 🤝 Agents
- [ ] Réviseur indépendant T215 (agent différent des implémenteurs)

---

## 📌 Dépendances / points d'attention
- La **Phase A4 (push)** ne se fait **jamais** sans relecture du diff + accord explicite.
- La **Phase C2** ne démarre qu'après **décision humaine** sur l'Option 1/2 (T202-E).
- Les **5 échecs de gates pré-existants** (G340/G390/G430/G481/G483) sont **hors périmètre** des phases ci-dessus — à traiter séparément si souhaité.
