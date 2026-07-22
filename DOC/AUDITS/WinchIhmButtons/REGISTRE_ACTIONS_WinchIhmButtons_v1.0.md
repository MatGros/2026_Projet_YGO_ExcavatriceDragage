# 🗂️ Registre d'actions — Boutons IHM mouvement Winch M1/M2 (v1.0)

> **Réouverture explicite et documentée de la doctrine T40** (`DOC/PLAN_TASK_v1.0.md`, suppression
> IHM_MANU 2026-07-19). Ce n'est PAS une régression accidentelle — décision produit tranchée en
> session avec justification et garde-fous équivalents à ceux qui avaient motivé le retrait.
>
> Cycle : `Discussion → Registre local → TASK_CONTEXT (C4) → double revue A/B TEST_DESIGN → code
> → double revue A/B ST généré → codesys-change`.

---

## 🚦 Contexte — pourquoi réouvrir T40

| Avant (T40, 2026-07-19) | Constat session (captures IHM cible) |
|---|---|
| Winch/Benne = aucun bouton IHM de mouvement, pilotage exclusif joystick homme-mort | L'IHM physique/cible à livrer contient des boutons de mouvement réels : `Btn_WinchBenneUp/Down`, `Btn_WinchRetenueUp/Down`, `Btn_WinchSyncUp` |
| Justification retrait : audit sécurité jugeait le pilotage direct "dangereux" (`AUDIT_Winch_v1.0.md:269`) | Besoin métier réel confirmé : page de mise en service **permanente** (pas temporaire), nécessaire pour piloter treuils indépendamment/couplés, accessible dès MAINT_N1 |

📌 **Ce registre traite cette réouverture explicitement, avec les mêmes garde-fous que ceux qui
avaient motivé le retrait** — pas une extension mécanique du pattern Translation M3 (l'agent de
revue avait initialement recommandé de NE PAS étendre, faute d'un besoin métier connu à l'époque ;
le besoin est maintenant confirmé et documenté ci-dessous).

---

## ✅ Décisions actées en session

| # | Sujet | Décision |
|---|---|---|
| D1 | Comportement bouton | **Maintenu** — mouvement tant que le doigt reste sur l'écran, relâchement = arrêt immédiat (rampe normale). Équivalent homme-mort du joystick, PAS une impulsion. |
| D2 | Sélection mutuellement exclusive | IHM **monotouche** — un seul mouvement actif à la fois (M1 seul / M2 seul / Couplé), contrainte matérielle de l'écran en plus d'un choix logiciel |
| D3 | Mode d'accès | **MAINT_N1** pour le mouvement direct (M1/M2/Couplé) — conforme `AF_Partie-05_Modes_Maintenance_v1.6.md` §MAINT_N1 : *"Commande : Joystick, treuils pilotables unitairement (M1, M2 séparés)"*, usage explicitement prévu dès N1 |
| D4 | Homing / référencement | **Reste MAINT_N2** (aucun changement — déjà le cas dans le code actuel, `FB_Encoder_Homing` : nominal MAINT_N1/N2, unitaire cible libre MAINT_N2 uniquement) |
| D5 | Durée de vie | **Permanente** — reste sur la machine livrée, pas un outil temporaire de mise en service à retirer ensuite |
| D6 | Paliers vitesse | Déjà géré par `FB_Winch`/`FB_SpeedStep` en aval — les boutons IHM alimentent seulement `StartStop`/`Direction`/`SpeedRefPct`, exactement comme le joystick aujourd'hui. Aucune nouvelle logique palier à créer. |
| D7 | Fonctions déjà couvertes (pas de nouveau code) | Homing (`BtnHome`), Benne ouvrir/fermer (`FB_Bucket` + `BtnOpen`/`BtnClose`), Translation + fréquence (`ST_TranslationHMI`), affichage codeurs (`Encoder.RawPos`/`PositionM`) |

---

## 🎯 Nouveauté à créer (le seul vrai delta)

**Mouvement direct par bouton IHM** — M1 seul / M2 seul / Couplé, en plus du joystick existant.

### Architecture proposée — symétrique à `JoystickWinchSelectArbitrated`, PAS `JoystickSelect`

⚠️ **Différence importante avec Translation M3** : Translation a un sélecteur binaire
`TglJoystickMaster` (joystick OU boutons, exclusif). Pour Winch, la sélection **treuil**
(M1/M2/Couplé) existe déjà via `JoystickWinchSelectArbitrated` — **on ne duplique pas** ce
sélecteur. La nouveauté est uniquement la **source de commande** (joystick OU boutons), le
treuil ciblé restant piloté par le même sélecteur qu'aujourd'hui.

Proposition : un `TglJoystickMaster` **par domaine Winch** (nouveau champ, cohérent nommage
convention actée), qui bascule la source de `StartStop`/`Direction`/`SpeedRefPct` dans
`PRG_06_WinchControl`, sans toucher à `JoystickWinchSelectArbitrated` (qui reste le sélecteur
de treuil ciblé, indépendant de la source).

```
IF TglJoystickMaster (Winch) = TRUE THEN
    source = Joystick (comportement actuel, inchangé)
ELSE
    source = Boutons IHM (BtnWinchUp / BtnWinchDown, selon treuil sélectionné)
END_IF
```

### Nouveaux champs IHM proposés (structure — pas encore validée nommage final)

| Struct | Champ | Rôle |
|---|---|---|
| `ST_ModesHMI` (ou nouveau struct dédié) | `TglJoystickMaster` | Bascule joystick / boutons IHM pour le domaine Winch |
| `ST_WinchHMI` (M1TreuilRetenue / M2TreuilBucket) | `BtnUp` | Bouton mouvement montée, maintenu |
| `ST_WinchHMI` | `BtnDown` | Bouton mouvement descente, maintenu |

