# R29 — Inventaire des problèmes /connect + Superviseur (2026-11-16)

Liste vérifiée, avec preuve et statut. Base : journal d'actions du jour
(`R29_JOURNAL_ACTIONS_20261116.md`), commits git, journal du service.

| # | Problème | Preuve | Statut |
|---|---|---|---|
| P1 | Un serveur de test purgait TOUS les listeners réels (port=0, colonne distante) | journal 11:21/11:44 `killed=[...8744, 27672...]` ; WER : 0 crash applicatif = kills purs | **CORRIGÉ** (78036c76, test_purge_guard 3 verts, run pendant service réel : survivant) |
| P2 | Suite de tests complète : 5 rouges à identifier, cause inconnue à date | run 11:20 `5 failed, 219 passed` | **OUVERT** — relance ciblée -k avec garde actif, dossier par dossier |
| P3 | Fiche structurée : troncature silencieuse sans marqueur | `_is_truncated` l.169-171 + valeurs coupées constatées par T432 | **CORRIGÉ** (marqueur `[…] tronqué à N car. — lire <contrat>`, connect_session.py) |
| P4 | Fiche : scope en dict Python brut | fiche T429-MMX01 (`{'allowed': [...]}`) | **CORRIGÉ** (texte `Autorisé : … · Interdit : …`) |
| P5 | Fiche : faux « hors_sujet » sur objectif/périmètre (exigence livrable mal ciblée) | `structure_quality.py` markers appliqués à primary_goal/milestone | **CORRIGÉ** (exigence limitée à criteria/evidence) |
| P6 | `mission_structure_origin` perdue au redémarrage (valeur déduite redevient "confirmé") | whitelist `_persist` sans le champ | **CORRIGÉ** (champ ajouté à la whitelist) |
| P7 | Doublon `assignment_id` à chaque re-rattachement (rapporté par T000-CC10) | fiche T000 : « le superviseur crée un nouvel assignment à chaque rattachement » | **OUVERT** — à corriger dans connect_session (idempotence sur native_id : réutiliser l'assignment existant) |
| P8 | Mort du serveur 46508, cause non tranchée (11:48:35 → 11:53:03) | journal : aucune ligne kill émise par mon run de test | **OUVERT** (« on verra après » — exploitant) |
| P9 | Le titre UI complet dépendait de 3 défauts (whitelist, rendu accordeon, rendu menu) | preuve live : menu gauche 4 titres complets | **CORRIGÉ** (7904f87d + 5fa25682 + 45606954) |
| P10 | Doc /connect : le titre UI = nom du menu gauche non précisé dans la skill | skill en deny-list | **PARTIEL** — README à jour (dfa8a322) ; précision skill = pose humaine |

Règle réside du jour (garde mécanique) : plus JAMAIS de pytest global ; ciblé -fichier + `-x`,
état/port isolés ; `conftest.py` refuse bind 8081/8082 et l'état réel pour tout test.
