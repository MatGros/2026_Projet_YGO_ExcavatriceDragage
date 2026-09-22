# 🧊 GEL GRAFCET SEMI_AUTO — AMENDEMENT T383 (2026-09-22)

> **Statut : ✅ VALIDÉ par l'exploitant (2026-09-22) — phase 0 close, GO code accordé.**
> Ce document AMENDE le GEL figé [`GEL_GRAFCET_SEMIAUTO_20260903.md`](./GEL_GRAFCET_SEMIAUTO_20260903.md)
> selon le **mécanisme d'arbitrage du GEL (section 4 ✏️ / Q)**. Le fichier gelé n'est PAS réécrit :
> l'amendement est un **ajout déclaratif** que le code livré doit respecter (AC6 / garde-fou phase 4).
>
> - **Tâche** : T383 (C4, parent T331) · **Brief** : `CONTRACTS/BRIEF_T383_MICROSTEP_DECHARGE_v1.md`
> - **Décisions exploitant** (2026-09-22, arbitrages §5 du brief) : voir §4.
> - **Revues C4** : 2 revues parallèles read-only — challenge du brief (sous-agent abc8fb3e) + audit
>   du garde-fou G525 (sous-agent a5083aba). Retours intégrés.
> - **Règle d'or respectée** : aucun fichier `CODE/` ni `CODE_XML/` touché — **doc seul**.

---

## 1️⃣ Objet de l'amendement

Le GEL figé (2026-09-03) déclare pour `AX15B_DUMP_OPEN` (16, DÉCHARGE) **deux** sorties :
`AT15B-c` (option, `RepositionRequest` → AX15C) et `AT15B` (`JoystickDeflected AND Benne_Done AND Benne_IsOpen` → `ReqOpen := FALSE` → **AX18**). Il **ne déclare aucun** saut `AX15B → AX10`.

Or le commit `31c9db0d` (T331) a introduit **sans GEL** une transition `AX15B → AX10_CLOSE_BUCKET`
(`FB_CycleSemiAuto.st:1567-1569`) — **seul saut arrière non déclaré** du séquenceur. **Principe
exploitant** : « un grafcet a des transitions définies, il ne peut pas faire de saut ».

Cet amendement acte la **séparation du besoin** :
1. **retirer la déviation** `AX15B → AX10` (elle ne sera pas remplacée par un saut déclaré — voir §3) ;
2. **créer un step de module benne sur place** `AX15D_DUMP_BUCKET_JOG` (=23), déclaré avec **toutes** ses
   entrées/sorties/messages au GEL, pour que l'opérateur puisse **ouvrir ET refermer la benne sur place
   à la trémie** sans quitter la phase de vidage et sans saut.

---

## 2️⃣ Nouvelle étape : `AX15D_DUMP_BUCKET_JOG` (= 23)

> **Nom** : `AX15D_DUMP_BUCKET_JOG` — aligné sur la famille DÉCHARGE (`AX15A`/`AX15B`/`AX15C`), `NAMING_CONVENTION.md`.
> **Valeur d'énumération** : `23` (voir §4-4 et §5). `E_AutoCycleStep.st` actuel : dernier `AX10B_RACCORDEMENT_P1 := 22`.

| Rep. | 🎬 | Contenu (variables réelles) |
|---|---|---|
| **AX15D_DUMP_BUCKET_JOG** (23) *(nouveau)* | 🟩 step — 🎛️ **module benne sur place** à la trémie | **treuils M1+M2 à 0** (`RunRequest := FALSE`, `ReqAscent/ReqDescend := FALSE`, `StepTgt := 0`) · **translation 0** (`ReqStart := FALSE`, `PositionTgt := 0`) · `Lifecycle.Busy := TRUE`. **Geste ouvert : `BucketCmd.ReqOpen := <geste>` · geste fermé : `BucketCmd.ReqClose := <geste>` · neutre = les deux à `FALSE`.** L'opérateur module la benne **SUR PLACE** au-dessus de la trémie. |
| **AT15D-open** | ⬇️ *(entrée — voir §4-1)* | geste d'entrée joystick depuis **AX15B** → **AX15D** |
| **AT15D-exit** *(retour vidage)* | ⬆️ *(sortie 1 — §4-2)* | **retour au centre mort (relâchement)** → **AX15B** |
| **AT15D-done** *(sortie 2)* | ⬇️ | `Benne_Done AND Benne_IsOpen` (contenu vidé) → **AX18_DONE_SYNC** (même logique que `AT15B`) |
| *(pas de sortie 3)* | — | **PAS d'échappatoire vers AX10** — §3 |

