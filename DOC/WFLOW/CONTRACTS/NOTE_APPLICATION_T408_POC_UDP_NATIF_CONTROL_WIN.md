# T408 — POC UDP natif multi-flux : recette attendue

## Objet

Ce POC mesure la planification UDP **dans** Control Win. Il est distinct de
T407, qui a prouve la connectivite mais aussi la limite ScriptEngine :

```text
T407 ScriptEngine : 138/138, p99 RTT 25.040 ms, mais ~217 ms/echange et max 519.836 ms
T408 UDP natif    : mesure a jouer dans une tache Control Win 10 ms
```

## Recette humaine — 2026-09-28

| Flux | Trames | Perte / invalide | p50 | p95 | p99 | Max | Verdict |
|---|---:|---:|---:|---:|---:|---:|---|
| Rapide 10 ms | 9 837 | 0 / 0 | 10,339 ms | 11,128 ms | **11,495 ms** | 12,490 ms | GO |
| Cyclique 50 ms | 1 967 | 0 / 0 | 51,904 ms | 53,323 ms | 53,964 ms | 55,680 ms | Conforme au flux lent |
| Événement | 3 | 0 / 0 | 3 308,061 ms | 3 360,846 ms | 3 360,846 ms | 3 360,846 ms | Intervalle entre trois impulsions, pas une latence réseau |

Conclusion : les flux cyclique et événementiel n ont pas dégradé le flux
rapide. Le transport UDP natif dans une tâche Control Win 10 ms satisfait le
seuil de conception T408 (p99 rapide <= 50 ms, aucune perte).

Reste avant clôture : confirmer `Enable := FALSE`, puis refaire un court essai
après redémarrage de l écho afin de vérifier que les sockets sont libérés et
réouverts sur les mêmes ports.

## Référence fonctionnelle validée

### Bibliothèques de la copie Control Win

| Bibliothèque System | Rôle dans T408 | État |
|---|---|---|
| `SysSocket` | création, envoi, réception et fermeture UDP | Validée à la compilation et en échange réel |
| `SysTypes2 Interfaces` | `RTS_IEC_HANDLE`, `RTS_INVALID_HANDLE`, `RTS_IEC_RESULT` | Validée à la compilation |
| `CmpErrors2 Interfaces` | non utilisée par la version finale ; peut rester installée | Sans effet sur le POC |

### Fichiers de référence

| Fichier | Fonction |
|---|---|
| `TOOLS/TWINBENCH/native_udp_poc/PRG_TwinBenchNativeUdpMulti_DECLARATION.st` | déclaration à remplacer intégralement dans le POU Control Win |
| `TOOLS/TWINBENCH/native_udp_poc/PRG_TwinBenchNativeUdpMulti_IMPLEMENTATION.st` | implémentation à remplacer intégralement dans le POU Control Win |
| `TOOLS/TWINBENCH/native_udp_poc/Start_T408_UdpEcho.ps1` | démarre l écho Python local en arrière-plan, 120 s |
| `TOOLS/TWINBENCH/native_udp_poc/udp_echo_t408.py` | écho et calcul des percentiles des trois flux |
| `TOOLS/AGENT_WORKFLOW/scripts/check_t408_native_udp_poc.py` | garde-fou statique : loopback, non-blocage, fermeture et absence de M3/production |

Empreintes SHA-256 de la version fonctionnelle : déclaration
`254D755A7B9532F199A0BE8460CEA5DA921F74B5E4FF38878D80D91956445B2A` ;
implémentation `838B5832E5C80C5DF4ACA60935DF0D21BE41DE57DE8CD558DD137E99CAD09EDC` ;
écho Python `90927E8F59777E790CAF8C5DF918C83657A0D714AA8244362D99A311F3E7BDC2` ;
lanceur PowerShell `98DF0661900974F8AA15ACE6699387C64FBEE420B85F4DAA6DCF291C1D87592F`.

Ces fichiers sont valides pour **la copie Control Win locale seulement**. Ils
ne doivent pas être importés dans le projet source ni dans le PLC réel.

## Installation dans la copie uniquement

1. Ouvrir `TwinBench_ControlWin.project` et verifier Control Win ONLINE.
2. Dans **Library Manager**, ajouter les bibliotheques System : **SysSocket**
   et **SysTypes2 Interfaces**. `CmpErrors2 Interfaces` peut rester installee,
   mais ce POC n en depend plus.
3. Ajouter le programme ST
   `TOOLS/TWINBENCH/native_udp_poc/PRG_TwinBenchNativeUdpMulti.st`.
4. Creer une nouvelle tache `TwinBenchUdpTask`, intervalle **10 ms**, et y
   attacher uniquement ce programme. Ne pas le placer dans le `MainTask`.
5. Telecharger vers **Control Win local** seulement apres compilation verte.
   **Recette compilation 2026-09-28 : PASS humain confirme.**
6. En Watch, mettre `Enable := TRUE`.
7. Lancer :

   ```powershell
   & 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\native_udp_poc\Start_T408_UdpEcho.ps1'
   ```

8. Attendre 120 s. Faire plusieurs impulsions `FALSE -> TRUE -> FALSE` sur
   `EventTrigger` durant la mesure.
9. Mettre `Enable := FALSE` avant Logout ; le POU ferme explicitement les
   trois sockets.

## Lecture des résultats

Le journal echo expose trois lignes : `RAPPORT rapide`, `cyclique`,
`evenement`.

| Verdict | Condition |
|---|---|
| GO de conception | rapide : 0 perte, p99 <= 50 ms ; les flux lent et événementiel ne dégradent pas ce résultat |
| NO-GO | p99 > 50 ms, max non expliqué, perte, erreur socket ou blocage de tâche |

Un GO T408 ne permet toujours **pas** d écrire dans M3. Il permet seulement de
cadrer un futur contrat d intégration M3 à cadence mesurée.
