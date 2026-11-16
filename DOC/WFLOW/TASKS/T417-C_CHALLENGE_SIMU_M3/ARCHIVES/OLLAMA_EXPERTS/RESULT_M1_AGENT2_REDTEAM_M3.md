🟡 ADVISORY — CHALLENGE M3 ARRÊT AU 1er TROU (SEMI_AUTO) : aucune des 3 solutions en l'état ne passe les 4 pièges ; combinaison sûre = S2 CORRIGÉ (mécanisme dynamique) + S3 CORRIGÉ (verrou statique post-arrêt), S1 ÉCARTÉ pour la fonction d'arrêt. Durée ≈ 25 min | Horodatage : n/d (rendu hors environnement horodaté).

Note (signalée une fois, non bloquante) : fichiers réels non consultés dans cette exécution, analyse statique établie sur les extraits fournis dans le brief. Aucun verdict PASS mécanique revendiqué ; l'analyse qualifie la conception, la preuve exécutée reste due.

**Faits / inférences / inconnues**
- Fait (brief) : `PositionSensorTarget` alimenté par bistables `M3_AtTremieStable`/`M3_AtP1Stable` (PRG_05) ; `PostRampTimeout = 3s` ; `CauseMecaB` ; ContactorCheck `FB_Brake` ; défauts ErrorId=16 (Méca B) / 64 ; `PositionTgt` = 1 (AX14) / 3 (AX2) ; `TranslationStopTimer` ; `CfgRampDecelFastRate` ; latch `M3_TremieHardStop*` ; `ReqMaintenanceSemantic`.
- Inférence (standard axe à frein, à confirmer au code) : séquence sûre = rampe → immobilisation confirmée → coupure MecaB confirmée → engagement frein, dans la fenêtre 3 s.
- Inconnues décisives : K1 mémorisation ou coupure directe `ReqStart`→`MovementRequested` ; K2 sémantique/délai des bistables PRG_05 ; K3 sortie exacte coupée par `M3_TremieHardStopActive` ; K4 ordre de libération du latch vs mouvement inverse ; K5 temps réel rampe rapide à 20 Hz.

## Niveau 1 — Invariants

