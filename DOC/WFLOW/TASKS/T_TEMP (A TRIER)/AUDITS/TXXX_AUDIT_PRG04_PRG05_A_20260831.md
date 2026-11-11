# 🔍 AUDIT `PRG_04_Treuils_Benne` / `PRG_05_Translation` — restructuration & débogage terrain

> 🎯 **Objet** : après le refactor ayant extrait les FB d'arbitrage (`FB_WinchCmdArbitrationM1/M2`, `FB_BucketCmdArbitration`, `FB_TranslationCmdArbitrationM3`), auditer la **charge**, la **lisibilité**, les **regroupements possibles** (FB/sous-bloc) et la **traçabilité de dépannage sur site** des 2 orchestrateurs ST.
> 📏 **Référentiel** : `DOC/STDS/CODE_QUALITY_STANDARDS.md` (surtout §10 « aucune logique métier inline », §2bis régions, §2quater conditions ≤3 termes), AF Partie-10 v2.1 §5 (régions réelles), AF Partie-11 v2.3 §3.
> 📅 **Date** : 2026-08-31 · 📊 **Verdict global** : 🟠 **PRG04 À CORRIGER** (logique métier encore inline & charge réelle, surtout couplage safety + projection) ; 🟢 **PRG05 OK** (structure saine, 2 extractions « nice-to-have » de sécurité-côté).

---

## 0 · Périmètre et sources lues (source de vérité `CODE/` actif)

