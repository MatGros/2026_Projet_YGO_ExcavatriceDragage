# 🔍 AUDIT — 29 cas limites de sécurité oubliés (AF métiers 08-14)

> **Date** : 2026-08-29 · **Périmètre** : 7 chapôs AF08→14 + 13 fiches FB filles + spec étalon AF01
> **Méthode** : audit READ-ONLY strict (aucune édition), recommandations limitées à l'ajout de couverture TC
> **Origine** : Étape 1 (challenge préalable sécurité) de l'OM « Reprise & Migration TC/AF §2 »
> **Acteur** : subagent DSH (b9e938aa), rapport consolidé par DSH (orchestrateur)
> **Statut** : livré — à trier en tâches correctives distinctes (voir §4)

---

## 1. Synthèse

| Criticité | Nombre | Impact potentiel |
|---|---|---|
| 🔴 **C4** | 2 | Catastrophe physique (chute de charge / perte de frein) |
| 🟠 **C3** | 16 | Critique sécurité (mouvement intempestif, interlock contournable) |
| 🔵 **C2** | 11 | Modéré (frontières, cumuls, verrous, temporisations) |
| **Total** | **29** | après dédoublonnage des chevauchements |

**Nature** : 20 cas avérés manquants (a) · 6 couverts mais faiblement (b) · 1 interlock contournable avéré documenté (T175) · incertitudes à qualifier (c) — les catégories se **chevauchent** (un cas peut être "avéré"/"faible"/"à qualifier" selon l'aspect), donc leur somme ≠ 29 (les 29 cas sont la répartition par criticité de la ligne précédente). Le détail des incertitudes (10 items) est en §4.

---

## 2. Détail des 29 cas

### 🔴 C4 — Catastrophe physique possible

| CAS | Titre | Fiche | Constat | Recommandation |
|---|---|---|---|---|
| **001** | Retombée d'un contacteur (palier OU sens) pendant le mouvement | `FB_Winch_v1.0` | Aucun TC. À la descente, perte de couple de freinage → **chute de charge** | TC « retombée contacteur pendant BUSY → SafeStop + latch » |
| **002** | AU / `PowerCutOffRequest` pendant une transition (palier, inversion, benne) | `FB_Winch` / `FB_Bucket` | Aucun TC d'avortement pendant séquence dynamique | TC « AU pendant `DirectionChangePending` / hausse palier / BUSY benne → avortement propre » |

### 🟠 C3 — Critique sécurité

| CAS | Titre | Fiche | Constat | Recommandation |
|---|---|---|---|---|
| **003** | Collage contacteur PENDANT le mouvement (pas seulement à l'arrêt) | `FB_Winch` | TC-P10-018 borné à l'arrêt commandé | TC collage détecté pendant transition N→N±1 |
| **004** | Chevauchement de contacteurs lors d'une transition de palier | `FB_Winch` | Aucun TC (015/017 = statique) | TC « pas de chevauchement d'excitation de 2 contacteurs » |
| **005** | Homing perdu EN MARCHE (saut in-bounds / perte EtherCAT transitoire) | `FB_Encoder_Homing`/`Safety`/`Reliability` | TC-P09-020.5 = boot seulement | TC saut in-bounds + re-contrôle cohérence sur retour bus |
| **006** | Codeur cru mais faux : homing sur cible erronée in-bounds, `EncoderIncoherent` muet | Encodeurs | Aucun TC « homing erroné in-bounds » | TC caractérisation du silence (mono-canal assumé) |
| **007** | Perte du `Homed` d'un SEUL codeur (M1 OU M2) en manœuvre benne (BUSY) | `FB_Bucket` | TC-P10-031 couvre défaut permanent, pas BUSY | TC perte `HomedM1`/`HomedM2` pendant BUSY → SafeStop+latch |
| **008** | Défaut latché perdu au bascule Enable FALSE→TRUE (violation T147) — FB_Bucket | `FB_Bucket` | L'état DISABLED remet `M1SlipDetected:=FALSE` (reset en branche inactive, `FB_Bucket.st:158`) ; le vrai enjeu T147 porte sur `M1SlipFaultLatched` (`M1SlipFaultLatched`, ~L143) qui ne doit PAS être reset au cycle Enable | TC + confirmer écart par lecture `FB_Bucket.st` |
| **009** | Capteur PV collé (désactive le ralentissement) — mot reste valide | `FB_Translation`/`PositionDecoder` | TC-P11-004 = nominal seulement | TC capteur PV collé FALSE/TRUE |
| **010** | Perte drive EtherCAT en marche → bit1 SafeStop seul + rampe muette | `FB_Translation`/`Safety_Translation` | Méca A (1s) = fallback PowerCutOff | TC combiné perte com en marche |
| **011** | `InvertDriveDirection` (compensation câblage moteur) : aucun TC | `FB_Translation` §7bis | Polarité erronée → sens inversé | TC polarité + ralentissement appariés au sens sémantique |
| **012** | Interlock anti-traversée M1/M2_Busy non câblé (contournable avéré) | `FB_Bucket` | TC-P10-025 état NV — `M1_Busy`/`M2_Busy` déclarés non utilisés (**T175**) | **Signaler** — écart d'implémentation, pas de TC manquant |
| **013** | Cumul défauts capteur joystick (RawOutOfRange + BusCanOpenOP simultanés) | AF08 | TC-P08-030 = un seul défaut à la fois | TC cumul bit1+bit2 → gate complet maintenu |
| **014** | Warmup 3s : fenêtre où la perte com opérateur ne déclenche PAS | `FB_Safety_Winch` | TC-P10-036.1 documente mais ne teste pas la fenêtre | TC mouvement dans les 3s après Enable + perte com |

### 🟠 C3 — Frontières & defense-in-depth

| CAS | Titre | Fiche | Constat | Recommandation |
|---|---|---|---|---|
| **015** | Frontière couche 1 / couche 2 glissement benne (1.0m → 2.0m) | `FB_Bucket` | TC frontière exacte non testée | TC glissement traversant 1.0 puis 2.0 en continu |
| **016** | Redémarrage auto après disparition de la cause (FB_Winch + FB_Bucket) | Winch/Bucket | Aucun TC de non-redémarrage | TC « défaut latché → cause disparait → pas de reprise sans Reset » |
| **017** | `BypassGlobal` masque cohérence codeur qui nourrit l'anti-télescopage (F11.05) | Encodeurs + Translation | TC-P09-030.6 / P11-014 seule | TC interaction bypass ↔ `HeightInterlockOk` |
| **018** | Perte bus EtherCAT pendant preset SDO en cours | `FB_Encoder_Abs` | §5 « preset continue » — fenêtre non testée | TC perte bus pendant `PresetSeqStep=1` → `EncoderFault` immédiat |

### 🔵 C2 — Modéré

| CAS | Titre | Fiche | Constat | Recommandation |
|---|---|---|---|---|
| **019** | Incohérence délai hausse palier FB_Winch (1s5) vs barrière (1s25) | `FB_Winch` | Alerte P1 sans TC | TC fenêtre 250ms de commande contradictoire |
| **020** | Frontière tolérance cohérence boot (999 vs 1000 pts) | `FB_Encoder_Homing` | TC-P09-020.5 sans borne | TC bornes 999/1000 (précédent TC-P09-020.4) |
| **021** | Inversion de sens pendant décélération PV (interlock 200ms) | `FB_Translation` | TC-P11-005 générique | TC inversion pendant ralentissement PV |
| **022** | Perte `BrakeFeedback` en marche (watchdog ré-armage mid-motion) | TranslationOutput + Safety_Translation | TC-P11-006 standard | TC perte BrakeFeedback pendant mouvement stable |
| **023** | AU / `PowerCutOffRequest` en cours de rampe/décélération M3 | `FB_Translation` | Aucun TC | TC mot 0 + frein appliqué + rampe abandonnée |
| **024** | Défaillances combinées M3 : mot incohérent (bit7) + perte drive (bit1) | PositionDecoder + Safety_Translation | Aucun TC cumul | TC cumul → frein appliqué si drive injoignable |
| **025** | Fault latché perdu sur bascule Enable OFF→ON sans Reset (T147 généralisé) | Safety_Translation + OutputInterlock + AF09 §14 | Aucun TC ne cycle Enable | TC latch préservé par FB porteur de latch |
| **026** | Verrou `ArrivalLock` / `DirectionAtArrival` (FB_Translation §5) | `FB_Translation` | Aucun TC | TC réengagement même sens bloqué + changement sens lève verrou |
| **027** | Ralentissement 3 zones : P1 + Maintenance (Direction=-1) | `FB_Translation` | TC-P11-004 PV seulement | TC ralentissement P1/Maintenance + gate MaintenanceM3Target |
| **028** | AF12 : `E_Diag_State.MONITORING` jamais assigné + Reset Ethercat jamais lu | AF12 + AF08 §8 | Bypass réseau peut masquer perte joystick | TC bypass → `SIMULATED` (pas READY) + qualifier 2 écarts code |
| **029** | Expiration exacte des temporisations (fenêtre d'un cycle) | Winch + Safety_Translation | Aucun TC aux frontières | TC `délai−1` / `délai+1` (miroir TC-P11-006 499/500ms) |

---

## 3. Cas confirmés NON oubliés (traçabilité)

Latch AU survit à la sim (TC-P13-023) · perte référence AU boot (TC-P09-020.5) · hors bornes codeur (TC-P09-030.4) · relais `HomingSuspect`→`EncoderIncoherent` (TC-P09-030.5) · `HomingSuspect` RETAIN (TC-P09-020.8) · homing sans permit / capteur haut absent / cible hors ±99m (TC-P09-020.7/.6/.4) · mot capteurs incohérent→SafeStop+PowerCutOff (TC-P11-002) · absence redémarrage auto après Méca A (TC-P11-010.1) · **1 scénario combiné existe** (TC-P11-011.1 Méca B variante perte IHM) · watchdog frein 500ms avec TC borne (TC-P11-006) · anti-redémarrage (TC-P11-007) · boutons IHM MAINT exigent Deadman (TC-P11-013) · `Enable=FALSE` coupe tout (TC-P11-003) · homing nominal 2 ordres (TC-P09-020.1) · timeout mouvement benne (TC-P10-046.1) · incohérence boot benne (TC-P10-047.1) · benne partiellement fermée palier 1 (TC-P10-045.1) · config palier invalide (TC-P10-017) · TC-P08-020.3 pas réarmement auto joystick · TC-P10-044.1 mou câble `DescendPermit`/`AscentPermit` · TC-P10-037.1 gate Enable latches préservés (FB_Safety_Winch, à étendre — cf. CAS-025)

---

## 4. Incertitudes à qualifier par lecture code

1. **Reset sur front (R_TRIG)** non validé (général) — risque d'acquittement continu
2. **Défaillances combinées simultanées** (priorité/écriture ErrorId) non spécifiée
3. **Méca E vs saut mono-codeur** : `TestOffsetPts` teste désync M1≠M2, pas saut mode commun
4. **PRG_05 §0bis** « coupure dure indépendante du sens » — dernier rempart du CAS-011
5. **`HeightInterlockOk`/F11.05** consomme-t-elle `HomedAndReliable` ? (impact CAS-006/017)
6. **Re-contrôle cohérence sur retour bus transitoire** — §5 dit « une fois par session Enable »
7. **`FB_Ramp.Current` commandée vs mesurée** (impact CAS-021)
8. **Code mort `DelayMotorDecel`/`TonDecel`** dans FB_Brake (comportement frein à caractériser)
9. **Calibration `TranslationAtPV`/`TranslationAtP2`** (T106, code mort) — dormant
10. **Ports morts `BrakeFeedback`/`FwdRevSpeedFeedbackOff`** sur `FB_Encoder_Homing`

---

## 5. Priorités d'action proposées (à arbitrer)

- 🔴 **C4 immédiat** : CAS-001 (retombée contacteur en marche), CAS-002 (AU pendant transition)
- 🟠 **C3 priorité 1** : CAS-008 (T147 FB_Bucket — confirmer code), CAS-012 (T175 — interlock non câblé), CAS-005/006 (homing perdu en marche)
- 🟠 **C3 priorité 2** : CAS-003/004/009/010/011/013/014/016/017
- 🔵 **C2** : CAS-019 à CAS-029

> ⚠️ 2 écarts code avérés signalés : T147 FB_Bucket (CAS-008) et T175 (CAS-012) — hors périmètre de ce document read-only, à traiter côté code par l'orchestrateur. Voir `DOC/WFLOW/TASKS.yaml` T175.
