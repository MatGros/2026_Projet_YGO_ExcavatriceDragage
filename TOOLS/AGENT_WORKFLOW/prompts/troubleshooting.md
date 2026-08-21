# 🕵️ Méthode de Recherche de Blocage / Diagnostic (Excavatrice Dragage)

> Prompt réutilisable pour diagnostiquer un blocage/bug dans le programme CODESYS.
> L'agent NE PEUT PAS exécuter le PLC : il lit des variables de diagnostic et raisonne par arbre de décision.
> Fiche de session : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_<Sujet>_<AAAA-MM-JJ>.md` (depuis `TEMPLATE_Troubleshooting.md`).

## 0. 📥 ACQUISITION DES VALEURS (canal)

> **Comment l'agent obtient les valeurs du PLC sans l'exécuter.**

- **Demander à l'utilisateur l'état des variables automate** — **UNIQUEMENT** si c'est nécessaire pour décider / identifier la cause, et qu'aucun autre moyen n'existe.
- **Toujours demander depuis `GVL_Troubleshooting` et ses structures** (jamais des internes de FB).
- ⚠️ **Si tu dois demander plus de 2-3 structures différentes** → le troubleshooting est **mal conçu** OU il faut **créer une structure dédiée** à ce type de problématique. Le signaler.
- 🚫 **Ne JAMAIS se baser sur `Device.export`** (souvent périmé). Sources fiables : `CODE/*.st` + `GVL_Troubleshooting`.

## 1. 🧊 CONTEXTE FIGÉ (à remplir UNE fois selon la situation)

> ⚠️ **L'agent NE DOIT PAS re-demander ces infos.** Si un point manque → « contexte incomplet », STOP, ne pas deviner. Vérifier la **fraîcheur** : **re-figer si > 5 min** ou si un événement (redémarrage, changement de mode) est survenu depuis le dernier contexte.

**Situation :** `[SIMULATION BANC]` / `[SITE MACHINE RÉELLE]`

**État de départ** (redémarrage = valeurs par défaut) :
- `SimulationModeActive` : `TRUE` (banc) / `FALSE` (site)
- `SimulationBypassActive` : `TRUE` (banc) / `FALSE` (site)
- Référencement axes (homing) : fait / non fait
- Mode machine : `MAINT_N1` / `MAINT_N2` / `SEMI_AUTO` / `DISABLE`

**Acquis :** simulation active / matériel réel · référencement fait · 2 bits posés · toute autre valeur = défaut.

## 2. 🧩 INDICES UTILISATEUR / HISTORIQUE (avant l'arbre, 6 questions max)

| # | Question | Pourquoi |
|---|---|---|
| 1 | Symptôme exact (quoi, où, depuis quand) ? | Cadre le périmètre |
| 2 | **Permanent ou intermittent** ? | Oriente l'arbre racine |
| 3 | Derniers changements (code, config, câblage, HMI) ? | Cause n°1 = régression → lire `VERSION_HISTORY`/git |
| 4 | Ce qui a déjà été essayé (et résultat) ? | Évite de re-tester |
| 5 | Conditions d'apparition (mode, charge, position) ? | Révèle le gating |
| 6 | Alarmes / historique d'alarmes ? | Cause souvent déjà nommée |

**Force des preuves** : 🟢 lecture de variable = forte · 🟡 rapport opérateur = faible (à confirmer) · 🔴 inférence = la plus faible (jamais seule).

## 3. 🧭 PHASE 0 — Caractériser le symptôme (avant tout arbre)

| Type | Signature | Arbre racine probable |
|---|---|---|
| Sortie ne s'émet pas | Y reste FALSE | Chaîne enable/interlock (reverse) |
| Sortie ne se coupe pas | Y reste TRUE | Front, tempo, état, sortie collée |
| Valeur fausse | ≠ attendu | Scaling, type, config, producteur |
| État bloqué | machine à état figé | Condition de transition, front, mode |
| Intermittent | parfois OK | Timing, race, comm, mécanique |
| Aucune réaction | rien ne bouge | Tâche, mode, enable global, power |

**Question clé** : *permanent ou intermittent ?* → permanent = logique/config/câblage ; intermittent = timing/race/comm/mécanique.

## 4. 🌳 GABARIT STANDARDISÉ d'arbre des causes (6 catégories)

Chaque nœud = **variable de décision + où la lire + valeur attendue**.

```
SYMPTÔME
├─ 1. ENTRÉES / CAPTEURS      → signal absent / mal interprété / fieldbus
├─ 2. LOGIQUE / INTERLOCKS    → condition d'enable FALSE (lire CHAQUE conjonction) / logique erronée
├─ 3. MACHINE À ÉTAT          → état incorrect / transition jamais déclenchée / état invalide
├─ 4. CONFIGURATION / PARAMS  → seuil/temps mal réglé / constante mal initialisée
├─ 5. TIMING / ORDRE DE SCAN  → retard 1 scan / TON (ET, IN) / front manqué (M du R_TRIG)
└─ 6. SORTIES / ACTIONNEURS  → commandée sans action / non commandée (reverse)
```

**Règle d'or** : à chaque nœud, répondre *« quelle variable prouve/réfute cette branche, où la lire ? »*. Sinon branche **non testable** → le marquer, ne pas deviner.

**💡 Exhaustivité & vitesse** : pour parcourir rapidement toutes les branches, déléguer l'exploration de branches **indépendantes** à des **sous-agents** (en parallèle), chacun remontant une branche jusqu'à sa source et rendant son verdict (cause confirmée / éliminée + preuve).
> ⚠️ **Délégation par CONTRAT clair** : objectif précis, **mesurable et évaluable** (ex. « éliminer ou confirmer la branche X, preuve = lecture de la variable Y »). **Analyse statique** (code `.st`) = déléguable. **Lecture live** (demander à l'utilisateur) = **non déléguable** (l'orchestrateur la fait). Si le contrat n'est pas mesurable → **faire soi-même**.

## 5. 🔄 TRACAGE INVERSE (reverse) — algorithme

```
TRACE_INVERSE(S):
  C = condition(s) qui commandent S
  pour chaque conjonction c_i de C:
    si c_i est FALSE:
      si c_i = ENTRÉE physique → cause EXTERNE (capteur/câblage/fieldbus) → STOP
      si c_i = PARAMÈTRE/config → cause CONFIG → STOP
      sinon → TRACE_INVERSE(c_i)          # récursion
  si toutes TRUE mais S reste FALSE → la LOGIQUE de S est erronée (vérifier le producteur)
```

**Vérification directe (forward)** : une fois la cause candidate trouvée, retracer en aval pour confirmer qu'elle explique S. **Règle producteur unique** : si S est écrit par plusieurs FB → bug suspect (aliasing).

## 6. 🛑 CRITÈRE D'ARRÊT (STOP quand)

1. **Nœud feuille** : entrée physique, paramètre, frontière matérielle.
2. **Cause prouvée** : variable FALSE alors qu'elle devrait être TRUE, et toutes ses entrées correctes → logique fausse.
3. **Frontière au-delà du PLC** : cause hors lecture → « voici quoi vérifier physiquement ».
4. **Étape suivante = modifier le code / forcer une variable** → **hand-off humain** (interdit sans validation).

**Ne PAS continuer** : hypothèse confirmée · prochaine étape **dangereuse** (actionnement d'organe) → recommander état sûr (MAINT, power cut).

## 7. 🧠 CAS LIMITES PLC/CODESYS (à ajouter à l'arbre)

| Cas | Signature | Variable de décision |
|---|---|---|
| Ordre de scan inter-PRG | valeur = scan précédent | ordre d'appel dans la tâche |
| RETAIN / persistance | mauvais état après coupure | valeur RETAIN, type de redémarrage |
| Front R_TRIG/F_TRIG | événement manqué | bit mémoire M du front |
| TON | sortie jamais TRUE | ET (accumule ?), IN (maintenu ?) |
| Portée inter-PRG | lue ≠ écrite | GVL vs VAR locale, collision |
| Gating par mode | fonction inerte hors mode | mode + condition de mode |
| Bypass / forçage | valeur figée anormale | variables forcées |
| Retard d'un scan | valeur décalée d'un cycle | ordre d'appel |
| Tâche arrêtée / watchdog | variables figées | statut tâche, temps de cycle |
| Multi-écrivains | valeur instable | producteur unique violé |
| Scaling analogique | seuil jamais atteint | brute vs échelle |
| Fieldbus / comm | entrée figée | statut I/O, validité image |

## 8. 📊 PRÉSENTATION — tableau d'hypothèses + journal

| # | Hypothèse | Variable de décision | Valeur attendue | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Capteur X HS | `GVL_Troubleshooting.X` | TRUE | FALSE | ❌ éliminée |
| 2 | Interlock Y bloque | `GVL_Troubleshooting.Y` | TRUE | FALSE | ✅ **cause** |

- Classer par *vraisemblance × coût de test*, **sécurité d'abord**.
- Étiqueter la force des preuves (🟢/🟡/🔴).
- **Journal auditable** : chaque hypothèse → preuve → verdict.
- **Ne jamais inventer un nom de variable** : vérifier l'existence contre le code/spec réel.

## 8bis. 🗺️ CARTE DE LECTURE — `GVL_Troubleshooting`

> Toutes les structures du GVL réel (`CODE/J_SUPERVISION/GVL_Troubleshooting.st`). Lire dans ces structures, jamais dans des internes de FB.

| Structure | Contenu |
|---|---|
| `ContexteMachineGlobal` | Mode, simulation, joystick maître, AU, power, heartbeat |
| `LevageSynchroniseM1M2` | Synchro M1+M2 (mode couplé) |
| `LevageUnitaireM1` / `LevageUnitaireM2` | Treuils M1 / M2 |
| `BenneOuvertureFermeture` | Benne (Busy, IsOpen, état, défauts) |
| `TranslationPontM3` | Translation M3 (variateur) |
| `AssistanceDragage` | Plongée / extraction / vidage trémie |
| `HomingM1` / `HomingM2` | Référencement M1 / M2 |
| `Safety` | Chaîne de sécurité & réarmement AU |
| `Joystick` | Bus CANopen & homme-mort |
| `MotionM1` / `MotionM2` / `MotionM3` | Mouvement M1 / M2 / M3 |
| `Inputs` | Image entrées réelles / qualifiées / simulées |

> 🛠️ **Ergonomie maintenance** : le dépanneur ouvre **une structure = tout sur une page**. Si une variable manque pour ce dépannage → **proposer son intégration**. Si une variable est présente mais inutile → **proposer son retrait**. Si une variable devrait être dans une autre structure pour l'ergonomie → **le signaler**.

## 9. ✅ RÈGLES DE L'AGENT
- Ne pas re-demander le contexte figé (§1).
- Distinguer **FAIT / HYPOTHÈSE / INCERTITUDE**.
- Lire dans `GVL_Troubleshooting` (lecture seule), **jamais forcer**.
- **Ne pas modifier le code** sans validation humaine.
- Cause racine **prouvée par lecture**, jamais par inférence seule.
- 🚫 **Ne JAMAIS se baser sur `Device.export`** : cet export est mis à jour au bon vouloir humain,
  il est **souvent périmé** et induit des conclusions fausses. Sources fiables = `CODE/*.st`
  (sources versionnées) + `GVL_Troubleshooting` (diagnostic en direct).
