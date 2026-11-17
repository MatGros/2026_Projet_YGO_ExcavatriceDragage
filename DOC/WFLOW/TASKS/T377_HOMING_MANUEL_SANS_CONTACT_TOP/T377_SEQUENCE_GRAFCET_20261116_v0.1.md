# T377 — Séquence homing : ancienne vs nouvelle (graphique)

> v0.1 · 2026-11-16 · CC03 · lecture seule, document de cadrage.
> Base : PLAN_TASK_v1.0.md §3. `= =` = transition inchangée. [NOUVEAU] = état ajouté.

## 1. Séquence actuelle (T364)

```
HX0_REPOS
  = =
HX1_BUCKET_PREPARE          (fermeture benne palier 1)
  = =
HX1A_COUPLING_INTERLOCK     (WinchSel=0, interlock couplage)
  = =
HX2_CLIMB_COUPLED           (MONTÉE AUTOMATIQUE palier 1 jusqu'au capteur)
  |
  | capteur TOP touché
  v
HX3_FLYING_REFERENCE        (HomeReq "à la volée" MODE A, repli MODE B à l'arrêt)
  |
  | BothAxesHomed
  v
HX4_STABILIZATION_CHECK     (fenêtre inertie, max 3 retries)
  = =
HX5_RELEASE_CLEARANCE       (dégagement zone haute)
  = =
HX6_HOMED_SUCCESS           (MachineHomed := TRUE, commit benne)
HX7_FAILED                  n'importe où si écart
```

## 2. Séquence nouvelle (T377)

```
HX0_REPOS
  = =                                   (inchangé)
HX1_BUCKET_PREPARE
  = =                                   (inchangé)
HX1A_COUPLING_INTERLOCK
  = =                                   (inchangé)
HX2_APPROCHE_MANUELLE                   (état réutilisé, logique neuve)

    DESCENTE ?             MONTÉE (joystick + homme-mort, palier 1)
       |                     | requise pour approcher, jamais obligatoire
       v                     v
  (opérateur            ┌─ capteur TOP touché ──► [NOUVEAU] HX2A_DEGAGEMENT
   pousse)              │                              |   AUCUNE référence écrite
       │                │ REFUS validation ──► retour   |   montée INTERDITE
       │                │ (msg IHM + compteur)         v   descente joystick seule
       │                │                              |
       │                │                              | capteur libre
       │                │ 5 GARDES au même scan :      | + treuils arrêtés
       │                │  1. MAINT_N2                 v
       │                │  2. treuils arrêtés ───► HX7_FAILED
       │                │  3. capteur libre         (cause C8
       │                │  4. manche au neutre       «Capteur haut touché
       │                │  5. pas de contact latched  — re-référencer»)
       │                │                              | Reset conscient
       │                v                              v  en MAINT_N2
       │   VALIDATION (BtnValidation) ──► HX3_REFERENCE_RESTORE
       │                                     |
       │                                     | HomeReq M1/M2 UNIQUES
       └── non requis : la descente          | (preset 8,50 m déjà câblé)
           n'attend rien                     v
                                    HX4_REFERENCE_VERIFY
                                     | preset LU confirmé 8,50 m
                                     | cohérence M1/M2
                                     v
HX5_RELEASE_CLEARANCE
  = =                                   (inchangé)
HX6_HOMED_SUCCESS
```

- Échec HX3 (timeout) ou HX4 (1 seule re-émission puis échec) → HX7_FAILED.

## 2bis. Arbitrage challenge A/B/C du 2026-11-16 (v0.2) — RETENU

Ta position : pas de FAIL après contact, l'arrêt suffit. Arbitrage hybride (B + latch) :

```
HX2_APPROCHE_MANUELLE
    | montée joystick + homme-mort, palier 1
    | message IHM : « approche à vue — proche capteur haut »
    | capteur TOP touché
    v
HX2A_DEGAGEMENT                 (latch TopContactLatched + cause C8 visible)
    |   AUCUNE référence écrite, montée INTERDITE
    |   descente joystick seule (palier 1)
    | dégagé : capteur libre + treuils arrêtés + manche neutre
    v
    retour HX2 (nouvelle approche manuelle) — PAS de retour HX3 direct :
    position après dépassement > 8,50 m, un preset écrirait un datum biaisé.

PAS de HX7 forcé après un simple contact. Reset conscient uniquement si
échec avéré (timeout, preset non confirmé). HX4 reste le dernier rempart :
bande asymétrique réglable, défaut +0,10 / -0,10 m ([8,40 ; 8,60]) — la
référence écrite reste toujours exactement 8,50 m (D5, exploitant 2026-11-16).
```

- Fondement physique : le garde capteur coupe déjà `AscentPermit` au contact
  (`FB_Safety_Winch.st:574`) — le stop ne dépend pas du FAIL.
- Fondement procédural : le latch + cause C8 maintiennent la trace (sinon contacts
  répétés invisibles) tout en permettant la reprise « si échappé, peut faire le homing ».
- Homing à l'arrêt = mécanisme identique aux boutons MAINT_N2 (vérifié :
  `PRG_03:274` BtnHome, garde arrêt `PRG_02:653,706`, preset 8,50 `PRG_02:661,716`) ;
  le cycle couplé ajoute qualification MachineHomed + benne + cohérence M1/M2.

## 3. Ce qui change en une liste

1. La montée HX2 : automatique → manuelle, sous gardes.
2. Le capteur TOP : déclencheur de référence → barrière seule (contact = cycle en échec propre, rien écrit).
3. Le verdict : opérateur (BtnValidation) au lieu du capteur.
4. HX3 : plus de mode "à la volée" — machine déjà à l'arrêt, un seul HomeReq.
5. HX4 : vérification du preset lu (8,50 m) au lieu de la fenêtre d'inertie.
6. +1 cause de défaut C8 « Capteur haut touché — re-référencer ».
