# Excavatrice de Dragage — Automate CODESYS 3.5

**Système de dragage en carrière noyée** — Pilotage d'un godet sous-marin avec 2 treuils, translation et sécurité intégrée.

---

## 📚 **Documentation Projet — À LIRE EN PRIORITÉ**

Tous les documents sont dans le dossier **`DOC/`** :

### 1️⃣ **[Convention de Nommage](DOC/NAMING_CONVENTION.md)** 
🔑 **ESSENTIEL** avant de coder.  
- PascalCase partout, **pas de hongrois** (`bFlag` ❌ → `Enable` ✅)
- Préfixes structurels : `ST_`, `E_`, `FB_`
- Booléens : entrée = verbe (`Start`), sortie = état (`Ready`)
- Exemples complets pour structures et instances

### 2️⃣ **[Analyse Fonctionnelle — Partie 1](DOC/AF_Partie1_Analyse_Fonctionnelle.md)**
Le projet en bref : équipements pilotés, fonctions principales, interactions.

### 3️⃣ **[Analyse Fonctionnelle — Partie 2](DOC/AF_Partie2_Architecture_Programme_v2.1.md)**
Architecture détaillée : cadencement des tâches (EtherCAT/CAN/Main), arborescence CODESYS complète, flux de données.

### 4️⃣ **[Analyse Fonctionnelle — Partie 3](DOC/AF_Partie3_Template_FB_Commun.md)**
Contrat standard que **tout FB respecte** :
- Interface VAR_INPUT/OUTPUT unifiée
- Machine d'état `E_State`
- Gestion `ErrorId` (bitfield)
- Logique Reset (front obligatoire, cause doit disparaître)
- Arrêt d'urgence & SafeStop

---

## 🏗️ **Structure du Projet**

```
excavatrice-dragage/
├── DOC/                      # 📖 Documentation (ICI COMMENCE)
│   ├── NAMING_CONVENTION.md
│   ├── AF_Partie1_Analyse_Fonctionnelle.md
│   ├── AF_Partie2_Architecture_Programme_v2.1.md
│   └── AF_Partie3_Template_FB_Commun.md
│
├── CODE/                     # 🔧 Code source XML CODESYS
│   └── FB_Filter_PT1__*.xml
│
├── PRJ/                      # 📦 Projet CODESYS
│   └── Device.export         (source de vérité)
│
├── tools/                    # 🛠️ Utilitaires
│   ├── extract.py           (extrait POUs → XML)
│   ├── inject.py            (réinjecte POUs modifiés)
│   ├── codesys_common.py    (fonctions partagées)
│   └── README.md            (mode d'emploi)
│
├── extraction/              # 📄 Sortie extract.py (1 POU = 1 XML)
├── import/                  # ✏️ POUs à réinjecter (avant inject.py)
│
└── README.md               # 👈 Vous êtes ici
```

---

## 🔄 **Workflow Édition**

Pour modifier du code en dehors de CODESYS :

```bash
# 1. Exporter depuis CODESYS → PRJ/Device.export

# 2. Extraire tous les POUs
python tools/extract.py --clean

# 3. Copier le(s) POU à modifier
#    extraction/ → import/ et éditer dans VS Code

# 4. Réinjecter les changements
python tools/inject.py

# 5. Réimporter Device.export dans CODESYS
```

**Garanties :** GUID unique, round-trip exact, backup automatique.  
👉 Voir [tools/README.md](tools/README.md) pour les options complètes.

---

## ⚡ **Points Clés à Retenir**

| Concept | Important |
|---------|-----------|
| **Nommage** | Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md) d'abord — aucun hongrois, PascalCase strict |
| **Tâches** | 3 niveaux : EtherCAT (haute) → CAN (10ms) → Main (20ms) |
| **FB Standard** | Tous les FB respectent le contrat [Partie 3](DOC/AF_Partie3_Template_FB_Commun.md) |
| **Sécurité** | SafeStop prioritaire, Reset = front obligatoire, AU physique indépendant |
| **Cycle** | Semi-auto : descente → synchro → remontée → vidage → retour |

---

## 🚀 **Commencer**

1. **Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [AF_Partie1](DOC/AF_Partie1_Analyse_Fonctionnelle.md) pour le contexte métier
3. Étudier [AF_Partie2](DOC/AF_Partie2_Architecture_Programme_v2.1.md) pour l'architecture
4. Comprendre [AF_Partie3](DOC/AF_Partie3_Template_FB_Commun.md) avant de coder un FB

---

## 📖 **Références**

- **Git** : `main` branch (clean)
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-06-30
