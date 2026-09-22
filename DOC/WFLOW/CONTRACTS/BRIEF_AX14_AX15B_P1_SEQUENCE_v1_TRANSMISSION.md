# 📋 BRIEF DE CAMPAGNE — Zone AX14 → AX15B (vidage trémie) + passage TRANSLATION → P1
## v1 — PRÊT À TRANSMETTRE À DES AGENTS EXTERNES

> 📅 2026-09-22 · 🏷️ Orchestrateur : DSH01 · ⚡ **Sujet URGENT** (exploitant : « pouvoir faire UN cycle sans blocage »)
> 🎯 **Tâches concernées** : **T331** (repli AX15b) · **T295** (timeout benne AX15B) · **T345** (AX14→AX15A) · **T349** (AX15A affichage) · **T319** (AX2/P1, close) · **T334** (translation M3) · **T324** (steps hors GEL) · **T382** (AX3 sans ReqClose)
> 📄 **Sources canoniques** : `AGENTS.md`, `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.x.md`, `DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md`, `CODE/G_CYCLE/FB_CycleSemiAuto.st`, `CODE/G_CYCLE/_TYPES/E_AutoCycleStep.st`
> 📎 **Briefs déjà émis à LIRE avant d'écrire** : `DOC/WFLOW/PROMPTS/09_BRIEF_T295_timeout_benne_AX3.md` · `DOC/WFLOW/CONTRACTS/BRIEF_T345_L2_AX14_AX15A_INSTANTANEE_v2.md`

---

## 0. PRÉAMBULE OBLIGATOIRE (extrait de `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — à lire en entier dans le dépôt)

Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué **manuellement** par l'exploitant dans CODESYS. **Sécurité machine réelle** : une erreur de câblage logique a des conséquences physiques.

**Persona** : Expert Senior Automatisme Industriel, Sécurité Machine (ISO 13849), CI/CD. **Challengeur anti-Yes-Man** : ne rien prendre pour argent comptant, y compris ce brief — s'il est faux, le dire avant d'agir. Distinguer **faits avérés / hypothèses / incertitudes**. Toujours répondre en français, style direct et synthétique.

**Interdits absolus**
- ⛔ **Aucun commit, aucun push** sans accord humain explicite et distinct.
- ⛔ **Toute modification de fichier exige une validation préalable** (traitée au §5 — arrêts humains).
- ⛔ Ne jamais créer/renommer un POU dont le nom diffère du nom de son fichier source ; pas de suffixe `_CFC`/`_LD` injustifié.
- ⛔ Ne jamais modifier `PRJ_CODESYS/…/Device.export`.
- ⛔ Aucun scratch à la racine ; aucune suppression/déplacement/désindexation d'artefact (le nettoyage est humain).
- ⛔ Élargir le scope : **signaler, ne pas décider**.

**Cas d'arrêt (ne pas produire de code, demander)** : spec incomplète/ambiguë · nommage indécidable · interface FB incomplète · `Reset` hors front · redémarrage automatique après défaut · `SafeStop`/`StartStop` sur un FB non-mouvement · `CoupeEnable` ou `FB_Watchdog` applicatif réintroduits.

**Devoir d'alerte** : tout problème constaté en cours de route (incohérence, bug préexistant, risque hors scope, doute de sécurité) remonte **immédiatement**, jamais à la fin, jamais silencieusement.

**Vérification mécanique — minimum à CHAQUE livraison de code**
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .            # bundle frais
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers .st touchés>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report          # liaison BLOQUANTE
```
⛔ Un bundle bien formé ou des tests Python verts **ne prouvent jamais** qu'une fonction est reliée. Seul `G200_check_linkage.py` le prouve, et son bloc `Auto-vérification liaison` doit être **collé dans la restitution**.

**Traçabilité d'impact AVANT de coder** : tracer qui **produit** la donnée, qui la **route**, qui la **consomme** — vérifier que la modification atteint le **consommateur final** (`DOC/STDS/CODE_QUALITY_STANDARDS.md §3ter`).

**Checkpoint de progression** : journaliser chaque étape via
`python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <SESSION> <ETAPE> <etat> --agent <nom> --msg "<résumé>"` (`--agent` : `CC01`, `AGY01`, `CDX01`, `DSH01`, `OPC01`).

---

## 1. OBJECTIF (résultat attendu, en une phrase)

À la **trémie** (vidage), l'opérateur doit pouvoir **manipuler la benne dans les deux sens sans quitter la phase de vidage**, et le **passage translation M3 → P1 → benne** doit s'enchaîner **sans blocage**, sur **UN cycle complet**.

## 2. ÉTAT RÉEL, MESURÉ SUR LE CODE (ne pas le redécouvrir — le vérifier)

### 2.1 Séquence DÉCHARGE (`E_AutoCycleStep.st:33-39`)
```text
AX13_DRAIN_PAUSE(13) → AX14_TRANSLATE_DUMP(14) → AX15A_DUMP_ARRIVE(15)
   → AX15B_DUMP_OPEN(16) → AX15C_DUMP_REPOSITION(17) → AX18_DONE_SYNC(18) → rebouclage AX2
