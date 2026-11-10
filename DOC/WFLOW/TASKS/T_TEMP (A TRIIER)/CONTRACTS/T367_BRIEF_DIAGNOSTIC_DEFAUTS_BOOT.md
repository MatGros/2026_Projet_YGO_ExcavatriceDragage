=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== INVESTIGATION D'ABORD — zéro code tant que le diagnostic n'est pas validé ===

## 1. Contexte

Texte exact de la demande utilisateur (2026-09-21), à reprendre au mot près comme objectif :
« Voir s'il est possible de ne pas avoir de défaut au démarrage, pour ne pas être obligé de
faire de recette ou d'acquittement de défauts et donc de fait de pouvoir réarmer la machine
sans blocage, ce qui est logique parce que la plupart du temps ce sont juste des faux positifs
et des blocages inutiles. »

⚠️ Ceci N'EST PAS l'ancienne tâche T367 ("fusion réarmement AU + acquittement défauts") —
cette ancienne version a été intégralement revertée (125 lignes supprimées) sur demande
explicite : « c'est pas le bon sujet ». Ne rien reprendre de son cadrage.

## 2. Ce qui est déjà connu (à vérifier, pas à répéter aveuglément)

Deux messages de bandeau déjà repérés au boot par l'utilisateur ce soir :
- `[PUPITRE] Boucle urgence ouverte - réarmer` — `FB_Hmi_BannerFormatter.st:680-681`,
  condition `NOT EmergencyChainClosed`.
- `Homing: Erreur ou Échec homing - Acquitter (Reset)` — `FB_CycleMachineHoming.st`,
  condition `Fault.Latched`.

Piste ouverte par un diagnostic antérieur (T369, non validé, à confirmer/infirmer) : la cause 0
de `FB_CycleMachineHoming` (`HomingLostInMotion`) est latchante et n'est effacée par le Reset
QUE si `WinchesMechanicallyStopped` est TRUE au moment de l'acquittement — lui-même dépendant
de 3 retours HW (contacteurs, freins, vitesse codeur) sur M1 ET M2. Si un seul retour est FALSE
au boot (transitoire capteur, câblage, banc), l'acquittement est SANS EFFET quel que soit le
nombre d'appuis — d'où l'impression de "faux positif qui bloque".

## 3. Objectif de la tâche

1. **Cartographier TOUS les défauts qui peuvent être actifs/latchés au boot**, pas seulement
   les 2 déjà connus : grep large sur les conditions de latch dans `CODE/` (chercher les
   patterns `Latching := TRUE`, `Fault.Latched`, tout défaut armé avant confirmation capteurs
   stabilisée après mise sous tension).
2. Pour chaque défaut trouvé : déterminer s'il s'agit d'un **vrai défaut** (condition physique
   réellement anormale) ou d'un **faux positif transitoire de boot** (ex. capteur pas encore
   stabilisé, retour HW pas encore rafraîchi au premier scan, latch posé avant que
   `FirstScanDone`/équivalent ne soit vrai).
3. Pour les faux positifs confirmés : proposer un mécanisme de **grâce au boot** cohérent avec
   le reste du projet (ex. ne pas armer un latch avant N scans stables, ou avant confirmation
   qu'une valeur HW a été rafraîchie au moins une fois) — **sans jamais masquer un vrai défaut**.
4. Distinguer clairement : (a) défauts qu'on peut légitimement ne plus lever au boot,
   (b) défauts qui doivent rester bloquants même au boot (sécurité réelle), (c) cas où le
   problème n'est pas le défaut lui-même mais l'acquittement qui reste sans effet (piste T369
   ci-dessus, potentiellement liée mais distincte).

## 4. Devoir de challenge

- Ne pas se limiter aux 2 messages déjà cités par l'utilisateur — il a dit explicitement que
  "la plupart du temps" ce sont des faux positifs, ce qui suggère plusieurs sources.
- Vérifier si `FB_CycleMachineHoming.st` (boot bug déjà corrigé ce soir, commit `bb9436e1`,
  voir aussi commit du fix auto-arm antérieur) a un lien avec ce sujet ou si c'est indépendant.
- Croiser avec le diagnostic T369 existant s'il est accessible
  (`DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md`
  si présent) — confirmer ou infirmer ses conclusions sur le terrain de cette tâche-ci.

## 5. Livrables

- Rapport écrit : tableau des défauts candidats à un faux positif de boot, preuve
  fichier:ligne pour chacun, verdict (vrai défaut / faux positif / lié à l'acquittement).
- Proposition d'approche (pas de code) pour chaque faux positif confirmé.
- **AUCUN CODE** dans ce lot tant que le diagnostic n'est pas remis et validé par l'utilisateur.

## 6. Contraintes non négociables

- Investigation en lecture seule stricte — zéro modification de `CODE/`.
- AUCUN COMMIT.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même restitution.
- Ne jamais proposer de masquer une sécurité réelle pour "faire disparaître" un défaut —
  le but est d'éliminer le bruit, pas la protection.
