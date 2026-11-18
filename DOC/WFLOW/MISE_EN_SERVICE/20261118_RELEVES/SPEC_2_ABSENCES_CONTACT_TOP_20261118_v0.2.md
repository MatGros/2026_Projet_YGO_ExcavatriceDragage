# SPEC — Absences capteur TOP (v0.2, fusion avec l'exigence « came franchie » + escalade)

CC03, 2026-11-18. Fusionne la v0.1 et l'exigence exploitant transmise via T417-C :
« la came peut franchir le capteur mais doit ARRÊTER toute montée (latch directionnel,
descente seule libre) ; si la montée continue après contact, PowerCutOff ».
Lecture seule, pas de code. Preuves fichier:ligne.

## A0 — Ce qui existe DÉJÀ dans 6956366b (à ne pas refaire)

- Le contact TOP coupe la montée EN DIRECT : `FB_Safety_Winch.st:577-585`
  (`AscentPermit = NOT (CauseTopLimitSwitchActive OR NOT TopPositionSensor ...)`,
  polarité directe TRUE = libre) et `PRG_04:1171-1180` (permis montance lit le DI).
- Cause 5 « Fin de course haut capteur atteint » LIVE (non latchée) :
  `FB_Safety_Winch.st:311-318`.
- Méca D (escalade) : armée en continu pendant `PostRampTimeout` = **3 s**
  (`FB_Safety_Winch.st:376-392`, :112 TonMecaD) → PowerCutOff inclus
  (`:523-531 CausesPowerCutOffActive`) et l'alarme carrousel existe déjà :
  `[M1] ErrorID:12 - MecaD - non-arret au capteur haut` (`FB_Hmi_BannerFormatter.st:969-970`).
- Précédent latch directionnel M3 (modèle à copier) : `PRG_06_Outputs.st:117-119`
  (VAR RETAIN `M3_TremieHardStopLatched`), set sur DI (:439-441), réarmement sur
  mouvement opposé OU Reset hors capteur (:443-447).

## A1 — Latch directionnel « capteur TOP franchi » (NOUVEAU — le cœur de l'exigence)

**Intention** : le contact cut la montée EN LIVE (existant) mais dès que la came
relâche le capteur, la montée redeviendrait possible → il faut SE SOUVENIR du contact
jusqu'au dégagement, comme le fait déjà la trémie pour M3.

**Design** (copie du pattern M3) :
1. `PRG_06_Outputs.st` — VAR RETAIN `M1M2_TopHardStopLatched : BOOL := FALSE`
2. Set : `NOT HwIn.Winch.M1M2_TopPositionFree_DI` (contact, polarité homing directe
   PRG_02:593) → latch TRUE.
