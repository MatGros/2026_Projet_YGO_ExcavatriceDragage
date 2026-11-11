# 🧪 GUIDE DE TEST RAPIDE — 22/09/2026
## 🎯 Objectif : valider la benne (2 défauts) en 15 minutes

> 📦 **À IMPORTER : `CODE_XML/CODE_Bundle.xml` (bundle COMPLET — certitude que tout est dedans)**
> *(le diff bundle rapide est aussi à jour : `CODE_XML/CODE_DiffBundle.xml`)*

---

## ⏱️ 0 — AVANT DE COMMENCER (2 min)

| ✅ | À vérifier | Où | Attendu |
|---|---|---|---|
| ☐ | Import CODESYS **compilé sans erreur** | CODESYS | 0 erreur |
| ☐ | Mode | bandeau | **MAINT_N2** (pour le homing) |
| ☐ | **M1 ET M2 NON référencés** *(c'est le cas du test !)* | `MachineHomingStep` → **HX0** | HX0 |
| ☐ | Sélecteur treuil | **`WinchSel = 2`** (M2 seul) | 2 |
| ☐ | Bornes benne | `M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits = 1` | 1 |

---

## 🎯 TEST 1 — La benne n'est PLUS bridée sans référencement (le principal)

```text
1. M1/M2 NON referencés (HX0), WinchSel = 2, TglManualBucketLimits = 1
2. Bouger la benne au joystick (tirer / pousser)
```
| Ce que tu dois voir | ✅/❌ |
|---|---|
| La benne **bouge librement** (plus de blocage immédiat) | ☐ |
| Le bandeau affiche : **`[BENNE] Referencement en cours - codeurs non references (normal)`** | ☐ |
| ❌ **Plus** de `[BENNE] ErrorID:05` sec pendant que tu références | ☐ |

## 🎯 TEST 2 — Les bornes REVIENNENT quand c'est référencé (non-régression)

```text
3. Referencer M1 puis M2 (homing normal)
4. Reprendre le jog benne
```
| Ce que tu dois voir | ✅/❌ |
|---|---|
| Les **bornes relatives sont de nouveau actives** (la benne s'arrête en butée haute/basse normale) | ☐ |
| Le message **standard** revient si un vrai défaut benne apparaît | ☐ |

## 🎯 TEST 3 — La benne SE FERME au FDC haut (ton défaut n°1)

```text
5. Amener le cycle a la position haute (FdC haut atteint, M1 et M2 en haut)
6. Commander la FERMETURE de la benne (WinchSel = 0 pour le couplage, puis geste de fermeture)
```
| Ce que tu dois voir | ✅/❌ |
|---|---|
| La fermeture **s'engage** (elle était impossible avant) | ☐ |
| Le message IHM dit **quoi faire** si elle ne s'engage pas | ☐ |
| ❌ Pas de `[BENNE] ErrorID:03` (timeout d'ouverture/fermeture) | ☐ |

## 🎯 TEST 4 — (bonus, 2 min) Profil de plongée auto

```text
7. Lancer une plongee auto
```
| Attendu | ✅/❌ |
|---|---|
| **M1 palier 4 / M2 palier 5** (profil asymétrique activé par défaut) | ☐ |

---

## 📝 RELEVÉ (remplis en marchant)

| Test | Résultat | Message affiché | Remarque |
|---|---|---|---|
| 1 — benne libre | ☐ OK ☐ KO | | |
| 2 — bornes de retour | ☐ OK ☐ KO | | |
| 3 — fermeture au FdC haut | ☐ OK ☐ KO | | |
| 4 — plongée M1=4 / M2=5 | ☐ OK ☐ KO | | |

## 🧰 SI ÇA BLOQUE

1. 🧊 **NE FAIS PAS DE RESET** avant d'avoir relevé (un Reset efface la preuve).
2. 📸 **Snapshot** pendant / juste après le blocage.
3. 📨 Envoie-moi le CSV → je dépouille et je te dis quel verrou a tenu.

## 🔎 Les 4 variables à regarder si besoin

| Variable | Ce qu'elle dit |
|---|---|
| `K_BenneOuvertureFermeture.Idx114_MachineHomingStep` | l'étape du homing (HX0 = non référencé) |
| `G_CycleSemiAuto.Idx206_Step` | l'étape du cycle |
| `G_CycleSemiAuto.Idx205_ErrorId` / `Idx217_FaultLatched` | défaut actif / latché |
| `M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits` | la bascule des bornes (1 = bornes actives SI référencé) |

---

> ✅ **C'est validé** quand : **Test 1 OK** (benne libre sans datum) **ET Test 2 OK** (bornes de retour une fois référencé) **ET Test 3 OK** (fermeture au FdC haut).
> ❌ Si **Test 1 KO** → le dé-bridage n'est pas effectif. Si **Test 2 KO** → on a enlevé trop (danger). Si **Test 3 KO** → le défaut « fenêtre benne » n'est pas résolu.
