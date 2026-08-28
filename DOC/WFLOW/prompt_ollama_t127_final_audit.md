# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION D'AUDIT GLOBAL FINAL T127 AVEC TOUS LES ARTEFACTS BRUTS

## 1. Logs d'exécution brute des Tests CI G_CYCLE (14 cas testés)
```text
PASS  FB_ExtractionSequence (3/3)
  PASS  TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure
  PASS  TC-P04-020 Extraction : mise en service sequence extraction
  PASS  TC-P04-021 : Sequence extraction complete et continue avec maintien constant du joystick operateur
PASS  FB_DiveSearch (4/4)
  PASS  TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure
  PASS  TC-P04-010 DiveSearch : mise en service recherche de couche
  PASS  TC-P04-011 : Sequence complete Kobold 4 temps avec coupure contacteur sur contact fond
  PASS  TC-P04-012 : Tentative descente en Palier 5 sous Kobold declenche defaut bloquant (Bridage Palier <= 4)
PASS  FB_Cycle (7/7)
  PASS  TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure
  PASS  TC-P04-001 : Relachement manche (CycleMotionPermit=FALSE) stoppe les commandes sans perdre l etape
  PASS  TC-P04-002 : Le cycle produit des demandes et passe a X1_HOMING sur Start
  PASS  TC-P04-003 : Defaut de synchronisation treuils bascule le cycle en STABILIZING et fige l etape
  PASS  TC-P04-004 : Reprise apres STABILIZING necessite Cause disparue + Reset + StartCycle (Anti-redémarrage auto)
  PASS  TC-P04-012 : Compteur de prelevements SampleCount RETAIN incremente sur X13_DONE_SYNC
  PASS  TC-P04-013 : Bascule Semi-Auto vers Maintenance preserve l etape et neutralise les demandes sans redemarrage auto
3 FB testes, 3 PASS, 0 FAIL (100%)
```

## 2. Sortie brute G200 Linkage (`G200_check_linkage.py --report`)
```text
Auto-verification liaison (G200_check_linkage.py) — PASS
  Linkage (L1-L7):    95 OK, 0 KO
  L8 (Output assign): 0 OK, 0 KO, 0 WARN
  L9 (I/O mapping):   0 OK, 0 KO, 0 WARN
  L10 (Single prod):  1255 OK, 1083 WARN
  L11 (Polarity):     0 OK, 33 WARN
  L12 (Timing):       1 OK, 0 KO, 6 WARN
  L13 (Orphelins):    71 OK, 0 KO
Linkage check: PASS (0 erreur(s), 1122 avertissement(s), 1351 instance(s) verifiee(s))
```

## 3. Rapport d'exécution des 22 Gates (`run_all_gates.py`)
```text
RESUME — TOUT (Temps total : 6.85s)
  PASS  G300 — Structure du depot
  PASS  G310 — Structure CODE (POU, suffixe, ordre)
  PASS  G320 — Couverture MAIN du bundle
  PASS  G330 — Securite des types et membres STRUCT
  PASS  G100 — Code style (VAR_OUTPUT, simulation)
  PASS  G200 — LIAISON (instances, refs, bundle)
  PASS  G210 — Cablage CFC natif
  PASS  G340 — Liens documentaires
  PASS  G350 — Collision noms HW (REX 2026-08-05)
  PASS  G360 — Interlock changement de sens (REX 2026-08-05)
  PASS  G370 — Cablage position calibree (REX 2026-08-06)
  PASS  G375 — Gate homme-mort mouvement (AF08 TC-P08-008)
  PASS  G110 — Nommage IEC (NC-010 a NC-070, informatif)
  PASS  G120 — Nommage DUT propriete d'un FB (NC-110, informatif)
  PASS  G127 — Completude gate neutralisation NOT Enable (informatif)
  PASS  G380 — Persistance config
  PASS  G390 — Fraicheur bundle
  PASS  G400 — Syntaxe ST du bundle (no terminator)
  PASS  G405 — Littéraux STRING ASCII (REX 2026-08-17)
  PASS  G410 — Invariants LD (tous les POU `_LD`, REX 2026-08-04/13)
  PASS  G430 — Commentaires REX (Zéro journal intime, §2ter)
  PASS  G440 — Skills agents (stub + canonique, anti-derive)
ALL GATES PASSED [OK] (22/22)
```

## 4. Log réel de compilation CODESYS 3.5.19.10
```text
------ Processus de compilation entamé : application : Device.Sim.Device.Application -------
Affecter un type à un code...
Nombre de symboles publiés : 1216
Fichier XML généré : 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PRJ_CODESYS\v0.6.17_Seq.Device.Application.xml'
Création de code...
Taille du code créé : 3395270 octets
Taille totale de mémoire allouée aux codes et données : 7662640 octets
La compilation est terminée -- 0 erreurs, 1 avertissements : prêt pour téléchargement
```

## 5. Contrats de tâche associés
- `TASK_CONTRACT_T127-A_TYPES_INTERFACE.yaml` (VALIDATED)
- `TASK_CONTRACT_T127-B_GRAFCET_LOGIC.yaml` (VALIDATED)
- `TASK_CONTRACT_T127-C_DIAG_DOC.yaml` (VALIDATED)
- `TASK_CONTRACT_T127-D_INTEGRATION_PRG03.yaml` (VALIDATED)
- `TASK_CONTRACT_T127-F_VISUAL_CI.yaml` (VALIDATED)

## 6. Verdict d'audit
À la vue de l'ensemble de ces preuves brutes et complètes, donne ton verdict formel (**PASS / BLOCK**) pour la clôture définitive du lot **T127**.
