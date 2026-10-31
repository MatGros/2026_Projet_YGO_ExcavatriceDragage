# Suite de Test & Qualification IHM CODESYS (T423)

Dossier : `TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/`

---

## 🎯 Scripts Actifs (Clairs et Unifiés)

Seuls **2 scripts opérationnels** sont conservés à la racine du dossier :

| Fichier | Rôle | Quand l'exécuter dans CODESYS |
|---|---|---|
| **`T423_AUDIT_DYNAMIC_BENCH.py`** | **Banc d'épreuve dynamique complet** : qualification intégrale des 5 champs du bandeau (Modes, Progression, Bypass, Guidage opérateur) + carrousel d'alarmes, avec matrice statistique de fin. | **À chaque campagne de test / baseline** |
| **`T423_UTIL_rearm_emergency.py`** | **Utilitaire de secours / diagnostic** : réarmement manuel forcé AU + contacteur en boucle fermée si besoin. | Ponctuellement si automate bloqué |
| `T423_engine.py` | Moteur commun (primitives `safe_read`, `safe_write`, `read_banner`). | *Module interne (non exécutable seul)* |

---

## 🗄️ Archives (`_archive/`)
Les scripts intermédiaires du POC (TC00, TC01, TC02 et premier audit passif) ont été déplacés dans [`_archive/`](./_archive/) afin de ne pas encombrer le menu CODESYS.
