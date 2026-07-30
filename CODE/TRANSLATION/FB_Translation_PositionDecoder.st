(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Translation_PositionDecoder — Décodage mot capteurs M3 (5 positions)
   ───────────────────────────────────────────────────────────────
    📄 Doc métier : DOC/AF_Partie-02_Architecture_Programme_v3.0.md §3
   🧩 Brique réduite (Partie3 §1bis) : pure logique combinatoire, pas de
      StartStop/Enable/Reset/Mode — décode 5 capteurs TOR (Trémie|PV|P2|P1|
      Maintenance) en mot de progression, dérive les 2 limites extrêmes et
      détecte toute combinaison incohérente (défense en profondeur M3).
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
