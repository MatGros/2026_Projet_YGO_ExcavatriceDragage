# 🟡 ADVISORY — Challenge H1/H2/H3 : dépassement M3 → choc 0,50 m (trace 27, 2026-09-04, Freq=913)

**Verdict :** aucune des 3 hypothèses n'est réfutable en l'état ; H2 est la seule qui ferme numériquement la trace seule (0,503 m/s ⇒ glissade ≈0,51 m ≥ 0,48-0,50 m requis) mais à la double condition gain réel ≈0,055 **ET** frein dégradé ; H1 est démontrée en banc (latch = seule variable) mais conditionnée à l'état de l'ordre et à l'erreur 64 ; H3 est un défaut de code réel mais conditionné au mode Maintenance.
**Impact :** le simulateur porte **deux angles morts indépendants** (came « infinie » de `FB_Sim_PositionSensor.st`, branche Maintenance :441 jamais jouée au banc) : son « arrêt propre » est un artefact de modélisation, pas une preuve de sûreté — ne pas s'appuyer dessus pour clore l'enquête.
**Durée/Horodatage :** ~45 min d'analyse, restitution immédiate. Aucun fichier modifié, aucun essai machine. Statuts ✅ = faits banc/code fournis-vérifiés (F) + calculs reproductibles par formule citée (I) ; ⚪ = inconnues déterminantes (X).

## Niveau 1 — Invariants

1. ✅ (F banc) Ré-énergisation au décrochage présente dans la logique as-built : trou de came 4 cm → 1 ré-énergisation, pénétration 0,0836 m — le permis `PRG_06_Outputs.st:431-450` est bien ré-ouvert sur perte capteur avec ordre maintenu.
2. ✅ (F banc) Causalité H1 isolée : sans latch → sortie came → ré-accélération → choc 0,50 m ; avec latch seul → arrêt 0,0486 m. Une seule variable change l'issue.
3. ✅ (F code) Gain audit 0,0551 m/(Hz·s) consigné (`FB_Sim_Translation.st:156`), clamp 0,05 (`FB_Translation_OdometryGain.st:57`) : le simulateur borne structurellement **sous** la donnée auditée.
4. ✅ (I, d = v·t + v²/(2a)) H2 réfutée à gain nominal : 9,13 Hz ⇒ 0,183 m/s ⇒ glissade ≈0,10 m ≪ 0,48 m requis. Et réfutée frein nominal : même à 0,0551, frein (0,05 s ; 1,75 m/s²) ⇒ ≈0,10 m. H2 exige **deux** déviations simultanées.
5. ✅ (I) H2 cohérente à gain audit : 0,503 m/s + frein humide (0,30 s ; 0,35 m/s²) ⇒ 0,151 + 0,362 = 0,513 m ≥ 0,478-0,50 m requis ; choc à ~0,10-0,15 m/s résiduel. Marge 12-34 mm ⇒ incident prédit seulement en haut de plage — la trace (913) est exactement là ; à 5 Hz, même dégradé : 0,19 m, pas de choc.
6. ✅ (I) Trace auto-cohérente : +115 ms × 0,20 m/s = 23 mm ≥ marge de sortie 18,3 mm (à 10 Hz, fin de came modélisée 0,04 — arrêt nominal 0,0217) — perte capteur explicable par un simple dépassement d'arrêt, **capteur sain** (excès : 4,7 mm, régime limite). Frein nominal déduit des deux arrêts (F modèle) : ≈0,05 s ; ≈1,75 m/s².
7. ⚪ (X) Mapping + classe d'ErrorId=64 (auto-reset vs latching) et effet sur le permis — information minimale manquante : définition au catalogue d'erreurs + présence dans la condition logique hors :431-450.
8. ⚪ (X) Sémantique signaux : Freq = sortie variateur réelle ou écho de consigne ? ContactFrein = ordre ou retour mesuré ? — discriminant n°1 entre H2 (coasting) et H1/H3 (axe encore alimenté).
9. ⚪ (X) Géométrie came réelle (longueur, bord actif, type capteur mécanique/inductif, NO/NF) : le 0,04 m du sim est une valeur de test, pas une cote machine.
10. ⚪ (X) Trace post-26553 ms manquante (décroissance Freq ? nouvelle Cmd ? bit Mode ? position ?) + nature exacte de la « butée électrique » (switch câblé vs limite logicielle) et cote vs 0,50 m.

## Niveau 1bis — Argumentaire par hypothèse

### H1 — Came finie + perte capteur post-passage + permis sans latch (:431-450)

