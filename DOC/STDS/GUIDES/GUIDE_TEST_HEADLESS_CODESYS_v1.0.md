# 🤖 Guide d'Automatisation & Qualification Headless CODESYS 3.5

> 📌 **Référentiel technique d'ingénierie pour agents et développeurs**.
> Décrit la méthodologie exacte pour exécuter des tests d'automatisation, des qualifications dynamiques ou des simulations en arrière-plan (**mode headless sans interface graphique**) sous CODESYS 3.5 (Python 2.7 / IronPython interne `ScriptEngine`).

---

## 🎯 1. Raison d'être & Responsabilité Unique

- **Problème résolu** : Les agents IA tentant de piloter CODESYS en ligne de commande échouent fréquemment en raison de :
  1. Mauvais chemin ou mauvais profil de version CODESYS.
  2. Plantages `NullReferenceException` lors de l'appel à `proj.save()`.
  3. Erreurs de compilation lors du remplacement de POU ST (mots-clés `END_PROGRAM` / `END_FUNCTION_BLOCK` en doublon).
  4. Réécritures cycliques de l'automate écrasant les valeurs écrites en simple `write`.
- **Principe fondamental** : **Ne jamais corrompre le fichier physique `.project` sur disque**. L'injection des modifications de code ST se fait **en mémoire RAM** pendant la session automate headless, garantissant un environnement de test 100% propre, jetable et sans risque.

---

## ⚙️ 2. Environnement & Ligne de Commande Système

Sur l'environnement cible Windows du projet :