📌 Sélection M1/M2/Couplé reste `JoystickWinchSelectArbitrated` — un seul jeu de boutons Up/Down
"virtuel" actif selon la sélection courante, ou bien `BtnUp`/`BtnDown` par instance M1/M2 avec le
même verrou mutuel que `FB_Modes.InhibitM1/M2` (empêcher les deux simultanément) — **à trancher
en TASK_CONTEXT avant code**.

---

## ⚠️ Garde-fous obligatoires (repris de la doctrine safety déjà en place)

| Garde-fou | Référence |
|---|---|
| Homme-mort **joystick réel** requis en parallèle, même en pilotage boutons | Précédent exact sur Translation M3 (`AF_Partie-11 v1.9 §6bis`) — écart de sécurité déjà découvert une fois, ne pas répéter |
| `FB_Safety_Winch` reste la seule source de `SafeStop`/`ForbidAscent`/`ForbidDescent`/`PowerCutOff` | Aucun bypass safety, boutons = juste une source de commande alternative au joystick, même filtrage aval |
| Interlock changement de sens (`DirectionInterlockDelay`) inchangé | Déjà dans `FB_Winch`, s'applique quelle que soit la source |
| Sélection M1/M2/Couplé (`JoystickWinchSelectArbitrated`) reste verrouillée par `FB_Modes` | Pas de nouveau chemin de contournement |
| Ponytail interdit (sujet safety C4) | `SAFETY_POLICY.md` |

---

## 🧠 Fiche d'impact à compléter avant TASK_CONTEXT

```md
### WINCH-BTN-01 — Boutons IHM mouvement Winch M1/M2/Couplé

**Décision validée :** boutons IHM maintenus (D1), monotouche (D2), MAINT_N1 (D3), permanent (D5).

**But / risque traité :** page IHM mise en service/exploitation nécessite pilotage direct
treuils, sans passer par le joystick physique — besoin métier confirmé (captures IHM cible).

**À ne pas faire :**
- pas de bouton impulsionnel (D1 tranché : maintenu uniquement) ;
- pas de nouveau bypass safety — FB_Safety_Winch reste la seule autorité SafeStop/Forbid*/PowerCutOff ;
- pas de mouvement bouton IHM sans homme-mort joystick réel en parallèle (précédent Translation §6bis) ;
- pas de modification CODE avant double revue A/B du TEST_DESIGN.

| Domaine | Impact vérifié / à traiter |
|---|---|
| FB / PRG propriétaire | PRG_06_WinchControl (arbitrage §1/§2), aucune modif FB_Winch/FB_Safety_Winch (interface déjà compatible) |
| Producteurs d'entrées | Nouveaux champs GVL_IHM (structs à trancher : TglJoystickMaster + BtnUp/BtnDown) |
| Consommateurs de sorties | PRG_06_WinchControl seul point d'arbitrage à modifier |
| IHM / GVL | ST_WinchHMI (M1/M2), struct sélecteur source à créer/positionner |
| EtherCAT / E/S | Aucun nouveau point I/O physique |
| Cycle / Modes | Aucun impact SEMI_AUTO (branche inchangée) — uniquement branche MAINT_N1/N2 |
| Simulation / PLC tests | Nouveau cas de test : bouton IHM sans homme-mort = pas de mouvement (garde-fou critique) |
| Safety (Enable, SafeStop, PowerCutOff, Reset) | Aucun changement de logique Safety — juste nouvelle source amont, filtrée identiquement |
| DOC impactée | AF_Partie-05 (Modes), AF_Partie-09 (Winch), PLAN_TASK (T40 réouverture tracée), NAVBOARD_MiseEnService |

**Stratégie** : lot unique (petit scope, symétrique Translation déjà validé).

**Préconditions :** structure exacte des nouveaux champs tranchée (TASK_CONTEXT).
**Tests intermédiaires :** bouton sans homme-mort = aucun mouvement (test critique n°1) ;
bouton + homme-mort = mouvement conforme joystick ; relâchement bouton = arrêt rampe normale ;
sélection M1/M2/Couplé inchangée (JoystickWinchSelectArbitrated toujours autorité) ; MAINT_N2/
SEMI_AUTO/DISABLE = boutons sans effet (comme joystick aujourd'hui hors MAINT_N1... à confirmer
si boutons doivent aussi fonctionner en MAINT_N2, cf. doctrine MAINT_N1 ET MAINT_N2 déjà valide
pour pilotage unitaire joystick).
**Critères d'acceptation :** double revue A/B consensus, bundle régénéré, mapping documenté.
**Condition de promotion vers PLAN_TASK :** TASK_CONTEXT + TEST_DESIGN validés.
```

---

## 📚 Sources
- Session utilisateur ↔ Claude (captures IHM cible, comportement bouton, mode accès)
- `DOC/PLAN_TASK_v1.0.md` T40 (doctrine retrait IHM_MANU)
- `DOC/AF_Partie-05_Modes_Maintenance_v1.6.md` §MAINT_N1/N2 (pilotage unitaire déjà prévu dès N1)
- `DOC/AF_Partie-11_Fonction_Translation_v1.9.md` §6bis (précédent homme-mort boutons IHM)
- `AUDIT_Winch_v1.0.md:269` (justification historique du retrait)
- `CODE/MAIN/PRG_06_WinchControl.st` §1/§2 (arbitrage actuel joystick)
- `CODE/TREUILS/FB_Winch.st` (interface StartStop/Direction/SpeedRefPct déjà compatible)
