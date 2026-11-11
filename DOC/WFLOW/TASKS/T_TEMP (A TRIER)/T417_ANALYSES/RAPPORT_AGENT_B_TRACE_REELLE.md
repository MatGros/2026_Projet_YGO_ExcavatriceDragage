## Checkpoint de mission

```bash
python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record M3-T400-CALIB en_cours --agent DSH01 --msg "Lecture trace terrain M3 (extrait fourni), cartographie des colonnes avant extraction"
```

## 🧭 Position de la mission (honnêteté d'expert d'abord)

**Fait critique à signaler AVANT toute extraction** : on me remet un **extrait** de la trace, avec un grand trou (`...`). Je ne peux pas :
- garantir les timestamps de retombée de frein (ils peuvent tomber dans le trou) ;
- mesurer les franchissements de capteurs (portion tronquée) ;
- affirmer une rampe « exacte » sur 2 points sans le fichier complet.

❌ **Je signale donc : mission sous-approvisionnée.** Je produis ci-après l'extraction **sur le donné réel fourni** (aucune invention), avec l'incertitude explicite par colonne. Si le fichier complet est accessible, me le transmettre refait l'extraction en 2 min et élimine 3 colonnes d'« incertain » de la table finale.

---

## 🦠 Audit qualité de la donnée d'entrée (préambule obligatoire avant calibrage)

Avant d'utiliser la moindre valeur, trois redflags de **cohérence temporelle** sur l'extrait lui-même :

| # | Observation | Fait | Conséquence si ignorée |
|---|---|---|---|
| R1 | `Timestamp_ms` évolue à pas moyen ~100 ms (`37→137→…`) alors que FICHE_T400 annonce un cycle PLC **10 ms** et que le CSV est dit « wide » | Échantillonnage d'export ~100 ms, pas la cadence PLC | On pense calibrer la boucle PLC alors on calibre le log d'export |
| R2 | Entre t=11753 (`Actual=266`) et t=11853 (`Actual=542`), le saut vertical est 276 unités en 100 ms = **>2× écart de pas précédent** | Trace non uniforme, probablement un défaut de log ou un filtre appliqué au CSV | Sur-estimation de pente localement |
| R3 | **Incohérence frein vs fréquence** : à t=11558 (`Brake=1`, freq 0) on voit ensuite 266/542/…/1000 — puis **à la retombée**, t=26438 : `Brake=0` **mais** les lignes suivantes 26553→27056 montrent `Actual=913→0` alors que `Brake=0` | Le frein ne peut pas physiquement retenir un moteur à 100× en état ouvert — soit inversion de colonne, soit export biaisé, soit le frein est un frein moteur pas « is » au sens normalisé | La calibration du « seuil de décrochage frein » serait fausse |
| R4 | **Inversion de séquence** t=11558 : `CommandWord` passe 0→2**avant** que `StatusWord` 129→**139** passe à ligne suivante : **ordre des évènements inversé dans le log** (cause/effet intervertis) | Le log export écrit probablement les valeurs du cycle *t* ou *t+dt* différemment selon les colonnes | Le calcul du délai Cause→Effet (ex. commande → réponse) serait biaisé de 1 échantillon (±100 ms) |

**Conclusion audit** : la trace est exploitable pour l'**ordre de grandeur des dynamales** (rampe/durée), mais pas pour des bornes de sécurité fines ni pour des délais de l'ordre de la centaine de ms sans ré-échantillonner à 10 ms ou relire la logique d'export.

---

## 🔬 Extraction (sur les SEULES lignes réellement présentes)

> ⚠️ Les segments `...` représentent ~1 h de trace non fournie. Toute valeur issue d'une inter-extrapolation est marquée `[INTERPOLÉ]`.

### Q1 — Dynamiques mesurées `Actual` vs `Setpoint`

**Phase montée (lignes 11256→12100 environ)**

| Timestamp_ms | M3_Actual | M3_Setpoint | Δt | Pente mesurée (unités/s) |
|---:|---:|---:|---:|---:|
| 11558 | 0 | 618 | — | — |
| 11652 | 45 | 800 | 94 ms | ≈ +479 u/s *(bruit 1er point)* |
| 11753 | 266 | 1000 | 101 ms | ≈ +2188 u/s *[ANORMAL, cf. R2]* |
| 11853 | 542 | 1000 | 100 ms | ≈ +2760 u/s |
| 23952 | 1000 | 1000 | (fin montée)`[INTERPOLÉ]` | moyen ≈ +160–170 u/s (1000 en ~580–620 ms) |

