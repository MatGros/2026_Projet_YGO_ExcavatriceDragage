=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== ANALYSE SEULE — AUCUN CODE/ MODIFIÉ ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). Découverte remontée par T351
(cartographie treuils M1/M2, `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md`) :

- `FB_WinchCmdArbitrationM1.st:117` porte une garde `AND NOT Context.BucketBusy`,
  mais **UNIQUEMENT dans la branche manuelle** (`ELSE` de `Auth.Mode =
  E_Mode.SEMI_AUTO`, ligne 62) — **en SEMI_AUTO, M1 n'a lui-même AUCUNE garde
  BucketBusy** (lignes 56-61). L'asymétrie n'est donc PAS "M1 protégé partout
  / M2 jamais protégé" — c'est plus fin, à vérifier mode par mode.
- `FB_WinchCmdArbitrationM2.st` porte un 3ᵉ chemin de commande distinct, le
  "chemin benne" (`:58-82`), dont le commentaire d'en-tête (`:59-64`) documente
  **déjà** un risque de ce type et cite explicitement le même incident terrain
  que ci-dessous — mais ce chemin est volontairement restreint à
  `WinchSel=2` ou `SEMI_AUTO` (n'existe pas en `WinchSel=1`).
- **Chemin non cité par T351, à tracer séparément** : les boutons IHM
  (`PRG_04_Treuils_Benne.st:104-111`, `IHM.BtnAscentM2`/`BtnDescentM2`)
  pilotent M2 **indépendamment de `WinchSel`**, sans garde `BucketBusy`
  visible à ce niveau — chemin de commande M2 distinct du joystick-Select,
  conditions d'activation différentes, à vérifier à part.
- Garde compensatoire existante : `WinchBothMotionBlockedByBucket`
  (`PRG_04_Treuils_Benne.st:396` — à revérifier, le fichier a bougé plusieurs
  fois) — ne couvre pas le cas `Busy=TRUE` d'après l'analyse T351.

**Incident terrain déjà documenté dans le code** (pas hypothétique) :
`PRG_04_Treuils_Benne.st:1394-1398`, commentaire — *« REX MES 2026-09-04 :
M1 parti seul 59 cm après ouverture benne »* — un verrou d'atomicité de
démarrage couplé existe depuis (mêmes lignes) pour ce cas précis, mais côté
"démarrage synchronisé", pas côté "garde BucketBusy" de ce brief. **La tâche
doit établir si ce verrou existant couvre déjà le scénario M2-seul/BucketBusy
du présent brief, ou si c'est un mécanisme différent qui laisse le trou
ouvert.**

**Position de l'utilisateur (exploitant machine, 2026-09-21) — CONFIRMÉ, pas
hypothétique** : en usage courant, M1 et M2 travaillent normalement toujours
synchronisés. **Mais en MAINTENANCE NIVEAU 2, l'exploitant inhibe
délibérément un ou plusieurs treuils pour travailler sur un seul câble
mécanique — cas d'usage réel confirmé (ex. jour de changement de câble,
enroulement mécanique sur un seul treuil).** Donc le mode "un treuil actif,
l'autre inhibé" **existe et est utilisé en exploitation**, pas seulement en
théorie. Question qui reste à trancher : **pendant ce mode d'inhibition
MAINT N2, le treuil actif peut-il être commandé alors que `BucketBusy=TRUE`,
et si oui la garde manquante sur M2 s'applique-t-elle réellement dans cette
fenêtre ?**

## 2. Objectif de la tâche (T354)

Déterminer, par preuve et non par déduction, si le trou de garde M2 est
**atteignable en exploitation réelle** — c'est la question qui prime sur tout
le reste. Ne pas proposer de correctif dans ce lot.

1. Établir la table de vérité réelle du scénario "M2 commandé seul, benne
   occupée (`BucketBusy=TRUE`), M1 gelé" : dans quels modes machine
   (MANU/MAINT/AUTO/SEMI_AUTO) ce scénario est-il physiquement
   commandable par l'opérateur ou par le cycle auto ? **Distinguer
   explicitement les 3 chemins de commande M2 identifiés** — joystick-select
   (`WinchSel`), boutons IHM directs (`BtnAscentM2`/`BtnDescentM2`,
   indépendants de `WinchSel`), et le "chemin benne" (`FB_WinchCmdArbitrationM2.st:58-82`)
   — chacun avec ses propres conditions d'activation, pas une table unique
   MANU-vs-AUTO. Citer fichier:ligne pour chaque condition d'entrée dans le
   mode et chaque interlock traversé.
