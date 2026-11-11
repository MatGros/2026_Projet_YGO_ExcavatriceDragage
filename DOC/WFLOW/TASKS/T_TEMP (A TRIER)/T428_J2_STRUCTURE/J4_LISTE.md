# T428 J4 — Structure appliquée par la liste seule

> 🟡 **Liste réordonnée, lecture réelle en simulation à faire.** Choix de l'exploitant le 2026-11-08 : la liste d'abord, sans programme automate. Aucune ligne de `CODE/` n'a changé.

## 1. Résultat

| Mesure | Avant J3 | Après J3 | **Après J4** |
|---|---:|---:|---:|
| Chemins lus | 571 | 595 | **438** |
| Lots de lecture de 100 | 6 | 6 | **5** |
| Octets de chemins | — | 36 138 | **26 173** (-28 %) |
| Chemins non résolus (contrôle statique) | 0 | 0 | **0** |

Fichier : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt`.

## 2. Ce qui a changé

| Action | Nombre | Règle |
|---|---:|---|
| Doublons retirés de la liste | 147 | Décisions `RETRAIT_*` de la table J2 ; l'ancre reste lue |
| Fausses valeurs retirées de la liste | 8 | `CABLER_J4` : la vraie valeur est lue depuis J3 |
| Constante sans source retirée | 1 | `Idx203_BypassSensorsGlobal`, toujours FALSE |
| Ordre | 438 | Général, M1, M2, M3 en 10 étapes, puis fonctions : **38 blocs contigus** |

Les variables restent dans le programme et dans la vue : seul le snapshot ne les lit plus. Les noms ne changent pas.

| Fausse valeur retirée | Vraie valeur lue à la place |
|---|---|
| `I/J.Outputs_500.Idx505_CmdBrakeRelease_RQ` | `GVL_IHM.IoHw.Out.M1/M2_BrakeRelease_RQ` |
| `L.Outputs_500.Idx501_CmdDriveControlWord` | `GVL_IHM.IoHw.Out.M3_CommandWord` |
| `L.Outputs_500.Idx503_CmdBrakeRelease_RQ` | `GVL_IHM.IoHw.Out.M3_BrakeRelease_RQ` |
| `T_Permits.M1/M2Safety{Ascent,Descend}Permit` (4) | `PRG_04_Treuils_Benne.SafetyPermitM1/M2_*` |

## 3. Contrôles

| Contrôle | Résultat |
|---|---|
| Chaque chemin retiré a une décision dans la table J2 | ✅ 0 perdu sans décision |
| Aucun chemin nouveau hors table | ✅ |
| Résolution statique des 438 chemins | ✅ 0 KO |
| Ordre par zone et étape | ✅ 38 blocs, aucun bloc coupé |
| Consommateurs de la liste | ✅ Seuls les scripts de lecture CODESYS (snapshot, acquisition périodique, snapshot_all) |

## 4. Limites et suite

- ⚠️ `generate_variable_list_from_code.py` écrit par défaut dans ce même fichier : le relancer écraserait la liste réordonnée.
- La liste n'accepte pas de titres de section : les blocs se reconnaissent à l'ordre, pas à un en-tête.
- **Un seul snapshot en simulation valide J3 et J4** : attendu `Variables lues : 438 / 438`, avec la durée relevée.
- Le nettoyage du code (vue, types, mock, AF-14) reste possible plus tard ; il n'est pas nécessaire au diagnostic.
