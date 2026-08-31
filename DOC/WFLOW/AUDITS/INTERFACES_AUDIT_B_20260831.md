# 🔬 CONTRE-AUDIT INDÉPENDANT — Interfaces globales (homogénéité + optimisation)

> **Fichier** : `DOC/WFLOW/AUDITS/INTERFACES_AUDIT_B_20260831.md`
> **Date** : 2026-08-31 · **Auteur** : contre-audit B indépendant (FB d'arbitrage, DUT, PRG)
> **Référentiels lus** : `DOC/STDS/NAMING_CONVENTION.md`, `DOC/STDS/CODE_QUALITY_STANDARDS.md`,
> `DOC/STDS/AUDIT_STRUCTS_MAPPING_20260827.md`, FB d'arbitrage (Winch M1/M2, Bucket, Translation M3),
> `FB_Winch`, `FB_Translation`, `FB_FaultCore`, `FB_WinchOutputInterlock`, DUT `ST_fbWinch_*`,
> `ST_Status/ST_Fault/ST_FaultCause`, `PRG_04`, `PRG_05`, `GVL_PERSISTENT`, structs d'échange.
> **Périmètre** : interfaces (`VAR_INPUT`/`VAR_OUTPUT`/`VAR_IN_OUT`), DUT, struct IHM. Aucun code modifié.

---

## 1. Différences avec l'audit initial ("audit A")

> ⚠️ **Aucun fichier `INTERFACES_AUDIT_A_*.md` n'existe au moment du contre-audit** (grep
> `INTERFACES_AUDIT` = 0 sur le dépôt). La comparaison directe avec l'audit A est donc **impossible**.
> Ce rapport se positionne donc :
> - en **référent de fait** : `AUDIT_STRUCTS_MAPPING_20260827.md` (inventaire statique des 103 structs /
>   9 enums / 57 FB) — que B **confirme** sur l'exhaustivité des types, et **complète** sur le plan
>   *comportemental* (ce qu'un inventaire statique de types ne peut pas voir) ;
> - en référence normative sur le *pattern* : `NAMING_CONVENTION.md` (NC-010…NC-110) et
>   `AUDIT_ConfigPersistence_v1.2.md` (G380).

**Ce que B apporte au-delà d'un inventaire de types (angles morts structurels d'un mapping statique) :**

| Dimension | `AUDIT_STRUCTS_MAPPING` (statique) | Contre-audit B (comportemental) |
|---|---|---|
| Paramètres FB **morts** (déclarés, jamais lus) | Ne peut pas les détecter | Détecté : `SpeedStepTable` (arbitrages), champs vestiges de `ST_fbWinch_*` |
| **Défaut de polarité** d'une entrée safety (`:= TRUE`) | Invisible | Vérifié : `DescendPermit`/`AscentPermit` (voir §4) |
| **Hétérogénéité de pattern** FB de mouvement (struct Cfg vs champs plats) | Invisible | Documenté FB_Winch vs FB_Translation (§2, §5) |
| **Cohérence fichier ↔ type** | Non contrôlé | Détecté : `ST_OperatorCoupledIntent.st` ↔ `ST_WinchBothIntent` (§2) |
| **Encoding UTF-8** des commentaires d'interface | Non contrôlé | Détecté : mojibake sur 3 DUT treuils (§3) |

---

## 2. Réflexion critique — interfaces qui semblent OK mais cachent un problème

### 🟠 2.1 `SpeedStepTable` = entrée morte sur `FB_WinchCmdArbitrationM1/M2`
Confirmé par grep : le seul usage de `SpeedStepTable` dans ces 2 FB est sa **déclaration** `VAR_INPUT`
(L28 / L29, commenté *« conservée pour compat interface »*). Jamais référencé dans le corps.
→ La conversion %→palier a été déplacée au joystick (T190-B). Maintenir une entrée morte :
**bruit d'interface** + **risque de fausse garantie** (un lecteur croit que l'arbitrage dépend de la table).
**Recommandation** : retirer `SpeedStepTable` des 2 arbitrages (vérifier G120 / liaison avant).