```

### 2.2 Défaut prouvé n°1 — AX15B quitte la phase vers AX10 (`FB_CycleSemiAuto.st`)
```text
L1554  AX15B : BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush     (ouverture = action de l'étape)
L1568  AX15B : BucketCmd.ReqOpen := FALSE
L1569  AX15B : State := E_AutoCycleStep.AX10_CLOSE_BUCKET             ⛔ SORTIE de la phase de vidage
L1571  AX15B → AX15C (repositionnement treuils)
L1607  AX15C → AX15B ✅ (le patron bidirectionnel INTRA-PHASE EXISTE DÉJÀ)
```
**Conséquence opérateur** : « fermer » = **sortir** du vidage et ré-entrer dans `AX10 → AX10B → AX11 → AX12 → AX13 → AX14 → AX15A → AX15B` ⇒ **il faut refaire une passe complète pour revenir au vidage**.
**Origine** : commit **`31c9db0d`** (2026-09-20 19:28, T331/AX15b, **`[NON TESTE MACHINE]`**).
**Motif déclaré (verbatim du commit)** : *« AX10 est déjà exclu de la surveillance de synchronisme M1/M2 (PRG_04:431-434) et porte déjà `BucketAutoCloseActive` (PRG_04:492-494) — rester en AX15B pour fermer aurait laissé la surveillance synchro active pendant une manœuvre dissymétrique (**faux WinchSyncError**) »* + *« le retour est à sens unique, rouvrir la benne à la trémie n'a pas de sens métier »* ← **hypothèse à renverser sur décision de l'exploitant**.

### 2.3 Défaut prouvé n°2 — AX3 (à P1) ne ferme JAMAIS la benne
```text
L1005 AX3_OPEN_BUCKET → L1025 BucketCmd.ReqOpen := TRUE → L1034 State := AX3_WAIT_DIVE_START
```
**Aucune ligne `BucketCmd.ReqClose` dans AX3** (modèle existant à copier : `L1316`, AX10 : `BucketCmd.ReqClose := DeadmanArmed AND JoystickPull AND ExtractionStepDelayTimer.Q`).
**Origine** : le commit **`ba95cbcd`** (2026-09-05) **annonce** le pilotage benne 2 sens à AX3, un **commentaire du code l'affirme encore**, et le **message opérateur le promet** — **le code ne le fait pas**. → tâche **T382** (créée 2026-09-22).

### 2.4 Trois lots FINIS, COMMITTÉS, **JAMAIS testés machine** (le cœur de la campagne)
| Lot | Commit | Contenu |
|---|---|---|
| **T295** | `e011036b` | `FB_Bucket.st` §1 Cause 2 réécrite : budget de timeout **gelé hors engagement opérateur**, cumulé pendant (`TimeoutEngaged := Lifecycle.Busy AND MotionRequestActive`, `:230`), PT inchangé 60 s, latch inchangé. **Sémantique actée par l'exploitant.** |
| **T331** | `31c9db0d` | Le repli AX15B → AX10 (§2.2) |
| **T345-L2** | `b7b2c04b` | AX14 → AX15A **instantané** + **verrou neutre latché en AX15A** (`SeenNeutralAfterArrival`, `L1495-1532`) : AX15B exige un push **postérieur** à un scan neutre |

### 2.5 État de la chaîne de test (à connaître AVANT de conclure)
- `WINCH_INTEG` (domaine treuils/benne) : **FAIL — ne compile pas** (argument mort `SetOffsetM`, `FB_TestHarness_PRG_03.st:96`) ⇒ **domaine AVEUGLE en CI**.
- `FB_CycleSemiAuto` : **43 tests / 5 ROUGES**, dont **« Bascule en AX_STAB sur défaut »** dès l'initialisation + 3 cas qui **n'atteignent jamais AX4** ⇒ **la CI ne peut PAS prouver un cycle nominal** aujourd'hui.
- Piste n°1 sur ces 5 rouges : **le harnais lui-même** (`SpeedMismatchThresholdMps := 0.0` **et** `SpeedMismatchTimeout := T#0ms`, `test_fb_cyclesemiauto.st:1344`) → écart de vitesse confirmé **instantanément** → repli `AX_STAB`. Cause **exclue** : la tempo max d'étape est désactivée en dur (`FB_CycleSemiAuto.st:385 TonStepMax(IN := FALSE)`).

## 3. MISSION (8 rubriques — `delegation_c3_c4.md`)

```text
OBJECTIF
- §1, plus : trancher par la MESURE ce qui, parmi les 3 lots finis non recettés et les 2 défauts
  prouvés, empêche réellement UN cycle complet — puis livrer la correction de séquence.

PÉRIMÈTRE / INTERDITS
- Autorisé (à confirmer par le contrat) : CODE/G_CYCLE/FB_CycleSemiAuto.st,
  CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st (UNIQUEMENT si la mesure l'exige),
  le test CI RESULTS/G_CYCLE/tests/test_fb_cyclesemiauto.st, la note d'application, les bundles.
- INTERDIT : CODE/B_AU_SECURITE/**, FB_Safety_*.st, FB_WinchOutputInterlock.st,
  CODE/J_SUPERVISION/GVL_IHM.st et _TYPES/**, DOC/AF/**, DOC/STDS/**, PRJ_CODESYS/**, Device.export,
  ARCHIVES/. AUCUNE modification de logique de sécurité, AUCUNE temporisation moteur/frein.

PHASES ET POINTS D'ARRÊT
1. Lire le §2, les 2 briefs référencés, l'AF_Partie-04 et le GEL du GRAFCET. VÉRIFIER le §2 ligne à ligne.
2. MESURER : reproduire la séquence (harness CI et/ou trace 10 ms) et établir OÙ un cycle bloque
   réellement (AX2 ? AX3 ? AX4 ? AX15B ?), avec preuve. Ne rien corriger avant.
3. CHALLENGER ce brief : toute affirmation du §2 qui ne tient pas doit être REFUTÉE par écrit.
4. ⛔ ARRÊT HUMAIN OBLIGATOIRE : rendre le diagnostic + le plan de correction. AUCUNE ligne de code
   avant le GO explicite de l'exploitant (les arbitrages du §5 conditionnent le plan).
5. Après GO : implémenter la correction de séquence, un seul écrivain, diff lisible.
6. Faire relire le diff par un agent INDÉPENDANT (read-only), corriger BLOCK/MAJOR.
7. Preuves : CI ciblée ROUGE avant / VERT après, bundle + diff bundle + G200 --report, palier C.

CRITÈRES TESTABLES
- AC1 : en AX15B, PUSH ouvre / PULL ferme / NEUTRE arrête LA BENNE, **en RESTANT en AX15B** ;
  aucune transition vers AX10 sur un simple geste inverse (preuve CI ROUGE avant / VERT après).
- AC2 : l'échappatoire de remontée prévue par T331 **existe toujours** et est déclenchée par un geste
  EXPLICITE et documenté (à définir avec l'exploitant — §5).
- AC3 : en AX3 (P1), le geste inverse commande réellement la FERMETURE (ReqClose), sur le modèle
  d'AX10 ; l'étape reste AX3 tant que la benne est manipulée.
- AC4 : un cycle complet (AX1_INIT → AX18) s'enchaîne sans repli AX_STAB et sans blocage, prouvé par
  CI (harnais réparé si nécessaire, cf. §5 arbitrage) OU par trace machine, ROUGE avant / VERT après.
- AC5 : aucune régression : diff VIDE sur le périmètre interdit du §PÉRIMÈTRE ; les tests des autres
  étapes (AX10, AX15C, T262) restent verts.
- AC6 : commentaires et messages opérateur alignés sur le comportement RÉEL (plus d'annonce d'un
  comportement absent).

SOUS-AGENTS AUTORISÉS
- Uniquement pour challenger le plan ou relire le diff, read-only, périmètre DISJOINT,
  avec le préambule en tête. L'agent principal reste SEUL écrivain et SEUL responsable.

PREUVES ATTENDUES
- Le diagnostic de blocage AVEC mesure (fichier:ligne + trace ou CI).
- ROUGE avant / VERT après (assertions fonctionnelles, JAMAIS une erreur de compilation présentée
  comme preuve).
- Bundle complet + diff bundle (liste des objets) + bloc `Auto-vérification liaison` (G200) collé.
- `git diff --numstat` des fichiers touchés + VIDE sur le périmètre interdit.

RESPONSABILITÉ DU PRINCIPAL
- Tu restes garant du code, du rapport, des preuves et de la cohérence avec le besoin.
- Tu vérifies les conclusions des autres agents ; tu ne recopies pas leurs affirmations comme preuves.

FORMAT DE RESTITUTION
- Verdict court · fichiers touchés · AC un par un · tests/gates · risques résiduels ·
  hors scope constaté · bloc Auto-vérification liaison · ce qui reste à tester par l'HUMAIN.
```

## 4. CE QUI NE PEUT PAS ÊTRE FAIT PAR UN AGENT (actions humaines, à lister explicitement)

- **Recette CODESYS** : import manuel du bundle + exécution de la passe complète (l'agent ne pilote pas CODESYS).
- **Trace 10 ms** machine (protocole `T348`, scénarios A-B-C) — c'est elle qui tranche une éventuelle ambiguïté résiduelle.
- **Export CODESYS frais** (`Device.export`) si un diagnostic l'exige — **jamais** un export existant.
- **Arbitrages** du §5.

## 5. ARBITRAGES À RENDRE PAR L'EXPLOITANT **AVANT** LE PLAN DE CORRECTION (groupés — une seule salve)

| # | Question | Pourquoi elle bloque |
|---|---|---|
| 1 | **L'échappatoire « fermer + remonter » de T331 doit-elle survivre ?** Si oui, par **quel geste explicite** (geste maintenu prolongé, bouton IHM, condition de fin de vidage) ? | Sans réponse, corriger AX15B **casserait** l'intention de sécurité d'origine (frein qui glisse, benne qui ne tombe pas) |
| 2 | **L'exclusion de la surveillance de synchronisme** pendant la fermeture à la trémie est-elle acceptée (élargie d'AX10 à AX15B) ? | C'est une décision **safety-adjacente** dans `PRG_04` — jamais improvisée par un agent |
| 3 | **AX3 (P1)** : la fermeture doit-elle être commandée par le geste inverse (comme annoncé) ? | Détermine si T382 est un **correctif** ou une **mise à jour du message** |
| 4 | **Le harnais CI** `FB_TestHarness_PRG_03.st:96` (`SetOffsetM`, VAR_INPUT supprimé par T202) peut-il être réparé dans ce lot ? | Sans lui, la CI ne peut pas prouver AC4 ; le fichier est hors du scope du contrat CI (T372) |
| 5 | **Priorité** : ce lot avant/pendant la campagne « 1 cycle sans blocage » ? | Fixe l'ordre de la campagne d'essais |

## 6. TRAÇABILITÉ

- Défaut n°1 (AX15B→AX10) : trouvé par l'**exploitant** (« à la 15 avant on pouvait ouvrir et aussi fermer pour remonter ; actuellement si je remonte on part en AX10 »), **vérifié ligne à ligne** par l'orchestrateur DSH01 sur l'arbre courant.
- Défaut n°2 (AX3 sans ReqClose) : **vérifié** par DSH01 sur le code + le commit `ba95cbcd` ; catalogué **T382**.
- Historique du passage **translation → P1** : transition `AX2 → AX3` modifiée par **T319 / `dcb28019`** (2026-09-19), changement **délibéré** (le mode « P1 déjà stable » enchaîne sous le même geste), **aucun détournement** vers une étape antérieure — contrairement à AX15B.
- Fiches liées : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_ManuelBoth_Impossible_20260922.md` · `…_Cycle_Error08_TranslationP1_20260922.md`.

> ⚠️ **Ce brief est un brief de CAMPAGNE, pas un GO d'implémentation.** Aucune ligne de code ne doit être
> écrite avant que le §5 soit arbitré et que le contrat de tâche correspondant soit écrit et validé par
> `check_task_contract.py`.
