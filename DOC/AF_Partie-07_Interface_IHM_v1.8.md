# 🖥️ Analyse Fonctionnelle — Partie 7 : Interface IHM (v1.8)

> Complément à `AF_Partie-07_Interface_IHM_v1.7.md`.

## H. Fiabilisation persistance config (FIX 2026-07-23, `CONFIG-PERSIST-01`)

### 🐛 Contexte

`GVL_IHM` est en `RETAIN` (pas `PERSISTENT`) : tout changement de structure d'un `ST_*HMI`
(comme lors d'une session de dev normale) invalide son contenu au prochain chargement — CODESYS
réinitialise chaque champ à son défaut struct déclaré. Un bloc de restauration dans
`PRG_09_Supervision.st` §2 est censé re-synchroniser ces valeurs depuis les vraies variables
`PERSISTENT` (`GVL_PERSISTENT.st`), mais utilisait une sentinelle `IF champ = 0.0 THEN` — cassée
dès que le défaut struct réel du champ n'est pas `0.0` (ex. `CfgTopSensorPos_M := 8.5`,
`CfgSyncTolerance_M := 0.25`). Résultat : la config (paliers vitesse, rampes SafeStop, limites
câble, tolérance synchro) retombait silencieusement au défaut struct sans jamais se resynchroniser.

### ✅ Fix — flag `Initialized` dédié

Chaque groupe de config exposé à l'IHM porte désormais un flag booléen dédié (défaut `FALSE`,
non ambigu contrairement à un champ métier) :

| Groupe | Champ | Struct |
|---|---|---|
| `M1TreuilRetenue.Cfg` / `M2TreuilBenne.Cfg` | `Initialized` | `ST_WinchCfg` |
| `Sync` | `CfgInitialized` | `ST_SyncHMI` |

Ce flag pilote (1) la restauration PERSISTENT→IHM une seule fois après invalidation RETAIN,
(2) le blocage de la propagation IHM→PERSISTENT (§3) tant que la restauration n'a pas eu lieu —
évite d'écraser le vrai PERSISTENT avec une valeur GVL_IHM fraîchement resettée.

### ⚠️ Alarme opérateur — `ConfigRestoredFromPersistent`

Une restauration de config est un événement anormal (RETAIN invalidé) : elle ne doit **jamais**
disparaître silencieusement, même doctrine que les défauts métier (reset = front conscient).

| Champ | Type | Direction | Rôle |
|---|---|---|---|
| `Commun.ConfigRestoredFromPersistent` | BOOL | PLC→IHM | Restauration détectée ce boot — vérifier les valeurs avant reprise cycle |
| `Commun.BtnAckConfigRestored` | BOOL | IHM→PLC | Acquittement opérateur (front) — seul moyen d'effacer le bit |

### 🐛 Bug cousin corrigé — `BypassRestoreDone`

Variable locale `PRG_09_Supervision` en simple `VAR` (pas `RETAIN`) : repassait à `FALSE` à
CHAQUE reset/download, même quand `GVL_IHM` (RETAIN) restait intact, ce qui pouvait re-forcer un
bypass `Global` que l'opérateur venait de désactiver. Corrigé en `VAR RETAIN`.

### 📄 Référence code

Implémentation dans `CODE/MAIN/PRG_09_Supervision.st` §2/§2bis/§3, `CODE/SUPERVISION/_TYPES/ST_WinchCfg.st`,
`CODE/SUPERVISION/_TYPES/ST_SyncHMI.st`, `CODE/SUPERVISION/_TYPES/ST_CommunHMI.st`.

⚠️ **Test PLC automatique non encore implémenté** (requis avant clôture — sujet limites
physiques/interlock/SafeStop, voir `AF_Partie-14` §Contrat tests). Suivi : `PLAN_TASK_v1.0.md` T65.
