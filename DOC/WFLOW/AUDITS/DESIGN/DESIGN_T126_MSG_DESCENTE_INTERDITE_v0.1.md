# 🖥️ T126 — IHM : message « descente interdite » précis + contexte dynamique

> 📄 **ÉTUDE / DESIGN (zéro code)** · 📅 2026-08-24 · 🎯 T126 — préciser la **cause** du message
> « descente interdite » et remplacer le champ figé « PILOTAGE DIRECT » par un **contexte dynamique**.
> Source : `FB_Hmi_BannerFormatter.st`, `GVL_IHM`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T126.

---

## 1. Constat (vérifié code)

| Élément | État actuel (`FB_Hmi_BannerFormatter`) |
|---|---|
| **Message direction bloquée** | `[TREUIL] Descente interdite` / `Montée interdite` (L258-262) — **générique**, sans la cause |
| **Champ 1 contexte** | `Banner.SequenceProgressText := 'Manuel: PILOTAGE DIRECT'` (L191) — **figé** pour MAINT_N1/N2, inutilement verbeux |

Le `DirectionBlocked` (L244-245) est déclenché par `NOT DescendPermit` / `NOT AscentPermit` mais
**ne précise pas le blocage** : c'est un booléen, on perd la cause (limite basse ? mou de câble ?
fin de course ? interlock ?). L'opérateur voit « interdite » sans savoir **pourquoi**, ni **dans
quel mode/état** la machine est (la cause éjecte du SEMI_AUTO = le vrai besoin).

---

## 2. Conception — message direction avec cause + contexte dynamique

### 2.1. Message « descente/montée interdite » avec cause

Remplacer le booléen `DirectionBlocked` seul par un **texte de cause** issu des sources réelles
de `DescendPermit`/`AscentPermit` (déjà disponibles en entrées du FB) :

| Cause candidate (descente) | Source |
|---|---|
| Limite basse / mou de câble | `NOT DescendPermit` dû à limite/mou (FB_Safety_Winch) |
| Fin de course haut | `NOT AscentPermit` (montée) |
| Interlock séquence / cycle | en SEMI_AUTO, la cause est la condition d'étape |

**Format proposé** :
```
[TREUIL] Descente interdite — cause: <Limite basse / Mou de câble / Interlock cycle>
```

> ⚠️ La **cause précise** doit être dérivée des **sorties** des FB safety (producteurs uniques),
> pas recalculée dans le formateur (anti-doublon, `1 FB = 1 responsabilité`). Le formateur ne fait
> qu'afficher une cause **déjà exposée** (ex. `MecaA`, `MecaE`, `LimitSwitch`, `HeightInterlockBlocking`).

### 2.2. Champ 1 — contexte dynamique (remplacer « PILOTAGE DIRECT »)

Remplacer le libellé figé par un contexte **composé dynamiquement** (concaténation de flags) :

```
[SIMU] [MAINT_N1] [M1+M2 COUPLÉS] [PILOTAGE MANUEL]
```

| Élément | Source | Affiché si |
|---|---|---|
| `[SIMU]` | `SimulationModeActive` | simu active |
| `[MAINT_N1]` / `[MAINT_N2]` | `CurrentMode` | mode courant |
| `[M1+M2 COUPLÉS]` | `BothAxesCoupled` | couplage |
| `[PILOTAGE MANUEL]` | mode manuel (au lieu de PILOTAGE DIRECT) | mode manuel |

---

## 3. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Quelles **causes exactes** afficher (dépend des sorties disponibles en entrée du formateur) ? |
| 2 | Le contexte dynamique remplace-t-il le champ `SequenceProgressText` seul, ou tout le bandeau champ 1 ? |
| 3 | Implémentation (code `FB_Hmi_BannerFormatter` + éventuels entrées) → **validation humaine** |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T126 |
| FB | `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` (L191, L244-262) |
| Spec IHM | `DOC/AF/AF_Partie-07_Interface_IHM_v2.1.md` |
| Contexte | `GVL_IHM`, `ST_HmiBanner` |