**1) Forces**
- (F banc) Causalité isolée par contre-épreuve : latch seul → 0,0486 m ; sans latch → 0,50 m. Mécanisme démontré, pas seulement plausible.
- (F banc) Le comportement dangereux existe déjà dans le modèle as-built (ré-alimentation dans le trou, 0,0836 m) ; seule la restitution du signal après le trou (« came infinie ») le transforme en arrêt propre — **l'arrêt propre du sim est un artefact**.
- (I) Marge de sortie mince : 18,3 mm à 10 Hz, absorbés par ~+92 ms de retard frein au-delà du nominal (preset banc 0,25 s ≫). H1 est une hypothèse du **haut de plage** ; à 5 Hz il faudrait ~+320 ms (frein quasi mort → bascule H2). La trace (9,13 Hz) y est.
- (I) Timing trace compatible (23 mm à +115 ms ≥ 18,3 mm).

**2) Contre-argumentaire strict**
- (F trace) L'ordre n'est **pas** maintenu sur l'extrait (Cmd 1→0 à 26438). Le scénario banc n'est terrain que via (a) cycle reset erreur-64 **puis nouvelle demande** — absente de l'extrait — ou (b) coupure cmd non parvenue au variateur (cf. Freq=913 encore affiché à +115 ms).
- (X) ErrorId=64 : si latching **ET** entrant dans la condition du permis, la ré-énergisation est impossible tant que l'erreur vit → H1 doit passer par le reset. Si warning auto-reset → jouable direct. Verdict H1 **indéterminé sans cette lecture**.
- (X) Sémantique du flanc Tremie : 1→0 peut être un flanc nominal de fin de zone ; anomalie seulement si l'axe franchit le bord physique de came. Bord actif/type capteur à confirmer au plan — un capteur NF traité « perte = défaut » inverserait la lecture.
- (I) Sémantique probable du permis à confirmer par lecture : « ré-armement dès que la zone n'est plus vue » (fail-dangerous). Le banc prouve ce comportement sur le modèle, pas la table de vérité exacte de :431-450.
- (I) Conjonction de 3 conditions (came réelle + frein 0,25/0,8 + ordre tenu) : a priori la moins parcimonieuse ; recevable si ≥2 prouvées.
- (I) Effet de bord correctif : latch naïf = axe immobilisable en maintenance → reset conditionné obligatoire (accusé + capteur ré-acquis + direction sortante).

**3) Paramètres à exposer + critère**
- `Sim_CamModel` : INFINITE_HOLE (as-is) / FINITE ; `Sim_CamStart_M` / `Sim_CamEnd_M` (bords, cotes plan machine ; 0,04 actuel étiqueté « valeur de test »).
- `Sim_PermitLatchCamExit_BOOL` : FALSE = as-built :431-450 / TRUE = latch (rejoue A/B : 0,50 vs 0,0486).
- `Sim_InjectErrorId`=64 + `Sim_ErrorClass` (AUTORESET_s ou LATCHED+ack) + `Sim_HoldCmdAfterCut_s` + scénario « reset puis nouvelle cmd ».
- Critère : FINITE (cotes réelles) + frein RETARDE + ordre tenu 9-10 Hz → 0,50 m atteint ⇒ H1 suffisante ; sinon balayage `BrakeDelay` 0,05→0,30 s pour le seuil de sortie, confronté à l'essai frein réel.

### H2 — Vitesse réelle sous-estimée (gain > 0,02) + glissement + frein dégradé

**1) Forces**
- (F code) Preuve documentaire interne : gain audit 0,0551 **mesuré** (×2,7 du gain simulé) et clamp 0,05 prouvant que le sim borne sous l'audit — optimisme par construction, pas par hypothèse.
- (I) Chaîne physique **seule** suffisante : 0,503 m/s + frein humide ⇒ 0,513 m → choc sans aucune hypothèse logicielle ; la perte capteur n'est même pas nécessaire ((F banc) 0,3797 m à gain 0,045 + frein humide sans mobiliser le décrochage).
- (I) Dépendance en vitesse prédite et conforme : choc seulement vers 9-10 Hz (5 Hz ⇒ 0,19 m même dégradé) — la trace est à 9,13 Hz.
- (I) Phénomène générique translation (contamination rail, frein fadé/usé) ; +115 ms sans réaction = coasting cohérent (~6 cm à 0,50 m/s).

