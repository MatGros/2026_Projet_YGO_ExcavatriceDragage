# TASK-0001 — Restreindre JoystickWinchSelect (M1/M2 seul) à MAINT_N2

**Status**: REVIEW
**Assigned**: Gemini
**Créé**: 2026-07-15 par Claude

---

## 🎯 Objectif (goal vérifiable — pas une simple consigne)
En exploitation normale (`Mode = MAINT_N1`, ou tout mode ≠ `MAINT_N2`), le joystick doit **toujours
piloter les deux treuils couplés** (M1+M2 ensemble), quelle que soit la position du sélecteur IHM
brut `GVL_IHM.IHM_MANU.JoystickWinchSelect` (1=M1 seul / 2=M2 seul / 3=Couplé). Piloter M1 seul ou
M2 seul désynchronise les deux treuils (câble en travers, désalignement mécanique du grappin) —
c'est un geste de mise en service/maintenance, pas d'exploitation courante.

**Pourquoi** : décision utilisateur du 2026-07-15 (session Claude) — piloter M1/M2 individuellement
« ça veut dire qu'il y a potentiellement tout de travers » ⇒ à réserver au `MAINT_N2`, sur le même
principe que `InhibitM1`/`InhibitM2` (`FB_Modes.st`, déjà restreints à `MAINT_N2`).

**Comportement cible** :
- `Mode = MAINT_N2` → le sélecteur IHM brut est respecté tel quel (1/2/3 → M1/M2/Couplé).
- `Mode ≠ MAINT_N2` (DISABLE, MAINT_N1, SEMI_AUTO) → **forcé à Couplé (=3)**, quelle que soit la
  valeur brute du sélecteur IHM.

Chaque critère d'acceptation ci-dessous doit permettre de vérifier ce comportement.

## 📂 Scope
**Fichiers à toucher** :
- `CODE/MODES/FB_Modes.st` — ajouter l'entrée `JoystickWinchSelectRequest : INT` (mappée depuis
  `GVL_IHM.IHM_MANU.JoystickWinchSelect`) et la sortie arbitrée `JoystickWinchSelectArbitrated : INT`,
  calculée sur le **même modèle exact** que `InhibitM1`/`InhibitM2` (lignes ~121-122 actuelles) :
  ```
  IF Mode = E_Mode.MAINT_N2 THEN
      JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
  ELSE
      JoystickWinchSelectArbitrated := 3; // Couplé forcé hors MAINT_N2
  END_IF;
  ```
  (adapter au style ST déjà en place dans le fichier, garder le commentaire REX daté)
- `CODE/MAIN/PRG_04_Modes.st` — câbler `JoystickWinchSelectRequest := GVL_IHM.IHM_MANU.JoystickWinchSelect`
  en entrée de l'instance `FB_Modes` (même pattern que `InhibitM1Request`/`InhibitM2Request`).
- `CODE/MAIN/PRG_10_Outputs.st` (lignes ~248-260, bloc `IF GVL_IHM.IHM_MANU.JoystickSelect THEN`) —
  remplacer les 6 lectures directes de `GVL_IHM.IHM_MANU.JoystickWinchSelect` (M1Fwd_Demand,
  M1Rev_Demand, M2Fwd_Demand, M2Rev_Demand, CoupledFwd_Demand, CoupledRev_Demand) par
  `PRG_04_Modes.instModes.JoystickWinchSelectArbitrated`.
- `DOC/AF_Partie-05_Modes_Maintenance_v1.5.md` — nouvelle version `v1.6`, documenter l'arbitrage
  `JoystickWinchSelectArbitrated` au même endroit que `InhibitM1`/`InhibitM2` (§ Inhibition treuils).