| Fichier | Lignes | Rôle |
|---|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | 1260 | Orchestrateur treuils M1/M2 + benne + synchro (objet A) |
| `CODE/M_MAIN/PRG_05_Translation.st` | 450 | Orchestrateur translation M3 (objet B) |
| `FB_WinchCmdArbitrationM1/M2.st` (109/117), `FB_BucketCmdArbitration.st` (72), `FB_TranslationCmdArbitrationM3.st` (112) | — | FB d'arbitrage extraits (vérifier le transfert effectif) |
| `FB_Winch.st` (325), `FB_Safety_Winch.st` (400) | — | FB métier treuils + safety |
| `BENNE/FB_Bucket.st` (372) | — | Séquencement benne |
| `FB_Translation.st` (272), `FB_Safety_Translation.st` (256)` | — | FB métier + safety M3 |
| `DOC/AF/AF_Partie-10_…_v2.1.md` (§5), `AF_Partie-11_…_v2.3.md` (§3) | — | Specs intégration programmes |
| `DOC/STDS/CODE_QUALITY_STANDARDS.md` (§10, §2bis, §2quater) | — | Référentiel qualité |

---

## 1 · Verdict par axe

| Axe | PRG04 | PRG05 |
|---|---|---|
| ⚖️ **Charge (volume réel / logique inline)** | 🟠 **À CORRIGER** — ~200 lignes de logique métier inline + ~230 lignes de projection | 🟢 **Bon** — ~450 l, l'essentiel est du câblage de FB |
| 📖 **Lisibilité des §** | 🟠 Correcte, mais plusieurs § mélangent câblage FB et logique inline (le lecteur ne sait plus quoi croire au watch) | 🟢 **Bonne** — régions propres et bien nommées |
| 🧩 **Regroupement/extraction** | 🟠 5 blocs extrayables (voir §3) | 🟡 2 extractions safety-adjacentes utiles |
| 🔧 **Débogage terrain** | 🟠 Bloquage de mouvement **non auto-expliqué** (chaîne de permis illisible à l'œil) | 🟡 Bon retour safety (bits nommés), à étoffer sur le « pourquoi on ne bouge pas » |

---

## 2 · ⚖️ Charge — ce qui reste lourd / inline dans chaque PRG

### 2.1 PRG04 (1260 l) — la logique métier inline reste substantielle

⚠️ Contre la règle `CODE_QUALITY_STANDARDS §10 rule 2` (« aucun `IF` complexe ni calcul métier inline »), le PRG porte **~200 lignes de vraie logique** (pas du câblage), principalement :

| Bloc inline | Lignes | ~Vol | Nature | Safety-côté |
|---|---|---|---|---|
| **Kobold fond : machine d'état** (`KoboldImmersionConfirmed`/`KoboldBottomTouchLatched`, front + fenêtre immersion `ImmersionUpper/Lower_M`, bypass) | §5 · 515–545 | ~30 l | Détection descendante auto-stop | 🛡️ **Oui** (gates `DescendPermit`) |
| **Phase montée contrôlée post-fermeture** (`ControlAscentArmedForThisClose`/`ExtractionControlActive`/positions de départ/distance) | §3 · 411–427 | ~17 l | Mini-machine d'état | 🟠 Oui (vitesse contrôlée) |
| **Assemblage taxonomie de permis** `ProcessPermit`→`ProcessAndSafetyPermit`→`EffectivePermit` + `SafeStopM1/M2_Active` couplés synchro + gates `DumpAtTremieDescentLocked` / `ExtractionAssist.AscentPermit` / `ManualBucketLimitsActive` | §5 & §5bis · 559–569, 762–798 | ~50 l | **Couplage croisé anti-télescopage** (le cœur) | 🛡️ **Oui + critique** |
| **Matrice maintenance N1/N2** : 10 bypass effectifs + override FDC haut logiciel + clamp plafond `TopLimitM*` (MIN/SEL) | §5-0 · 589–638 | ~50 l | Doctrine bypass + re-homing | 🛡️ **Oui** (levées de butées) |
| **Agrégateur de clamp de palier** commun `CommonMaxStep*` puis `M2MaxStep*` + `MinStepDown` plongée | §5ter · 803–839 | ~35 l | Coordination M1/M2 | 🟠 Oui (réduction de vitesse) |
| Conditions process `WinchBothMotionBlockedByBucket` / `BucketNotClosedAscentStep1` / `SlackCableAscentStep1` / `SyncMinorDeviation*` | §2 · 296–324 | ~15 l | Process gating | 🟠 Mélangées |
| `ArmingPermit` (Option B, interlock benne) | §3bis · 441 | 1 l | Permission homme-mort | 🛡️ Oui |

⚠️ Et **~230 lignes de projection** (§7 + §8) : `WinchM1State.xxx := …` / `WinchM2State.xxx := …` / `WinchM1Safety.Error*` (décodage `ErrorId`) — **pure copie / affichage, zéro logique**, mais elle **gonfle la vue code** et ne présente aucun intérêt en lecture d'orchestration.

**Verdict charge PRG04** : le refactor arbitrage a bien marché (les 4 FB d'arbitrage sont propres et « bit-identique » documentés), mais **la couche de coordination (permis + synchro) reste dans le PRG**. C'est le gros du poids restant et c'est *aussi* le bloc le plus sensible.

### 2.2 PRG05 (450 l) — charge saine

L'essentiel est du câblage de FB (arbitrage, safety, translation, estimateur, décodeur). Reste inline :
- Verrous bistables + mémoire du dernier point (`M3_LimitSwitchFwd/RevStable`, `M3_AtXxxStable`, `TonM3ConfirmedMoving 1,5s`) — §0bis/§0ter/§0quater, lignes 126–169 (~45 l). **C'est une petite machine d'état**, safety-côté (libération des butées extrêmes / arrêt dur).
- Interlock hauteur fail-safe `M3_HeightInterlockOk` — §0, lignes 108–112.
- Sélecteur de cible `CASE SelTarget` → `M3_PositionSensorTarget` — §1, lignes 214–235.

**Verdict charge PRG05** : bon. Pas de couplage croisé lourd. Les 3 blocs inline sont *safety-adjacents* mais volumineux et auto-contenus → candidats FB propres.

---

## 3 · 📖 Lisibilité — découpage des §

### Points solides (confirmés)
- **Régions conformes §2bis** : numérotation alignée corps/AF (`§1..§8`), sous-sections `bis/ter/quater`, descriptions courtes → repli CODESYS efficace.
- **PRG05**: très lisible, chaque région = 1 FB bien identifié. Modèle à suivre.
- **Diagnostic safety déjà bien exposé** dans les PRG : `WinchM1Safety.Error*`/`TranslationSafety.Error*` = décodage nommé des `ErrorId` → bon pour le terrain.

### Ce qui gêne la lecture
1. **PRG04 §5/§5bis mélange câblage + couplage** : on ne distingue pas, à la lecture, « ce que calcule le PRG » de « ce que renvoie le FB ». Au Watch c'est pire : la chaîne de permis est **multi-étages** (Safety → ProcessAndSafety → Effective) et un technicien ne voit pas *directement* quel étage bloque.
2. **Grands appels paramétrés** (instBucket, instSafetyWinchM1/M2 : ~50–60 paramètres chacun, dont les `Bypass*`). Inévitable en ST mais la projection voisine n'aide pas.
3. **Non-respect §2quater (conditions >3 termes)** sur du code *retouché par le refactor* : ex. `instWinchSync.Enable` (448–451, 5 termes), `SlackCableAscentStep1` (296–303, ≥4), `ProcessPermitM2_Descend` (563–564), `ProcessAndSafetyPermitM2_Ascent` (790). ⚠️ La règle §2quater est *déclarée non-rétroactive*, mais tout refactor est l'occasion de la mettre en conformité — les conditions re-touchées devraient être scindées en BOOL nommés **observables seuls au Watch**.
4. **Incohérence de convention de noms** : `_BucketState`, `_CommunCfgPersist`, `_WinchM1CfgPersist` (préfixe `_` = refs GVL_PERSISTENT) côtoient des locaux `BucketState`, `WinchM1State` → risque de confusion lecteur. (Nommage existant non-rétroactif, mais à ne pas amplifier.)
5. **Redondance de publication** : `BucketState`/`WinchM1State`/`WinchM2State` sont à la fois remplis champ-par-champ (§8) **puis copiés** dans `Data.*` (§ fin) → double passe qui n'apporte rien (le §8 pourrait charger `Data.*` directement).

---

## 4 · 🧩 Regroupement / extraction — propositions concrètes

> Principe (cohérent avec le refactor arbitrage déjà fait) : **extraire un FB par responsabilité, bit-identique, validé par gate G200 + tests**. Prioriser par **gain de lecture × risque safety**.

### PRG04 — 5 extractions candidates (par ordre de priorité)

| # | FB proposé | Logique transférée | Gain | Risque safety |
|---|---|---|---|---|
| **P1** | `FB_WinchPermitCoupler` (couplage anti-télescopage) | taxonomie permis + `SafeStopM1/M2_Active` + gates `DumpAtTremie`/`ExtractionAssist`/`ManualBucketLimits` + synthèse `EffectivePermit*` | **Le cœur du PRG04 sort du PRG ; la page devient lisible ; un seul endroit à auditer** | 🛡️ **Critique** → refactor bit-identique obligatoire, gate G200 + tests dédiés (couplage synchro), zéro changement d'état |
| **P2** | `FB_WinchStepClamp` | agrégateur §5ter (`CommonMaxStep*` + `M2MaxStep*` + `MinStepDown`) | Unité testable (borne palier), allège la section | 🟠 Moyen → clamp = réduction vitesse, test vectoriel |
| **P3** | `FB_KoboldBottomDetect` | machine d'état fond Kobold (§5, immersion + latch + bypass) | Détection autonome, traçable | 🛡️ Haut (stoppe la descente) → bit-identique, test fenêtres immersion |
| **P4** | `FB_BucketAscentControl` | phase montée contrôlée post-fermeture (§3) | Mini-machine à état propre | 🟠 Moyen (vitesse) |
| **P5** | `FB_WinchStateProjection` | projection §8 (`WinchM1/M2State`, `WinchM1/M2Safety`, `SyncState`, `BucketState`) + publication `Data.*` | **≈230 l de copie disparaissent** de la vue orchestrateur | 🟢 Nul (pure copie) — premier candidat si l'on veut décharger VITE la vue |

### PRG05 — 2 extractions utiles (nice-to-have, safety-adjacentes)

| # | FB proposé | Logique transférée | Gain | Risque safety |
|---|---|---|---|---|
| **P6** | `FB_TranslationPositionMemory` | verrous bistables butées + mémoire dernier point `M3_AtXxx` + `TonM3ConfirmedMoving` (§0ter/§0quater) | Machine à état déplacée, testable (anticipation dégagement) | 🟠 Moyen (libération butées dures) |
| **P7** | `FB_TranslationTargetSelector` (ou enrichir `FB_TranslationCmdArbitrationM3`) | `CASE SelTarget`→`M3_PositionSensorTarget` (§1) | Cible d'arrêt centralisée près de l'arbitrage | 🟢 Faible |

> ⚠️ **L'interlock hauteur `M3_HeightInterlockOk`** (§0, fail-safe) doit **rester un fait produit par PRG05** (il dépend de M1/M2 encodeurs, multi-PRG) — ne pas l'enfermer dans FB_Safety_Translation (perte du producteur unique). Le scinder en BOOL nommés suffit.

---

## 5 · 🔧 Débogage terrain — traçabilité / diagnostic

### ✅ Ce qui est déjà bon
- Diagnostics safety nommés (`WinchM1Safety.Error*`, `TranslationSafety.Error*`, `BlockedBySafety`, `SafeStopSafety`, `PowerCutOffSafety`).
- `FinalInterlock*` (état, raison, erreur, `RestartInhibit`, tempos) déjà exposés → très utile.
- `M1LogicRequest*` (palier & %) et `StepNumber` publiés → voit la consigne vs le réel.

### ❌ Lacunes (le vrai besoin terrain)
1. **« Pourquoi ça ne bouge pas » n'est pas auto-expliqué** sur la chaîne de permis multi-étages PRG04. Un technicien sur site doit *recalculer à la main* `EffectivePermit = ProcessAndSafety AND synchro`. → Publier un **« blame/motif de blocage » par axe** : enum/bitset `AxisBlockReason` (EX : `BUCKET_BUSY`, `SYNC_BLOCK`, `KOBOLD_FOND`, `INHIBIT`, `MAINT_LIMIT`, `NOT_HOMED`, `HEIGHT`, `NOT_PERMITTED`, `NONE`) produit par la couche de coordiition, visible en un coup d'œil sur l'IHM/le Watch. **C'est l'amélioration débogage n°1.**
2. **Bistables §0quater PRG05 difficiles à tracer** : l'IHM voit `M3_AtXxx` mais pas la cause d'un verrou resté posé. → exposer `M3_ConfirmedMoving` et la tempo `TonM3ConfirmedMoving` (déjà là) + un flag « libéré par mouvement ».
3. **Pas de trace temporelle** du dernier événement de blocage (lequel, quand, duré). → optionnel : latcher `AxisBlockReason` + `TonSinceBlock` pour l'IHM (léger, fort impact dépannage).

---

## 6 · 🛡️ Impact safety (résumé impartial)

- **Les 3 blocs les plus sensibles du projet vivent dans PRG04 §5/§5bis** : le couplage anti-télescopage (`EffectivePermit`), la matrice de bypass maintenance, le clamp de palier. **Ce n'est pas un défaut**, mais toute restructuration les concerne → **règle absolue : refactor bit-identique + validation G200 (liaison) + tests unitaires, zéro changement de sémantique**. Aucune logique de redémarrage auto à introduire (Reset sur front, anti-redémarrage conservés).
- **Kobold / hauteur / by-passes de butées** : extractions sûres *si* bit-identique ; sinon risqué (gates de descente et levées de butées logicielles). La **hauteur M3 reste un fait PRG** (producteur unique multi-PRG).
- **PRG05** : extractions P6/P7 sans risque fonctionnel, mais P6 touche la libération des butées dures → à valider.
- **Aucun chemin d'actionneur non protégé identifié** dans ce périmètre (la barrière physique reste PRG_06, hors scope → cf. AUDIT PRG06).

---

## 7 · ✅ Actions prioritaires (impartial)

| Priorité | Action | Pourquoi | Risque |
|---|---|---|---|
| **1** | Extraire **`FB_WinchStateProjection`** (P5) : sort ~230 l de copie de la vue PRG04 | Décharge immédiate et sûre (pure copie) ; dégonfle le fichier d'~20 % | 🟢 nul |
| **2** | Introduire un **`AxisBlockReason` par axe** (blame de blocage) issu de la couche de permutation | Gain débogage terrain n°1 : « pourquoi on ne bouge pas » visible | 🟢 nul, forte plus-value |
| **3** | **(avec gate strict)** Extraire **`FB_WinchPermitCoupler`** (P1) — le couplage `EffectivePermit`/`SafeStop` | Rends PRG04 lisible et le couplage auditable en un point | 🛡️ critique → bit-identique + tests |
| **4** | Extraire **`FB_WinchStepClamp`** (P2) puis **`FB_KoboldBottomDetect`** (P3), **`FB_BucketAscentControl`** (P4) | Allège §5/§5ter, rend les machines à état testables | 🟠→🛡️ selon bloc |
| **5** | PRG05 : extraire **`FB_TranslationPositionMemory`** (P6) + **`FB_TranslationTargetSelector`** (P7) | Aligne PRG05 sur le modèle « FB par responsabilité » | 🟠 (P6 safety-côté) |
| **6** | Scinder (au fil du refactor) les conditions >3 termes re-touchées en BOOL nommés (§2quater) — ex. `instWinchSync.Enable`, `SlackCableAscentStep1`, `ProcessPermitM2_Descend` | Chaque terme devient Watch-able seul | 🟢 nul |

**Séquence conseillée** : P5 (rapide, sûr) → blame (2) → P1 avec validation complète → puis P2–P4 → P6/P7. **Ne pas tout faire d'un coup** : chaque extraction est un lot unitaire validé (gates + G200). Criticité globale du chantier : **C2** (amélioration lecture/support) — la machine reste fonctionnelle et sûre à l'état actuel.

---

> 🧭 **Source de vérité** : `CODE/` actif. Référentiel : `CODE_QUALITY_STANDARDS.md` (§10, §2bis, §2quater), AF Partie-10 §5, AF Partie-11 §3. REX 2026-08-12 (`§2quater`, condition à 7 termes vécue sur PRG04) rappelé en préambule de la règle.
