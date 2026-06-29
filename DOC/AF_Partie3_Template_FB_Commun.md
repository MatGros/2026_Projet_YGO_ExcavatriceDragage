# 📋 Analyse Fonctionnelle — Partie 3 : Template FB Commun

> Contrat unique que **tout** `FB_*` respecte.
> Interface + machine d'état + gestion défauts/reset/AU.
> Pas de code interne — règles et structure.

---

## 🎯 Règles socle
- 🧩 POO par **composition** : pas de méthode/propriété.
- 1 FB = 1 responsabilité, périmètre net.
- Nommage sémantique, **sans hongrois**.
- Booléens : entrée = **verbe**, sortie = **état**.
- Le FB est **autonome et sûr** : sans `Enable`, il se neutralise.

---

## 🔌 1. Interface standard

**📥 VAR_INPUT — Commande**
| Nom | Type | Rôle |
|-----|------|------|
| `Enable` | BOOL | Active la logique |
| `Reset` | BOOL | Acquittement défaut (front interne) |

**🛡️ VAR_INPUT — Sécurité / contexte**
| Nom | Type | Rôle |
|-----|------|------|
| `SafeStop` | BOOL | Arrêt sûr forcé (actif = stop) |
| `SafetyOk` | BOOL | Conditions globales OK |
| `EStopOk` | BOOL | AU réarmé, machine mouvante |
| `Mode` | `E_Mode` | Mode courant (autorisations) |

**📤 VAR_OUTPUT — État**
| Nom | Type | Rôle |
|-----|------|------|
| `Ready` | BOOL | Prêt à recevoir un ordre |
| `Busy` | BOOL | Action en cours |
| `Done` | BOOL | Action terminée |
| `Error` | BOOL | Miroir de `ErrorId <> 0` |
| `ErrorId` | WORD | Code défaut bitfield |
| `State` | `E_State` | Phase opérationnelle |
| `StateAtError` | `E_State` | 📸 Snapshot phase au défaut |

**💾 VAR RETAIN** → paramètres persistants (offsets, calibrations).
**🔒 VAR** → instances composées (`LIN_TRAFO`, `RAMP_REAL`…) + copies locales.

---

## 🚦 2. E_State — ENUM exclusif (phases SEULES)

⚠️ Valeurs ordinales, **pas** des bits → toujours **1 seul état** à la fois.
`Error` et `SafeStop` sont **orthogonaux** : ils se superposent sans polluer la phase.

| Val | État | Sens |
|-----|------|------|
| 0 | `DISABLED` | Enable faux, neutralisé |
| 1 | `INIT` | Démarrage / vérifs |
| 2 | `READY` | Prêt, attend ordre |
| 3 | `BUSY` | Action en cours |
| 4 | `DONE` | Action terminée |
| 5 | `STOPPING` | Décél rampe avant arrêt *(optionnel : Winch/Translation)* |

---

## 🧾 3. ErrorId — bitfield

- `WORD` = **16 défauts max** par FB (→ `DWORD` si dépassement).
- 0 = pas de défaut ; bit n = défaut n. **Cumul possible.**
- Sans mnémonique : chaque bit **set à un seul endroit** dans le code + **commentaire FR** explicatif.
- 🔑 `Error := (ErrorId <> 0)`.

---

## 🧷 4. State vs Error → séparés

| Variable | Rôle | Sur défaut |
|----------|------|-----------|
| `State` | Phase opérationnelle | Continue (phase réelle) |
| `Error` | Flag défaut | Miroir `ErrorId <> 0` |
| `ErrorId` | Détail bitfield | Cumul des causes |
| `StateAtError` | 📸 Snapshot phase à l'instant du défaut | **Figé jusqu'à acquittement** |

🧭 `State` = "ce que je fais", `StateAtError` = "où ça a planté".
📌 `StateAtError` reste figé tant que l'alarme n'est pas acquittée → diagnostic préservé.