- `DOC/AF_Partie-09_Fonction_Winch_v1.10.md` — nouvelle version `v1.11`, mettre à jour la référence
  `T20` de `PLAN_TASK_v1.0.md` (le sélecteur IHM M1/M2/Couplé reste TODO côté IHM elle-même, mais
  l'arbitrage logiciel MAINT_N2 est maintenant fait) — référencer `AF_Partie-05 v1.6`.
- `DOC/PLAN_TASK_v1.0.md` — mettre à jour la ligne `T20` (préciser ce qui reste réellement ouvert :
  seul le sélecteur physique/IHM visu M1/M2/Couplé, l'arbitrage logiciel est fait).

**Explicitement HORS scope** (ne pas toucher même si tentant) :
- `CODE/SUPERVISION/ST_IHM_MANU.st` — **table figée**, ne JAMAIS y ajouter/retirer un champ. Le champ
  brut `JoystickWinchSelect` y reste tel quel, on ne fait qu'ajouter un arbitrage EN AVAL dans `FB_Modes`.
- `CODE/WINCH/FB_Winch.st`, `FB_WinchSync.st`, `FB_Safety_Winch.st` — aucune modif, l'arbitrage se fait
  en amont (routage `PRG_10_Outputs`), pas dans les FB métier treuil eux-mêmes.
- `InhibitM1`/`InhibitM2` existants — ne pas toucher, juste s'en inspirer comme modèle.
- Pas de bouton IHM physique dédié à créer/documenter ici — ce sera une tâche séparée (reste de T20).

## 🔒 Contraintes (copiées, pas juste référencées)
- **Nommage** : PascalCase strict, aucun hongrois, voir `DOC/NAMING_CONVENTION.md`.
- **`FB_Modes` n'est PAS un FB de mouvement** : pas de `StartStop`/`SafeStop` à ajouter dessus. Il
  garde son profil actuel (arbitrage de droits, comme `InhibitM1`/`InhibitM2`/`HomingApproachEnable`).
- Suivre l'**exemple de code exact** de `InhibitM1`/`InhibitM2` dans `FB_Modes.st` — même structure
  `Request` (entrée brute) → variable arbitrée (sortie), même commentaire de précédence mode.
- Contrat FB général (`AF_Partie-03_Template_FB_Commun_v1.3.md`) : `Reset` = front obligatoire — non
  applicable ici (pas de nouveau `Reset`, on ajoute juste une entrée/sortie sur un FB existant).
- Doc métier applicable : `DOC/AF_Partie-05_Modes_Maintenance_v1.5.md` (arbitrage) et
  `DOC/AF_Partie-09_Fonction_Winch_v1.10.md` (consommation par `PRG_10_Outputs`).
- Versionner toute doc modifiée (`vX.Y` → `vX.Y+1`, jamais écraser une version existante).

## ✅ Critère d'acceptation
- [ ] Compile en CODESYS sans erreur (bundle PLCopenXML généré 0 erreur)
- [ ] `Mode = MAINT_N1` + `JoystickWinchSelect` brut = 1 ou 2 → `JoystickWinchSelectArbitrated = 3`
      (Couplé forcé), M1 seul/M2 seul **impossible** au joystick
- [ ] `Mode = MAINT_N2` + `JoystickWinchSelect` brut = 1 → `JoystickWinchSelectArbitrated = 1`
      (M1 seul respecté)
- [ ] `Mode = MAINT_N2` + `JoystickWinchSelect` brut = 2 → `JoystickWinchSelectArbitrated = 2`
      (M2 seul respecté)
- [ ] `Mode = DISABLE` ou `SEMI_AUTO` → même comportement forcé Couplé que `MAINT_N1` (sécurité par
      défaut, cohérent avec `InhibitM1`/`InhibitM2` qui sont aussi FALSE hors `MAINT_N2`)
- [ ] `PRG_10_Outputs.st` (M1Fwd_Demand/M1Rev_Demand/M2Fwd_Demand/M2Rev_Demand/CoupledFwd_Demand/
      CoupledRev_Demand) lit `PRG_04_Modes.instModes.JoystickWinchSelectArbitrated`, plus jamais
      `GVL_IHM.IHM_MANU.JoystickWinchSelect` directement
- [ ] `ST_IHM_MANU.st` **non modifié** (aucun champ ajouté/retiré/renommé)
- [ ] `AF_Partie-05` et `AF_Partie-09` versionnés (`v1.6`/`v1.11`) avec le nouveau comportement documenté
- [ ] `PLAN_TASK_v1.0.md` ligne T20 mise à jour (préciser ce qui reste vraiment ouvert)

## 📝 Log
| Date | Auteur | Note |
|---|---|---|
| 2026-07-15 | Claude | Tâche créée — décision utilisateur de restreindre M1-seul/M2-seul au MAINT_N2, sur le modèle InhibitM1/InhibitM2 |
| 2026-07-15 | Gemini | Démarrage de la tâche (Status: IN_PROGRESS) |
| 2026-07-15 | Gemini | Travail terminé. Modifications apportées dans FB_Modes.st, PRG_04_Modes.st et PRG_10_Outputs.st. Bundle régénéré. Specs v1.6 et v1.11 créées et référencées. (Status: REVIEW) |