3. Réarmement : Reset IHM **hors contact** OU demande descente pure confirmée par
   les deux treuils (ReqDescend actif, à l'image de ReqMaintenanceSemantic M3).
4. Consommation : `PRG_04` permets de montée (:1171-1180) : ajouter `AND NOT
   M1M2_TopHardStopLatched` + publication `FB_MirrorBypassRetain` pour l'IHM/diag.
   Descence JAMAIS touchée.
- Bypass TopLimit : le bypass explicite (`BypassTopLimitSwitch`) doit gâter aussi le
  latch (sinon capteur cassé = machine irrécupérable) — mention explicite au diff.

**TC** : contact → latch ; came relâchée → montée toujours refusée ; descente OK ;
Reset hors contact → relance possible. + TC persist au reboot (RETAIN).

## A2 — Escalade PowerCutOff « montée persiste après contact »

**Design** : ne pas créer de cause (table 0..15 PLEINE). Réutiliser **Meca D exactement**
— son sens est déjà « escalade fin de course haut » :
- `FB_Safety_Winch` : + 1 TON `TonTopEscalate (PT := CfgTopEscalateDelay)`;
  condition d'entrée = contact (polarité homing) **ET** montée commandée
  (`ReqAscent`/`MovementCommanded` — entrées déjà disponibles :18/:425).
- Sortie du TON → `MecaDFaultLatched := TRUE` → cause 11 existante → PowerCutOff +
  alarme carrousel MecaD existante. +3-5 lignes.
- Débogage frein (Meca B / BrakeForceAllowed de 6956366b) : NON touché.

**Délai — décision exploitant 18/11 (après ma proposition 500 ms rejetée) :**
- **Defaut = 2,0 s minimum, paramètre Cfg** (décision l'exploitant : « reste au moins 2s »).
- Justification d'ancrage code : le tempo actuel 3 s (`PostRampTimeout`, FB_Safety_Winch:112)
  est conservé pour le Meca D GENERAL ; la nouvelle tempo contact-maintenue est un
  chemin dédié a 2 s. La mesure de vitesse N2 reste recommandée (hypothèse) pour
  documenter le glissement : a 0,4 m/s (palier 1, `ST_fbMachineHomingCycle_Cfg.st:21`)
  2 s = 0,80 m ; en N2 contacteur direct, a mesurer site.
- Le plancher anti-mitraillement `CST_ContactorMinInterval` 400 ms (PRG_06:114) est
  largement sous le 2 s retenu : aucun risque de mitraillage.

**TC** : contact + montée maintenue → PowerCutOff ≤ délai ; contact + descente →
aucune escalade ; contact + repos → aucune escalade.

## A3 — Messages IHM + décisions exploitant du 18/11 (amendées en vol)

- TOP : le carrousel a déjà MecaD non-arrêt (:969-970) ; il MANQUE le message
  « persistant » du latch : bandeau/action « Position haute déjà dépassée — redescendre
  pour dégager » tant que `M1M2_TopHardStopLatched` (canal OperatorAction/
  SpecialCondition, G408). + le message latch homing de la v0.1 (3 libellés).
- Mou de câble : **v0.1 disait « rien à faire » (exclusion documentée :940-944) —
  l'exploitant a surrogé** : « toute alarme défaut doit apparaître dans le message user ».
  Nouveau **A3bis** : publier AUSSI les warnings dans le carrousel, avec préfixe
  distinct `[W] ` pour restituer le tri bloquant/warning :
  mou de câble (:675-679 → entrée carrousel), surchauffe frein (déjà :966-968),
  surchauffe moteur (déjà :951-953), limites haute/basse (cause 5/6).
  Points de conception pour T417-C : respecter `CST_NbMaxAlarmes` (prioriser les
  bloquants puis les W par ancienneté) ; mettre à jour la décision « AF-07 §6 » qui
  devient « tout défaut visible, W préfixé » ; gate G408 passée sur chaque texte.
- **Portée des parades frein (question exploitant : M1/M2 ou M3 ?)** — vérifié au
  commit : l'exemption « descente pure » de Meca D et `BrakeForceAllowed` visent
  les **treuils M1/M2 only** (PRG_04:967/:998/:1070, FB_Safety_Winch:379-381 ; PRG_05
  et FB_Safety_Translation ne sont PAS dans le diff de 6956366b). Pour **M3**, le design
  d'origine de la barrière Trémie autorise déjà le recul (P1/Maintenance) malgré le
  latch (`PRG_06:449-450`) : le besoin « dégager sans être coupé » est déjà couvert
  pour M3 par la géométrie directionnelle, pas besoin des mêmes exemptions.
- **Desserrage volontaire en N2** : déjà opérationnel en N2 (condition `MaintN2`,
  PRG_04:967) — rien à ajouter ; test de non-régression dans A4.
- **Voyant Reset** (décision « il le faut ») : inchangé vs v0.1 — `PRG_07:614` étendu
  aux sources latched (TC5-TC7 v0.1).

**A3ter — Tests A3bis (tout défaut visible dans le carrousel)**
- Feature (simu) : provoquer un warning non bloquant (ex. mou de câble simulé) →
  l'alarme apparaît dans le carrousel avec préfixe `[W] ` SANS couper les movements ;
  provoquer un défaut bloquant → position carrousel prioritaire conservée.
- Non-régression (simu + site) : (a) le nombre d'alarmes simultanées > `CST_NbMaxAlarmes`
  dégrade proprement (bloquants d'abord, puis W) ; (b) les 5 priorités de bandeau
  (AU/puissance/SafeStop/direction) affichées AVANT tout warning ne changent pas ; (c)
  SEMI_AUTO inchangé.

## Recoupements

- **T377-B** : même FB (FB_Safety_Winch) mais lignes disjointes (cause 1 :277-282) ;
  aucun conflit si 2 commits (latch/escalade après T377-B). A2 n'ajoute AUCUNE cause.
- **6956366b** : A2 complète le chantier Meca D ouvert par ce commit (réactivation N2 +
  exemption descente) — cohérent, aucune reprise du diff existant.
- **Ordre conseillé** : T377-B d'abord (démarrage), puis A1+A2+A3 (un lot), puis
  AnyFaultActive (A part, trivial).

## A4 — Tests pratiques (règle : CHAQUE intention = 1 test feature + 1 test non-régression)

Chaque item a : d'abord en simu (CODESYS, simulateur intégré), puis en site.
Le test non-régression doit être rejouable AVANT/APRÈS avec le même protocole.

**A1 — Latch anti-martelage**
- Feature (simu) : en N2, monter M1/M2 jusqu'au contact du capteur → la montée s'arrête.
  Relâcher la came (redescendre 1 geste), puis RETENTER monter → refus + message
  « position déjà dépassée ». Descendre franchement + Reset → la montée redevient possible.
- Feature (site) : même geste lent, benne vide ou à vue, palier 1.
- Non-régression (simu + site) : (a) une montée NORMALE qui ne touche pas le capteur se
  comporte exactement comme avant (aucun latch, aucun message) ; (b) la descente reste
  TOUJOURS libre contact ou pas ; (c) le homing guidé 5 étapes complet reste jouable de
  bout en bout (c'est son point de blocage historique) ; (d) avec le bypass capteur armé,
  la machine reste manœuvrable (latch gâté) ; (e) SEMI_AUTO : cycle complet inchangé.

**A2 — Coupure puissance (défaut 2 s) si montée maintenue sur le capteur**
- Feature (simu) : contact + MAINTENIR la commande de montée → coupure alimentation
  treuils en ~2 s + alarme carrousel « MecaD - non-arrêt au capteur haut » ;
  pour réutiliser : relâcher, acquitter (Reset), la montée reste verrouillée par A1.
- Feature (site) : mesurer la vitesse N2 réelle AVANT de figer le délai (trace), puis
  test avec consigne mantenue sous surveillance et benne à vide basse.
- Non-régression (simu + site) : (a) contact + AUCUNE commande → AUCUNE coupure
  (repose contre le capteur sans commande ne doit pas couper) ; (b) contact + descente
  pure → aucune coupure ; (c) HORS contact : le Meca D général garde son tempo 3 s
  d'origine (aucun changement de comportement existant) ; (d) le desserrage de frein
  volontaire N2 ne déclenche toujours PAS Meca B (test BrakeForceAllowed inchangé).

**A3 — Voyant Reset étendu**
- Feature (simu) : provoquer 1 défaut acquittable (ex. échec homing volontaire) → le
  voyant Reset s'allume ; Reset → il s'éteint. Idem défaut synthé latched.
- Non-régression (simu + site) : (a) un défaut LIVE (joystick débranché) garde le voyant
  allumé tant que présent — le voyant ne promet plus un Reset magique, il indique la
  disponibilité d'acquittement ; (b) aucun circuit d'entraînement ne change de
  comportement (publication d'information seulement) ; (c) SEMI_AUTO inchangé.