**2) Contre-argumentaire strict**
- (I, réfutation double) Gain nominal OU frein nominal ⇒ ≈0,10 m ≪ requis. Deux déviations **simultanées** à prouver — mais chacune est directement mesurable.
- (X) État du frein non prouvable par la trace si ContactFrein = bit d'ordre : nécessite essai frein instrumenté ou historique maintenance (usure, température, contamination). Sinon H2 = compatibilité, pas démonstration.
- (X) Validité du 0,0551 : même axe M3 ? charge ? date d'audit vs évolutions machine ? Un chronométrage entre deux repères à ~9 Hz tranche en 10 min.
- (X) Si Freq=913 à +115 ms est une **sortie réelle** post-coupure ⇒ axe alimenté : le coasting pur est invalidé au profit d'une commande toujours active (H1/H3, ou voie 4 « coupure non effective »). **LE discriminant économique.**
- (I) H2 est muette sur l'erreur 64 : vérifier que le mapping d'erreur peut résulter de ce scénario, sinon compléter la chaîne.

**3) Paramètres à exposer + critère**
- `Sim_Gain_MPerHzS` : plage [0,02 ; 0,06], défaut verrouillé 0,02, override banc **loggé** (clamp 0,05 conservé en production).
- `Sim_BrakeDelay_s` / `Sim_BrakeDecel_Ms2` presets nommés : NOMINAL (0,05/1,75, déduit), RETARDE (0,25/0,80), HUMIDE (0,30/0,35).
- `Sim_Slope_pct` (1 % ⇒ +0,098 m/s²), `Sim_LoadMass_Kg`, `Sim_InertiaDecoupled_BOOL`.
- Critère : grille gain×frein automatisée, iso-ligne « 0,50 m atteint » ; l'exploitant reporte gain mesuré + essai frein : point **dans** la zone ⇒ H2 validée ; hors ⇒ réfutée.

### H3 — Branche Maintenance sans inhibition position (`PRG_06_Outputs.st:441`)

**1) Forces**
- (F code) Asymétrie avérée, non spéculative : `EffectivePermitM3_Maintenance` sans `HardStop` ni `AND NOT M3_PosMaintenance_DI`, contrairement à la branche nominale — signature typique de mode ajouté après coup / copier-coller.
- (I) Chaîne la plus courte : en Maintenance, aucune inhibition position → l'axe va à consigne jusqu'au bloc, **quel que soit** frein et capteur ; la perte capteur devient conséquence (traversée de came à pleine consigne), pas cause. Aucun paramètre dégradé requis.
- (I) Angle mort exact du simulateur : si le banc ne joue que le chemin opérateur, le défaut est inreproductible **par construction** — « sim propre / machine choquée » est la signature attendue d'une branche non modélisée. Deuxième angle mort indépendant du sim.

**2) Contre-argumentaire strict**
- (X) Condition d'usage : manœuvre incident **en mode Maintenance** (bit Mode absent de l'extrait ; trace complète/journal d'équipe tranche). Mode opérateur avéré ⇒ H3 disculpée pour cet événement (défaut à corriger quand même).
- (X) Dérogation possible : si le mode Maintenance autorise volontairement le passage de zone (intervention sur la butée), c'est une conception — à prouver par doc/consigne HMI ; il resterait à expliquer le maintien d'ordre et l'absence de coupure.
- (X) Butée électrique : si un switch câblé (chaîne/STO) existe, H3 seule ne suffit pas (il faudrait qu'il soit hors de la chaîne maintenance OU défaillant). Si la « butée électrique » est la limite logicielle pilotée par ce permis, H3 suffit à tout expliquer.
- (I) La coupure synchrone Cmd 1→0 + erreur 64 (26438) n'est pas produite naturellement par H3 (ordre requis maintenu) → scénario à compléter (reprise post-reset ou second ordre), comme H1.
- (I) Ergonomie : maintien d'ordre ≈1,0-2,6 s (0,48 m à 0,50/0,18 m/s) ; plausible en maintenance (homme présent), à vérifier (ordre à impulsion ?).

**3) Paramètres à exposer + critère**
- `Sim_MaintenanceMode_BOOL` + banc exécutant le **POU PRG_06 réel** contre E/S simulées (zéro ré-implémentation) ; `Sim_PRG06_MaintHardStopPatch_BOOL` : FALSE as-built / TRUE corrigé (A/B).
- `Sim_HoldCmdAfterCut_s` (maintien humain réaliste borné, pas infini).
- Critère : Maintenance + gain nominal + frein nominal + ordre tenu 9,13 Hz → 0,50 m atteint sans aucun paramètre dégradé ⇒ H3 suffisante seule (la plus parcimonieuse) ; sinon H3 = facteur contributif seulement.