---

## 🔑 5. Logique Reset (cœur sécurité)

**Principe : l'acquittement n'est JAMAIS mémorisé. Front obligatoire.**

```
ResetEdge = R_TRIG(Reset)            // front uniquement, par FB

Pour chaque bit de ErrorId :
   SI (cause disparue) ET (ResetEdge actif ce cycle)
       → efface le bit
   SINON
       → le bit reste
```

🧭 Conséquences voulues :
- 🔴 Cause **toujours présente** + appui reset → **rien** (front gaspillé).
- 🟠 Cause disparue **toute seule** → alarme **reste** (pas d'appui = pas d'effacement).
- 🟢 Cause disparue **+ nouveau front** reset → efface.

⚠️ **Cas mains-dans-le-moteur** : défaut résolu seul → moteur **ne redémarre pas** → appui délibéré requis **après** disparition. ✅

📌 Acquittement IHM = **bouton général** → tente le reset de tous les FB.
📌 Tant que `StateAtError` figé → on peut **retenter** des reset jusqu'à acquittement effectif.
📌 Appliqué à **tous les FB** (cohérence maintenance), critique sur Winch / Brake / Translation.

---

## 🛑 6. Acquitter ≠ redémarrer

```
Alarme effacée → State revient READY (pas BUSY)
Redémarrage   → exige un NOUVEL ordre explicite (Cycle ou opérateur)
```

🧭 En semi-auto : un défaut → Cycle va en **HOLD sûr**, ne reprend jamais en aveugle.

---

## 🟥 7. Arrêt d'Urgence — chaîne indépendante

| Élément | Nature | Action |
|---------|--------|--------|
| 🔴 Bouton AU | Physique câblé | Coupe tout (contacteurs, freins collent) |
| 🔧 Réarmement AU | Bouton **physique** | Réautorise le mouvement |
| ✅ `EStopOk` | Info | =1 **quand réarmé + contacteurs collés** |

🧭 Règles strictes :
- 🔌 Réarmement AU = **physique**, pas IHM.
- 🚫 Réarmer l'AU **n'efface pas** les alarmes (2 actions distinctes).
- 🔗 `EStopOk` alimente `SafetyOk` / `SafeStop` des FB.

```
AU enfoncé         → EStopOk = 0 → SafeStop actif → sorties sûres
AU réarmé physique → EStopOk = 1 → mouvement réautorisé
Alarmes            → toujours présentes → acquittement IHM séparé requis
```

---

## 🖥️ 8. Couplage IHM

Chaque FB porte **1 struct** d'échange écran :
```
Hmi : ST_<Objet>Hmi   // lecture (mesures, état, ErrorId, StateAtError)
                      // écriture (consignes manuel, reset)
```
→ L'intégrateur IHM mappe **une seule struct** par objet, jamais les internes. ✅

---

## 🧱 9. Squelette d'exécution (phases, pas de code)

```
1. 🛡️ GATE     → NOT Enable / SafeStop(EStop) → sorties sûres + RETURN
2. 📥 ACQUIRE  → copies locales + range check entrées
3. 🚦 STATE    → avance la phase (DISABLED…DONE)
4. ⚙️ CORE     → briques métier composées (si autorisé)
5. 🧾 ERROR    → set bits ErrorId + fige StateAtError
6. 🔑 RESET    → R_TRIG + efface bits dont cause disparue
7. 📤 OUTPUT   → mappe sorties + force sûr si Error/SafeStop
8. 🖥️ HMI      → Error, ErrorId, State, StateAtError → écran
```

📌 Ordre **imposé** : sécurité d'abord, IHM en dernier.
📌 Sortie sûre (étape 7) **prioritaire** sur la phase : `State` peut dire BUSY, sorties coupées si `Error`/`SafeStop`.
📌 Copies locales = **intégrité** (jamais agir sur la donnée brute volatile).
