# Mise en service — Fiche de suivi du 17/11/2026

> **Tenue par :** TORC-CC10 (orchestrateur) · **Ouverte :** 2026-11-17
> **Rôle de la fiche :** (1) cadencer la journée, (2) lister ce qui a été implémenté depuis la dernière MES et doit être testé, (3) tracer événements, mesures, constats.
> **Règle :** le journal (§5) est alimenté au fil de l'eau. Une valeur mesurée = valeur brute + source. Une impression = marquée « hypothèse ».

---

## 1. Point de départ

| Élément | Valeur | Source |
|---|---|---|
| Dernière MES machine | 22-23/09/2026 (tag `MES_FIN_20260923`) | `REGISTRE_Suivi_MiseEnService_20260923.md` |
| Programme chargé sur la machine | v0.7.25 ≈ commit `e38cc09a` | `REINTEGRATION_POST_MES_20261027_1707.md` |
| Code livré à tester aujourd'hui | `main`, bundles régénérés le 16/11 (`a681b221`) | git |
| Bundles | `CODE_XML/CODE_Bundle.xml` (complet) · `CODE_XML/CODE_DiffBundle.xml` (rapide) | guide terrain v3.0 |
| Trace M3 | `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/Trace_Site_M3_Par_Echelle.trace` (35 variables, 4 échelles) | guide terrain v3.0 |

⚠️ **Tout ce qui est listé en §3 n'a jamais tourné sur la machine réelle.** Les tests simu ne valent pas preuve machine.
⚠️ Le contenu du DiffBundle (12 objets au 16/11 13:31) a pu changer avec le correctif simu `a681b221` : le recompter avant import.

---

## 2. Déroulé de la journée (ordre proposé)

Les durées ne sont pas estimées : à noter dans le journal au fur et à mesure.

- [ ] **A. Avant de toucher au programme (sécurité + sauvegarde)**
  - [ ] A1 Capteur FdC haut M1/M2 `M1M2_TopPositionFree_DI` : état physique constaté. Shunté depuis le 25/09 → **aucun homing automatique ancien**.
  - [ ] A2 Connexion en ligne **sans charger** : sauvegarder `GVL_PERSISTENT` (positions M3 1,5 / 3,5 / 5,0 / 10,0 m, gain `k`, réf. M1/M2 8,50 m, offsets benne).
  - [ ] A3 Noter la version du programme actuellement sur l'automate (export frais, jamais le `Device.export` du dépôt).
- [ ] **B. Chargement**
  - [ ] B1 Import du bundle (complet ou diff) · B2 compilation sans erreur · B3 téléchargement · B4 réécriture des persistantes sauvegardées (A2).
  - [ ] B5 Compteurs horaires : vérifier lecture IHM (Heures/Minutes machine, M1, M2, M3) puis conservation après coupure/redémarrage (**T396**, première charge : les persistantes bougent).
- [ ] **C. Référence M3 en MANU (point de comparaison)**
  - [ ] C1 Arrêt Trémie et P1 en MANU : relever la distance d'arrêt après capteur (attendu : ~10 cm, frein tient).
  - [ ] C2 Noter l'état frein M3 affiché IHM pendant l'arrêt (souvenir exploitant incertain : voir §4.2).
- [ ] **D. MAINT_N2 (T395, C4)** — voir §3.1
- [ ] **E. M3 en SEMI_AUTO : arrêt au 1er trou capteur (T417-E)** — voir §3.2
- [ ] **F. Options cycle (T417-F)** — voir §3.3
- [ ] **G. Homing unitaire M1/M2 (T377 partiel)** — voir §3.4
- [ ] **H. Contrôles IHM / diagnostic** — voir §3.5
- [ ] **I. Clôture**
  - [ ] I1 Export frais du projet (état réellement testé) · I2 sauvegarde persistantes finales · I3 liste des constats ouverts · I4 décision : programme laissé sur l'automate = lequel (version, bundle).

---

## 3. Ce qui a été implémenté depuis la dernière MES et doit être testé