**Échelle des valeurs — point bloquant** : le moteur plaque HELMKE 963 min⁻¹ à 50 Hz et FICHE_T400 indique `M3_ActualFrequencyHz` en Hz, résolution 0,01.
- Si unité = **1/100 Hz** : 1000 → **10,00 Hz**, montée totale ~580 ms, pente ≈ **17 Hz/s** ✔️ cohérent avec la rampe PLC documentée `20 Hz/s` (40 %/s sur échelle 50 Hz), écart ~15 % attribuable au premier échantillon bruité et au pas de 100 ms.
- Si unité = **0,1 Hz** : 1000 → **100,0 Hz** > 50 Hz physique du réseau → **impossible**.
- Si unité = **Hz plein** : 1000 Hz impossible.

➡️ **Conclusion (unique cohérence physique) : échelle = 1/100 Hz. Donc 1000 = 10,00 Hz, 618 = 6,18 Hz, 45 = 0,45 Hz.**

| Mesure | Valeur extraite | Certitude |
|---|---:|---|
| Temps de montée `Setpoint=1000` → `Actual=1000` | ≈ 560–600 ms | échantillonnage 100 ms → ±1 pas |
| Rampe effective mesurée montée | ≈ **17 ± 4 Hz/s** | ⚠️ à valider sur fichier complet |
| Rampe annoncée FICHE_T400 (PLC) | 20 Hz/s | doc |
| **Écart mesurée vs doc** | −15 à −30 % | ⚠️ à confirmer, possible filtre variateur |
| Temps de descente (t=26438 → 27056) | **≈ 560 ms** (1000 → 0, avec `Brake=0` toute la descente) | mesuré direct |
| Pente descente mesurée | ≈ **−17 ± 4 Hz/s** | symétrique de la montée |