| Paramètre | Valeur exacte |
|---|---|
| **Chemin CODESYS** | `C:\Program Files\CODESYS 3.5.19.10\CODESYS\Common\CODESYS.exe` |
| **Profil actif** | `"CODESYS V3.5 SP19 Patch 1"` *(obligatoire, sans quoi CODESYS ne charge pas les bons packages)* |
| **Option Headless** | `--noUI` *(exécute en arrière-plan sans ouvrir l'interface graphique)* |
| **Option Script** | `--runscript="C:\chemin\vers\harnais.py"` |

### 🚀 Commande de lancement PowerShell
```powershell
& "C:\Program Files\CODESYS 3.5.19.10\CODESYS\Common\CODESYS.exe" --profile="CODESYS V3.5 SP19 Patch 1" --runscript="C:\tmp\run_bench_headless.py" --noUI
```

---

## ⚠️ 3. Les 4 Règles d'Or pour Réussir l'Automatisation

### Règle 1 : Remplacement POU en RAM (Zéro appel à `proj.save()`)
Supprimer un POU de l'arborescence CODESYS pour réimporter du XML casse les GUIDs internes du projet et déclenche :
`SystemError: Object reference not set to an instance of an object`.

✅ **Solution canonique** : Mettre à jour `textual_declaration` et `textual_implementation` directement sur l'objet POU existant en mémoire :
```python
pou_obj = proj.find('Mon_POU', True)[0]
pou_obj.textual_declaration.replace(declaration_str)
pou_obj.textual_implementation.replace(implementation_str)
```

### Règle 2 : Stripper les mots-clés de fermeture ST
L'éditeur `textual_implementation` de CODESYS génère automatiquement son propre mot-clé de clôture. Si le fichier source `.st` se termine par `END_PROGRAM` ou `END_FUNCTION_BLOCK`, il y aura une erreur de syntaxe à la compilation (`app.build()`).

✅ **Solution canonique** :
```python
pos = content.rfind('END_VAR')
decl = content[:pos + 7]
impl = content[pos + 7:].strip()

if impl.endswith('END_PROGRAM'):
    impl = impl[:-11].rstrip()
elif impl.endswith('END_FUNCTION_BLOCK'):
    impl = impl[:-18].rstrip()
```

### Règle 3 : Basculer obligatoirement en Simulation Locale
Avant tout `app.build()` ou `online.create_online_application()`, s'assurer que le runtime virtuel est actif :
```python
dev = app
while dev is not None and not hasattr(dev, 'get_simulation_mode'):
    dev = getattr(dev, 'parent', None)
if dev is not None and not dev.get_simulation_mode():
    dev.set_simulation_mode(True)
```

### Règle 4 : Forçage explicite vs Écriture simple
Une variable d'entrée ou de diagnostic recalculée à chaque cycle automate (ex. tâche 20 ms) écrasera immédiatement toute écriture simple (`write_prepared_values()`).
Pour forcer une valeur pendant un test dynamique :

```python
online_app.set_prepared_value(var_path, value_str)
for method in ("force_prepared_values", "ForcePreparedValues", "force_values"):
    if hasattr(online_app, method):
        getattr(online_app, method)()
        break
```
Et à la restauration (fin de cas de test), appeler systématiquement :
```python
for method in ("unforce_all_values", "UnforceAll", "unforce_all"):
    if hasattr(online_app, method):
        getattr(online_app, method)()
        break
```

---

## 📄 4. Modèle de Script Harnais Complet (`harness_template.py`)

Ce script prêt à l'emploi sert de modèle pour orchestrer n'importe quel test headless :

```python
# -*- coding: utf-8 -*-
import sys, os, io

LOG_FILE = r'C:\tmp\codesys_headless_output.txt'
PROJECT_PATH = r'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PRJ_CODESYS\v0.7.36_SimBench_M3PLC_CalcPos_20261029.project'
BENCH_SCRIPT = r'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\T423_IHM\T423_AUDIT_DYNAMIC_BENCH.py'

try:
    log = io.open(LOG_FILE, 'w', encoding='utf-8')
    log.write(u"=== DÉMARRAGE HARNAIS HEADLESS CODESYS ===\n")
    
    # 1. Ouverture du projet
    proj = projects.open(PROJECT_PATH)
    app = proj.active_application

    # 2. Activation du mode simulation
    dev = app
    while dev is not None and not hasattr(dev, 'get_simulation_mode'):
        dev = getattr(dev, 'parent', None)
    if dev is not None and not dev.get_simulation_mode():
        dev.set_simulation_mode(True)

    # 3. Injection en RAM des POU modifiés (exemple)
    def patch_pou_in_memory(proj, pou_name, file_path):
        with io.open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        objs = proj.find(pou_name, True)
        if not objs:
            log.write(u"[WARN] POU non trouvé : " + pou_name + u"\n")
            return False
        o = objs[0]
        pos = content.rfind('END_VAR')
        decl = content[:pos + 7]
        impl = content[pos + 7:].strip()
        if impl.endswith('END_PROGRAM'): impl = impl[:-11].rstrip()
        elif impl.endswith('END_FUNCTION_BLOCK'): impl = impl[:-18].rstrip()
        o.textual_declaration.replace(decl)
        o.textual_implementation.replace(impl)
        log.write(u"[OK] POU injecté en RAM : " + pou_name + u"\n")
        return True

    # patch_pou_in_memory(proj, 'FB_MonBloc', r'C:\...\CODE\FB_MonBloc.st')

    # 4. Compilation et passage en RUN
    log.write(u"Compilation de l'application...\n")
    app.build()
    online_app = online.create_online_application(app)
    online_app.login(OnlineChangeOption.Try, True)
    if str(online_app.application_state) != 'run':
        online_app.start()

    log.write(u"[OK] Automate en RUN - Exécution du banc de test...\n")
    log.flush()

    # 5. Redirection de sortie et exécution du banc
    class OutputLogger(object):
        def __init__(self, handle): self.handle = handle
        def write(self, msg): self.handle.write(msg); self.handle.flush()
        def flush(self): self.handle.flush()

    old_stdout = sys.stdout
    sys.stdout = OutputLogger(log)

    globs = {'online': online, 'projects': projects, 'system': system, '__name__': '__main__'}
    exec(compile(open(BENCH_SCRIPT, 'rb').read(), BENCH_SCRIPT, 'exec'), globs, globs)

    # 6. Déconnexion propre
    sys.stdout = old_stdout
    online_app.logout()
    proj.close()
    log.write(u"\n=== FIN DE QUALIFICATION SANS ERREUR ===\n")
    log.close()

except Exception as err:
    log.write(u"\n[EXCEPTION] " + str(err) + u"\n")
    import traceback
    log.write(unicode(traceback.format_exc()))
    log.close()

system.exit()
```

---

## 🗂️ 5. Références Projet Associées

- Guide des tests du projet : [`DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md`](DOC/STDS/GUIDES/GUIDE_GATES_ET_TESTS_v1.2.md)
- Suite de test IHM T423 qualifiée : [`TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/`](TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/)
- Règle de non-destruction du projet : [`AGENTS.md`](AGENTS.md)
