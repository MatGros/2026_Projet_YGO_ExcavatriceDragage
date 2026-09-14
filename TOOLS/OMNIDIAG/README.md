# 🧭 OMNIDIAG — Moteur d'Extraction & Explorateur Interactif des Diagnostics

> **Périmètre** : Excavatrice de dragage en carrière noyée — CODESYS 3.5.  
> **Rôle** : Extraction déterministe et automatisée de toutes les alarmes, messages opérateur, causes de blocage et vérifications à partir du code source ST, couplée à un moteur d'enrichissement de maintenance et un visualiseur interactif Web / Excel.

---

## 🎯 Fonctionnalités

1. 🔍 **Parser Automatique Déterministe (`parser.py`)** :
   - Extrait directement depuis les fichiers sources `CODE/` :
     - Les 71 alarmes bloquantes et 34 alarmes historisées du carrousel (`FB_Hmi_BannerFormatter.st`)
     - Les 52 actions opérateur et interlocks de mouvement refusé (`DirectionBlocked`)
     - Les 20 messages d'abandon de séquence de réarmement AU (`LastAbortCause`)
     - Les 6 conditions spéciales, dérogations et bridages
     - Les 20 consignes pas-à-pas de Homing Machine (`FB_CycleMachineHoming.st`)
     - Les 27 messages de sécurité et d'urgence (`FB_Safety_EmergencyManagement.st`)
     - Les 13 contrôles de prévol machine arrêtée (`FB_Acquisition_Preflight.st`)
     - Les 16 causes hiérarchisées de blocage terrain (`E_WinchTraceBlockReason`, `E_TranslationTraceBlockReason`)
     - Les 23 causes nommées des socles de défauts transverses (`FB_FaultCore` : benne, synchro, translation, cycle)
2. 🧠 **Moteur d'Enrichissement Expert (`enricher.py`)** :
   - Associe à chaque élément :
     - La **cause racine physique** détaillée
     - L'**action immédiate en cabine** pour le conducteur
     - L'**action technique de maintenance** (armoire électrique, mécanique, hydraulique)
     - Les **points de test matériels** (modules, borniers, capteurs)
     - Le niveau de gravité normatif
     - Des **mots-clés de recherche**
   - Supporte la surcharge / l'extension via `knowledge_base.json` (remplissable par un expert ou un LLM).
3. 📊 **Export Excel Multi-Onglets (`generator_excel.py`)** :
   - Classeur Excel professionnel (`omnidiag_alarms_and_messages.xlsx`) avec onglets thématiques :
     - `Toutes les Données` (synthèse générale avec auto-filtres)
     - `Alarmes Carrousel` (bloquantes et historisées)
     - `Guidage & Actions` (actions conducteur et conditions spéciales)
     - `Sécurité & AU` (chaîne AU, contacteurs, échecs d'armement)
     - `Homing & Preflight` (référencement et checklist)
     - `Trace & Socles Défauts` (causes de blocage et défauts FB)
4. 📄 **Export CSV Universel (`generator_excel.py`)** :
   - Fichier CSV encodé UTF-8 avec BOM (`omnidiag_alarms_and_messages.csv`), séparateur point-virgule pour une compatibilité immédiate avec Excel Windows en français.
5. 🌐 **Explorateur Interactif Web Hors-Ligne (`generator_html.py`)** :
   - Fichier HTML monopage autonome (`omnidiag_viewer.html`), 100% sans dépendance externe (zéro CDN, fonctionne en local sans connexion internet).
   - Recherche instantanée temps réel (mots-clés, codes défaut, organes, textes).
   - Filtres dynamiques par catégorie, organe et niveau de blocage.
   - Bascule double affichage : **Mode Fiches Dépannage** (avec bouton de copie pour rapport d'intervention) vs **Mode Tableau / Manuel**.
   - Volet d'assistance rapide de dépannage (arbres de décision réarmement AU, treuils bloqués, désynchronisme).

---

## 🚀 Utilisation Rapide

- **Lanceur rapide (double-clic)** : `TOOLS/OMNIDIAG/OMNIDIAG_START.bat` (ou avec `-r` pour forcer un re-scan complet).
- **Ligne de commande** :
```powershell
python TOOLS/OMNIDIAG/build_omnidiag.py
```

### Options CLI
```powershell
python TOOLS/OMNIDIAG/build_omnidiag.py --help
python TOOLS/OMNIDIAG/build_omnidiag.py --outdir "C:/MonDossierExport"
```

---

## 📁 Architecture des Fichiers

```text
TOOLS/OMNIDIAG/
├── build_omnidiag.py       # Point d'entrée principal (CLI)
├── parser.py               # Parser regex déterministe du code source ST
├── enricher.py             # Moteur de règles expertes et d'enrichissement
├── generator_excel.py      # Générateur Excel openpyxl et CSV
├── generator_html.py       # Générateur de l'application web interactive
├── knowledge_base.json     # Dictionnaire de surcharges / enrichissement IA optionnel
├── README.md               # Documentation de l'outil
└── EXPORTS/                # Dossier de sortie généré
    ├── omnidiag_alarms_and_messages.xlsx
    ├── omnidiag_alarms_and_messages.csv
    └── omnidiag_viewer.html
```

---

## 🤖 Extension de la Base de Connaissances (Humain ou IA / LLM)

Pour enrichir ou modifier une explication sans toucher au code python, ajouter simplement une entrée dans `knowledge_base.json` indexée par l'`id` (ex : `ALM_012`) ou par le texte exact du message :

```json
{
  "ALM_012": {
    "cause_racine": "Frein treuil M1 resté ouvert après rampe de décélération.",
    "action_conducteur": "Ne pas manœuvrer. Abaisser la benne au sol si possible.",
    "action_maintenance": "Vérifier la commande 24V du relais de frein et la garniture mécanique.",
    "points_test": "Bornier armoire X3:14, contacteur K_Brake_M1",
    "gravite_detail": "CRITIQUE (Sécurité positive)"
  }
}
```
Puis relancer `python TOOLS/OMNIDIAG/build_omnidiag.py`.
