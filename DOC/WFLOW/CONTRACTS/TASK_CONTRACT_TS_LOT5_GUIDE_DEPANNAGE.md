# TS_LOT5 — Guide de dépannage dans CODESYS (T428 J5)

> Contrat machine : [TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.yaml](TASK_CONTRACT_TS_LOT5_GUIDE_DEPANNAGE.yaml). Ce fichier en est la lecture humaine.

## 🎯 Objectif
Ouvrir `FB_TroubleshootingGuide` dans CODESYS et savoir, pour un symptôme, quelles variables du snapshot lire, dans quel ordre, quelle valeur est saine et où aller ensuite. Aucun effet machine.

## 🧱 Forme retenue
| Point | Choix | Raison |
|---|---|---|
| Objet | FB `light` dédié, instancié et appelé par `PRG_07` | Choix de l'exploitant ; un objet isolé serait orphelin pour G200 |
| FB et non FC | FB | Le convertisseur PLCopenXML ne génère pas de FUNCTION |
| Contenu | Commentaires `//` dans le corps, puis `Ready := Enable;` | Lisible dans l'IDE ; aucun commentaire bloc imbriqué |
| Garde-fou | Gate G531 | Chemins vivants, sections et 10 étapes, texte sans date ni REX |

## ✅ Critères
| AC | Vérification |
|---|---|
| AC1 FB light, appelé par PRG_07 | Diff, G200, bundle |
| AC2 Sommaire, général, 3 axes en 10 étapes, fonctions, cas | G531 |
| AC3 Chemins cités dans le code et la liste du snapshot | G531, mutation détectée |
| AC4 Valeurs saines et renvois vérifiés à la source | Rédacteurs DeepSeek, challengers, juge natif |
| AC5 Texte de fonctionnement, `//` seulement | G531, revue |
| AC6 Rejeu publié, seuils proposés 9/15 et 12/15 | Note d'étude |
| AC7 Import et compilation CODESYS | Exploitant |
| AC8 Nom de fichier identique au nom de POU, suffixe ST | Bundle, G200 |

## 🧪 Agents
| Rôle | Agents |
|---|---|
| Rédaction | 5 DeepSeek : général, M1, M2, M3, fonctions |
| Challenge | 1er tour mal cadré (140 points, surtout faux), 2e tour à citation obligatoire (32 points), panel 4 experts : automaticien, mainteneur, sécurité machine, conducteur |
| Jugement | Juge natif Claude, vérification à la source |

## 🛑 Points d'arrêt
Import et compilation par l'exploitant ; snapshot en simulation en fin de chantier (438/438 attendu).
