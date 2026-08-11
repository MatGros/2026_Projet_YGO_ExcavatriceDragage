(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Translation_PositionDecoder — Décodage mot capteurs M3 (5 positions)
   ───────────────────────────────────────────────────────────────
    📄 Doc métier : DOC/AF_Partie-02_Architecture_Programme_v3.1.md §3
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
    SensorTremie      : BOOL;   // Capteur extrême gauche (Trémie)
    SensorPV          : BOOL;   // Capteur pré-ralentissement avant Trémie (Point de Vitesse)
    SensorP2          : BOOL;   // Capteur zone de travail P2
    SensorP1          : BOOL;   // Capteur zone de travail P1
    SensorMaintenance : BOOL;   // Capteur extrême droite (Maintenance, accès MAINT_N2 uniquement)
END_VAR
VAR_OUTPUT
    LimitSwitchFwd    : BOOL;   // Extrême Trémie confirmé (mot = 11111)
    LimitSwitchRev    : BOOL;   // Extrême Maintenance confirmé (mot = 00000)
    Incoherent        : BOOL;   // Mot hors des 6 combinaisons valides -> défaut sécurité (SafeStop+PowerCutOff, voir FB_Safety_Translation)
    SensorsWord       : BYTE;   // Diagnostic (bit4=Trémie, bit3=PV, bit2=P2, bit1=P1, bit0=Maintenance)

    // 🆕 Exposition des positions individuelles pour consommation par les programmes aval (migration PRG_00_Inputs)
    // ⚠️ CUMULATIF ("au-dessus de ce seuil") — pour le ralentissement d'approche (zone large,
    // doit tenir toute la durée de l'approche, pas juste un instant). Ne PAS utiliser pour
    // détecter une arrivée/cible (voir TranslationAtXxx ci-dessous, mot exact, avec front).
    TranslationPosTremie      : BOOL;   // TRUE = capteur Trémie actif
    TranslationPosPV          : BOOL;   // TRUE = capteur PV actif
    TranslationPosP2          : BOOL;   // TRUE = capteur P2 actif
    TranslationPosP1          : BOOL;   // TRUE = capteur P1 actif
    TranslationPosMaintenance : BOOL;   // TRUE = capteur Maintenance actif

    // 🆕 2026-08-06 (REX terrain, confirmé sur machine réelle) : mot EXACT (5 bits combinés)
    // ABANDONNÉ pour la détection d'arrivée/cible — fragile au décalage came. Détection par FRONT
    // DU CAPTEUR PROPRE à chaque position (montant OU descendant) : le franchissement d'un point Xi
    // est marqué par SON PROPRE capteur qui bascule (front descendant en venant de Trémie = on
    // vient de dépasser Xi ; front montant en venant de Maintenance = on vient d'atteindre Xi) —
    // PAS par le capteur voisin (une tentative précédente basée sur le mot thermomètre utilisait le
    // capteur PRÉCÉDENT et armait le point ~un cran trop tôt, dès l'entrée de la zone d'approche au
    // lieu du franchissement réel du point — confirmé en direct sur machine : arrêt bloqué à P2 au
    // lieu de P1). Trémie et Maintenance (bouts de chaîne) n'ont qu'un seul sens d'arrivée valide
    // chacun (pas de zone au-delà). ⚠️ Signal TRANSITOIRE (1 cycle) — distingue "être ENTRE 2
    // capteurs" (zone, niveau, TranslationPosXxx cumulatif ci-dessus, pilote le ralentissement
    // d'approche) de "être À la position d'UN capteur" (point, front, ci-dessous, pilote l'arrêt).
    // L'appelant (PRG_05_Translation §0quater) le mémorise en verrou bistable (doctrine
    // M3_LimitSwitchFwd/RevStable §0ter) pour tenir le niveau nécessaire au débounce/verrou
    // anti-rebond de FB_Translation.
    TranslationAtTremie      : BOOL;   // TRUE 1 cycle : front montant SensorTremie (arrivée venant de Maintenance uniquement)
    TranslationAtPV          : BOOL;   // TRUE 1 cycle : front (montant ou descendant) SensorPV
    TranslationAtP2          : BOOL;   // TRUE 1 cycle : front (montant ou descendant) SensorP2
    TranslationAtP1          : BOOL;   // TRUE 1 cycle : front (montant ou descendant) SensorP1
    TranslationAtMaintenance : BOOL;   // TRUE 1 cycle : front descendant SensorMaintenance (arrivée venant de Trémie uniquement)
END_VAR

VAR
    EdgeUpTremie      : R_TRIG;
    EdgeDnTremie      : F_TRIG;
    EdgeUpPV          : R_TRIG;
    EdgeDnPV          : F_TRIG;
    EdgeUpP2          : R_TRIG;
    EdgeDnP2          : F_TRIG;
    EdgeUpP1          : R_TRIG;
    EdgeDnP1          : F_TRIG;
    EdgeUpMaintenance : R_TRIG;
    EdgeDnMaintenance : F_TRIG;
END_VAR

// === IMPLEMENTATION ===

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
LimitSwitchFwd := (NOT Incoherent) AND (SensorsWord = 2#11111);
LimitSwitchRev := (NOT Incoherent) AND (SensorsWord = 2#00000);

// 🆕 Reprise des capteurs de position pour les consommateurs legacy (passthrough, identique à l'entrée filtrée)
// ⚠️ CUMULATIF — voir avertissement en déclaration, réservé au ralentissement d'approche.
TranslationPosTremie      := SensorTremie;
TranslationPosPV          := SensorPV;
TranslationPosP2          := SensorP2;
TranslationPosP1          := SensorP1;
TranslationPosMaintenance := SensorMaintenance;

// 🆕 2026-08-06 (REX décalage came) : front individuel par capteur — voir avertissement en
// déclaration. Transitoire (1 cycle), mémorisé par l'appelant.
EdgeUpTremie(CLK := SensorTremie);           EdgeDnTremie(CLK := SensorTremie);
EdgeUpPV(CLK := SensorPV);                   EdgeDnPV(CLK := SensorPV);
EdgeUpP2(CLK := SensorP2);                   EdgeDnP2(CLK := SensorP2);
EdgeUpP1(CLK := SensorP1);                   EdgeDnP1(CLK := SensorP1);
EdgeUpMaintenance(CLK := SensorMaintenance); EdgeDnMaintenance(CLK := SensorMaintenance);

// 🆕 Front du capteur PROPRE à chaque position — voir modèle en déclaration (confirmé terrain).
// Extrémités : un seul sens valide chacune. Points intermédiaires : les deux fronts de LEUR PROPRE
// capteur (montant = atteint en venant de Maintenance, descendant = dépassé en venant de Trémie).
TranslationAtTremie      := EdgeUpTremie.Q;
TranslationAtPV          := EdgeUpPV.Q OR EdgeDnPV.Q;
TranslationAtP2          := EdgeUpP2.Q OR EdgeDnP2.Q;
TranslationAtP1          := EdgeUpP1.Q OR EdgeDnP1.Q;
TranslationAtMaintenance := EdgeDnMaintenance.Q;
