(* ═══════════════════════════════════════════════════════════════
   🧩 FB_Translation_PositionDecoder — Décodage mot capteurs M3 (5 positions)
   ───────────────────────────────────────────────────────────────
    📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🧩 Brique technique (AF_Partie-03 §2) : contrat minimal, pas de
      StartStop/Enable/Reset/Mode — décode 5 capteurs TOR (Trémie|PV|P2|P1|
      Maintenance) en mot de progression, dérive les 2 limites extrêmes,
      détecte toute combinaison incohérente (défense en profondeur M3) et
      les fronts individuels par capteur (arrivée/cible, robuste décalage came).
   🎯 Mot valide : progression monotone de 11111 (extrême Trémie) à 00000
      (extrême Maintenance) : 11111→01111→00111→00011→00001→00000.
      Tout autre mot = incohérence câblage/mécanique (capteur collé/HS).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation_PositionDecoder
VAR_INPUT
    SensorTremie      : BOOL;   // --> [HW] Capteur extrême gauche (Trémie)
    SensorPV          : BOOL;   // --> [HW] Capteur pré-ralentissement avant Trémie (Point de Vitesse)
    SensorP2          : BOOL;   // --> [HW] Capteur zone de travail P2
    SensorP1          : BOOL;   // --> [HW] Capteur zone de travail P1
    SensorMaintenance : BOOL;   // --> [HW] Capteur extrême droite (Maintenance, accès MAINT_N2 uniquement)
END_VAR
VAR_OUTPUT
    LimitSwitchTremie    : BOOL;   // <-- [STAT] Extrême Trémie confirmé (mot = 11111) (ex-LimitSwitchFwd)
    LimitSwitchMaintenance : BOOL; // <-- [STAT] Extrême Maintenance confirmé (mot = 00000) (ex-LimitSwitchRev)
    Incoherent        : BOOL;   // <-- [DIAG] Mot hors des 6 combinaisons valides -> défaut sécurité (SafeStop+PowerCutOff, voir FB_Safety_Translation)
    SensorsWord       : BYTE;   // <-- [DIAG] Diagnostic (bit4=Trémie, bit3=PV, bit2=P2, bit1=P1, bit0=Maintenance)

    // Exposition des positions individuelles pour consommation par les programmes aval
    // ⚠️ CUMULATIF ("au-dessus de ce seuil") — pour le ralentissement d'approche (zone large,
    // doit tenir toute la durée de l'approche, pas juste un instant). Ne PAS utiliser pour
    // détecter une arrivée/cible (voir TranslationAtXxx ci-dessous, mot exact, avec front).
    TranslationPosTremie      : BOOL;   // <-- [STAT] TRUE = capteur Trémie actif
    TranslationPosPV          : BOOL;   // <-- [STAT] TRUE = capteur PV actif
    TranslationPosP2          : BOOL;   // <-- [STAT] TRUE = capteur P2 actif
    TranslationPosP1          : BOOL;   // <-- [STAT] TRUE = capteur P1 actif
    TranslationPosMaintenance : BOOL;   // <-- [STAT] TRUE = capteur Maintenance actif

    // Détection d'arrivée/cible par FRONT DU CAPTEUR PROPRE à chaque position (montant OU
    // descendant) : le franchissement d'un point Xi est marqué par SON PROPRE capteur qui bascule
    // (front descendant en venant de Trémie = on vient de dépasser Xi ; front montant en venant de
    // Maintenance = on vient d'atteindre Xi). Trémie et Maintenance (bouts de chaîne) n'ont qu'un
    // seul sens d'arrivée valide chacun. ⚠️ Signal TRANSITOIRE (1 cycle) — distinct des
    // TranslationPosXxx (niveau cumulatif, réservé au ralentissement). L'appelant
    // (PRG_05_Translation §0quater) le mémorise en verrou bistable pour le débounce/verrou
    // anti-rebond de FB_Translation.
    TranslationAtTremie      : BOOL;   // <-- [STAT] TRUE 1 cycle : front montant SensorTremie (arrivée venant de Maintenance uniquement)
    TranslationAtPV          : BOOL;   // <-- [STAT] TRUE 1 cycle : front (montant ou descendant) SensorPV
    TranslationAtP2          : BOOL;   // <-- [STAT] TRUE 1 cycle : front (montant ou descendant) SensorP2
    TranslationAtP1          : BOOL;   // <-- [STAT] TRUE 1 cycle : front (montant ou descendant) SensorP1
    TranslationAtMaintenance : BOOL;   // <-- [STAT] TRUE 1 cycle : front descendant SensorMaintenance (arrivée venant de Trémie uniquement)
END_VAR

VAR
    EdgeUpTremie      : R_TRIG;   // . [LOC] Front montant Trémie
    EdgeDnTremie      : F_TRIG;   // . [LOC] Front descendant Trémie
    EdgeUpPV          : R_TRIG;   // . [LOC] Front montant PV
    EdgeDnPV          : F_TRIG;   // . [LOC] Front descendant PV
    EdgeUpP2          : R_TRIG;   // . [LOC] Front montant P2
    EdgeDnP2          : F_TRIG;   // . [LOC] Front descendant P2
    EdgeUpP1          : R_TRIG;   // . [LOC] Front montant P1
    EdgeDnP1          : F_TRIG;   // . [LOC] Front descendant P1
    EdgeUpMaintenance : R_TRIG;   // . [LOC] Front montant Maintenance
    EdgeDnMaintenance : F_TRIG;   // . [LOC] Front descendant Maintenance
END_VAR

// === IMPLEMENTATION ===

{region "§1 Assemblage mot et cohérence"}
// 🧾 Assemblage du mot (bit4=Trémie ... bit0=Maintenance, ordre doc AF_Partie-02 §3bis)
SensorsWord := 0;
IF SensorTremie      THEN SensorsWord := SensorsWord OR 16#10; END_IF;
IF SensorPV          THEN SensorsWord := SensorsWord OR 16#08; END_IF;
IF SensorP2          THEN SensorsWord := SensorsWord OR 16#04; END_IF;
IF SensorP1          THEN SensorsWord := SensorsWord OR 16#02; END_IF;
IF SensorMaintenance THEN SensorsWord := SensorsWord OR 16#01; END_IF;

// 🎯 Les 6 combinaisons valides (progression monotone décroissante Trémie→Maintenance)
CASE SensorsWord OF
    2#11111, 2#01111, 2#00111, 2#00011, 2#00001, 2#00000:
        Incoherent := FALSE;
    ELSE
        Incoherent := TRUE;
END_CASE;

// 🚧 Limites extrêmes — uniquement sur mot valide (évite un Fdc fantôme déclenché par une incohérence)
LimitSwitchTremie := (NOT Incoherent) AND (SensorsWord = 2#11111);
LimitSwitchMaintenance := (NOT Incoherent) AND (SensorsWord = 2#00000);
{endregion}

{region "§2 Reprise capteurs"}
// Reprise des capteurs de position pour les consommateurs aval (passthrough, identique à l'entrée filtrée)
// ⚠️ CUMULATIF — voir avertissement en déclaration, réservé au ralentissement d'approche.
TranslationPosTremie      := SensorTremie;
TranslationPosPV          := SensorPV;
TranslationPosP2          := SensorP2;
TranslationPosP1          := SensorP1;
TranslationPosMaintenance := SensorMaintenance;
{endregion}

{region "§3 Fronts individuels"}
// Front individuel par capteur — voir avertissement en déclaration. Transitoire (1 cycle),
// mémorisé par l'appelant.
EdgeUpTremie(CLK := SensorTremie);           EdgeDnTremie(CLK := SensorTremie);
EdgeUpPV(CLK := SensorPV);                   EdgeDnPV(CLK := SensorPV);
EdgeUpP2(CLK := SensorP2);                   EdgeDnP2(CLK := SensorP2);
EdgeUpP1(CLK := SensorP1);                   EdgeDnP1(CLK := SensorP1);
EdgeUpMaintenance(CLK := SensorMaintenance); EdgeDnMaintenance(CLK := SensorMaintenance);

// Front du capteur PROPRE à chaque position — voir modèle en déclaration.
// Extrémités : un seul sens valide chacune. Points intermédiaires : les deux fronts de LEUR PROPRE
// capteur (montant = atteint en venant de Maintenance, descendant = dépassé en venant de Trémie).
TranslationAtTremie      := EdgeUpTremie.Q;
TranslationAtPV          := EdgeUpPV.Q OR EdgeDnPV.Q;
TranslationAtP2          := EdgeUpP2.Q OR EdgeDnP2.Q;
TranslationAtP1          := EdgeUpP1.Q OR EdgeDnP1.Q;
TranslationAtMaintenance := EdgeDnMaintenance.Q;
{endregion}
