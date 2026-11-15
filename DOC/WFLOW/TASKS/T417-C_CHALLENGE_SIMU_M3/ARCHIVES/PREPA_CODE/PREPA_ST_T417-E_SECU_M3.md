# Préparation ST `T417-E` — Branche Sécurité M3 & Sorties (`CODE/M_MAIN/` + `CODE/I_TRANSLATION/`)

> **Statut :** Brouillon prêt au GO C3/C4 (aucune modification appliquée sur `CODE/`). Intègre les retours du panel Ollama (Power-Up `01111`, anti-rebond ~100 ms, piège `2#00000`, PV `5 Hz` sur 1–2 derniers m).

## 1. Plan A1 — Latch Trémie `RETAIN` + Anti-rebond (`CODE/M_MAIN/PRG_06_Outputs.st:431-451`)
- **Contexte vérifié :** `M3_TremieHardStopActive := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic;` (`PRG_06_Outputs.st:431-432`).
- **Brouillon cible (avec mémoire persistante `GVL_PERSISTENT._M3TremieHardStopLatched`) :**
```iecst
// Qualification anti-rebond (~100 ms) ou front net sur M3_PosTremie_DI
TonM3TremieConfirm(IN := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI, PT := T#100MS);

// Armement du latch sur detection Tremie OU au power-up si position hors came non prouvee (01111)
IF PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI THEN
    GVL_PERSISTENT._M3TremieHardStopLatched := TRUE;
END_IF;

// Rearmement uniquement au poste/IHM (Reset) ET (capteur revenu OU commande opposee Maintenance)
IF (PRG_07_Supervision.FaultMachineReset_IHM OR PRG_07_Supervision.JoystickReset_CMD)
   AND NOT PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI
   AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqMaintenanceSemantic THEN
    GVL_PERSISTENT._M3TremieHardStopLatched := FALSE;
END_IF;

M3_TremieHardStopActive := (PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI
                            OR GVL_PERSISTENT._M3TremieHardStopLatched)
                           AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic;
```
*(Et dans `instTranslationOutputInterlockM3` ligne 439 : `EffectivePermitM3_Tremie := ... AND NOT PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI AND NOT GVL_PERSISTENT._M3TremieHardStopLatched;`)*

## 2. Plan A2 — Symétrie Maintenance (`PRG_06_Outputs.st:441`)
- ⚠️ **Garde anti-piège `2#00000` (Expert Maintenance) :** `2#00000` code aussi une perte de chaîne capteurs 24 V. **Ne jamais bloquer sur `2#00000` seul** ; n'activer `M3_MaintenanceHardStopActive` que sur **capteur dédié actif à `1`** (`M3_PosMaintenance_DI` vérifié physiquement câblé NO/NF sain).

## 3. Cascade Plan B2 / B1 / Plan C
- **Plan B2 (`5 Hz` sur les 1–2 derniers mètres) :** garder `10 Hz` sur les ~3 premiers mètres après `M3_PosPV_DI` et réduire à `5,0 Hz` uniquement sur les 1–2 derniers mètres (divise `E_choc` par 4× sans pénaliser le cycle).
- **Plan B1 (`FB_Translation_OdometryGain.st:57`) :** si mesure terrain `P2↔PV` donne `k > 0,05`, relever `CST_GainMax` (`0.05 -> 0.07`).
- **Plan C1 (secours ultime) :** verrou thermomètre si transition `11111 -> 01111` **sans commande Maintenance**, confirmée sur ~100 ms (pas `<= 2 scans`), testé d'abord à l'arrêt par forçage `SensorsWord` (variateur inhibé).

## 4. Cahier FAT/SAT minimal avant signature C3/C4
1. Injection stuck-at-0 / stuck-at-1 et rebonds < 100 ms.
2. Coupure/redémarrage API en zone `01111` hors came : mouvement Trémie bloqué.
3. Reset + dégagement en sens opposé Maintenance vérifié.
