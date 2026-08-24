# FB_WinchSync — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.0.md`](AF_Partie-10_Fonction_Winch_v2.0.md) §4.
> Rôle de **ce** document : synchro niveau 1 (warning), couplage croisé — et **catalogue unique**
> des `TC-P10-014`, `015`, `016`.
> Source code : `CODE/H_TREUILS_BENNE/FB_WinchSync.st` · instance unique dans `PRG_04_Treuils_Benne.st` (ST). 🚩 La conversion CFC natif est **abandonnée** (2026-08-16) : aucune page CFC native cible.

> 🟠 **v1.1 (2026-08-24)** — correction de valeurs après revue indépendante (T55) : le **Warn est
> instantané + latch (sans timer)** et le **800 ms est sur le Fault (0.50 m)**, pas sur le Warn ;
> Méca E = **2.5 m** (code), pas 2.0 m/3 s. Voir §3 et TC-P10-014.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Niveau 1 vs Méca E (défense en profondeur)
4. Couplage croisé Treuils
5. Alertes et écarts
6. Documents liés

## 🧪 Points de validation (`TC-P10-014/015/016` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P10-014</code></nobr> | Sync bit0 (écart > 0.10 m, **instantané + latch**, sans timer) ➔ SyncWarn IHM seul | `💻 AUTO` |
| <nobr><code>TC-P10-015</code></nobr> | Sync bit1 (incohérence commande, 500 ms) ➔ SafeStop fast | `💻 AUTO` |
| <nobr><code>TC-P10-016</code></nobr> | Couplage croisé : `SyncActive` ➔ arrêt d'un treuil coupe l'autre | `💻 AUTO` |

---

## 1. Rôle et profil

Surveillance **niveau 1** de l'écart M1/M2 — brique de diagnostic/warning, PAS un bloc safety
domaine (pas de `SafeStop` direct sur simple écart). 1 seule instance (`instWinchSync`),
partagée par les deux treuils.

---

## 2. Interface

| Entrée | Sens |
|---|---|
| `CablePosM1/M2`, `HomedM1/M2` | Position + référencement (sortie Encodeurs) |
| `SyncEnable` | Autorité mode (voir §3bis Modes) |
| `CfgSyncToleranceM` :=0.10 m | Seuil warning |
| `CfgSyncCriticalToleranceM` :=0.50 m | Seuil fault |
| `ActiveOffsetM` | Offset dynamique (0 hors benne, décalage pendant manœuvre benne) |
| `RelayFwdM1/M2`, `RelayRevM1/M2`, `Contactor1..4_M1/M2` | Cohérence commande |

**Sorties** : `DeltaPosM` (ABS), `SignedDeltaPosM` (signé, >0=M1 plus haut), `SyncActive`,
`SyncWarn`, `SyncDeviationWarn`, `SyncDeviationFault`, `ErrorId` (bit0 écart, bit1 incohérence commande).

---

## 3. Niveau 1 vs Méca E (défense en profondeur)

> ⚠️ **Correction v1.1 (vérifié code)** : le **Warn (0.10 m) est instantané + latch, SANS
> temporisation** (`FB_SyncDeviation` : `SyncDeviationWarn := WarnActive OR WarnLatched`). Le
> **800 ms est sur le Fault (0.50 m)** (`DeviationFaultTimer`). Le `ContactorMismatch` est à
> **500 ms**. Méca E = **2.5 m** (code, `CriticalSyncToleranceM`), pas 2.0 m/3 s.

| Niveau | Seuil | Délai | Conséquence |
|---|---|---|---|
| **1** (ce FB, bit0) | 0.10 m | **instantané + latch** (sans timer) | `SyncWarn` IHM **seul** — pas de SafeStop direct |
| **1** (ce FB, bit1) | incohérence commande | 500 ms | **Grave** — remonté SafeStop fast côté Treuils |
| **1** (ce FB, bit2) | 0.50 m | **800 ms** | `SyncDeviationFault` — block signal / palier 1 |
| **2** (Méca E, `FB_Safety_Winch`) | 2.5 m (`CriticalSyncToleranceM`) | — | bit12 SafeStop seul, bit13 +PowerCutOff |

Le niveau 1 est ~20× plus sensible que Méca E — sert d'alerte précoce, pas de coupure.

**`SyncActive` selon Mode** : MAINT_N1=imposé TRUE · MAINT_N2=`SyncEnable` (pilotable) ·
Manuel/SemiAuto=TRUE par défaut. ⚠️ **`SyncActive` est indépendant de la gravité** — le problème
est porté par Warn/Fault, pas par `SyncActive` (cf. T55).

---

## 4. Couplage croisé Treuils

Si `SyncActive`, tout arrêt (SafeStop/Permit) sur **un** treuil coupe l'**autre au même scan**
(pas d'attente du filtre 500/800 ms interne) — câblé dans le programme Treuils ST actuel (`PRG_04_Treuils_Benne.st`), pas dans ce FB.

Suspendu pendant `BenneBusy` (écart transitoire volontaire) et en butée normale
(`AscentPermit/DescendPermitMx_Active`).

Gate optionnel `_SyncSoftStopEnable` (défaut FALSE) : si TRUE, bit0 n'est plus réintégré en
SafeStop fast — géré uniquement par blocage directionnel (le sens qui aggrave l'écart est
bloqué, celui qui le réduit reste autorisé).

---

## 5. Alertes et écarts

Aucun écart majeur identifié — comportement conforme au code (`FB_WinchSync.st`,
`FB_SyncDeviation.st`, `FB_SyncContactor.st`) sur ce périmètre.

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF10 / FB_Safety_Winch | Méca E — défense en profondeur niveau 2 |
| AF05 | Modes — `SyncEnable` |
| Code | `CODE/H_TREUILS_BENNE/FB_WinchSync.st`, `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (ST) |
| Étude T55 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_SYNCHRONISME_UNIQUE_4NIVEAUX_v0.2.md` |
