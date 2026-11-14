# BRIEF — Challenge Red Team d'une analyse catalogue (lecture seule, pas de code)

## Rôle
Red Team d'automatisme industriel + task manager. Tu challenger une analyse d'un autre agent.
Tu ne peux PAS lire le dépôt : tout le contexte est DANS ce brief. Raisonner uniquement sur les extraits fournis. Si une info manque, l'étiqueter HYPOTHÈSE, jamais l'inventer.

## Objectif mesurable
Fournir, pour chacune des 5 questions Q1..Q5 ci-dessous, un verdict : CONFIRMÉ / RÉFUTÉ / NUANCE, avec l'argument qui l'appuie (citer un extrait du brief ou l'étiqueter hypothèse). Puis ≤3 pépites (points forts) et ≤3 pièges (angles morts).

## Non-Goals
Pas de code, pas de réécriture du catalogue TASKS.yaml, pas de nouveau périmètre. Tu évalues l'ANALYSE, tu ne l'exécutes pas.

## Contexte projet (2 lignes)
CODESYS 3.5 pour excavatrice de dragage en carrière noyée. Catalogue de tâches DOC/WFLOW/TASKS.yaml géré par un coordinateur unique (CC01). Le chariot M3 (translation) va de P1 (bord bassin) à la trémie ; treuils M1 (levage) et M2 (benne) ; le GRAFCET semi-auto est GELÉ par un document d'amendement strict (gel).

## Question analysée par l'estimateur
L'orchestrateur T000-CC10 a validé 2 ajustements :
- 🔥 T417-C : simu M3 + solutions au problème actuel + terminal dédié.
- 🔥 Nouveau besoin à rattacher : « mouvements combinés treuil + translation, ouverture benne pendant la translation vers trémie en auto. Pas de plongée avant P1 dans l'autre sens. »

## La proposition à challenger (verbatim de l'estimateur)
### Verdict 1 — T417-C : NON renommage, NON fusion
1. NON fusion : T417 (AGY01, mécanique réaliste, en pause token) ≠ T417-C (AGY02, actif, problème courant). Fusion = mélanger acteurs + périmètres, casser le verrou AGY02.
2. NON renommage d'ID : verrou actif, référencé au contrat et au résumé ; précédent T430 : renommage brise les consommateurs.
3. Couvert déjà : l'objectif 4 de T417-C prévoit déjà « dossier de validation (patch+guard) OU bascule C3/C4 » : l'ajout « solutions » est une précision, pas un nouveau périmètre.
4. Action utile : le coordinateur pose son flag et met à jour le champ contexte T417-C en 2 lignes (solutions incluses + terminal dédié). Le terminal dédié n'est pas une tâche — un moyen, à tracer en contexte uniquement.

### Verdict 2 — Nouveau besoin couplage : AUCUNE tâche existante → nouvelle tâche à créer
- Sondé : T383, T382, T389, T345, T331, T324, T361, T334 → toutes séquentielles strictes (gel imposé) ; aucune ne couvre le parallélisme treuil+translation ni l'ouverture benne pendant translation vers trémie.
- Hypothèse structurelle à challenger : AX15B ouvre à l'arrêt (treuils 0, translation 0 — fiche T383/gel) ; le besoin demande l'inverse → amendement de structure du gel + interlocks → criticité C4.
- Contrainte « pas de plongée avant P1 (retour) » : déjà structurée par AX3 (step AX3_WAIT_DIVE_START), mais à re-déclarer explicitement dans l'amendement si le couplage autorise mouvements croisés.

## Pièces factuelles fournies (extraits)

### Fiche T417 (parent) — statut pause, agent AGY01
- titre : « SimBench M3 - mecanique realiste et chaine automate-variateur-mouvement »
- contexte : Decisions exploitant 2026-10-28 : deceleration pilotee par le variateur apres mot zero ; rampe automate legerement plus douce ; estimations geometrie/vitesse acceptees ; balancement secondaire. Aucun depassement ni defaut impose.
- description : Reprendre la fidelite de la chaine complete du simulateur ST. Le programme machine reste intact.
- objectifs : mécanique M3 réaliste ; chaîne automate→variateur→mouvement ; même mécanique manuel et auto ; observer dépassements/butées/défauts naturels ; challenge indépendant, implementation par CDX01, revue du diff.
- avancement : Pause pour limite token agent. Checkpoint sauvegardé (FB_Sim_Translation etc.).

### Fiche T417-B (sous-tâche, statut ⬜ libre, agent —)
- titre : « SimBench — regroupement des variables de simulation en structures SimM3 / SimWinch »
- description : Refactor après validation de T417 L1+L2. bloque_par: [T417].

### Fiche T417-C (sous-tâche ACTIVE, statut pause, agent AGY02, criticité C2, verrou 🔒 AGY02)
- titre : « Challenge & diagnostic simulation M3 (depassement butee petite vitesse) »
- contexte : Phase 1 lecture seule + audit réel M3 (PRG_05/PRG_06/FB_Translation + L_SIMULATION). Dossier provisoire: DOC/WFLOW/TASKS/T000-AGY02_GEMINI_4_HYDRO_CHALLENGE_SIMU_M3.
- description : Tri historique T417 sans effacer, cartographie chaîne réelle M3 vs modèle simulé, registre d'hypothèses, reproduction isolée en sandbox et dossier de patch (fix+guard) si valide.
- objectifs : (1) trier historique T417 ; (2) cartographier chaîne réelle vs L_SIMULATION ; (3) reproduire dépassement de butée en simulation isolée avec oracles ; (4) « Produire le dossier de validation (patch + guard) ou basculer C3/C4 si code production touche ».

### Fiche T383 (statut ⬜, C4, famille cycle, libre) — extraits clés
- Le GRAFCET semi-auto est GELÉ (doc de gel) ; l'étape AX15B_DUMP_OPEN déclare « vidage : ouverture benne au-dessus de la tremie, treuils 0, M1+M2 0 ».
- Principe exploitant retenu : « un grafcet a des transitions definies, il ne peut pas faire de saut ».
- T383 crée une micro-step AX15D (moduler la benne SUR PLACE à l'arrêt, treuils 0, translation 0), avec amendement du gel en phase 0 avant tout code ; criticité C4 (plan humain obligatoire).
- T382 : à P1 (AX3), le pilotage benne annoncé bidirectionnel n'existe pas dans le code (ReqClose jamais généré).
- T324 : régulariser les steps spéciaux hors gel (AX3_WAIT_DIVE_START, AX10B_RACCORDEMENT_P1).
- T391/T390/T392 (clôturées ou autres) portent des défauts M3 (verrou arrivée, faux défaut sur butée) — hors sujet couplage.

## Questions Q1..Q5
- Q1 — Le verdict « NON fusion T417-C dans T417 » est-il solide ? Cherche l'argument qui le RENVERSE ou l'affaiblit (ex. le besoin « solutions au problème actuel » relève-t-il de T417 parent plutôt que T417-C ?).
- Q2 — Le verdict « NON renommage d'ID » est-il solide ? L'ajout « solutions » justifie-t-il plutôt une sous-tâche T417-D distincte, ou rien du tout ?
- Q3 — Le classement « aucune tâche existante ne couvre le couplage » est-il correct sur la seule base des fiches fournies ? Un des candidats sondés couvre-t-il en réalité tout ou partie du besoin ?
- Q4 — La criticité C4 proposée pour la future tâche couplage est-elle proportionnée (touches gel + interlocks), ou sur-/sous-estimée ?
- Q5 — L'assertion « pas de plongée avant P1 déjà structurée par AX3_WAIT_DIVE_START » est-elle justifiée par les extraits, ou fallait-il la marquer hypothèse ?

## Format de sortie attendu (concis)
1. Pour Q1..Q5 : « Qn : VERDICT — 1 à 3 lignes d'argument (citation ou hypothèse étiquetée) ».
2. « Pépites (≤3) : ... »
3. « Pièges (≤3) : ... »
4. « Recommandation actionnable (≤3 lignes) : ... »
