# T377 — Revue par simulation mentale : matrice complete ENTREES/SORTIES de chaque etat

## Ta mission
Simuler mentalement le GRAFCET T377 (design post-arbitrages, pas encore implémente).
Pour CHAQUE etat : lister les conditions d'entree, les sorties possibles, les blocages
potentiels, et se demander « l'operateur peut-il toujours atteindre/quitte cet etat ? ».
Verdict par transition : OPERATIONNEL / BLOQUE-SANS-MESSAGE / INDEFINI.
Enfin : liste des CAS D'ENTREE/SORTIE MANQUANTS + top 5 corrections.

## Etat machine sous-jacent (faits code verifiees)
- Entrees cycle : StartRequest (IHM BtnStart), BtnValidation (IHM BtnValidate APRES mini-lot :
  le BP homme-mort brut du joystick ne declenche plus), Reset (IHM acquittement defaut).
- MAINT_N2 seul autorise l'entree. MAINT_N1 : homing unitaire possible hors cycle.
- HOMING UNITAIRE (hors cycle) : BtnHome/BtnHomingAtZero par treuil AMENDE : interlock
  prevu = refuse tant que le cycle tourne (CycleRunning).
- Reset conscient : purge TOUTES les etapes (§4) → retour HX0, M3Locked relache.
- Sortie de mode pendant cycle → ModeLostDuringCycle → HX7 (echec fail-safe).
- Enable FALSE → toutes sorties a 0, retour HX0 (gate §7).
- Mouvement treuil hors phase pendant cycle (grace 3 s) → TransactionAbort → HX7.
- Perte datum apres homing en mouvement → cause 0 latchee + ReHomingAckRequired →
  MachineHomed FALSE jusqu'au Reset. Arret mecanique confirme = WinchesMechanicallyStopped.
- PowerCutOff masquee en MAINT_N2 (PRG_04:1632/1653). Barriere montee conservee
  (EffectivePermit*_Ascent coupe le permis au contact, PRG_04:1126-1129).

## GRAFCET (design cible v0.3)

HX0_REPOS :
- ENTREES-SORTIE : (BtnStart OU BtnValidation) + MAINT_N2 + manche neutre (garde
  anti-declenchement accidentel) → HX1. AMENAGEMENT : si MachineHomed TRUE deja,
  BtnValidation NE relance pas ; seul BtnStart relance apres etre deja reference.
- AMENAGEMENT : homing unitaire interlock (pas de preset pendant cycle).
- Pas d'autres actions. M3Locked FALSE en HX0.

HX1_BUCKET_PREPARE (fermeture benne) :
- Montee benne : manche tire + homme-mort, palier 1. Confirmation IHM
  BtnConfirmHomingBucket + manche neutre → HX1a.
- Blocage possible : MotionOutOfPhase/ModeLost → HX7.

HX1A_COUPLING_INTERLOCK :
- WinchSel force 0, settle 300 ms, arret mecanique requis, manche neutre → HX2.

HX2_APPROCHE_MANUELLE :
- Montee couplee palier 1 SI : homme-mort+manche tire ET couple ET capteur libre
  ET pas de latch contact ET coherence M1/M2 (garde skew).
- CONTACT capteur → latch + HX2A (PAS de FAIL).
- Validation IHM (front BtnValidation) acceptee SI 5 gardes : MAINT_N2, arret
  mecanique, capteur libre, manche neutre, pas de latch → HX3.
- Refus → latch refuse + compteur + message (latch purge sur Reset ou prochain appui).
- ClimbTimer 300 s : expire → cause dediee + message ; budget reset des que
  commande tombee (montee continue), reprise libre au re-appui.
- Relache homme-mort → montee s'arrete (permis), pas de latch, reprise par re-tirer.

HX2A_DEGAGEMENT (contact capteur, aucune reference possible) :
- Montee INTERDITE (latch). Descente SEULE : homme-mort + manche pousse, palier 1.
- Sortie : capteur libre + arret + neutre → retour HX2 (nouvelle approche).
- Sortie : Reset conscient → HX0. Cause C8 latchee pendant la fenetre, message
  IHM HX2A persistant tant que latch.
- Pas de timeout de degagement (design voulu : Reset ou degagement = sorties).

HX3_REFERENCE_RESTORE :
- Machine a l'arret par construction. UN SEUL HomeReq M1+M2 a l'arret (preset 8,50 m).
- Sortie : BothAxesHomed → HX4. Timeout 60 s → HX7.

HX4_REFERENCE_VERIFY :
- Verif : BothAxesHomed + arret + neutre + coherence M1/M2 1,0 m + bande 8,50
  +0,10/-0,10 → HX5. Echec → UNE re-emission HomeReq puis HX7 si re-succes toujours.
- Mouvement hors phase ici → abort → HX7.

HX5_DEGAGEMENT (neutre + arret requis) → HX6. HX6 : commit benne atomique +
MachineHomed := TRUE → HX0. HX7 : attente Reset conscient MAINT_N2 → HX0.

## Cas systematiques a verifier (pour CHAQUE etat)
1. Entree atteignable ? (conditions realisables, l'operateur la comprend)
2. Toutes les sorties presentes ? Etat sans sortie = piege ?
3. Coupure puissance AU / Enable FALSE / sortie de mode / reboot PLC a cet etat :
   reprise propre ? Etat residuel ? Preset accidentel possible ?
4. Reset conscient a cet etat : consequence OK (benne fermee non commuite, datum...) ?
5. Geste operateur parasite a cet etat (validation, start, boutons benne,
   BtnHome unitaire, changement selecteur treuil) : effet = ? message = ?
6. Message IHM associe present et non ambigu ?
7. HX2A/HX3/HX4/HX5 : que se passe-t-il si l'operateur remonte le manche (montee)
   pendant ces etats ? (mouvement hors phase → abort → OK ?)
8. Le latch contact (HX2A) et le latch refus sont-ils purges au bon endroit ?
   Risque de residuel bloquant ?

## Livrable attendu
- Grille : etat → condition d'entree → sorties → verdict (OP/BLOQUE-SANS-MSG/INDEFINI)
  + 1 ligne par anomalie.
- Liste finale : cas d'entree/sortie MANQUANTS + top 5 corrections (concis, actionnel).
