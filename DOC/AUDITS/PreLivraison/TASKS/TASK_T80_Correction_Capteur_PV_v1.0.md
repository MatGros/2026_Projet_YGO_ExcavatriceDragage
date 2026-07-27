# 🐛 FICHE DE TÂCHE — T80 : capteur PV translation M3 non relié

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🔴 **PRIORITÉ HAUTE**
> ⏱️ **À traiter AVANT le lot L4d** (le débranchement de la simulation démasquera ce bug).
> 📖 **Contexte projet et règles de travail : lire les §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**
> (contexte machine, lectures obligatoires, devoir d'alerte — ils s'appliquent intégralement ici).

---

## 1. 🔍 Le défaut (prouvé, pas déduit)

La translation M3 est repérée par **5 capteurs en codage croisé monotone** :
`11111` Trémie · `01111` PV · `00111` P2 · `00011` P1 · `00001` · `00000` Maintenance.
Toute autre combinaison ⇒ `Incoherent` ⇒ `SafeStop` + `PowerCutOff`.

**Le capteur PV (bit3) n'est relié à rien :**

| Côté | Constat |
|---|---|
| Matériel | La voie existe et est mappée sous **`PosPV_DI_`** — *avec un underscore final* (`Device.export`, description « Capteur d'info position chariot », Bit1) |
| Code | `PRG_00_Inputs.st:267` lit **`GVL_Translation_M3_Stub.PosPV_DI`** — *sans* underscore : un `VAR_GLOBAL` de stub que **rien n'écrit jamais** |
| Preuve | `PosPV_DI_` (underscore final) : **0 occurrence** dans tout `CODE/` |

**Origine** : lors du mapping, le nom `PosPV_DI` était déjà pris par la déclaration du stub →
CODESYS a **suffixé silencieusement** en `PosPV_DI_` pour éviter la collision. Le mapping *semble*
fait dans l'éditeur, mais ne relie rien.

### 💥 Conséquence en mode réel

`TranslationPosPV = FALSE` en permanence ⇒ en position **Trémie**, le mot vaut `10111` au lieu de
`11111` ⇒ **incohérent** ⇒ `FB_Safety_Translation` bit7 ⇒ **`SafeStop` + `PowerCutOff`**.
De plus `LimitSwitchFwd/Rev := FALSE` ⇒ **les butées extrêmes M3 ne fonctionnent plus**, et le
ralentissement PV avant Trémie ne se déclenche jamais.

👉 Jusqu'ici, la simulation (`FB_Sim_Translation`) fournissait un PV cohérent et **masquait
entièrement ce bug**.

---

## 2. 🎯 Travail à réaliser

### 👤 Côté CODESYS — fait par l'utilisateur, pas par toi

1. Supprimer la déclaration `PosPV_DI : BOOL;` de `CODE/TRANSLATION/GVL_Translation_M3_Stub.st`
2. Renommer la voie physique `PosPV_DI_` → **`M3_PosPV_DI`**
3. **Vérifier le nom obtenu** — aucun underscore parasite (c'est le piège d'origine)

### 🤖 Côté code — ton travail

| Fichier | Action |
|---|---|
| `CODE/TRANSLATION/GVL_Translation_M3_Stub.st` | Supprimer **la seule ligne** `PosPV_DI : BOOL;` |
| `CODE/MAIN/PRG_00_Inputs.st` (~l. 267) | `GVL_Translation_M3_Stub.PosPV_DI` → **`M3_PosPV_DI`** (variable d'E/S globale) |

### ⛔ Interdictions

- ❌ **Ne supprime PAS** `GVL_Translation_M3_Stub` en entier : `StubTranslationPositionSelect_IHM`
  y est déclaré et **est consommé** (`PRG_00`, `PRG_09`)
- ❌ Ne touche à aucun autre capteur M3, ni à `FB_Translation_PositionDecoder`, ni à
  `FB_Safety_Translation`
- ❌ Ne modifie pas la logique de décodage : elle est correcte, c'est la **source** qui est fausse
- ❌ Aucun commit

---

## 3. 🛑 Pièges

| # | Piège |
|---|---|
| P1 | Le nom `M3_PosPV_DI` doit exister côté device **avant** que le code y fasse référence, sinon la compilation échoue chez l'utilisateur. Signale-le dans ta note d'application |
| P2 | `PRG_00:267` contient un `SEL(...)` avec la branche simulée `instSimTranslation.PosPV` — **conserve-la telle quelle**, elle sera retirée au lot L4d, pas ici |
| P3 | Les 4 autres capteurs (`PosTremie_DI`, `PosFosse1_DI`, `PosFosse2_DI`, `PosMaintenance_DI`) ne sont **pas** concernés par cette fiche |

---

## 4. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_T80_v1.0.md` :

- tableau **fichier · ligne · avant → après**
- confirmation : `0` occurrence de `GVL_Translation_M3_Stub.PosPV_DI` dans `CODE/` (donne la commande)
- confirmation : `StubTranslationPositionSelect_IHM` **toujours présent et consommé**
- note d'application CODESYS, avec l'ordre : *device d'abord, code ensuite*
- tes alertes éventuelles

### ✅ Critères de sortie

- [ ] `PosPV_DI` supprimé du stub, `StubTranslationPositionSelect_IHM` intact
- [ ] `PRG_00:267` lit `M3_PosPV_DI`
- [ ] Le `SEL` et la branche simulée sont conservés
- [ ] Aucun autre fichier modifié

### 🧪 Test à faire par l'utilisateur après application

Mettre M3 en position **Trémie** : le mot des 5 capteurs doit valoir `11111`,
`SensorWordIncoherent = FALSE`, aucun `SafeStop`/`PowerCutOff`.
Puis vérifier que le passage en zone **PV** déclenche bien le ralentissement avant Trémie.
