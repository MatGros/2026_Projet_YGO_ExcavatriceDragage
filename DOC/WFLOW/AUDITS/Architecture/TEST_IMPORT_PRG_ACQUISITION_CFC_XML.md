# Essai CODESYS — `PRG_ACQUISITION_CFC.xml`

> Premier livrable CFC natif. Remplace à l'identique le POU historique
> `PRG_ACQUISITION_CFC`, **sans modification de MainTask**.
>
> ⚠️ Faire l'essai sur Device.Sim / banc, jamais directement sur la machine sans
> validation automatique et humaine complète.

## Import

1. Faire une archive CODESYS du projet fonctionnel.
2. Sélectionner `Application` → **Project / Import PLCopenXML**.
3. Importer `CODE_XML/CODE_Bundle.xml`.
4. Vérifier que CODESYS propose de remplacer **un seul** objet :
   `PRG_ACQUISITION_CFC`.
5. Vérifier que la `MainTask` appelle toujours exactement
   `PRG_ACQUISITION_CFC` : aucun ordre ni appel ne change dans ce lot.
6. Compiler. Zéro erreur est obligatoire avant téléchargement.

## Observation minimale

| Watch CODESYS | Attendu |
|---|---|
| `PRG_ACQUISITION_CFC.HwReal` | Image des E/S réelles présente. |
| `PRG_ACQUISITION_CFC.HwSim` | Image banc de simulation présente. |
| `PRG_ACQUISITION_CFC.HwIn` | Réel ou simulé selon les flags `GVL_Simulation`. |
| `PRG_ACQUISITION_CFC.WinchInputSourceChanged` | Impulsion unique lors de la bascule source Winch, jamais au boot. |
| `PRG_ACQUISITION_CFC.M3_SensorsWord` | Mot capteurs identique à la valeur précédente. |
| `PRG_ACQUISITION_CFC.M3_SensorWordIncoherent` | Même diagnostic qu'avant import. |

## Essai simulation

1. Conserver les commandes mouvement neutralisées.
2. Basculer un seul domaine simulé dans `GVL_Simulation`.
3. Confirmer que seul ce sous-domaine de `HwIn` bascule sur `HwSim`.
4. Revenir au réel et confirmer le retour de `HwIn`.
5. Si une valeur, un diagnostic ou une polarité diffère : **ne pas télécharger** ;
   exporter le journal de compilation et relever la variable concernée.

## Ce qui ne change pas

- même nom POU : `PRG_ACQUISITION_CFC` ;
- même rang/configuration `MainTask` ;
- même corps métier, déplacé dans `FB_AcquisitionLegacyBridge` ;
- mêmes sorties publiques, plus quatre sorties M3 auparavant lues illégalement
  dans l'instance privée du décodeur.
