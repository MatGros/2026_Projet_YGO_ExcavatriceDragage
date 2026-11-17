# T377 — Revue par simulation mentale GRAFCET v0.3

```
╔══════════════════════════════════════════════════════════════════╗
║  🟡  V E R D I C T :  A D V I S O R Y                            ║
║                                                                  ║
║  GRAFCET structuralement sain (0 impasse, pas de preset          ║
║  accidentel) mais 4 points BLOQUE-SANS-MSG et 7 trous            ║
║  INDEFINI à lever avant implémentation — dont la purge du        ║
║  latch C8, seule véritable impasse de reprise possible.          ║
║                                                                  ║
║  Durée revue : ~30 min | Simulation statique, non exécutée       ║
╚══════════════════════════════════════════════════════════════════╝
```

_Portée et limites : simulation mentale à partir du design v0.3 et des faits code cités dans le brief (PRG_04:1632/1653, 1126-1129 considérés vérifiés par l'émetteur). Aucune lecture du code, aucune exécution. Faits → repris du brief ; inférences → marquées (i) ; inconnues → ⚪._
_Note unique : `AGENTS.md` non accessible dans ce contexte d'exécution ; le standard de sortie et le brief T377 ont servi de référentiel._

---

## Niveau 1 — Grille état → entrées → sorties → verdict

**1. HX0_REPOS — [✅ PASS]**
- ENTRÉES : boot, HX6, HX7-via-Reset. SORTIES : HX1 via (BtnStart OU BtnValidation) + MAINT_N2 + manche neutre.
- ✅ Coupure AU / Enable FALSE / reboot → HX0 est l'état cible. MachineHomed volatile ou persistant : les deux chemins restent valides (re-homing ou reprise directe).
- ❌ BtnValidation sans effet si MachineHomed TRUE (aménagement) : **aucun message de déroutement** → geste silencieux.
- ⚪ Geste parasite : BtnHome unitaire autorisé à HX0 au repos (CycleRunning FALSE) → homing M1/M2 modifie la référence hors GRAFCET, sans annonce. Couvert en aval par HX4 (bande 8,50 ±0,10), mais confusion exploit possible.

**2. HX1_BUCKET_PREPARE — [✅ PASS / 1 INDEFINI sécurité]**
- ENTRÉES : HX0. SORTIES : HX1A (Confirm + neutre) ; HX7 (hors phase, ModeLost) ; HX0 (Enable FALSE).
- ⚪ **Relâche homme-mort à HX1** : comportement non écrit (la règle « permis coupé, pas de latch, reprise en re-tirant » n'existe qu'en HX2). Si le permis n'est pas un ET continu, la benne continue en l'absence d'homme-mort → point de sécurité. (i) : transposition probable du schéma HX2, mais non écrit.
- ❌ Aucun message d'attente « fermeture benne » et aucun timeout → attente opérateur silencieuse.
- ⚪ Reset pendant montée benne (manche tenu) : couper-permis-avant-purge non spécifié → INDEFINI.

**3. HX1A_COUPLING_INTERLOCK — [✅ PASS / 1 BLOQUE-SANS-MSG]**
- ENTRÉES : HX1. SORTIES : HX2 (settle 300 ms + WinchesMechanicallyStopped + neutre) ; HX7 (hors phase).
- ✅ Montée manche pendant HX1A : WinchSel forcé 0 → pas de mouvement → pas de faux hors phase. Réponse correcte.
- ❌ Arrêt mécanique jamais reçu (frein défaillant) → **attente infinie sans message ni timeout**.
- ⚪ Sélecteur tourné pendant HX1A : re-forçage à 0 sans notification (mineur).

**4. HX2_APPROCHE_MANUELLE — [✅ PASS / 2 INDEFINI]**
- ENTRÉES : HX1A. SORTIES : montée (5 gardes), HX2A (contact + latch), HX3 (front BtnValidation + 5 gardes), HX7 (hors phase), HX0 (Reset / Enable FALSE).
- ✅ Refus validation → latch + compteur + message : seul refus entièrement adossé à un feedback. Bon modèle à répliquer.
- ❌ Garde skew / cohérence M1/M2 KO : l'opérateur tire, rien ne bouge, **aucun message spécifié** → BLOQUE-SANS-MSG.
- ⚪ **ClimbTimer expire (300 s)** : effet non écrit (warning non bloquant vs abort → HX7 ?) → INDEFINI. Budget rechargé à chaque relâche → escalade illimitée par à-coups ; contournement possible si le timer était une limite de progression. Intention à trancher.
- ⚪ Purge du latch contact au retour HX2 : non écrite (voir état 5).

**5. HX2A_DEGAGEMENT — [✅ PASS / INDEFINI majeur latch C8]**
- ENTRÉES : contact capteur. SORTIES : HX2 (capteur libre + arrêt + neutre) ; HX0 (Reset). Pas de timeout — voulu et assumé.
- ✅ Message IHM persistant tant que latch : présent. Contenu à figer (doit porter l'interdiction de montée « DESCENTE SEULE »).
- ⚪ **INDEFINI majeur — destin du latch C8 hors des deux sorties prévues** : (a) au retour HX2, la garde HX2 « pas de latch contact » exige une purge non écrite, sinon l'opérateur libère le capteur, descend… et ne peut plus remonter sans Reset complet (benne + couplage + approche) ; (b) Enable FALSE depuis HX2A → HX0 : latch purge ou fantôme ? Non écrit.
- ✅ Montée manche : interdite par latch, pas de mouvement → pas de faux hors phase.

**6. HX3_REFERENCE_RESTORE — [✅ PASS / 1 INDEFINI, 1 BLOQUE-SANS-MSG]**
- ENTRÉES : HX2 (front BtnValidation + 5 gardes). SORTIES : HX4 (BothAxesHomed) ; HX7 (timeout 60 s) ; HX0 (Reset) ; HX0 (Enable FALSE).
- ✅ Preset unique à l'arrêt : pas de preset sur machine en mouvement ; pas de re-boucle de presets à cet état.
- ❌ Timeout 60 s → HX7 **sans cause nommée** (contrairement à ClimbTimer qui a une « cause dédiée ») → message générique probable.
- ⚪ **Reset pendant HomeReq actif** : seul état à mouvement automatique ; l'interruption (couper permis puis purger ?) n'est pas spécifiée → INDEFINI. Priorité de spécification.
- Montée manche pendant preset : si entrées manuelles actives → mouvement concurrent = hors phase → abort HX7 (couvert par le surveillant, brutal, sans cause affichée).

**7. HX4_REFERENCE_VERIFY — [✅ PASS / INDEFINI]**
- ENTRÉES : HX3 (BothAxesHomed). SORTIES : HX5 (verif OK) ; HX7 (verif KO après une re-émission HomeReq) ; HX7 (hors phase) ; Reset / Enable FALSE → HX0.
- ✅ Une seule re-émission HomeReq : pas de boucle de référencement.
- ⚪ Formulation « puis HX7 si re-succes toujours » ambiguë (lecture retenue : re-homing réussi mais verif bande 8,50 KO → HX7). À réécrire sans ambiguïté.
- ⚪ Permis manuels à HX4 non spécifiés : tirer le manche → soit mouvement couplé réel → abort HX7 (cycle entier perdu pour un geste parasite), soit inopérant silencieux. INDEFINI.
- ⚪ Cause d'échec verif (dérive datum) non nommée.

**8. HX5_DEGAGEMENT — [✅ PASS / sous-spécifié]**
- ENTRÉES : HX4 (verif OK). SORTIES : HX6 (neutre + arrêt) ; Reset ; fail-safe habituels.
- ✅ Aucune action requise : transition automatique dès conditions statiques → fonctionne, pas de piège d'attente (conditions immédiatement réalisables).
- ❌ Aucun message IHM spécifié ; geste parasite manche = INDEFINI (même trous que HX4).

**9. HX6_COMMIT — [✅ PASS]**
- ENTRÉES : HX5. SORTIES : HX0 (unique). État transitoire instantané, aucun attente, aucun mouvement possible.
- ✅ Ordre d'écriture implicite « commit benne puis MachineHomed := TRUE » : fail-safe sur fenêtre de coupure (benne commutée sans référence → re-homing, jamais l'inverse). À figer comme invariant d'implémentation.

**10. HX7_ECHEC_FAILSAFE — [❌ BLOQUE-SANS-MSG (messages) / mécanique OP]**
- ENTRÉES : ModeLost pendant cycle ; TransactionAbort (hors phase, grâce 3 s) ; timeout HX3 ; verif KO HX4. SORTIE : Reset (MAINT_N2) → HX0.
- ✅ Aucune action en HX7 → permis à 0 → pas de mouvement parasite possible. Attente sans timeout : voulu, états toujours quittable via Reset (question 1 OK).
- ❌ **Causes d'entrée non énumérées ni affichées** (contrairement à ClimbTimer) : l'opérateur voit « échec » sans savoir lequel ni quoi faire → diagnostic impossible.
- ⚪ **Enable FALSE à HX7 → HX0 sans Reset** : purge équivalente au Reset conscient non spécifiée. Sinon : relance (BtnStart) sans acquittement de la cause → trou fail-safe.
- ⚪ Sortie de mode N2→N1 pendant HX7 : non spécifié.

### Synthèse transitions nommées (14)
- ✅ OPERATIONNEL : 11 (HX0→HX1, HX1→HX1A, HX1A→HX2, HX2→HX2A, HX2→HX3 + refus, HX2A→HX0, HX3→HX4, HX4→HX5, HX5→HX6, HX6→HX0, HX7→HX0).
- ❌ BLOQUE-SANS-MSG : 2 (HX3→HX7 timeout sans cause ; HX7 message d'entrée absent).
- ⚪ INDEFINI : 1 (HX2A→HX2, purge C8) + 7 trous transverses (C8 hors sorties prévues, ClimbTimer, Reset pendant mouvement ×2, permis manuels HX4/HX5, Enable FALSE purge, permis relâche HX1).

---

## Niveau 1 bis — Argumentaire technique

Le squelette d'états est sain : chaque état possède au moins une sortie atteignable, les fail-safe globaux (ModeLost, hors phase avec grâce 3 s, Enable FALSE) sont plaqués partout, le preset est confiné à HX3 avec garde d'arrêt, et le commit benne précède MachineHomed (ordre inverse-sûr). Les défauts sont concentrés sur (1) la destinée du latch C8 hors des deux sorties écrites d'HX2A — seul cas où le design peut créer une impasse de reprise via garde HX2 jamais purgée ; (2) l'asymétrie de feedback : un seul refus (BtnValidation en HX2) a latch+compteur+message, tous les autres gestes parasites sont inopérants sans texte ; (3) HX7 reçoit quatre causes distinctes sans enum ni affichage. Ce sont des trous de spécification, pas des fautes de conception — d'où ADVISORY, pas BLOCK.

---

## Cas d'ENTRÉE/SORTIE manquants (listes consolidées)

**Sorties manquantes (états/trous)**
1. Destin du latch C8 : purge au retour HX2 ? purge/persistance sur Enable FALSE et ModeLost depuis HX2/HX2A ? [impasse potentielle]
2. Effet de ClimbTimer 300 s expire : bloquant (→HX7) ou warning non bloquant ? + escalation par à-coups assumée ou non.
3. Comportement « Relâche homme-mort » à HX1 (transposition du schéma HX2 non écrite) — point sécurité.
4. Purge déclenchée par Enable FALSE : équivalente au Reset conscient ou non ? (crucial depuis HX7).
5. Sortie de mode MAINT_N2→MAINT_N1 pendant HX7 / HX2A : non traitée.

**Entrées manquantes (gestes non couverts)**
6. Reset pendant mouvement réel : montée benne HX1, HomeReq actif HX3, montée couplée HX2 → couper-permis-avant-purge non spécifié.
7. Permis des commandes manuelles hors HX1/HX2/HX2A : tirer le manche en HX3/HX4/HX5/HX6.

**Messages IHM manquants**
8. Causes d'entrée HX7 (enum + texte + action « Appuyer Reset ») ; cause du timeout HX3 ; cause d'échec verif HX4 (dérive datum).
9. Feedback d'attente : HX1 (fermeture benne), HX1A (arrêt mécanique), HX5.
10. Messages d'inopérance : BtnValidation à HX0 déjà référencé ; BtnStart à HX7 ; refus interlock BtnHome (CycleRunning) ; garde skew KO à HX2 ; WinchSel verrouillé.
11. Contenu du message HX2A (doit porter l'interdiction « DESCENTE SEULE »).
12. Verrouillage WinchSel dès HX1 (forcé seulement à HX1A aujourd'hui).

---

## Niveau 2 — Plan d'action chirurgical

**1. Purge latch C8** — Localisation : design v0.3, sections HX2A/HX2 + gate §7. Ancre : « Sortie : capteur libre + arret + neutre → retour HX2 » et « Enable FALSE → ... retour HX0 (gate §7) ». Action exacte : écrire la règle « C8 est purgé (a) à l'entrée HX2 après dégagement réussi, (b) par Reset conscient ; toute sortie d'HX2A par Enable FALSE ou ModeLost exige capteur libre confirmé avant autorisation de relance en HX0, sinon HX0 refuse BtnStart avec message ». Outil : pytest `test_latch_c8_purge_paths` (4 chemins). Risque si ignoré : relance avec latch fantôme → approche montée impossible sans raison affichée, ou contact non résolu silencieusement oublié.

**2. Trancher ClimbTimer** — Localisation : HX2. Ancre : « ClimbTimer 300 s : expire → cause dediee + message ». Action exacte : choisir et écrire « expire = message non bloquant, budget par appui » OU « expire → passage HX7 avec cause dédiée » ; documenter l'escalade par à-coups. Outil : pytest `test_climb_timer_budget_reset`. Risque : opérateur sans retour sur l'effet réel ; limite de progression contournable.

**3. Enum des causes HX7** — Localisation : HX7 + les 4 transitions d'entrée. Ancre : « HX7 : attente Reset conscient MAINT_N2 → HX0 ». Action exacte : définir `CauseFailSafe ∈ {ModeLostDuringCycle, TransactionAbort, HomingTimeout60s, VerifyFailDatum}` ; afficher valeur + « Appuyer Reset pour acquitter » ; relier timeout HX3 et échec HX4 à leur entrée respective. Outil : pytest `test_hx7_entry_causes` + contrôle enum (G521/littéraux). Risque : diagnostic impossible → arrêt machine prolongé.

**4. Harmoniser la purge** — Localisation : gate §7 + §4 (Reset conscient). Ancre : « Reset conscient : purge TOUTES les etapes (§4) ». Action exacte : invariant unique « toute purge (Reset OU Enable FALSE) : (1) coupe les permis à 0 D'ABORD, (2) purge étapes + latches C8 + latch refus + causes, (3) retour HX0 » ; interdire la purge pendant mouvement avant coupure du permis. Outil : revue de séquence + pytest `test_purge_permission_seq`. Risque : reprise sans acquittement depuis HX7 ; purge pendant mouvement → permis résiduel.

**5. Fermer les gestes silencieux** — Localisation : HX0/HX1/HX1A/HX2 + WinchSel + interlock homing. Ancre : « AMENAGEMENT : si MachineHomed TRUE deja, BtnValidation NE relance pas » et « interlock prevu = refuse tant que le cycle tourne ». Action exacte : ajouter message de déroutement BtnValidation-ignoré, messages d'attente HX1/HX1A/HX5, message garde-skew-KO, verrouillage WinchSel dès HX1, message de refus BtnHome. Outil : contrôle enum messages (G340/G521) + test IHM. Risque : opérateur « pousse dans le vide » → abandon, contournement, ou attente infinie de HX1A.

---

**Décision recommandée** : lever les points 1, 3 et 4 (sémantique purge/latch/causes) avant tout codage — ce sont des invariantes transverses qui coûtent cher à refactorer une fois implémentés ; les points 2 et 5 peuvent suivre dans le même lot de design v0.4. Aucun bloquant de sécurité structurel détecté à ce stade, à condition d'écrire explicitement le point 3 de la liste manquants (relâche homme-mort à HX1).