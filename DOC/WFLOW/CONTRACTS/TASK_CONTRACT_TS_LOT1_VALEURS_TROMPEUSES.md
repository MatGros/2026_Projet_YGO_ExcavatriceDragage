# Lot 1 de T428 — Valeurs trompeuses du snapshot

> Contrat structuré : `TASK_CONTRACT_TS_LOT1_VALEURS_TROMPEUSES.yaml`. Plan général : `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.md`, jalon J1.

**But :** chaque variable corrigée affiche ce que son nom annonce. Aucun ordre machine ne change, aucun nom ni chemin de snapshot ne change.

**État :** contrat rédigé, en attente du GO d'implémentation. Aucune écriture dans `CODE/`.

## Corrections

| Variable | Aujourd'hui | Après |
|---|---|---|
| `N/O/P.Step2_ModeAuthorized` | Faux en SEMI_AUTO | Vrai si le mode n'est pas `DISABLE` |
| `I/J.Outputs_500`, `H.Idx501/502`, `N/O.Relay*`, `K.Idx501` | Demande, ou constante pour `K.Idx501` | Ordres finaux publiés par `PRG_06` |
| `I/J.Idx407_FinalAuthorizedStep` | Palier demandé | Palier autorisé par la barrière, un cycle de retard au plus |
| `I/J.Idx323/324` | Calcul local | `Safety.CableLimitAscent`, la butée réellement appliquée |
| `C.PowerCutOffRequest` | Copie de `PowerCutOffActive` | `PRG_06_Outputs.Data.PowerCutOffRequest` |
| `L.Idx502_CmdDriveFreq_Hz` | 0 | Consigne finale M3, échelle et conversion à confirmer |
| `I.Idx307_SlackCablePhysical_DI` | FALSE | Même signal que la sécurité M1 |

## Périmètre

- **Modifiable :** `FB_TroubleshootingView.st`, `PRG_07_Supervision.st`, lignes 110 et 177 de `FB_WinchStateProjection.st`, test et mock CI, AF-14, bundles.
- **Interdit :** `GVL_Troubleshooting.st`, ses types, `G_CYCLE`, `PRG_04`, `PRG_06`, l'interlock, la sécurité treuil.
- **Inchangé :** `RequestedDirection`, `Idx208`, `Idx209` et le terme T371 de `Step8_OutputInterlockOk`.

## Preuves attendues

Test CI de la vue, bundle complet, diff bundle, G200, palier C, liste de variables identique, diff limité au périmètre, geste habituel inchangé en simulation, rejeu à l'aveugle publié.

## Points de vigilance

- Les champs `Outputs` des anciens snapshots ne sont plus comparables directement.
- `M3_SetpointFrequencyHz` est un `WORD`, `L.Idx502` un `UINT`.
- Le harnais CI de la vue peut bloquer (T372) : le signaler, ne pas le contourner.
- `FinalAuthorizedStep` n'est lu que par la vue, vérifié sur tout `CODE/`.
