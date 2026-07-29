# 📥 Analyse Fonctionnelle — Partie 6 : Conditionnement E/S (v1.8 — Lot 3A : sorties Q directes depuis PRG_10_Outputs_LD ; FB_Output reste disponible sans instance ; confirmations frein explicitement nommées.)

> **Projet** : Excavatrice de dragage — CODESYS 3.5  
> **Statut** : référence active · 2026-07-27  
> **Évolution v1.7** : acquisition centralisée et frontière `HwReal` / `HwIn`.

---

## 1. 🎯 Rôle

Le conditionnement transforme les E/S brutes en signaux métier stables et de polarité explicite.
`FB_Input` filtre les entrées TOR (20 ms) et porte l'inversion NO/NC nécessaire; `FB_Output`
conditionne la sortie relais finale. Aucune logique métier ne lit directement une E/S matérielle.

## 2. 🏗️ Chaîne d'acquisition unique

```text
%IX / PDO ──► HwReal ──► HwIn ──► FB_Input ──► PRG_00 VAR_OUTPUT ──► métier
```

- `PRG_00_Inputs` §0 recopie toutes les entrées physiques et PDO dans `HwReal`.
- §0bis sélectionne par domaine l'image réelle ou celle du banc : `HwIn`.
- §1 applique `FB_Input` (filtre 20 ms, inversion documentée) puis publie les valeurs normalisées.
- Les autres `PRG` et FB lisent exclusivement les sorties de `PRG_00_Inputs`.

La simulation reste ainsi en amont du conditionnement; elle ne force jamais une sortie de FB ni
ne complète une valeur réelle.

## 3. 🔌 Convention de nommage E/S

| Forme | Exemple | `TRUE` signifie |
|---|---|---|
| `<Domaine>_<ÉtatQuandTRUE>_DI` | `M1_BrakeIsOpen_DI` | l'état physique explicitement nommé |
| `<Domaine>_<ActionCommandée>_RQ` | `M1_BrakeRelease_RQ` | l'action demandée est active |
| `_DQ` | `M1_RelayFwd_Up_DQ` | la sortie physique finale est alimentée |

La polarité doit être lisible dans le nom. Les références de renommage et le REX C1 sont dans
`AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`.

## 4. 🔒 Polarités de sécurité

- Les retours NC/fail-safe nommés `Ok`, `Closed`, `Tensioned` ont un repos sain explicite.
- Une entrée inversée est normalisée une seule fois dans `PRG_00` par `FB_Input`, jamais dans les
  consommateurs.
- `PowerContactorEngaged_DI` confirme le contacteur de puissance; ce n'est pas la boucle AU.
- `EmergencyChainClosed_DI` indique la boucle AU fermée.
- `PowerKeepAlive_A/B_RQ = TRUE` maintient l'énergie; sa retombée coupe la puissance.

## 5. 📥 Application CODESYS 3.5

Après import de `CODE/CODE_Bundle.xml`, vérifier en vue instance, dans cet ordre :

1. `HwReal` : point E/S/PDO brut;
2. `HwIn` : source réellement sélectionnée;
3. instance `FB_Input` : filtre/inversion;
4. sortie `PRG_00_Inputs` : valeur métier publiée.

Toute divergence de polarité se corrige à l'étape de conditionnement, pas dans un FB métier.


---

## Lot 3A — Frontière sorties

`PRG_10_Outputs_LD` écrit directement les Q finales M1/M2/M3. Les 15 instances `FB_Output` sont retirées ; `FB_Output.st` reste disponible comme POU non instancié (conservé pour compatibilité/outillage, sans canal de commande actif). Les états `M1/M2/M3BrakeCommandOpenConfirmed` sont produits une seule fois dans `PRG_00_Inputs` après filtrage : TRUE confirme le contacteur/bobine de desserrage, sans conclure sur la position mécanique du frein.

`FB_Winch` / `FB_SpeedStepTable` reste l'unique producteur du mapping C1..C4 : `FB_WinchOutputInterlock_LD` reçoit les quatre demandes et les laisse passer exactement quand le palier et les gates sont autorisés, sinon il les masque. Il ne reconstruit aucune combinaison, notamment pour les tables M2 Benne dynamiques. `FB_TranslationOutputInterlock_LD` autorise les mots M3 1/2 et la fréquence seulement si la demande de desserrage **et** sa confirmation contacteur/bobine sont simultanément vraies.

Les frontières finales `FB_WinchOutputInterlock_LD` et `FB_TranslationOutputInterlock_LD` restent en ST malgré leur suffixe `_LD`. Le générateur PLCopenXML convertit uniquement les `PROGRAM PRG_*_LD` en Ladder ; ce suffixe marque la fin de parcours lisible maintenance. Les recopiages BOOL connus de l'interface restent des réseaux `contact → coil`. Dans `PRG_10_Outputs_LD`, les PDO AC600 non booléens sont générés en liaisons Ladder typées `inVariable → outVariable` : `M3_CommandWord` (WORD) et `M3_SetpointFrequencyHz` (UINT) ne sont jamais générés en contact/bobine BOOL.

`SafeStop` conserve le contrat Partie 3 : `FB_Winch` / `FB_Translation` produisent la rampe rapide avec `Enable` maintenu. Les interlocks finaux ne transforment pas ce signal en coupure sèche ; ils coupent après retombée effective de la demande métier, ou immédiatement sur `Enable=FALSE`, `EmergencyStopOk=FALSE`, timeout ou défaut final.

### Implantation C4 vérifiable — instances au plus près des sorties

```text
PRG_06_WinchControl.VAR_OUTPUT WinchM1/WinchM2FinalInterlockRequest
PRG_07_TranslationControl.VAR_OUTPUT TranslationFinalInterlockRequest
                     ↓ (ordre MainTask : PRG_06 → PRG_07 → PRG_10)
PRG_10_Outputs_LD : 3 instances stateful `FB_*OutputInterlock_LD`
                     ↓
Q M1/M2, frein M3 et PDO AC600
```

`PRG_06` et `PRG_07` ne réécrivent jamais les variables de `PRG_10`. Les structures sont des
sorties publiques typées, à producteur unique, lues directement par `PRG_10` : ce ne sont ni une
GVL ni un canal de commande caché. Après import, l'utilisateur confirme l'ordre de POU ci-dessus
dans MainTask avant toute qualification CODESYS.