2. Vérifier explicitement l'hypothèse utilisateur : en usage normal, M1 et M2
   sont-ils TOUJOURS pilotés ensemble (synchronisation forcée quelque part
   dans le code), ou existe-t-il un chemin réel (pas juste déclaré) où M2 peut
   recevoir un ordre de mouvement sans M1 ?
3. Chercher la doctrine documentée (AF_Partie-10, TASKS.yaml historique,
   commentaires de code) qui justifierait une différence M1/M2 volontaire —
   ou déclarer explicitement "NON SOURCÉE" si rien ne la justifie.
4. Si le scénario est réellement atteignable : proposer 2-3 options de
   correction comparées (ex. ajouter la même garde `NOT BucketBusy` sur M2,
   ou étendre `WinchBothMotionBlockedByBucket` pour couvrir `Busy=TRUE`),
   chiffrées en impact (quels modes seraient bloqués en plus si on ajoute la
   garde).

## 3. Méthode

- Repartir de l'extraction T351 (fichier:ligne ci-dessus), mais **revérifier
  chaque ligne sur le code actuel** — le fichier a bougé plusieurs fois
  pendant T351, ne pas faire confiance aux numéros sans recontrôle.
- Tracer tous les points d'entrée possibles vers une commande M2 (joystick
  MANU/MAINT, cycle AUTO/SEMI_AUTO) et vérifier à chaque point si une garde
  de synchronisation M1/M2 existe en amont ou en aval.
- Table de vérité = tableau explicite {Mode, BucketBusy, M1 état, M2 commande
  possible ?, garde traversée fichier:ligne, verdict atteignable OUI/NON}.

## 4. Devoir de challenge

- Ne pas conclure "atteignable" ou "non atteignable" sans avoir tracé
  physiquement TOUS les chemins de commande M2 identifiés dans T351 (au moins
  les 2 chaînes MANU et AUTO/SEMI_AUTO).
- Le mode MAINTENANCE NIVEAU 2 avec inhibition d'un ou plusieurs treuils est
  un cas d'usage réel confirmé par l'exploitant (changement de câble
  mécanique) — **prioritaire dans la table de vérité**, pas une hypothèse à
  vérifier en option. Tracer précisément ce mode dans le code (comment
  l'inhibition est commandée, quel FB/variable) et vérifier si `BucketBusy`
  peut être vrai pendant que ce mode est actif.
- Si la conclusion est "risque théorique, jamais atteignable en pratique", le
  dire clairement et argumenter — ne pas gonfler la gravité pour se couvrir.

## 5. Chantiers concurrents

- Vérifier `TASK_LOCKS.json` avant de commencer — `PRG_04_Treuils_Benne.st`
  et les FB `FB_WinchCmdArbitrationM1/M2.st` ont été touchés récemment
  (T351 lecture, T262 fermeture benne, T346).
- T355 (catalogue T325 + dérogation bypass) et T353 (outil cartographie)
  touchent des documents proches — pas de CODE/ en commun, risque faible.

## 6. Livrables attendus

- Document d'analyse sous `DOC/WFLOW/TROUBLESHOOTING/FICHES/` ou
  `DOC/WFLOW/AUDITS/` (nom au choix de l'agent, cohérent avec la convention
  du projet), contenant : table de vérité prouvée, verdict atteignabilité,
  doctrine sourcée ou NON SOURCÉE, options de correction chiffrées si
  atteignable.
- Contrat `TASK_CONTRACT_T354_*.yaml` (C3).
- `TASKS.yaml` mis à jour (T354), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 7. Contraintes non négociables

- AUCUN `CODE/` modifié — analyse et options comparées seulement, aucune
  implémentation dans ce lot.
- AUCUN COMMIT sans accord explicite distinct du GO.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle) dans la même
  restitution.