**Piège 1 (trou mécanique 1→0→1)**
1. S1 ne consomme pas le capteur pour couper l'arrivée : le trou est traversé sans réaction, arrêt final à la cible/timer ; comportement non oscillant mais S1 ne réalise pas l'arrêt « dès le 1er trou » → `[❌ FAIL]` sur l'objectif.
2. S2 avec armement `ArrivalLock` sur FRONT du bistable et verrou mémoire : le retour à 0 dans le trou ne désarme rien, pas de reprise, arrêt en début de trou par rampe rapide → `[✅ PASS]` sous réserve K2 (bistable SET au bord, sans délai repoussant l'arrêt).
3. S3 : latch insensible au 1→0→1 (mémorisé) → `[✅ PASS]` sur la stabilité ; le résultat machine dépend de l'effet du hard stop (voir piège 3) → effet couvert ailleurs.

**Piège 2 (dégagement en sens opposé)**
4. S1 : aucun blocage par capteur au départ inverse, mais maintien de `PositionTgt` non borné au cycle courant = écrasement de consigne au départ suivant (mauvaise destination) → `[❌ FAIL]` si non borné (K1).
5. S2 : départ inverse non bloqué tant que l'armement exige un FRONT d'arrivée dans le nouveau sens (au départ inversé depuis l'arrêt-sur-trou, le bistable de destination est FALSE) → `[✅ PASS]` ; exception à interdire par test : nouveau mouvement dont la destination = zone de départ (front déjà présent au lancement → mouvement mort-né par lock instantané).
6. S3 : si le reset du latch exige l'EXÉCUTION du mouvement inverse alors que le hard stop interdit tout mouvement → verrou mortel, aucun départ possible `[❌ FAIL]` variante A ; si le latch est libéré SUR LA DEMANDE inverse avant départ → `[✅ PASS]` variante B ; arbitrage = K4.

**Piège 3 (défauts 16/64, ContactorCheck, PostRamp 3 s)**
7. S1 : si `MovementRequested` est mémorisé, couper `ReqStart` n'a aucun effet (ni défaut, ni arrêt au trou) ; si coupure directe au 1er front, le FB enchaîne sa séquence standard → défaut évité seulement si front+verrou (sinon relance au 0 du trou → CauseMecaB par inversions rapprochées) → `[⚪ N/A]` tant que K1 n'est pas levé.
8. S2 tel que spécifié : « `MovementRequested := FALSE` dès que `ArrivalLock` armé » = coupure AVANT immobilisation, séquence puissance/frein violée → risque CauseMecaB, ContactorCheck, PostRampTimeout(3 s) → `[❌ FAIL]` en l'état.
9. S2 corrigé : `ArrivalLock` sert uniquement à activer `CfgRampDecelFastRate` et verrouiller ; `MovementRequested` coupé UNIQUEMENT à immobilisation confirmée (vitesse ≈ 0) → séquence standard respectée, défauts évités → `[✅ PASS]` après correction.
10. S3 : hard stop agissant comme coupure dynamique (MecaB/BrakeRelease) pendant le mouvement à 20 Hz → ordre coupure/frein inversé, contacteur sous charge → ErrorId 16/64 probable `[❌ FAIL]` si effet dynamique (K3) ; acceptable UNIQUEMENT en verrou statique post-immobilisation.

**Verdict B**
11. Aucune des 3 solutions en l'état ne tient les 4 pièges (S1 hors-cible, S2/S3 dangereuses au piège 3, S3 aussi au piège 2 variante A) → `[❌ FAIL]`.
12. Combinaison sûre proposée : S2 corrigé (front+lock+rampe rapide, coupure à immobilisation) comme mécanisme d'arrêt au 1er trou ; S3 corrigé (latch libéré sur demande inverse avant départ, verrou strictement statique) comme interdiction de reprise ; S1 écarté pour l'arrêt, conservable hors sécurité avec `PositionTgt`/timer bornés au cycle → `[✅ PASS]` au niveau conception, sous réserve K1–K5.
13. « 100 % sûr » non proclamable : requiert suite déterministe 10 cas (trou oscillant trémie/P1, départs inverses depuis trou, départ depuis zone cible, AX14, AX2, forçage défauts) avec assertion 0 occurrence CauseMecaB/PostRamp/ContactorCheck → preuve restante `[⚪ N/A]` à ce stade.
14. Aucune modification de périmètre, ni TASKS.yaml, ni commit par ce challenge (lecture seule) → `[✅ PASS]`.

## Niveau 1 bis — Argumentaire technique

Règle de conception déduite : l'événement « 1er trou » déclenche un VERROU mémoire + une RAMPE RAPIDE, jamais une coupure directe. La coupure de `MovementRequested` reste la conclusion normale de `FB_Translation` à l'immobilisation ; la coupure du frein n'intervient qu'après confirmation de coupure MecaB. Trois mécanismes en résultent : (1) pattern anti-oscillation obligatoire sur capteur à 20 Hz = front + verrou, tout trigger d'état rejoue 1→0→1 et provoque stop/relance/ré-stop → CauseMecaB par inversions rapprochées ; (2) tout verrou posé à l'arrivée doit être libérable indépendamment du mouvement qu'il interdit (libération par DEMANDE autorisée), sinon verrou mortel (S3 variante A) ; (3) tout maintien de consigne (`PositionTgt`) doit être borné au cycle courant, sinon détournement du départ suivant (S1 piège 2). Point de calage : si les bistables PRG_05 ont un délai de confirmation, l'arrêt dérive dans le trou ; acceptable si marge entre fond de trou et capteur, à quantifier (K5, rapport à `PostRampTimeout = 3 s` : exiger marge de sécurité ≥ 2× sur la chaîne armement→immobilisation→frein engagé). Immobilisation au milieu du trou (capteur rendu 0 à l'arrêt) n'entrave pas le départ si les repères restent mémorisés — à couvrir par test.

## Niveau 2 — Plan d'action chirurgical

1. Localisation : `FB_CycleSemiAuto.st` (interface translation). Ancre : liaison `ReqStart` → `MovementRequested`. Action : trancher mémorisé ou coupure directe, consigner (K1). Outil : lecture ciblée + grep déterministe. Risque si ignoré : conclusion fausse sur S1 (arrêt fantôme ou coupure surprise).
2. Localisation : `PRG_05_*.st`. Ancre : `M3_AtTremieStable`, `M3_AtP1Stable`. Action : relever SET/RESET (front vs état) et délai de confirmation (K2). Outil : lecture + grep. Risque si ignoré : dérive du point d'arrêt, verdict S2 erroné.
3. Localisation : `PRG_06_Outputs.st`. Ancre : `M3_TremieHardStopActive`, `M3_TremieHardStopLatched`, `ReqMaintenanceSemantic`. Action : identifier la sortie coupée (K3) ; si coupure dynamique en mouvement → refactorer en verrou strictement post-arrêt ; libérer le latch sur la demande inversée autorisée AVANT départ, jamais à la détection du mouvement. Outil : lecture + diff. Risque si ignoré : défauts 16/64 et verrou mortel.
4. Localisation : `FB_Translation.st`. Ancre : section armement arrivée + section rampe. Action exacte : `RTRIG(PositionSensorTarget) AND LastMoveDirection → ArrivalLock := TRUE` (reset uniquement au lancement d'un nouveau mouvement après arrêt confirmé) ; `IF ArrivalLock THEN DecelRate := CfgRampDecelFastRate` ; `MovementRequested := FALSE` UNIQUEMENT `IF ArrivalLock AND AxeStopped`. Outil : pytest + simulateur capteur (séquence 1→0→1 à 20 Hz). Risque si ignoré : CauseMecaB / ErrorId 16 / 64.
5. Localisation : `FB_Safety_Translation.st` / `FB_Brake.st`. Ancre : `PostRampTimeout = 3s`, `CauseMecaB`, ContactorCheck. Action : chronométrer armement → immobilisation → frein engagé en rampe rapide à 20 Hz ; imposer marge ≥ 2× sur fenêtre 3 s ; interdire toute voie coupant BrakeRelease avant confirmation de coupure MecaB. Outil : script de simulation chronométré + assertions. Risque si ignoré : défaut en cadence réelle.
6. Localisation : banc de tests du dépôt. Action : suite 10 cas déterministes listée en invariant 13, verdict par cas, zéro tableau. Outil : pytest (+ scripts du catalogue si disponibles). Risque si ignoré : mise en service sans preuve de non-déclenchement des défauts.

Information minimale manquante pour lever l'ADVISORY : résolution de K1–K5, durée de rampe rapide à 20 Hz, disponibilité des fichiers réels et de l'environnement d'exécution déterministe.