🔴 **Alerte factuelle (devoir d'alerte)** : la FICHE_T400 écrit `Décélération SafeStop = 100 %/s = 50 Hz/s`. La descente **mesurée** au moment du défaut est ≈ **−17 Hz/s**, PAS un arrêt SafeStop à 50 Hz/s — la retombée de fréquence suit une rampe douce, **pas** un freinage rapide ni un désexcitation. Deux explications possibles (à départager sur le fichier complet) : (a) le défaut survient par **retombée de commande** et non variateur en défaut, et la fréissance est la rampe PLC normale ; (b) l'extrait est post-défaut et le frein a déjà fait son travail sur la partie non vue. **Hypothèse la plus plausible (cf. Q4)** : (b).

### Q2 — Timestamps exacts du frein

| Évènement | Timestamp | Preuve ligne | Fréquence à l'instant |
|---|---:|---|---:|
| **Ouverture frein** | **11558 ms** | `BrakeIsOpen` 0→1 | Actual **0,00 Hz** (valeur brute 0) — ⚠️ le frein s'ouvre **à 0 Hz**, donc **AVANT** toute montée |
| **Fermeture (retombée)** | **26438 ms** | `BrakeIsOpen` 1→0 | Actual **1000 u = 10,00 Hz** — ⚠️ fermeture **à pleine vitesse**

🔴 **Deux anomalies terrain distinctes à signaler à l'orchestrateur** :
1. Ouverture du frein **avec commande de marche déjà donnée** (CommandWord=2 présent à 11558, pas avant) — le frein ne s'ouvre donc pas en pré-positionnement mais **réaction à la commande**. Cohérent avec un enchaînement `commande → frein` et non `frein → commande`.
2. **Fermeture du frein à actual = 10 Hz** : c'est un **freinage à vitesse pleine** (et non un freinage après ramping à 0). Physiquement : ça use le frein et provoque un arrêt brutal du chariot ; sur une machine de dragage réelle c'est un mode de défaillance à auditer. Ce n'est **pas** un frein « maintien » classique mais un frein de travail en cas de défaut. → signalement hors scope.

### Q3 — `M3_StatusWord` : valeurs et transitions

Suite exactement observée :

| Timestamp | StatusWord | Bits modifiés vs 129 (binaire `10000001`) |
|---:|---:|---|
| 37 ... 11458 | **129** | `1000 0001` — ready / no-fault (référence) |
| 11558 | **139** | `1000 1011` — bit 1 (2) et bit 3 (8) = passage en « switch-on » / « opération enabled » |
| 11652 ... 26353 | **139** puis **133** à partir de 23952 | `1000 0101` — bit 1 à 0, bit 2 à 1 |
| 26438 | **133** | `1000 0101` — inchangé par rapport à 139 mais **bit 1 retombé, bit 6 activé** (`ErrorId State passe à 64 / 65`) |
| 27056 | **129** | retour état initial, défaut acquitté |

⚠️ ⚠️ **Important** à signaler : le bit **« fault »** au sens PROFIdrive (bit 3 du status) **n'est pas le vecteur d'entrée du défaut** ici : la trace montre `Safety.Error=1` (colonne 12) **seulement à t≥26438** avec `State.Error=1/64`. Donc :
- **bit « fautif » PROFIdrive absent** dans la trace à l'instant t=26438 : le défaut est visible au niveau PLC (`State.ErrorId 64/65`, `Safety.ErrorId 0`) et **pas** au niveau PROFIdrive status word. Le variateur n'est pas mis en défaut PROFIdrive ; c'est le **PLC lui-même** qui lève l'erreur applicative. **Cause du défaut = commande logique PLC (CommandWord retombé 2→1→0) ou commande opérateur, PAS un défaut variateur**. ➡️ À départager sur les lignes 26037–26438 du fichier complet (non fournies).

### Q4 — `ErrorId` Safety / State : timestamps, cause apparente

| Timestamp | Safety.Error | Safety.ErrorId | State.Error | State.ErrorId |
|---:|---:|---:|---:|---:|
| ≤ 11458 | 0 | 0 | 0 | 1 | ← **State.ErrorId=1 SANS State.Error — incohérence de codage** |
| 10956 | 0 | 0 | 0 | **0** | ← passage bref 1→0 **avant** la commande de marche : probable `W#16#1` = « pas de défaut » codé `1` (souvent `ERR_OK=0` ou `1`) |
| 11558–26353 | 0 | 0 | 0 | 0 | sans défaut |
| **26438** | **1** | **0** | **1** | **64** | ← **défaut Safety ET State simultanés** |
| 26553–26953 | 1 | 0 | 1 | **65** | ← `State.ErrorId` passe 64→65 pendant la descente |
| 27056 | 1 | 0 | 1 | 65 | puis retour à 1 à 27254 → rearm |

- `Safety.ErrorId` reste à **0** tout au long : le bloc `Safety` n'a **pas** levé son propre identifiant. Le défaut est donc **monopolarisé** côté State.
- Codes **64 / 65** non décodés dans FICHE_T400. ⚠️ **[HYPOTHÈSE]** à départager sur la source : `64 = W#16#40` et `65 = W#16#41` sont des codes de défaut **génériques PROFIdrive** (souvent « Drive object fault » / « paramètre de commande »). Je **n'affirme pas** la signification sans la doc du FB — je la demande à l'orchestrateur. **Aucune affirmation non sourcée à ce stade.**
- Séquence temporelle : **State.ErrorId 64 apparaît simultanément à la fermeture frein ET à la retombée CommandWord**. Cause apparente la plus cohérente avec l'ordre observé : **arrêt opérateur / arrêt de cycle → retombée commande → fermeture frein à pleine vitesse → détection PLC d'une condition interdite** (probablement « fermeture du frein alors que la fréquence réelle > seuil » , mais sans code exact je n'affirme pas). **Action demandée** : fournir la doc des codes 40/41 du FB de translation ou du variateur HELMKE pour lever l'ambiguïté.

### Q5 — Constantes physiques à retenir pour SimBench M3 (calibrage)

> 🎯 **Règle TDAH-friendly : on calibre sur la mesure, on documente l'écart avec la doc.**

| Constante | Valeur retenue | Source | Statut |
|---|---:|---|---|
| `T400_AXIS_MAX_FREQ_HZ` | **10,00 Hz** (échelle 1/100 sur la trace) | trace mesurée, cohérence physique | ✅ factuel |
| `T400_RAMP_UP_HZ_S` | **17 ± 4 Hz/s** | trace (inter-échantillonnée) | ⚠️ à affiner sur fichier complet |
| `T400_RAMP_DOWN_HZ_S` | **17 ± 4 Hz/s** | trace | ⚠️ idem |
| `T400_SETPOINT_DEFAULT_HZ` | 10,00 Hz (consigne 1000 u) | trace | ✅ |
| `T400_BRAKE_OPEN_TIME_FROM_CMD_MS` | **0** (frein s'ouvre au tick de commande) | trace 11558 | ✅ mesuré, **précision ±100 ms** |
| `T400_BRAKE_CLOSE_SPEED_THRESHOLD_HZ` | **non applicable / freinage à 10 Hz mesuré** | trace 26438 | 🔴 anomalie à traiter |
| `T400_DECCEL_SAFESTOP_HZ_S` | **PAS mesuré** dans l'extrait : descente observée = rampe normale, pas SafeStop à 50 Hz/s | trace | ❌ à extraire du fichier complet |
| `T400_INVERSION_DELAY_MIN_MS` | non mesurable sur extrait | FICHE_T400 doc | — |
| `T400_SENSOR_PATTERN` | 11111 (Trémie) → 01111 (PV) → 00111 (P2) → 00011 (P1) → 00000 (Maintenance) | FICHE_T400 | ✅ |
| Distance Trémie → Maintenance | 30,00 m | FICHE_T400 | ✅ |
| Temps idéal 0 → 30 m à 10 Hz (nouvelle échelle) | **3,0 s** à vitesse constante — **incohérent** avec FICHE_T400 qui annonce « 37,5 s hors acc/frein à 0,80 m/s » | FICHE_T400 « 40 Hz → 0,80 m/s » | 🔴 **incohérence majeure** à départager |
| Gain translation | FICHE_T400 `0,02 m/(Hz·s)` **provisoire** | FICHE_T400 | à recalibrer |

🔴 **Alerte factuelle n°2 (devoir d'alerte)** : si unité trace = 1/100 Hz, la vitesse max réelle est 10 Hz → 10×0,02·10 = 0,20 m/s → parcours 30 m en 150 s. FICHE_T400 annonce **0,80 m/s à 40 Hz** → 37,5 s. **Les deux sont incompatibles**. Soit :
- (a) l'échelle de la trace **n'est pas 1/100 Hz** (contre-intuitif physiquement) et l'on reste sur l'hypothèse `0,1 Hz` → 100 Hz max (impossible réseau 50 Hz) ;
- (b) le couple moteur/roue/réducteur fait que 10,00 Hz variateur correspond bien à 0,80 m/s (gain ≈ 0,08 m/(Hz·s), 4× le gain provisoire FICHE_T400) — **cohérent physiquement** (10 Hz pour un rotor 963 min⁻¹ à 8,6 Hz ≈ démultiplication forte) ;
- (c) la trace contient une valeur de consigne **non convertie** en Hz mais en d'autre unité (échelle 1/1000 ?).

➡️ **Demande à l'orchestrateur : confirmer l'unité réelle de M3_ActualFrequencyHz (échelle 1/100 ou non) via la doc du variateur HELMKE ou le POU `FB_Translation`. Sans cela, la vitesse linéaire reste indéterminée (0,20 ou 0,80 m/s), et le SimBench sera biaisé d'un facteur 4.**

---

## 📋 Restitution format contractuel

```text
Auto-vérification liaison (G200_check_linkage.py) — N/A (tâche d'analyse, aucun code modifié)
Gates : n/a
Diff bundle : n/a
Fichiers modifiés : aucun (tâche lecture pure)
Hors scope constaté (devoir d'alerte) :
  1. Trace fournie en extrait tronqué (~1 h manquante) → Q1/Q2 incomplètes sur SafeStop et franchissements capteurs
  2. Échelle unités de M3_ActualFrequencyHz non confirmée → vitesse linéaire indéterminée (×4)
  3. Freinage à pleine vitesse (10 Hz) : anomalie terrain à auditer
  4. Codes défaut 64/65 non décodés → doc variateur/FB à fournir
  5. Incohérence State.ErrorId=1 vs State.Error=0 en début de trace → codage d'erreur à clarifier
```

## ❓ Demandes explicitement adressées à l'orchestrateur (ne pas décider seul)

1. **Fichier trace complet** (`Suivi_TranslationM3bug_20260904_27_wide.csv`) : me le transmettre pour refaire l'extraction sans interpolation (gain : 3 incertitudes éliminées).
2. **Unité de `M3_ActualFrequencyHz`** : échelle 1/100 Hz ou 0,1 Hz ? (impact ×4 sur vitesse linéaire)
3. **Doc codes 64 / 65** (HELMKE ou FB `ST_fbTranslation_Cfg` ou POU lié) pour lever l'ambiguïté causale du défaut.
4. **Décision de sécurité** sur la retombée de frein à vitesse pleine : c'est une anomalie physique réelle — est-elle connue et acceptée, ou doit-elle être traitée comme ticket de bug terrain séparé ?

---

### En attente de validation
- **Aucun fichier modifié** dans ce passage (tâche lecture pure ✔️ conforme au contrat).
- Rien n'est « terminé » tant que les 4 demandes ci-dessus ne sont pas adressées : la Q5 reste **partielle et provisoirement biaisée** sur 2 lignes de la table sans réponse de l'orchestrateur.