**Preuve livrée** = ce qui existe avant la MES (ce n'est jamais une preuve machine).

### 3.1 T395 — MAINT_N2 : pilotage inconditionnel contacteurs et treuils (criticité C4)
- **Quoi :** en `MAINT_N2`, M1 seul (`WinchSel=1`), M2 seul (`2`), M1+M2 (`0`) pilotables malgré les défauts, sous trois réserves : AU fermé (`PowerContactorEngaged_DI`), homme-mort joystick, capteur haut `M1M2_TopPositionFree_DI`.
- **Tester :** les 3 sélections, montée + descente, joystick et boutons IHM. Vérifier fermeture franche des contacteurs/freins, et que `WinchSel=0` ne bascule pas seul à 2.
- **Renvoi :** guide terrain §3 étape 1 · note code §5 — `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md`
- **Point de vigilance :** cette fonction contourne des interverrouillages. Le capteur haut étant shunté, **la barrière haute matérielle est absente** : manœuvre à vue, AU à portée.
- **Preuve livrée :** commit `5ecfa1d6` (16/11) · statut catalogue T395 ⬜ · aucun test machine.

### 3.2 T417-E — M3 : arrêt SEMI_AUTO au 1er trou capteur
- **Quoi :** en SEMI_AUTO, rampe rapide et fermeture frein dès le 1er trou (Trémie ou P1), comme en MANU. Latch `M3_TremieHardStopLatched` en `RETAIN` (survit à une coupure).
- **Tester (à 20 Hz, trace chargée) :** AX14 Trémie et AX2 P1 — au 1er front capteur, `BrakeReleaseRequest` et `DriveControlWord` tombent à 0 ; relever la distance d'arrêt (avant : −0,40 m Trémie, +5,38 m P1 en **simulation**).
- **À tester aussi :** latch après coupure/remise sous tension ; recul volontaire vers P1/Maintenance qui lève le latch ; reset IHM.
- **Renvois :** guide terrain §2.A et §3 étape 2 · `T417-C_SYNTHESE_ETUDE_M3_20261115_v1.0.md` · `REGISTRE_MES_TEMOIGNAGE_M3_20261030.md` (récit exploitant, non instrumenté).
- **Preuve livrée :** commits `fd1bb138`, `0f9dec83`, `8fc65110`, `aa20ed28` (16/11) · simulation uniquement.
- **Hypothèse non tranchée :** le glissement lent de 30-50 cm vers la butée pendant l'ouverture benne (vu sur machine) peut venir d'un relâchement de frein et d'une pente de rail. Ce lot ne le traite pas forcément : **relever l'état frein et la position pendant le vidage** (voir §4.2).

### 3.3 T417-F — Options du cycle SEMI_AUTO (3 réglages IHM, défaut = comportement historique)
Variables : `GVL_IHM.CycleSemiAuto.Cmd.*` (non persistées).

- **`SetPauseBeforeDump_S`** (REAL, défaut 0.0) : pause avant ouverture benne. Test à 0.0 puis 0.5.
- **`TglAllowDumpInPV`** (BOOL, défaut FALSE) : ouverture benne dès la zone PV ; retour P1 dès benne ouverte. Test AX14 + push manche.
  - **Nuance codée :** X gauche et Y poussé **en même temps** → M2 n'ouvre pas tant que X n'est pas relâché (`FB_WinchCmdArbitrationM2.st:69`). Décider sur site si ça convient.
- **`TglRelaxSemiAutoStart`** (BOOL, défaut FALSE) : départ AX1 plus souple (fenêtre haute 0,4 → 2,0 m).
  - Diagnostic AX1 (toujours actif) : 3 messages — M3 en Maintenance / M1-M2 hors zone haute / état benne non qualifié.
- **Renvois :** `NOTE_MISE_A_JOUR_CODE_20261116.md` §1-3 (même dossier que le guide).
- **Preuve livrée :** commits `9081b291`, `b567cf5d`, `aa20ed28`.

### 3.4 T377 (partiel) — Anti-démarrage du homing au joystick
- **Quoi :** toucher joystick / homme-mort en MAINT_N2 ne lance plus le cycle homing. Le lancement se fait **uniquement** par bouton IHM, manche au neutre. Le geste « 3 appuis homme-mort » disparaît (à répéter aux opérateurs).
- **Tester :** (a) toucher manche + homme-mort en MAINT_N2 → rien ne démarre ; (b) homing unitaire `BtnHome` / `BtnHomingAtZero` fonctionne ; (c) démarrage cycle par IHM manche au neutre.
- **Ordre imposé (rapport T377) :** 1er test en homing **unitaire** ; T377 complet = bundle suivant, **pas de GO** aujourd'hui.
- **Renvoi :** `DOC/WFLOW/TASKS/T377_HOMING_MANUEL_SANS_CONTACT_TOP/T377_RAPPORT_TRANSMISSION_20261116_v1.0.md` · patchs : `T377_ECHANGE_AGENT_TERRAIN_20261116_v1.0.md`.
- **Preuve livrée :** commit `f28a84ab`.

### 3.5 Supervision, IHM, diagnostic
- **T396 compteurs horaires (UDINT, jamais négatifs)** : voir B5. Commit `a6b45c92`. Catalogue ⬜.
- **T424 robustesse IHM / bannière / décodage AX7** : bannière IHM correcte pendant les cycles ; message AX7 lisible. Commits `ae052e32`, `9b793b43` (31/10). Catalogue ✅ (validation simu/banc).
- **T428 guide de dépannage dans CODESYS** (`FB_TroubleshootingGuide`, valeurs trompeuses du troubleshooting) : commits `40d81bf4`, `8ac56593` (08/11), marqués **[NON TESTE IMPORT]**. Vérifier l'import et l'absence d'erreur de compilation. Catalogue ⏸️.
- **Coefficient odométrique M3 réglable site** (`ac17beef`, 28/10) : valeur actuelle à relever avant et après chargement. L'exploitant l'a déclaré « validé et conservé » le 09/11 (registre de réintégration).

### 3.6 Hors périmètre machine (ne pas chercher à tester)
Simulation (`L_SIMULATION`, T417-D, T421) et outillage Superviseur/Task Manager (T429) n'agissent pas sur la machine.

---

## 4. Points ouverts connus (non corrigés, à ne pas confondre avec une régression)

### 4.1 Défauts terrain présents dans la base
- **T334** (⬜) : arrêt M3 au-delà de P1/Trémie en cycle auto. T417-E vise ce comportement mais **n'est pas prouvé** tant que non testé machine.
- **T386** (⬜, C4) : rotation de phase « mal gérée », non corrigée.
- **FdC haut M1/M2** cassé et shunté côté client (registre 26/09).
- **T394** (⬜) : robustesse position P1 après reboot sous l'eau et permis de translation/descente M3.
- **AX15D** non réintégré : en AX15B, **tirer le manche ne fait rien**. Le texte opérateur « Tirer : fermer et remonter » est faux (déjà sur machine).
- **T377 complet** : préparé, **pas de GO**. Homing automatique ancien à ne pas utiliser.

### 4.2 Observations exploitant à vérifier aujourd'hui (récit du 30/10, hypothèses)
- Pendant l'ouverture benne à la Trémie, le chariot dérive très lentement vers la butée. **À relever :** état frein M3 (IHM et contact `M3_BrakeIsOpen_DI`), position à t0 et t+30 s, pente éventuelle du rail.
- Défauts brake M3 à AX14 → AX15, plus fréquents à 10 Hz qu'à 20 Hz (souvenir : à confirmer).
- Retour P1 : défaut possible mais plus rare (souvenir incertain).

---

## 5. Journal des événements

Format : `HH:MM · étape · fait / mesure / constat · source (fichier, trace, photo)`.
Marquer chaque ligne : **[FAIT]** observé · **[MESURE]** valeur brute · **[CONSTAT]** écart ou défaut · **[HYPOTHÈSE]** · **[DÉCISION]**.

- `2026-11-17 (heure à compléter)` · préparation · **[FAIT]** fiche créée par TORC-CC10 à partir de : guide terrain M3 v3.0 (16/11), note de mise à jour code (16/11), registre de réintégration (27/10), témoignage M3 (30/10), rapport T377 (16/11), historique git depuis le 27/10.
- `…`

---

## 6. Mesures relevées

| Heure | Étape | Grandeur | Valeur brute | Condition (mode, fréquence, sens) | Source |
|---|---|---|---|---|---|
| | C1 | Distance d'arrêt Trémie, MANU | | | |
| | C1 | Distance d'arrêt P1, MANU | | | |
| | E | Distance d'arrêt Trémie, SEMI_AUTO | | 20 Hz | |
| | E | Distance d'arrêt P1, SEMI_AUTO | | 20 Hz | |
| | 4.2 | Dérive M3 pendant vidage (30 s) | | | |

---

## 7. Constats et décisions

| # | Heure | Constat / décision | Lié à | Suite (qui, quoi) |
|---|---|---|---|---|
| | | | | |

---

## 8. Documents de renvoi

- Guide terrain (étapes détaillées, arbres de décision) : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md`
- Note de mise à jour code (fichiers:lignes) : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/NOTE_MISE_A_JOUR_CODE_20261116.md`
- Synthèse M3 : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/T417-C_SYNTHESE_ETUDE_M3_20261115_v1.0.md`
- Faisabilité T417-D/E/F : `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/RAPPORT_FAISABILITE_COMPARATIVE_T417-D_E_F.md`
- Homing T377 : `DOC/WFLOW/TASKS/T377_HOMING_MANUEL_SANS_CONTACT_TOP/` (rapport de transmission, échange agent terrain, séquence Grafcet)
- Témoignage M3 : `DOC/WFLOW/MISE_EN_SERVICE/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md`
- Réintégration / état machine : `DOC/WFLOW/MISE_EN_SERVICE/REINTEGRATION_POST_MES_20261027_1707/`
- Dernière MES (références) : `REGISTRE_Suivi_MiseEnService_20260923.md` · `REGISTRE_PrepaNextMES_20260926.md`
