# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION D'AUDIT COMPARATIF ARCHITECTURE & STANDARDS : PRG_03 vs STANDARDS PROJET (AF-02, AF-03, AF-04, AF-05, CODE_QUALITY_STANDARDS)

## 1. Contexte & Problématique
L'utilisateur a un doute sur la conformité de `PRG_03_Modes_Cycle.st` et de l'architecture globale par rapport aux standards du projet :
- Structure interne du POU (régions `{region "§N ..."}`, variables locales, ordre ST).
- Encapsulation des données et accès directs aux internals des autres PRG (ex: `PRG_04_Treuils_Benne.instWinchSync`, `PRG_05_Translation.instTranslationM3`, `PRG_04_Treuils_Benne.instBucket`).
- Raccordement des flux inter-POU selon le pipeline AF-02 (Pipeline: PRG_02 -> PRG_03 -> PRG_04 -> PRG_05 -> PRG_06 -> PRG_07).
- Respect du contrat de publication `Data : ST_ModesCycleInterPrg`.

## 2. Code réel de PRG_03_Modes_Cycle.st
```pascal
PROGRAM PRG_03_Modes_Cycle

VAR_INPUT
END_VAR

VAR_OUTPUT
    Data              : ST_ModesCycleInterPrg;  // Bus public
END_VAR

VAR
    instModes         : FB_Modes; // Arbitrage des modes
    instCycleSemiAuto : FB_Cycle; // Séquenceur de cycle semi-auto (privé)
END_VAR

// §1 ARBITRAGE DES MODES
instModes(...);

// §2 SÉQUENCEUR DE CYCLE
instCycleSemiAuto(
    Enable                  := (instModes.Auth.Mode = E_Mode.SEMI_AUTO),
    ...
    WinchSyncError          := PRG_04_Treuils_Benne.instWinchSync.Fault.Error,
    WinchSyncDeltaM         := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM,
    ...
    Translation_Busy        := (ABS(PRG_05_Translation.instTranslationM3.RequestedDriveFreqHz) > 0.1),
    Translation_Done        := PRG_05_Translation.instTranslationM3.TargetReached,
    Benne_Busy              := PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy,
    Benne_Done              := PRG_04_Treuils_Benne.instBucket.Lifecycle.Done,
    Benne_IsOpen            := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    Benne_IsClosed          := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    ...
);

// §3 PUBLICATION DU BUS INTER-PRG
Data.Auth := instModes.Auth;
IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
    Data.ReqProgram.ReqWinchM1... := ...
    Data.SequenceState... := ...
ELSE
    // Neutralisation déterministe
    Data.ReqProgram... := FALSE / 0.0;
    Data.SequenceState... := Neutre;
END_IF;
END_PROGRAM
```

## 3. Questions d'Audit
1. **Quels sont les écarts exacts de `PRG_03_Modes_Cycle.st` avec les standards projet (`CODE_QUALITY_STANDARDS.md`, `AF_Partie-02_Architecture_Programme`) ?**
   - Identifier l'absence de `{region ...}`
   - Identifier les accès directs aux instances internes de PRG_04 (`instWinchSync`, `instBucket`) et PRG_05 (`instTranslationM3`) qui devraient passer par `PRG_04.Data` et `PRG_05.Data`.
2. **Quelle est la conformité de `PRG_02`, `PRG_04`, `PRG_05`, `PRG_06`, `PRG_07` par rapport à ce pattern ?**
3. **Quelles sont les actions correctives concrètes à mener pour aligner `PRG_03` à 100% sur l'état de l'art du projet (sans régression fonctionnelle) ?**

Rédige une analyse rigoureuse, technique, sans complaisance, au format Senior Lead Automation Engineer.
