# FB_Sim_Encoder — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.5.md`](../AF_Partie-13_Fonction_Simulation_v2.5.md) §4.
> Rôle de **ce** document : modèle simulé d'un codeur absolu de treuil — et **catalogue unique**
> des `TC-P13-030...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Encoder.st` · instances `FB_SimBench.instSimEncoderM1/M2`.

> 🆕 **v1.1 — révision de `TC-P13-032`** (2026-09-20, T338) : l'exigence « `RawPos` ne descend
> jamais sous 0 (borne explicite en soustraction) » était satisfaite par un **plancher muet à 0**
> (`IF RawPos >= Increment THEN ... ELSE RawPos := 0;`). Conséquence mesurée sur banc : dès que le
> comptage atteignait 0, la position restait **figée pour toujours en descente** alors que la
> vitesse pleine continuait d'être publiée — signature « position figée + vitesse non nulle +
> aucun défaut » (les snapshots M2 du 2026-09-20 à 17:25:09 montrent `COD2_PosValue = 0` avec
> `COD2_SpdValue = -525`, soit −1,75 m/s). Le plancher a été retiré : le comptage est un entier
> **signé 32 bits** qui franchit 0 sans s'y figer, et la seule borne restante (plage de
> représentation) est **signalée**. Le zéro de comptage d'un codeur absolu est arbitraire : c'est
> `HomingRefRaw` qui porte la référence, jamais la valeur du compteur brut.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Comptage brut `RawPos` (sémantique signée, garde de plage)
4. Persistance `RawPos`
5. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P13-030...`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 170px);">
    <col style="width: 90px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Intention / Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-030</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>RelayFwd</code>/<code>RelayRev</code> font compter <code>RawPos</code> de <code>SpeedTgt_Pct * 0.1 * SpeedScaleFactor</code> par scan</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-031</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>PresetCmd=TRUE</code> charge <code>PresetValue</code> directement (priorité sur Fwd/Rev), après <code>PresetLatencyCycles</code> — position conservée et vitesse nulle pendant la latence</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-032</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><b>Révisé v1.1</b> — le comptage est un entier <b>signé</b> : la descente le fait <b>descendre de façon continue</b> et <b>franchir 0</b> (0 est un point de passage, jamais une butée) ; aucune branche de comptage ne le borne à un littéral</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-033</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>RawPos</code> survit à un reset froid (via <code>VAR_IN_OUT</code> référençant <code>GVL_PERSISTENT</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>👁️ MANUEL</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-034</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SpeedReportTauS=0.0</code> conserve le saut instantané historique de <code>RawSpdOut</code> (non-régression T316)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-035</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SpeedReportTauS&gt;0</code> fait décroître <code>RawSpdOut</code> sur plusieurs scans après coupure relais (rampe 1er ordre, pas un escalier) — fidélité fenêtre AX10_WAIT_ASCENT_START, T316</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-036</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Comptage à 0 sous commande de descente : le scan suivant <b>ne maintient pas 0</b> — régression directe du blocage M2 du 2026-09-20</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-037</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Garde de plage : au franchissement de ±<code>CST_CountTravelLimitPts</code>, le comptage est borné à la limite <b>et</b> <code>CountSaturated</code> passe à TRUE dans le même scan, <b>et</b> aucune vitesse de mouvement n'est publiée (<code>RawSpdOut = 0</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-038</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Continuité bidirectionnelle : depuis un comptage négatif, la montée le ramène à 0 puis au-delà, sans saut ni butée</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>V-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

🧩 Brique réduite (`AF_Partie-03 §2`) : pas de contrat `Enable/Reset/Error` complet — outil de banc.
Fait « compter » un codeur absolu comme si le treuil tournait réellement, à partir des relais de
sens commandés et de la vitesse rampée courante. Extraction pure d'une logique déjà en place dans
l'ancien `PRG_02_Encoders.st` (bloc « SIMULATION SUR BANC DE TEST ») — aucun changement de
comportement lors de l'extraction, juste dissociation en FB dédié.

Deux instances : une par treuil (M1/M2), câblées depuis `FB_SimBench`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Simulation active (`SimulationModeActive AND NOT BusEncoderMxIsReal`) |
| `RelayFwd`/`RelayRev` | BOOL | Sens commandé (contacteurs de sens du treuil) |
| `SpeedTgt_Pct` | REAL | Vitesse rampée courante (magnitude, %) |
| `PresetCmd` | BOOL | TRUE le cycle où un preset (homing) doit être appliqué |
| `PresetValue` | UDINT | Valeur brute à charger lors du preset |
| `SpeedScaleFactor` | REAL | Multiplicateur confort de test banc (défaut 1.0), `GVL_Simulation.SimEncoderSpeedFactor` |
| `TestOffsetCmd`/`TestOffsetPts` | BOOL / DINT | Front = injecte un vrai saut de position (test Méca E / rattrapage synchro) |
| `SpeedReportTauS` | REAL | Constante de temps 1er ordre du retour vitesse rapporté (`RawSpdOut`), s. `0.0` = saut instantané (défaut, historique). `>0` = rampe continue au lieu d'un escalier à la coupure relais — position (`RawPosOut`) non affectée. Non calibré treuil (T316, `SYNTHETIQUE`). |

| Sortie/IN_OUT | Type | Sens |
|---|---|---|
| `RawPosOut` | UDINT | Position brute simulée, à aiguiller à la place de la valeur EtherCAT réelle |
| `RawSpdOut` | DINT | Vitesse brute simulée (objet CoE `0x6031:01`, 0,1 RPM) |
| `CountSaturated` **(v1.1)** | BOOL | Comptage en butée de **plage de représentation** (voir §3) — saturation **signalée**, jamais muette. `FALSE` hors `Enable` |
| `RawPos` (`VAR_IN_OUT`) | UDINT | Référence `_SimEncoderRawPosM1/M2` dans `GVL_PERSISTENT` |

---

## 3. Comptage brut `RawPos` — sémantique signée & garde de plage (v1.1)

**Le compteur brut est un entier SIGNÉ.** Le conteneur `UDINT` n'est qu'un support d'échange :
toute la chaîne aval le relit en `DINT` (`FB_Encoder_Scale`, `FB_Encoder_Homing` via
`UDINT_TO_DINT`). Conséquences normatives :

1. **`0` n'est pas une butée** : c'est un point de passage comme un autre. Une descente qui atteint 0
   **continue** de décrémenter (la représentation signée donne −41 pts, etc.). Le zéro de comptage
   d'un codeur absolu est **arbitraire** ; seule `HomingRefRaw` porte la référence métier.
2. **Aucune branche de comptage ne borne à un littéral** — ni en mouvement (`RelayFwd`/`RelayRev`),
   ni en roulis inertiel. Une butée littérale sur un comptage brut est interdite par le garde-fou
   `G510_check_sim_silent_floor.py`.
3. **Seule borne admise = plage de représentation, et elle est signalée** : au franchissement de
   ±`CST_CountTravelLimitPts` (2^30 pts = 262 144 m de câble — jamais atteint en essai), le
   comptage est borné à la limite, `CountSaturated` passe à `TRUE` dans le **même scan**, et la
   vitesse de mouvement est purgée (`RawSpdOut = 0`). Une position bornée ne publie **jamais** une
   vitesse de mouvement : c'est exactement ce qui interdit la signature « position figée + vitesse
   non nulle + zéro défaut ».
4. **Pourquoi cette garde est loin de l'usage réel** : elle protège contre le seul point de
   discontinuité de la représentation (franchissement de ±2^31). La placer à la moitié de la plage
   signée laisse une marge de sécurité sans jamais contraindre la plage utile du banc.

> ⚠️ **Hors périmètre de ce FB** : la **ré-initialisation** du comptage persisté (une valeur de
> comptage nulle est ré-injectée à une constante de banc par `FB_SimBench`, première activation du
> banc) ne relève pas du modèle codeur. Elle reste à traiter séparément : elle produit, elle, un
> **saut** de position que la chaîne réelle ne sait pas qualifier (voir T338, CR2).

---

## 4. Persistance `RawPos`

`RawPos` est passé en `VAR_IN_OUT`, référencé depuis `GVL_PERSISTENT` — pas de champ interne au
FB. `PERSISTENT` n'est valide que sur du `VAR_GLOBAL` en CODESYS, pas sur une variable locale de
FB (`VAR RETAIN`/`VAR PERSISTENT RETAIN` locaux testés, aucun ne convient). Un vrai codeur absolu
physique conserve son comptage brut à travers un reset froid, indépendamment de l'automate — le
modèle simulé doit reproduire ce comportement pour rester représentatif d'un test de reprise après
coupure.

> 📌 **Conséquence de la sémantique signée (§3)** : le comptage persisté peut devenir **négatif**
> (représenté au-delà de 2^31 en `UDINT`, ex. `4294967255` = −41 pts). C'est **normal** et
> inoffensif pour la chaîne aval, qui travaille en `DINT`. Une valeur haute en fenêtre Watch n'est
> **pas** une anomalie.

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation §2 (aiguillage `WinchInputSourceSimulated`) |
| AF09/AF10 | `FB_Encoder_Abs`, `FB_Encoder_Homing` (consommateurs réels de `RawPosOut`) |
| Code | `CODE/L_SIMULATION/FB_Sim_Encoder.st`, `CODE/GVL_PERSISTENT.st` |
| Test CI | `TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_sim_encoder.st` |
| Garde-fou | `TOOLS/AGENT_WORKFLOW/scripts/G510_check_sim_silent_floor.py` |
| Diagnostic | `DOC/WFLOW/TROUBLESHOOTING/TROUBLESHOOTING_T338_PositionM2_Figee_2026-09-20.md` |
