# 🟡 ADVISORY — Challenge T377 : raisonnement RT globalement sain, 5 corrections exigées avant implémentation/site

**Impact** : le design tient (arrêt au contact préservé par architecture, défauts A/B réellement traités) mais deux ambiguïtés portent la sécurité (mode d'exécution du homing, "barrière = AU") et le produit à demi-mappé n'est pas verrouillé.
**Durée/Horodatage** : ~45 min d'analyse sur le brief seul. Lecture seule, aucun fichier lu — tous les numéros de ligne proviennent du brief et restent à re-vérifier mécaniquement avant intégration. `AGENTS.md` non accessible dans cette mission (mention unique, non bloquante).

---

## Réponses directes aux 4 questions

**Q1 — Validité des points 1-5 du RT :**
1. **Point 1** : diagnostic D1 juste (aucun chemin PowerCutOff câblé depuis le FB homing ; production côté FB_Safety_Winch). Deux corrections : (a) le **mode d'exécution du homing n'est pas tranché** — le brief dit "palier 1" (MANU_N1 + homme-mort) mais toute l'analyse AC3 est faite en MAINT_N2 ; or le masque PowerCutOff (`AND NOT MaintN2`, PRG_04:1632/1653) ne masque qu'en MAINT_N2 — si le homing est accessible en MANU_N1, AC3 y est observable et l'escalade câblée via FB_Safety_Winch est possible à coût faible ; l'amendement AC3 doit être **scopé par mode** ; (b) la formulation **"barrière physique = AU" est surdéclarée** (voir invariant 2).
2. **Point 2** : architecture juste — T377 ne touche pas PRG_04, donc l'arrêt au contact est préservé par discipline de diff ; MAIS la démonstration "stop au contact indépendant du grafcet" est incomplète : la chaîne `EffectivePermit*_Ascent` consommatrice de la barrière et les bypass explicites ("sauf bypass explicite") ne sont ni audités, ni vérifiés contre les neutralisations PRG_04:501-514.
3. **Point 3** : les deux défauts sont réels, les fixes corrects. Ajouts manquants : purge du latch `LastValidationRefused` au changement de mode/init, comptage sur **front montant** du bouton (anti double-comptage), et cohérence GVL_TroubleshootingView + TC après retrait de la cause C8 (aucun TC ne doit plus asserter C8).
4. **Point 4** : liste fichiers et durée plausibles. **Couverture TC insuffisante** (invariant 11) : redémarrage mid-séquence, barrière collée/shuntée, garde d'entrée, assert "position NON modifiée au contact", golden traces des gestes.
5. **Point 5** : avis défendable mais **précondition non énoncée** : le 1er essai M3/MAINT_N2 doit pouvoir se faire avec l'ancien référencement. Si l'ancien protocole est inutilisable (capteur fragile retiré de la fonction référence), inverser l'ordre. À trancher explicitement.

**Q2 — Risques indirects** : voir niveau 1 bis (mode commun MaintN2, barrière shuntée = plus d'arrêt haut, météo sur validation visuelle, skew M1/M2, redémarrage, facteur humain homme-mort, bypass résiduel).

**Q3 — Découplage étapes/mapping** : **non sûr en l'état**. L'inertie naturelle (grafcet jamais entré) n'est pas un verrou fiable car PRG_03:95-99 impose déjà `MachineHoming.CmdWinchSelect` quand Active — un armement partiel peut produire du mouvement. Exiger : verrou `xArmed := FALSE` par défaut consommé par la condition d'entrée (PRG_02/PRG_03), **matrice de mapping sortie→consommateur (file:line)** comme livrable, TC "inertie" vert avant TC "mappé", interdiction d'essai site si la paire de TC n'est pas verte.

**Q4 — Minimal site-test avant acceptation** (ordre, factuel) :
1. Démarrage à froid, manches en l'état (y compris non-neutre) → **aucune entrée homing** ; gestes habituels inchangés (M1, M2, benne, translation, un aller-retour chacun).
2. Garde : tentative d'entrée avec manche non-neutre → refus, aucun mouvement.
3. Health-check barrière : sortie inactive hors zone → entrée autorisée ; sortie collée → entrée bloquée.
4. Approche vitesse min sous homme-mort : relâche en cours → arrêt, pas de FAIL, séquence figée.
5. Contact volontaire barrière (basse vitesse) : **valeur position inchangée** (relever avant/après), latch affiché, dégagement OK.
6. Validation acceptée au repère → preset exactement 8,50 m sur le(s) axe(s) concerné(s) ; validation refusée → message lattché jusqu'au prochain appui.
7. En MAINT_N2 : IHM montre l'état des masques (PowerCutOff, bypass contacteur) pendant l'essai.

---

## Niveau 1 — Invariants (verdicts analytiques sur le reasoning RT ; preuve mécanique requise avant intégration)

1. Diagnostic D1 : aucun chemin PowerCutOff depuis le FB homing, production côté FB_Safety_Winch — `[✅ PASS]`
2. Formulation "barrière physique = AU + stop contact" en MAINT_N2 — `[❌ FAIL]` (arrêt commandé par retrait permis ; PowerCutOff masquée + contacteur final bypassé ⇒ pas de coupure de puissance démontrée)
3. Mode d'exécution du homing (palier 1 vs MAINT_N2) tranché et reporté dans AC2/AC3 — `[❌ FAIL]` (ambiguïté non résolue)
4. Amendements AC2 (4⇒5 gardes), AC4 (23,5 m = benne), typos, `SafetyPermit_Ascent`→`AscentPermit` — `[✅ PASS]` analytique
5. D4 hors périmètre (translation, 0 occurrence `MachineHomed` dans I_TRANSLATION), tâche dédiée — `[✅ PASS]`
6. Chaîne d'arrêt au contact en MAINT_N2 démontrée (permits non neutralisés, aucun bypass armé) — `[❌ FAIL]` (démonstration absente du brief RT)
7. Défaut A (LastValidationRefused même scan) + fix latch, compteur restant juste — `[✅ PASS]` (completer purge mode/init + edge-detection)
8. Défaut B (Cause 8 transient, Fault.Latched exposé HX2A) + fallback retrait C8 — `[✅ PASS]` (conditionné : sorties dédiées latchées, zéro TC asserte C8)
9. Liste fichiers enum/Cfg/FB_CycleMachineHoming/PRG_02/PRG_07/ST_HomingChecklist/FB_TroubleshootingView/GVL_Troubleshooting — `[✅ PASS]`
10. Couverture tests (6 SimBench + 13 TC) suffisante — `[❌ FAIL]`
11. Ordonnancement point 5 avec précondition explicite (ancien référencement fonctionnel pour le 1er essai) — `[❌ FAIL]`
12. Découplage étapes/mapping périphériques verrouillé (inquiétude exploitant) — `[❌ FAIL]` en l'état, sûr après verrou Armed + matrice
13. Garde manche-neutre + geste inchange transformés en TC déterministes — `[⚪ N/A]` (principe retenu par RT, conversion à faire)
14. Portée de preuve : brief seul, lignes non relues — `[⚪ N/A]` (limitation mission ; re-grep obligatoire avant tout PASS terrain)

---

## Niveau 1 bis — Argumentaire technique

- **Arrêt au contact ≠ coupure de puissance en MAINT_N2.** PRG_04:1632/1653 masque `instSafetyWinch*.PowerCutOff` par `AND NOT MaintN2` et PRG_06:355-356 bypass `instSyncContactorFinal` : le contact ne retire qu'un permis de commande (PRG_04:1126-1129) ⇒ arrêt commandé, moteurs sous tension, dépassement fonction de la vitesse d'approche. D1=C est directionnellement juste mais doit requalifier la sûreté réellement offerte et borner l'overshoot par un cap de `StepTgt` en approche, pas par un filtre du capteur (lissage = retard d'arrêt = overshoot accru).
- **Mode à trancher.** "Palier 1" (homme-mort) suggère MANU_N1 ; l'analyse AC3 est faite en MAINT_N2. En MANU_N1, PowerCutOff n'est pas masquée ⇒ escalade câblée possible via FB_Safety_Winch (entrée dédiée). En MAINT_N2, retrait C8 + événement IHM comme le RT. Les deux chemins doivent être énoncés avec le mode de validité de chacun.
- **Risques indirects (Q2)** :
  1. Mode commun : flag `MaintN2` unique masque PowerCutOff des **deux** treuils (1632/1653) — masquage invisible à l'exploitation si non affiché/loggé.
  2. Barrière shuntée/collée (capteur fragile, vraie cause de T377) : plus d'arrêt haut automatique **silencieusement** — health-check à l'entrée indispensable.
  3. Météo/lumière : validation visuelle du repère 8,50 m sous brouillard/éblouissement/nuit ⇒ référence fausse systématique propagée à l'auto — condition de visibilité dans le checklist.
  4. Skew M1/M2 : SyncBlocks neutralisés en MAINT_N2 (PRG_04:501-514) + preset d'un seul visuel ⇒ décalage institutionnalisé, contrainte mécanique à la remise en M3 — exiger validation par axe ou contrôle d'alignement avant preset ; statuer sur la gate d'entrée M3 "les deux référencés".
  5. Redémarrage mid-séquence : reinit propre, jamais de preset sur glitch, latches purgés, pas de reprise automatique.
  6. Facteur humain : homme-mort maintenu longtemps (fatigue/contournement), durée d'approche limitée ; refus ambigu = retries aveugles (latch + raison affichée — couvert par fix A).
  7. Bypass explicite résiduel ("sauf bypass explicite" PRG_04:1126) : état bypass resté armé d'une session antérieure ou armé par le grafcet ⇒ arrêt au contact disparaît ; affichage/verrouillage au boot.
- **Inconnues factuelles** (à lever avant implémentation) : contenu AC1-AC7 ; contenu exact de `EffectivePermit*_Ascent` ; routage de l'homme-mort et son statut en MAINT_N2 ; point d'armement de `MachineHoming.Active` (PRG_02 ?) ; consommateurs de `Fault.Latched` hors checklist ; gate d'entrée M3 sur référencement complet.

---

## Niveau 2 — Plan d'action chirurgical

1. **Localisation** : spec/contrat T377 — **Ancre** : "AC3" — **Action** : rescope AC3 par mode (MAINT_N2 : pas d'escalade routée, événement sorties dédiées + IHM, arrêt = retrait permis avec cap de vitesse d'approche documenté ; MANU_N1 : décider escalation câblée ou amendement identique) et requalifier "AU" en "arrêt commandé niveau commande" — **Outil** : `grep -n "AC3" docs/` + diff contrat — **Risque si ignoré** : déclaration de sûreté fausse sur site.
2. **Localisation** : contrat — **Ancre** : "AC2"/"AC4" — **Action** : appliquer amendements (5 gardes, 23,5 m benne, AscentPermit) après re-vérification grep — **Outil** : `grep -rn "SafetyPermit_Ascent\|AscentPermit" CODE/ docs/` — **Risque** : spec citant un signal inexistant.
3. **Localisation** : ST_MachineHoming + Cfg + PRG_02/PRG_03:95-99 — **Ancre** : struct et condition d'entrée — **Action** : ajouter `xArmed : BOOL := FALSE` consommé par la condition d'activation, plus **matrice de mapping** dans le rapport (preset write, latch, dégagement, IHM, homme-mort consommé, barrière consommée, cap StepTgt → file:line) — **Outil** : `grep -n "xArmed"` + SimBench TC inertie — **Risque** : essai site d'un mi-produit armé (inquiétude exploitant).
4. **Localisation** : SimBench/TC T377 — **Ancre** : suite de tests — **Action** : ajouter les scénarios manquants (démarrage froid neutre/non-neutre, relâche homme-mort, contact avec assert position inchangée, barrière collée, restart mid-séquence, golden gestes M1/M2/benne/translation) — **Outil** : pytest/G200-SimBench — **Risque** : régression gestes et états corrompus non détectés avant site.
5. **Localisation** : ST_HomingChecklist — **Ancre** : conditions d'entrée/validation — **Action** : ajouter visibilité (météo/lumière), health-check barrière (collée ⇒ blocage), cap vitesse d'approche justifié par l'overshoot admissible, règle d'alignement/validation M1-M2 avant preset — **Outil** : revue + TC — **Risque** : référence fausse, barrière shuntée silencieuse, skew mécanique.
6. **Localisation** : PRG_04:1632/1653, PRG_06:355-356 (documentation, hors diff T377) — **Ancre** : "AND NOT MaintN2" / bypass — **Action** : afficher + logger les masques/bypass à l'IHM ; énumérer tous les bypass explicites et prouver que le grafcet T377 n'en arme aucun — **Outil** : `grep -n "MaintN2" CODE/` ; `grep -in "bypass" CODE/` — **Risque** : masquage invisible, imputation d'incident impossible.
7. **Localisation** : décision d'ordonnancement (point 5) — **Ancre** : plan d'essai du 1er test M3/MAINT_N2 — **Action** : écrire la précondition "1er essai réalisable avec l'ancien référencement" ; sinon inverser l'ordre — **Outil** : doc d'essai + relecture RT — **Risque** : 1er essai bloqué, imputation mélangée.

**Décision recommandée** : ne pas lancer l'implémentation ST tant que (a) le mode d'exécution du homing est tranché et AC3 rescopé, (b) la chaîne d'arrêt au contact en MAINT_N2 est démontrée (pas seulement affirmée), (c) le verrou `xArmed` + matrice de mapping sont spécifiés. Le reste des conclusions RT est reconductible tel quel.