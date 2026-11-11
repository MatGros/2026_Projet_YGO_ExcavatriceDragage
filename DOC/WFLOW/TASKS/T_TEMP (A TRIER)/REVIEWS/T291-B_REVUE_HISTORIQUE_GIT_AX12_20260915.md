# 🧬 Revue Git indépendante — T291-B / arrêt AX12 à 7,37 m

> Date : 2026-09-15 · Mode : lecture seule · Verdict : **RÉGRESSION IDENTIFIÉE (95 %)**

## Chronologie

| Commit | Effet | Verdict |
|---|---|---|
| `225cb085` | Ralentissement haut calculé par axe, plafond P1 | Mécanisme antérieur |
| `f36c4480` | Égalité finale stricte des demandes Both + neutralisation | Premier facteur de régression |
| `92601d2c` | AX12 passe de P4 à P5 | Rend possible le cas exact P1/P5 |
| `196abd5c` | Exception P4/P5 limitée à la descente AX4..AX7 | Hors cause |
| `9a6aa738`, `885ad4b1` | Modèle SimBench M2/Kobold | Révèle le défaut, ne modifie pas AX12 réel |

## Mécanisme

1. M1 entre seul dans la zone de ralentissement haute : P5 → P1 immédiat.
2. M2 corrigé reste hors zone : P5.
3. `WinchBothFinalRequestsCoherent=FALSE`.
4. Les demandes physiques M1/M2 sont neutralisées sans défaut ni message.
5. Après relâchement, les deux shapers repartent à P1 pendant environ 700 ms : les 13 cm restants
   peuvent être parcourus avant une nouvelle divergence.

## Couverture manquante

- Les tests `FB_Winch` couvrent le ralentissement d'un axe seul.
- G494 vérifie textuellement la présence de la barrière, pas un cap asymétrique légitime.
- Aucun test PRG04 ne couvre Both avec positions corrigées M1/M2 différentes.
- T270 n'a ajouté aucun test d'intégration autour du passage AX12 à P5.

## Conclusion

La mesure codeur n'a pas été altérée. La correction doit cibler l'autorité de ralentissement et
d'arrêt en Both, pilotée par M1 selon la décision utilisateur, tout en conservant les filets M2
corrigés indépendants.