Messages opérateur (contrainte **G408 ≤ 70 car.**, non trompeurs : ils disent ce que fait la machine **et** ce qu'elle va faire) :
- *module* (figé phase 1) — `"AX15d - Pousser : ouvrir benne. Tirer : fermer. Relacher : retour."` (**68 car.**), publié par `OperatorAction` d'AX15D ;
- *état* (`CycleStateStr`) — `"AX15d - Module benne a la tremie"` ;
- *fin vidé* — réutiliser le ton d'`AX18` (« Cycle terminé — aller en P1 pour recommencer », GEL L113).

## 3️⃣ PAS d'échappatoire `AX15D → AX10`

**Décision exploitant (arb. 3)** : « Quel échappatoire AX10 ? c'est absurde, AX10 n'est pas en face de la
trémie, il n'en a jamais été question. » Les **2 revues C4 convergent** : `AX15D(23) → AX10(10)` serait un
**saut arrière de 13 étapes** reproduisant le pattern que le brief lui-même condamne (`AX15B → AX10`).

→ Le brief v1 §3/§4 prévoyait une « échappatoire » en phase 3. **Cette phase 3 est supprimée.** Le micro-step
sert à **fermer la benne sur place** ; la remontée éventuelle reste un geste/séquence explicitement déclaré
hors micro-step et **non couvert par cet amendement**. La suppression de la déviation (phase 2) **ne remplace
pas** `AX15B → AX10` par un nouveau saut.

**Doctrine de sortie « benne fermée » — décision exploitant (2026-09-22, réfutation du risque de cul-de-sac)** :
il n'existe **pas de cul-de-sac** après fermeture sur place. Ordre des replis pour un vidage manqué à la trémie :
1. **Ouvrir la benne** sur place (pousser en AX15D) — le repli naturel, exactement ce que le micro-step permet ;
2. si la benne est **bloquée** (impossible d'ouvrir), **quitter le mode cycle auto** → bascule en **maintenance
   (MAINT)** où l'opérateur « se débrouille » hors séquenceur (diagnostic / débocage manuel).
AX10 n'est **jamais** un repli depuis la trémie : il appartient à la chaîne d'extraction `AX9 ⇒ AX10 ⇒ AX10B ⇒
AX11 ⇒ AX12 ⇒ AX13` (montée couplée depuis le fond, hors portée du vidage). La déviation `AX15B → AX10`
supprimée était un **saut illégitime** dans cette chaîne, pas un repli utile.

**Décisions SAFETY tracées (accord exploitant 2026-09-22) :**
- **Exclusion sync AX15D** (arb. 5) : `AX15D` est ajouté à la liste d'exclusion de la **cause 1 `WinchSyncError`**
  (`FB_CycleSemiAuto.st`, `instCauses[1].Active`, exclusions AX8/AX9/AX10/AX11 + nouvelle `AX15D`) — même fenêtre
  de vidage que AX10, cohérent avec l'arb. 5 (« exclure comme AX10, c'est la base de la machine »).
- **DirectInversionPermit** (PRG_02_Acquisition.st) : l'extension de ce **permis [SAFE]** à `AX15D` est **tracée
  ici comme décision safety** — l'opérateur alterne pousser (ouvrir) / tirer (fermer) dans le micro-step SANS
  retour au neutre, sinon l'homme-mort se désarmerait au milieu de la manipulation. Permis de GESTE uniquement,
  consommé par `FB_Joystick` / `PRG_04` comme `AX15B`, jamais une autorisation de mouvement autonome. Miroir du
  commentaire `FB_Joystick.st:28` (mis à jour AX15d).

## 4️⃣ Décisions exploitant (arbitrages §5 du brief — salve 2026-09-22)

| # | Question | Décision exploitant | Conséquence dans cet amendement |
|---|---|---|---|
| 1 | Geste d'entrée en AX15D | **Geste joystick, jamais de bouton IHM** (« tout au joystick, le moins de mouvement ») | `AT15D-open` = geste joystick (candidat : tirer Y+/Pull) depuis AX15B |
| 2 | Retour au vidage (sortie 1) | **Centre mort / relâchement** (« c'est la base de la machine », interlock) | `AT15D-exit` = retour au neutre → AX15B |
| 3 | Échappatoire (phase 3) | **Refusée** | Phase 3 supprimée, aucune transition → AX10 ajoutée |
| 4 | Nom + valeur d'enum | **`AX15D_DUMP_BUCKET_JOG := 23`** | valeur 23 (après AX10B := 22) |
| 5 | Exclusion surveillance sync | **Validée comme l'existant AX10** (c'est la base) | tracée au §3 du GEL, déjà active dans le code (`FB_CycleSemiAuto.st:472`) |

## 5️⃣ Régularisation des steps hors GEL préexistants (exigence revue #1, M2)

La revue C4 (#1) relève que le garde-fou de phase 4 échouera sur **2 steps spéciaux déjà hors GEL** qui
n'ont **pas** de transition déclarée dans le GEL figé. Pour rendre le garde-fou AC6 fiable, **cet amendement
régularise explicitement ces 3 steps hors numérotation régulière** :

| Enum | Valeur | Statut | Rôle au GEL |
|---|---|---|---|
| `AX3_WAIT_DIVE_START` | 21 | à déclarer | transition benne→plongée : sorties neutres jusqu'à arrêt mécanique M1/M2 confirmé (transverse de séquence) |
| `AX10B_RACCORDEMENT_P1` | 22 | à déclarer | raccordement continu P1 : fermeture benne → montée contrôlée (transverse de séquence) |
| `AX15D_DUMP_BUCKET_JOG` | 23 | nouveau (§2) | module benne sur place — **step de plein droit** (DÉCHARGE) |

> Ces deux steps (21/22) sont des **steps de passage** existants ; l'amendement les **déclare** au GEL pour
> que le garde-fou (phase 4) compare sur le **numéro** sans faux positif (AC6). Leur contenu n'est pas modifié
> ici : le périmètre T383 ne leur apporte aucun changement de comportement.

## 6️⃣ Preuves mécaniques / état avant code

- `CODE/G_CYCLE/FB_CycleSemiAuto.st` : **propre vs HEAD** au moment de l'amendement (git status vide).
- Déviation à la déviation : `:1567-1569` (branche `IF DeadmanArmed AND JoystickPull THEN … State := AX10_CLOSE_BUCKET`) — cible **entière** de la suppression phase 2 (revue N1 : supprimer :1568-1569 seulement laisserait une branche IF vide).
- Métrique corrigée (revue N1) : **33 affectations `State := E_AutoCycleStep` directes** (et non « 39 » — conflation `State`/`PausedState`/`SavedState` à AX0).

## 7️⃣ Critères d'acceptation de l'amendement (phase 0 — ✅ VALIDÉ 2026-09-22)

- [x] Le step `AX15D` (23) est déclaré avec **contenu + toutes ses entrées/sorties/messages** (GEL amendé).
- [x] Aucune transition vers une étape antérieure autre que les retours déclarés (`AX15D → AX15B`) — et surtout **aucun** `AX15D → AX10`, **aucun** `AX15B → AX10`.
- [x] L'exclusion de la surveillance de synchronisme est **tracée** (décision safety arbitrage 5).
- [x] Les steps hors GEL 21/22/23 sont déclarés pour fiabiliser le garde-fou AC6 (phase 4).
- [x] `git diff` : **AUCUN fichier `CODE/`, `CODE_XML/`, gate, test** modifié par la phase 0 — doc seul.
- [x] Messages ≤ 70 car. (G408) — figés en phase 1 (`AX15d - Pousser : ouvrir benne. Tirer : fermer. Relacher : retour.` = 66 car. ; `AX15b - ... Tirer : fermer sur place (micro-step).` = 64 car.).
- [x] Doctrine de sortie « benne fermée » tracée (ouvrir sur place → sinon MAINT) — §3.

> **Phase 0 CLOSE.** Le code (phase 1/2) est livré et conforme à cet amendement — voir restitution T383.
