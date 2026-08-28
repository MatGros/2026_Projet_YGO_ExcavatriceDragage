## ✅ Validation préalable de l'approche

La centralisation des cycles dans `PRG_03` et la spécialisation de `PRG_04` en muscle/sécurité est cohérente avec les principes d'encapsulation et de responsabilité unique du projet. Les propositions ci-dessous reflètent cette architecture sans perte d'information technique.

**Points de vigilance signalés (devoir d'alerte) :**
- Le flux `ReqProgram.ReqBucket` doit être documenté dans `AF_Partie-03` (contrat du DUT `ST_ModesCycleInterPrg`) pour garantir la traçabilité inter-documents.
- Les retours N-1 (ex: `Data.SequenceState`) doivent être explicitement nommés dans les sections concernées pour éviter toute ambiguïté.
- Vérifier que `PRG_04` n'a plus aucune référence à `FB_DiveSearch`/`FB_ExtractionSequence` dans son code (hors scope de cette mission, mais à confirmer par le lot T166).

---

## 📘 Bloc 1 — `AF_Partie-02_Architecture_Programme_v3.2.md`

### 1.1 Remplacer le tableau des responsabilités (§3) par :

| PRG | Responsabilités principales | Instances clés |
|-----|-----------------------------|----------------|
| `PRG_01_Init` | Initialisation générale, paramétrage, défauts initiaux | `FB_Init`, `FB_Config` |
| `PRG_02_IHM` | Interface opérateur, commandes manuelles, visualisation | `FB_IHM`, `FB_AlarmView` |
| `PRG_03_Modes_Cycle` | **Arbitrage des modes machine, séquencement semi-automatique, assistances de dragage** | `FB_Modes`, `FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionSequence` |
| `PRG_04_Treuils_Benne` | **Pilotage treuils M1/M2, synchronisation, commande benne, sécurités physiques** | `FB_WinchControl`, `FB_WinchSync`, `FB_Bucket`, `FB_Safety_Winch` |
| `PRG_05_...` | (inchangé) | ... |
| `PRG_06_...` | (inchangé) | ... |
| `PRG_07_...` | (inchangé) | ... |

### 1.2 Mettre à jour la section `PRG_03_Modes_Cycle` :

> **Rôle** : Centralise toutes les décisions de cycle et d'assistances. Instancie `FB_Modes`, `FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionSequence`. Publie ses demandes sur `Data : ST_ModesCycleInterPrg` (`Data.Auth`, `Data.ReqProgram.ReqBucket`, `Data.SequenceState`).
>
> **Flux vers PRG_04** : Les commandes de benne et de recherche Kobold sont transmises via `Data.ReqProgram.ReqBucket`. `PRG_04` arbitre et applique ces requêtes après validation de ses sécurités locales.

### 1.3 Mettre à jour la section `PRG_04_Treuils_Benne` :

> **Rôle** : Muscle et sécurité physique. Régule vitesses/paliers treuils M1/M2, synchronise via `FB_WinchSync`, commande la benne via `FB_Bucket`, applique les sécurités `FB_Safety_Winch` et barrières finales.
>
> **Réception des requêtes** : Reçoit les demandes de cycle via `PRG_03.Data.ReqProgram.ReqBucket`. N'instancie plus `FB_DiveSearch` ni `FB_ExtractionSequence` (déplacés dans `PRG_03`). Retourne l'état d'avancement via `Data.SequenceState` (retour N-1).

---

## 📗 Bloc 2 — `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`

### 2.1 Mettre à jour le rôle et périmètre (section introductive) :

> `FB_DiveSearch` et `FB_ExtractionSequence` sont des **briques de cycle transverses** rattachées opérationnellement à `PRG_03_Modes_Cycle`. Elles ne sont plus instanciées dans `PRG_04_Treuils_Benne`. Leur exécution est orchestrée par `FB_Cycle` (séquenceur maître X0..X13).

### 2.2 Ajouter un paragraphe sur la transmission des commandes :

> **Transmission vers PRG_04** : Les commandes issues des briques de cycle (ex: ouverture benne, descente Kobold) sont publiées sur le bus `Data.ReqProgram.ReqBucket` (type `ST_ModesCycleInterPrg`). `PRG_04` les reçoit, les arbitre avec ses sécurités locales, puis les applique sur les actionneurs. Les retours d'exécution (positions, défauts) remontent via `Data.SequenceState`.

---

## 📙 Bloc 3 — `AF_Partie-10_Fonction_Winch_v2.1.md`

### 3.1 Mettre à jour le rôle de `PRG_04` :

> `PRG_04_Treuils_Benne` est dédié au **pilotage physique des treuils et de la benne**. Il n'instancie plus `FB_DiveSearch` ni `FB_ExtractionSequence`. Il **arbitre et applique** les requêtes benne et Kobold reçues de `PRG_03.Data.ReqProgram.ReqBucket`, après validation des sécurités (`FB_Safety_Winch`, barrières finales).

### 3.2 Mettre à jour la table des composants (extrait) :

| Composant | Rôle | Instancié dans |
|-----------|------|----------------|
| `FB_WinchControl` | Régulation vitesses/paliers M1/M2 | `PRG_04` |
| `FB_WinchSync` | Synchronisation treuils | `PRG_04` |
| `FB_Bucket` | Commande benne | `PRG_04` |
| `FB_Safety_Winch` | Sécurités treuils | `PRG_04` |
| ~~`FB_DiveSearch`~~ | ~~Assistance plongée~~ | **Retiré** — déplacé dans `PRG_03` |
| ~~`FB_ExtractionSequence`~~ | ~~Séquence extraction~~ | **Retiré** — déplacé dans `PRG_03` |

> **Note** : Les requêtes reçues via `ReqProgram.ReqBucket` sont traitées en priorité après les sécurités locales. Tout conflit (ex: demande benne pendant défaut treuil) est résolu par `PRG_04` (sécurité prioritaire).

---

## 🔍 Vérifications finales

- **Cohérence inter-documents** : Les trois blocs utilisent les mêmes termes (`ReqProgram.ReqBucket`, `SequenceState`, `PRG_03_Modes_Cycle`). Aucune contradiction.
- **Conformité nommage** : Les noms de PRG et FB respectent `NAMING_CONVENTION.md` (pas de suffixe de langage, noms alignés fichiers).
- **Encapsulation** : `PRG_04` ne reçoit que des requêtes via le bus, pas d'accès direct aux internes de `PRG_03`.

**Hors scope constaté** : La vérification que le code de `PRG_04` ne référence plus `FB_DiveSearch`/`FB_ExtractionSequence` (lot T166) n'est pas couverte par cette mission documentaire. À confirmer par l'orchestrateur.