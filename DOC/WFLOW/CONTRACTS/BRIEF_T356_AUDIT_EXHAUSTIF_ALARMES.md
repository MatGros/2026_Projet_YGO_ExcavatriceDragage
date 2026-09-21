=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== LECTURE SEULE — AUCUN CODE/ TOUCHÉ ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Observation utilisateur
2026-09-21 : suspicion d'écarts sur toute la chaîne alarme — certains défauts
existent en process/safety mais ne remontent pas (pas de bit actif, pas de
message bannière, pas d'action utilisateur associée). Pas de registre central
d'alarmes identifié dans le code (repéré par l'orchestrateur : bandeau carrousel
`ST_AlarmBanner.st`/`FB_Hmi_BannerFormatter.st`, mais chaque domaine métier
semble porter ses propres bits de défaut dispersés — à confirmer/infirmer).

Chaînes diagnostic déjà connues : `CODE/C_DIAG_RESEAUX/` (Ethercat, CanOpen,
IhmHeartbeat), bandeau `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` +
`ST_AlarmBanner.st` (carrousel, 50 slots, `AlarmArray`).

## 2. Objectif de la tâche (T356)

Audit exhaustif, PAS de correction dans ce lot — établir un état des lieux
chiffré avant toute décision. Prendre le temps nécessaire, viser
l'exhaustivité plutôt que la vitesse.

Pour **chaque** alarme process ET safety identifiable dans le code (viser
100% de couverture par domaine métier : treuils M1/M2, benne, translation,
synchronisation, sécurité/AU, réseaux/diag, joystick), tracer dans un
**tableau** (CSV ou Markdown tableau, un fichier unique) les colonnes
suivantes :

| Colonne | Contenu |
|---|---|
| Domaine | Treuil M1/M2/Benne/Translation/Sync/Safety/Réseau/Joystick/... |
| Nom du défaut | Variable ou condition exacte |
| Fichier:ligne (déclaration) | Où la condition est calculée |
| Fichier:ligne (écriture du bit) | Où le bit de défaut est réellement mis à TRUE |
| Remonte en bannière ? | OUI/NON + fichier:ligne de preuve |
| Message utilisateur associé ? | OUI/NON + texte exact si trouvé |
| Silencieuse ? | OUI si le défaut existe en code mais n'a aucune sortie visible (ni bannière, ni IHM, ni log) |
| Catégorie sécurité | Process / Safety (ISO 13849 si applicable) |
| Remarque | Écart constaté, ambiguïté, ou "conforme" |

## 3. Méthode — SCRIPT D'INVENTAIRE D'ABORD, LECTURE HUMAINE ENSUITE

⚠️ Une lecture manuelle seule ne garantit PAS l'exhaustivité (risque d'oubli
humain/agent sur un projet de cette taille). **Étape 1 obligatoire : écrire un
script** (`TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py` ou
équivalent, Python) qui parcourt mécaniquement tout `CODE/*.st` et extrait
**tous** les candidats défaut/alarme par pattern de nommage, sans jugement —
un simple grep structuré, zéro faux négatif toléré :
- Chercher tous les patterns candidats de déclaration de variable BOOL dont
  le nom contient (insensible à la casse) : `Fault`, `Defect`, `Alarm`,
  `Warning`, `Error`, `Diag`, `Failure`, `Trip`. Vérifier d'abord
  `NAMING_CONVENTION.md` pour la convention officielle — si elle est stricte,
  l'utiliser en priorité ; si elle est absente ou incomplète pour ce
  vocabulaire, le signaler explicitement (c'est déjà un écart en soi) et
  élargir la liste de patterns en conséquence.
- Pour chaque candidat : fichier, ligne de déclaration, nom exact.
- Le script produit une liste brute (CSV) = univers de départ, garanti
  mécaniquement exhaustif sur les patterns retenus (100% de couverture
  grep, pas d'oubli de lecture).

**Étape 2 : qualification.** Pour chaque ligne de cette liste brute, tracer
manuellement (lecture réelle, pas de supposition) : où le bit est réellement
écrit à TRUE, s'il remonte au bandeau (`FB_Hmi_BannerFormatter.st`), s'il a un
message utilisateur associé, s'il est silencieux.
- Vérifier aussi le sens inverse : le bandeau/carrousel a-t-il des entrées qui
  ne correspondent à AUCUN bit de défaut réel (message fantôme) ?
- Ne pas se limiter aux alarmes actuellement actives en simulation — lire le
  code source, pas seulement observer un état runtime.
- Focus explicite demandé par l'utilisateur : alarmes **treuil M1/M2**,
  **synchronisation**, et **toutes les alarmes safety** en priorité 1 ; le
  reste (translation, benne, réseau) en priorité 2.
- Vérifier aussi côté IHM/SCADA (`CODE/J_SUPERVISION/GVL_IHM.st` et la table
  de correspondance code→texte si elle existe) : un défaut peut remonter côté
  ST mais perdre son texte côté table d'affichage — chemin distinct à vérifier
  séparément, ne pas supposer qu'un bit câblé au bandeau a forcément un texte.
- Vérifier si un outillage CI existant (`TOOLS/AGENT_WORKFLOW/scripts/`) fait
  déjà un inventaire proche (grep de patterns, gates G4xx/G5xx) réutilisable
  plutôt que réinventer — chercher avant d'écrire le script.

## 4. Devoir de challenge

- Ne pas déclarer un défaut "conforme" sans avoir tracé physiquement son
  chemin jusqu'à une sortie utilisateur (bannière ou message) — preuve
  fichier:ligne obligatoire, jamais une supposition de câblage.
- Si un défaut safety semble silencieux, le signaler en tête de synthèse —
  c'est le point le plus critique du lot.
- Si la notion même de "message d'action utilisateur" n'existe pas dans le
  code actuel (aucun mécanisme identifié), le dire clairement plutôt que de
  forcer un rapprochement.

## 5. Livrables attendus

- Le script d'inventaire (`TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py`
  ou équivalent), réutilisable pour une re-vérification future après
  correctifs (non ajouté à `run_all_gates.py` dans ce lot — audit ponctuel,
  pas un gate bloquant).
- La liste brute produite par le script (CSV, univers de départ).
- Un tableau exhaustif qualifié (CSV ou Markdown) sous
  `DOC/WFLOW/AUDITS/AUDIT_T356_ALARMES_EXHAUSTIF_<date>.md` (ou `.csv` en
  complément), traçant chaque candidat de la liste brute.
- Une synthèse courte en tête de document : nombre total de candidats scannés
  par le script, nombre qualifiés silencieux, nombre safety silencieux (le
  chiffre le plus important), écarts majeurs classés par gravité, et le taux
  de couverture du script (candidats trouvés par pattern vs candidats trouvés
  en plus par lecture manuelle, si le script a raté des cas atypiques).
- Contrat `TASK_CONTRACT_T356_*.yaml` (C2, audit).
- `TASKS.yaml` mis à jour (T356), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 6. Contraintes non négociables

- AUCUN `CODE/` modifié — audit pur, zéro correction dans ce lot (les
  corrections viendront dans des tâches séparées une fois l'état des lieux
  validé par l'utilisateur).
- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
- Prendre le temps nécessaire à l'exhaustivité — ce n'est pas un lot rapide,
  la qualité du recensement prime sur la vitesse.
