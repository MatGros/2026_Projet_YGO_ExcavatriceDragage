# Session de Troubleshooting — Alarmes codeurs avant réarmement AU

> Date : 2026-09-07 · Situation : à confirmer (banc/site) · Statut : ANALYSE STATIQUE

## 1. Contexte figé

- Aucun snapshot PLC fourni ; conclusion limitée au code source versionné.
- Symptôme rapporté : pendant le réarmement de l'AU, les codeurs hors tension génèrent des alarmes visibles comme liées au homing.

## 2. Arbre des causes

| Hypothèse | Preuve statique | Verdict |
|---|---|---|
| Défaut de transaction homing | `FB_Encoder_Homing` ne crée un défaut qu'après une commande de homing / transaction preset. | Écartée pour le symptôme décrit. |
| Perte attendue des codeurs, affichée en alarme | `PRG_02_Acquisition` maintient `instDiagEthercat` et les deux `FB_Encoder` activés ; la perte EtherCAT rend les codeurs non opérationnels. `FB_Hmi_BannerFormatter` les affiche après 1,5 s sans condition AU. | Cause candidate forte (analyse statique). |

## 3. Correction proposée — validation humaine requise

- Ne pas désactiver le diagnostic EtherCAT, les FB codeurs, ni les interlocks mouvement.
- Inhiber uniquement les alarmes IHM « codeur non opérationnel » tant que l'AU n'est pas complètement réarmée : boucle AU fermée **et** contacteur puissance engagé.
- Après réarmement complet, conserver le délai anti-bagotement actuel (1,5 s) puis alarmer immédiatement tout codeur qui reste indisponible.

## 4. Variables à vérifier par snapshot unique si validation terrain requise

- `GVL_Troubleshooting.C_Safety.AllConditionsMet`
- `GVL_Troubleshooting.E_HomingM1.Step3_EncoderAvailable`
- `GVL_Troubleshooting.F_HomingM2.Step3_EncoderAvailable`

## 5. Journal

- 2026-09-07 : analyse statique effectuée ; aucune modification de code ni forçage PLC.
