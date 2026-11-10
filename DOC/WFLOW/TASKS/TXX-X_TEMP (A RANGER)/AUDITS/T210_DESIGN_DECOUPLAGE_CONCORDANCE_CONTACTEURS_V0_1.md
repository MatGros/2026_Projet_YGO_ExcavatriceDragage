# DESIGN T210 — Concordance contacteurs toujours active (interfaçage minimal)

> **Statut** : Analyse de cadrage (étape 1 de T210) — **lecture seule, zéro code modifié**.
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T210.yaml`
> **Date** : 2026-09-01 · **Auteur** : DSH (DeepSeek)
> **Principe** : **fiabilité d'abord** — s'interfacer avec l'existant, **zéro structure
> créée/modifiée**, mise en forme différée.

---

## 1 · Objectif (fiabilité)

La **concordance commandes/contacteurs M1/M2** (`FB_SyncContactor`) doit être
**effective dès que les 2 treuils sont commandés**, indépendamment du mode
synchronisme. Seul le bypass la neutralise. Le mode synchronisme (`SyncEnable`)
ne pilote que l'écart de position (`FB_SyncDeviation`).

**Changement minimal** : retirer le gate `SyncEnable` de `FB_SyncContactor` et le
remplacer par une condition « 2 treuils commandés » calculée **à partir des entrées
existantes** (aucun DUT/struct nouveau).

---

## 2 · Constat dans le code existant

`FB_SyncContactor.st:63` :
```st
MismatchActive := SyncEnable AND (
    (RelayFwdM1 <> RelayFwdM2) OR (RelayRevM1 <> RelayRevM2) OR
    (Contactor1_M1 <> Contactor1_M2) OR ... (Contactor4_M1 <> Contactor4_M2)
);
```
➡️ La concordance n'est active que si `SyncEnable=TRUE`. Or elle doit l'être dès
que les 2 treuils sont commandés, quel que soit le mode.

---

## 3 · Changement cible (minimal, sans structure)

Dans `FB_SyncContactor.st`, remplacer le gate `SyncEnable` par une condition
« 2 treuils commandés » calculée **inline** depuis les entrées déjà présentes
(relais + contacteurs M1/M2) — une **variable locale BOOL**, pas un DUT :

```st
// Concordance active dès que les 2 treuils sont commandés (relais ou contacteur)
// OU en mode synchronisme (SyncEnable). Seul BypassGlobal neutralise.
BothCommanded := (RelayFwdM1 OR RelayRevM1 OR Contactor1_M1 OR Contactor2_M1
                  OR Contactor3_M1 OR Contactor4_M1)
             AND (RelayFwdM2 OR RelayRevM2 OR Contactor1_M2 OR Contactor2_M2
                  OR Contactor3_M2 OR Contactor4_M2);

MismatchActive := (BothCommanded OR SyncEnable) AND (
    (RelayFwdM1 <> RelayFwdM2) OR (RelayRevM1 <> RelayRevM2) OR
    (Contactor1_M1 <> Contactor1_M2) OR ... (Contactor4_M1 <> Contactor4_M2)
);
```

- **Aucune structure créée/modifiée** : `BothCommanded` est une `VAR` locale BOOL.
- **Interface inchangée** : mêmes entrées/sorties, mêmes types.
- **Décision validée 2026-09-01** : gate = `BothCommanded OR SyncEnable` (robuste,
  pas de régression en mode sync quand un seul treuil est commandé ; `SyncEnable`
  reste utilisé, pas de paramètre mort).
- **Impact sécurité** : `ContactorMismatch` (bit 1 de `Fault.ErrorId`) déclenche
  `SafeStop` M1/M2 (PRG_04:531/533) dès que les 2 treuils sont commandés avec des
  commandes divergentes, même hors mode synchronisme — comportement voulu, à valider.
- **Fiabilité** : la concordance ne peut plus être désactivée par le mode.

---

## 4 · Périmètre minimal (fiabilité d'abord)

| Fichier | Changement | Structure ? |
|---|---|---|
| `FB_SyncContactor.st` | Retirer le gate `SyncEnable`, ajouter `BothCommanded` (VAR locale) | ❌ non |
| `FB_SyncDeviation.st` | **Aucun** — reste gaté par `SyncEnable` (mode synchronisme = écart position) | ❌ non |
| `FB_WinchSync.st` | **Aucun** — propage déjà les sorties des 2 sous-blocs | ❌ non |
| `ST_SyncCmd.st` | Défaut `SelSyncEnable := FALSE` (désactivé par défaut) | ❌ non (valeur par défaut) |

**Hors périmètre (différé)** : mise en forme, renommages, refactor d'interface,
création de DUT, doc AF détaillée.

---

## 5 · Points de vigilance (fiabilité — à confirmer avant code)

- **V1** : `BothCommanded` (AND des 2 axes) évite les faux positifs quand un seul
  treuil est commandé. **Décision validée** : gate = `BothCommanded OR SyncEnable`
  (pas de régression en mode sync quand un seul treuil est commandé).
- **V2** : `FB_Safety_Winch` Méca E (écart critique) reste gaté par `SyncEnable` —
  **inchangé ici** (hors périmètre minimal). À noter, pas à modifier.
- **V3** : `instWinchSync.Enable` (PRG_04 §4) désactive tout `FB_WinchSync` si
  benne/homing/inhibit — **inchangé ici**. La concordance suivra ce gate existant.
- **V4** : en mode non-synchronisé, commander les 2 treuils à des **paliers
  différents** → discordance → `SafeStop` + latch (Reset requis). Comportement
  voulu (concordance obligatoire), à confirmer sur site.

---

## 6 · Conclusion

Le changement minimal et fiable est **localisé dans `FB_SyncContactor.st`** :
remplacer le gate `SyncEnable` par une condition « 2 treuils commandés » calculée
depuis les entrées existantes. Aucune structure créée/modifiée, interface inchangée.
Le reste (désactivation par défaut, doc, mise en forme) est différé.