### 🟠 2.2 `FB_WinchCmdArbitrationM1` vs `M2` — quasi-duplication
M1 et M2 partagent ~70 % du corps (bloc manuel boutons/joystick/both identique, gating StartStop
différent uniquement par symétrie synchro + chemin benne M2). Duplication assumée mais **à haut coût
de maintenance** : le jour où le gating StartStop évolue, le risque de divergence silencieuse M1/M2 est réel.
**Recommandation (optimisation, pas urgente)** : soit fusionner en un FB unique paramétré (repère en
`Cfg`, synchro inversée en flag), soit au minimum extraire le **bloc manuel commun** dans un sous-FB
unique consommé par les deux — et documenter explicitement la liste des asymétries dans chaque en-tête.

### 🟠 2.3 Structure file ↔ type incohérente : `ST_WinchBothIntent`
Fichier `…/3_CYCLE_ET_MODES/ST_OperatorCoupledIntent.st` **déclare** `TYPE ST_WinchBothIntent`.
Le nom de fichier ne correspond pas au nom de type (NC-090 « 1 notion = 1 nom », et le mapping
fichier↔type). En navigation CODESYS, on voit `ST_OperatorCoupledIntent` (nom fichier) qui n'existe
**pas** comme type — confusion. **Recommandation** : renommer le fichier `ST_WinchBothIntent.st`
(si le type `ST_OperatorCoupledIntent` n'existe pas par ailleurs — à confirmer pour éviter un renommage
à tort).