## Vérifications décisives (coût croissant)

1. (0) Lire mapping + classe d'ErrorId=64 et sa présence dans la condition du permis.
2. (0) Rejouer la trace complète ≥26553 ms : Freq décroît ou figée ? nouvelle Cmd ? ContactFrein ? bit Mode ?
3. (0) Établir la sémantique : Freq (retour/consigne), ContactFrein (ordre/retour).
4. (~30 min) Plan + mètre : longueur de came, bord actif, type capteur, gap capteur↔butée, cote butée électrique vs 0,50 m.
5. (~10 min) Chronométrage à ~9 Hz ⇒ gain réel (vs 0,0551).
6. (essai) Frein : temps d'engagement + décélération (vs 0,30/0,35).
- Voies concurrentes hors périmètre à écarter par les mêmes vérifications : butée câblée HS/bypass ; coupure cmd non effective au variateur (expliquerait Freq=913 sans ré-permis) ; contacteur frein soudé.

## Niveau 2 — Plan d'action chirurgical

1. **Localisation :** `FB_Sim_PositionSensor.st` — **Ancre :** `CamDropoutWidth` — **Action :** remplacer par `Sim_CamModel` (INFINITE_HOLE/FINITE) + `Sim_CamStart_M`/`Sim_CamEnd_M` ; défaut FINITE seulement après relevé terrain. **Outil :** banc paramétrique, pytest scénarios H1 (rejouer 0,0836 / 0,0486 / 0,50). **Risque si ignoré :** le sim masque le danger came finie ; toute validation future est un artefact.
2. **Localisation :** `FB_Sim_Translation.st:156` + `FB_Translation_OdometryGain.st:57` — **Ancre :** gain audit 0,0551 / clamp 0,05 — **Action :** exposer `Sim_Gain_MPerHzS` [0,02-0,06] override loggé + presets freins nommés. **Outil :** grille gain×frein automatisée + iso-0,50 m. **Risque :** H2, la plus quantitative, reste non testable par l'exploitant seul.
3. **Localisation :** `PRG_06_Outputs.st:441` — **Ancre :** `EffectivePermitM3_Maintenance` — **Action :** ne pas modifier avant décision ; préparer le patch (`HardStop` + `AND NOT M3_PosMaintenance_DI`) sous flag A/B banc. **Outil :** banc exécutant le POU réel. **Risque :** corriger immédiatement = détruire la reproductibilité du terrain ; ne jamais corriger = récurrence si H3 confirmée.
4. **Localisation :** catalogue erreurs + condition du permis — **Ancre :** ErrorId=64 — **Action :** lire classe/effet, exposer `Sim_ErrorClass`. **Outil :** grep déterministe sur :431-450 + gestion d'erreur. **Risque :** scénarios H1/H3 rejoués avec la reprise possible/impossible inversée.
5. **Localisation :** `PRG_06_Outputs.st:431-450` — **Ancre :** permis sans latch — **Action :** latch candidat à reset conditionné (ack + capteur ré-acquis + direction sortante) sous `Sim_PermitLatchCamExit_BOOL`. **Outil :** A/B banc. **Risque :** latch naïf = bloquant maintenance ; absence de latch = ré-énergisation si H1 confirmée.

## Limites & auto-revue

- Chiffres banc (0,0836 / 0,0486 / 0,3797) pris comme fournis-coordinateur, **non re-exécutés ici** — à rejouer après exposition des paramètres.
- Calculs fermés sans rampe variateur ni dynamique contacteur : tolérance ~±15 % sur les seuils (18,3 mm ; 0,51 m). Pas de verdict PASS annoncé sur vérification non exécutée : les statuts ✅ se réfèrent aux faits fournis ou à des formules reproductibles.
- Frein nominal (0,05 s ; 1,75 m/s²) = déduction des deux arrêts nominaux, pas une mesure.
- Aucune modification de fichier, aucun essai machine ; périmètre analyse/lecture strict.

## Décision exploitant recommandée

- Ne **pas** trancher H1/H2/H3 sur la trace seule : elle est compatible avec les trois ; le discriminant est postérieur à 26553 ms.
- Enchaîner V1→V6 (coût nul à faible) ; mesurer gain réel + essai frein **avant** tout verdict.
- Corriger :441 sauf dérogation documentée (défense en profondeur), en conservant la variante as-built au banc pour l'enquête ; exposer les paramètres du Niveau 2 avant de rejouer les campagnes.