### 🟡 2.4 Sorties d'arbitrage benne `CmdOpen_IHM` / `CmdClose_IHM`
Sur `FB_BucketCmdArbitration`, les sorties arbitrées s'appellent `CmdOpen_IHM`/`CmdClose_IHM`. Le
suffixe `_IHM` est ici **trompeur** : ce sont des **commandes effectives** (sortie `[CMD]`), pas des
entrées IHM. La convention NC-090 n'autorise pas un même suffixe pour deux sens de flux (`_IHM`
= entrée bouton ailleurs, sortie commande ici).
**Recommandation** : `CmdOpen` / `CmdClose` (cibles de l'IHM), ou au minimum documenter que `_IHM`
= « commande issue de la section IHM/manuel ». À harmoniser avec `KoboldContactorCmdArbitrated`.

---

## 3. Ergonomie de lecture — chemins de données & lisibilité

### ✅ Les PRG sont bien structurés
`PRG_04` organise le flux en **12 `{region}`** (§1 Intention… → §8 Publication états) — lisible,
les commentaires de section sont en place. `PRG_05` pareil (`{region "§0 Décodage position M3"}`…).
C'est un point fort à créditer.

### 🟠 3.1 Mojibake UTF-8 sur les DUT d'interface des treuils
3 fichiers portent des commentaires **corrompus** (accents/émojis remplacés, ex. `dÃ©codage %â†’palier`) :
- `_TYPES/ST_fbWinch_Cfg.st`
- `_TYPES/ST_fbWinch_DriveRequest.st`
- `_TYPES/ST_fbWinch_Sensors.st`

→ Ces 3 fichiers sont précisément les **contrats d'interface de FB_Winch** : leur lisibilité compte
beaucoup. Corriger par ré-encodage UTF-8 (grep `ðŸ|â€|Ã©` pour localiser).

### 🟠 3.2 Interface `FB_Translation` = trop de champs plats au call-site
`FB_Translation` prend ~13 paramètres `[CFG]` plats (`CfgRampAccelRate`, `CfgRampDecelNormalRate`,
`CfgRampDecelFastRate`, `ApproachSpeedTremieHz`, `ApproachSpeedMaintenanceHz`, `ApproachSpeedP1Hz`,
`DriveFreqScaleMaxHz`, `CaptorDebounce`, `BrakeDelay*`…). `PRG_05` les **ré-assigne un par un** :
- rampes ← `GVL_PERSISTENT._TranslationRampAccelRate_Pct` (flat) ;
- vitesses d'approche ← `GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedTremie_Hz` (via `ST_TranslationCfg`).

→ **Double sourcing de config** dans le même FB : partie flat RETAIN + partie struct pontée.
C'est le contraire du pattern `Cfg : ST_fb<Fb>_Cfg` + pont (NC-110 / G380) appliqué à FB_Winch
(`Config : ST_fbWinch_Cfg`). Hétérogène et difficile à auditer.
**Recommandation** : regrouper les réglages de translation dans `ST_fbTranslation_Cfg`
(`Cfg` struct + pont persistant), ou au minimum uniformiser la source.

---

## 4. Impact safety — interfaces qui peuvent masquer un défaut

### 🟠 4.1 Défaut par défaut `:= TRUE` sur `DescendPermit` / `AscentPermit` (FB_Winch)
```st
DescendPermit : BOOL := TRUE;   // permis de descente
AscentPermit  : BOOL := TRUE;   // permis de montée
```
Ces entrées de **famille sécurité** (autorisation de mouvement) sont initialisées à **autoriser**.
La règle fail-safe (NC-100 / §Polarité) veut « rupture de liaison → `FALSE` = bloqué ». Or un
FB dont le câblage est oublié **resterait autorisé**. **Mesuré** : en production, PRG_04 câble
toujours `EffectivePermitM1/M2_*` (marge réduite). Mais c'est **incohérent** avec la philosophie et
dangereux au refactor (une nouvelle instance non câblée autoriserait le mouvement).
**Recommandation** : passer à `:= FALSE` (fail-safe par défaut), ou forcer l'appel PRG en nommé pour
contraindre le câblage. Ne se corriger qu'en lot dédié (impact liaison).

### 🟡 4.2 Forme d'état legacy sur `FB_WinchOutputInterlock`
La barrière finale expose `Error/ErrorId/State/StateAtError/Reason` (**shape legacy**) au lieu du
socle standard `Fault : ST_Fault` (forme cible §2quinquies). Toléré (« 17 FB legacy ») mais
**hétérogène** avec FB_Winch/FB_Translation (`Fault : ST_Fault`). Sans urgence safety, mais à
basculer au prochain refactor d'interface pour homogénéiser le contrat de défaut.

### 🟢 4.3 Positif — le modèle `ST_Fault` + `FB_FaultCore` est sain
`ST_Fault` (vue live + latché) réutilisé par FB_Winch et FB_Translation, `FB_FaultCore` unique,
interlock **toujours sur la cause brute** (`Causes[i].Active`), Reset sur front non conditionné,
défaut laté persisté même `Enable=FALSE`. C'est un excellent socle d'interface : à généraliser et à
créditer.

---

## 5. Optimisations concrètes proposées (regroupement / renommage / structuration)

| # | Optimisation | Impact | Effort |
|---|---|---|---|
| O1 | **Retirer `SpeedStepTable`** des `FB_WinchCmdArbitrationM1/M2` (entrée morte) | Lisibilité + honnêteté d'interface | Faible |
| O2 | **Renommer `CmdOpen_IHM`/`CmdClose_IHM`** → `CmdOpen`/`CmdClose` (sortie commande, pas entrée IHM) | Clarté sémantique (NC-090) | Faible |
| O3 | **Regrouper la config translation** en `ST_fbTranslation_Cfg` (struct Cfg + pont), uniformiser la source (flat RETAIN + struct) | Homogénéité pattern (NC-110/G380) + auditabilité RETAIN | Moyen |
| O4 | **Extraction du bloc manuel commun** M1/M2 de l'arbitrage treuils (sous-FB unique) | Anti-divergence silencieuse | Moyen |
| O5 | **Corriger l'encodage UTF-8** des 3 DUT treuils | Lisibilité des contrats | Trivial |
| O6 | **Renommer le fichier** `ST_OperatorCoupledIntent.st` → `ST_WinchBothIntent.st` | Cohérence fichier ↔ type | Trivial |
| O7 | **Passer les permis `:= FALSE`** sur FB_Winch (fail-safe au défaut) | Sécurité interface au refactor | Faible (lot dédié) |
| O8 | Bascule `FB_WinchOutputInterlock` vers `Fault : ST_Fault` (avec le lot legacy) | Homogénéité du contrat défaut | Moyen |

> ⚠️ Toutes les optimisations O1–O8 touchent des interfaces consommées : **jamais au fil de l'eau**.
> Chacune exige son **lot dédié** (remappage des consommateurs + vérif `G200_check_linkage.py` +
> bundle `generate_codesys_bundle.py`), conformément à la règle « aucun renommage sans lot dédié ».

---

## 6. Verdict par axe

| Axe | Verdict | Appréciation |
|---|---|---|
| **Réflexion critique** | ✅ Bien, 3 points à corriger | Les interfaces sont globalement saines ; les pièges (entrée morte, suffixe `_IHM` trompeur, fichier↔type) sont localisés |
| **Ergonomie de lecture** | ✅ Bon (PRG bien structurés) | Points : config translation éclatée + mojibake sur les 3 DUT treuils |
| **Impact safety** | 🟠 1 point à traiter | `DescendPermit/AscentPermit := TRUE` par défaut = incohérent avec le fail-safe. Pas d'effet en prod câblée, à corriger en lot |
| **Optimisations** | 🟢 8 actions concrètes | Faible/moyen effort, net gain d'homogénéité et d'auditabilité |

**Verdict global** : les **interfaces sont de bonne qualité** — le socle défaut (`ST_Fault`/`FB_FaultCore`),
l'architecture struct par FB propriétaire (NC-110) et la structuration des PRG sont des points forts.
Les défauts relevés sont **localisés et non bloquants en production**, mais **à corriger en lots
dédiés** avant tout nouveau refactor d'interface (notamment le point safety 4.1).

---

## 7. 🎯 Actions prioritaires

1. **🛡️ [Safety] Passer `DescendPermit`/`AscentPermit` à `FALSE` par défaut sur `FB_Winch`** (ou
   contraindre le câblage nommé en PRG_04) — seule action à impact safety réel, en lot dédié avec
   vérification liaison. *(4.1 / O7)*
2. **🧹 [Faible, mécanique] Retirer `SpeedStepTable`** entrée morte des `FB_WinchCmdArbitrationM1/M2` *(O1)*.
3. **📐 [Homogénéité] Regrouper la config de `FB_Translation`** en `ST_fbTranslation_Cfg` + pont
   (uniformiser la source RETAIN) pour aligner sur le pattern FB_Winch *(O3)*.
4. **🔍 [Trivial] Corriger l'encodage UTF-8** des 3 DUT treuils + renommer
   `ST_OperatorCoupledIntent.st` → `ST_WinchBothIntent.st` *(O5/O6)*.
5. **🧩 [Maintenance] Extraire le bloc manuel commun M1/M2** de l'arbitrage treuils pour prévenir
   les divergences silencieuses *(O4)*.
6. **✍️ [Sémantique] Renommer `CmdOpen_IHM`/`CmdClose_IHM`** → `CmdOpen`/`CmdClose` *(O2)*.

> ⚠️ **Règle de lot** : aucune de ces actions ne remap des consommateurs au fil de l'eau. Chaque
> action = lot dédié avec `G200_check_linkage.py` vert + bundle frais avant restitution
> (auto-vérification obligatoire `AGENTS.md`).

---

*Fin du contre-audit B — interfaces (contre-audit indépendant).*
