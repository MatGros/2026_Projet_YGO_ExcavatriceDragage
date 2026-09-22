# 📋 BRIEF — LOT « MESSAGES DE BLOCAGE SILENCIEUX » (T375 + T365)
## v1 — PRÊT À TRANSMETTRE

> 📅 2026-09-22 · 🏷️ Rédacteur : **DSH01** (orchestrateur) · 🎯 **Lots groupés** : **T375** (C3) + **T365** (C2, parent T356)
> 📄 Faits techniques **vérifiés de première main** par l'orchestrateur (§2) · 🚫 **Aucune logique de sécurité à toucher**
> 🧩 Principe directeur : **un défaut qui n'est pas NOMMÉ à l'IHM est un défaut qui n'existe pas pour l'opérateur**

---

## 0. PRÉAMBULE OBLIGATOIRE (source : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — à lire en entier)

Automate **CODESYS 3.5**, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué **manuellement** par l'exploitant. **Sécurité machine réelle.**

**Persona** : Expert Senior Automatisme / Supervision-IHM / Sécurité Machine (ISO 13849) / CI-CD. **Challengeur anti-Yes-Man** : ce brief n'est pas parole d'évangile — s'il est faux, le dire **avant** d'agir. Distinguer **faits / hypothèses / incertitudes**. Répondre en **français**, direct.

**Interdits** : ⛔ aucun commit/push sans accord humain explicite · ⛔ toute modification exige une validation préalable · ⛔ ne jamais modifier `PRJ_CODESYS/…/Device.export` · ⛔ aucun scratch à la racine · ⛔ **élargir le scope = signaler, jamais décider**.

**Cas d'arrêt** : spec ambiguë · nommage indécidable · interface FB incomplète · `Reset` hors front · **redémarrage automatique après défaut**.

**Devoir d'alerte** : toute incohérence, bug préexistant, risque hors scope ou doute de sécurité remonte **immédiatement**.

**Vérification mécanique à chaque livraison** :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers .st touches>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report      # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
⛔ Un bundle bien formé ou des tests verts **ne prouvent jamais** la liaison : seul `G200_check_linkage.py` le prouve → **coller le bloc `Auto-vérification liaison`**.

🔒 **RÈGLE DE PREUVE IMPOSÉE (leçon du challenge expert du 2026-09-22)** : toute mesure doit **épingler la révision** qu'elle décrit — **hash git blob** des fichiers touchés (`git hash-object <fichier>`), précisé comme tel (*le hash du fichier de travail diffère du blob si les fins de ligne CRLF/LF diffèrent*). Une capture d'écran ou un `AlarmArray` cité sans révision **n'est pas une preuve**.

---

## 1. OBJECTIF (une phrase)

**Aucun défaut ni refus ne doit rester sans message opérateur nommé et exploitable** : quand la machine est bloquée, l'opérateur doit lire **quoi** est en cause et **quelle action** faire.

---

## 2. LES 4 VOIES SILENCIEUSES — faits **VÉRIFIÉS** (à re-mesurer, pas à croire)

### 2.1 Voie 1 — Refus par **séquencement benne couplé** (T375, AC1)
Le cycle refuse une commande couplée treuils/M3 en attente de la séquence benne… **sans publier de message nommé**. *(T375, AC1 — à re-prouver sur le code réel.)*

### 2.2 Voie 2 — **Causes latchées masquées par les portes de validité** (T375, AC2) — ✅ **VÉRIFIÉ**
```text
FB_Hmi_BannerFormatter.st:924   IF WinchM1Safety.ErrorPhaseRotation AND Vh0800Valid AND (...)
FB_Hmi_BannerFormatter.st:972   IF WinchM2Safety.ErrorPhaseRotation AND Vh0800Valid AND (...)
FB_Hmi_BannerFormatter.st:1011  IF TranslationSafety.ErrorPhaseRotation AND Vh0800Valid AND (...)
FB_Hmi_BannerFormatter.st:238-251  TofFaultEncM2(IN := (NOT Network.EncoderM2.Operational) AND NetworkSurveillanceActive, PT := T#1.5s)
                                   -> EncM2Valid := NOT TofFaultEncM2.Q
```
➡️ Les alarmes **nommées** sont conditionnées par `Vh0800Valid` / `EncM1Valid` / `EncM2Valid` / `LocalIoValid` / `VarM3Valid`. **Quand une porte est FALSE, la cause latcheée existe mais n'est JAMAIS nommée** ⇒ l'opérateur voit `AnyFault=1` **sans texte**.
**Exigence** : une cause **latchée** doit être publiée **MÊME SI** ces portes sont FALSE (au minimum : « défaut actif — diagnostic indisponible : <porte fautive> »).

### 2.3 Voie 3 — Message **MecaB non qualifié** (extension T375, 2026-09-22) — ✅ **VÉRIFIÉ**
```text
FB_Hmi_BannerFormatter.st:554  '[M3] MecaB (arrêt non confirmé) - Reset puis réarmer'
FB_Hmi_BannerFormatter.st:560  '[M1] MecaB (arrêt non confirmé) - Reset puis réarmer'
FB_Safety_Winch.st:341  UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive
                                             AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)
```
➡️ **Texte IDENTIQUE pour les 3 axes** et **aucune** indication de la sous-condition fautive : l'opérateur ne sait pas s'il doit vérifier les **CONTACTEURS** (non retombés) ou le **FREIN** (encore ouvert), ni **depuis combien de temps** (`TonMecaB` / `MecaBElapsedTime`, `FB_Safety_Winch.st:110/:342/:347`).
**Retours déjà disponibles** (`ST_HwWinch.st:8/10`) : `M1_ContactorsReleased_DI`, `M1_BrakeIsOpen_DI` (+ miroir diagnostic `Idx103_ContactorsReleased_DI`, `ST_Chain_Winch_Inputs.st:5` ; `Idx314_ErrorMecaB`, `FB_TroubleshootingView.st:199/278`).
**Libellés proposés** (≤ 70 car. — contrainte G408) :
- `[M1] MecaB - arret non confirme : contacteurs engages (Xs)`
- `[M1] MecaB - arret non confirme : frein encore ouvert (Xs)`

### 2.4 Voie 4 — **`ModesFault` absent du bandeau** (T365) — ✅ **PRIORITÉ DÉCLARÉE « URGENTE »** dans son titre
`AnyFault = 1` **sans alarme visible** + **message datum illisible**. *(T365, parent T356 = « Audit exhaustif de la chaîne alarmes ».)*
**Exigence** : tout groupe de défauts agrégé (`ModesFault`, datum de référencement…) qui met `AnyFault` à 1 **doit** produire **au moins une ligne nommée** dans le bandeau, et le message **datum** doit être lisible (≤ 70 car., mots entiers, sans jargon tronqué).

---

## 3. MISSION

Rendre **nommées et exploitables** les 4 voies ci-dessus, **dans la couche IHM** (`FB_Hmi_BannerFormatter` et ses DUT de messages), **sans jamais toucher à la logique de sécurité**.

```
PHASE 0 — MESURER (lecture seule, obligatoire)
  - Reproduire les 4 voies (simulation) et relever pour chacune : AnyFault, les portes
    (Vh0800Valid/EncM1Valid/EncM2Valid/LocalIoValid/VarM3Valid), l AlarmArray resultant,
    et le defaut reellement latche (Idx3xx).
  - Livrable : tableau voie -> cause reelle -> ce que l operateur voit aujourd hui -> ce qu il devrait voir.
  ⛔ ARRET HUMAIN : restitution + arbitrage des libelles avant d ecrire.

PHASE 1 — PUBLIER LES CAUSES MASQUEES (le coeur de la valeur)
  - Une cause latchee est publiee MEME si une porte de validite est FALSE.
  - Aucun affaiblissement : les alarmes existantes gardent leur ordre de priorite et leurs libelles.

PHASE 2 — QUALIFIER LES MESSAGES
  - MecaB : nommer la sous-condition fautive (contacteurs / frein) + le temps ecoule.
  - ModesFault + datum : ligne nommee, message lisible.
  - Tous les nouveaux messages <= 70 caracteres (G408), mots entiers, non trompeurs.

PHASE 3 — PREUVES ET GARDE-FOUS
  - Tests CI ROUGE avant / VERT apres pour chaque voie.
  - Baseline AlarmeArray identique pour les cas non concernes (zero regression).
  - G524 : aucun terme bloquant non declare (voir AC4 de T375).
```

---

## 4. CRITÈRES TESTABLES

- **AC1** : le refus par **séquencement benne couplé** publie un message **nommé** (test unitaire + observation IHM).
- **AC2** : une cause **latchée** (`MecaB` `ErrorID:09`) est publiée **MÊME SI** `EncM2Valid`/`LocalIoValid`/`VarM3Valid` est FALSE — **2 cas de test** (porte TRUE / porte FALSE).
- **AC3** : **zéro régression** des messages existants — baseline `AlarmArray` identique (libellés, ordre de priorité).
- **AC4** : `G524` refuse tout **terme bloquant non déclaré** en le nommant ; `--selftest` avec mutation.
- **AC5** : **MecaB qualifié** — le message nomme **la sous-condition fautive** (contacteurs vs frein) **et** le temps écoulé ; test qui échoue si la qualification est retirée (mutation).
- **AC6** : **T365** — `ModesFault` (et tout agrégat mettant `AnyFault` à 1) produit **au moins une ligne nommée** ; le message **datum** est lisible (≤ 70 car.).
- **AC7** : tout nouveau message **≤ 70 caractères** (G408) — et **le producteur côté cycle** est vérifié aussi (`OperatorAction` de `FB_CycleSemiAuto` **n'est PAS couvert par G408** : écart connu, à signaler, cf. le message `AX15c` à 76 car.).
- **AC8** : preuve **épinglée** — `git hash-object` des fichiers touchés + `G200 --report` collé + palier C sans rouge nouveau.

---

## 5. PÉRIMÈTRE ET INTERDITS

| | |
|---|---|
| **Attendu** | `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` · les DUT de messages (`ST_Chain_*_Safety`, types d'alarme) · **le fichier de test CI** concerné |
| ⛔ **INTERDIT** | **`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st`** (voir §6), `CODE/B_AU_SECURITE/**`, toute temporisation moteur/frein, tout **bypass** nouveau, `DOC/AF/**`, `DOC/STDS/**`, `PRJ_CODESYS/**`, `Device.export`, les tests d'autres entrées CI |
| ⚠️ **Signaler sans faire** | toute cause de blocage **sans texte** découverte en chemin (une par une, avec fichier:ligne) |

🚨 **CONTRAINTE IMPÉRATIVE (arbitrée par l'orchestrateur)** : la qualification du message **MecaB** doit être **calculée dans la couche IHM à partir des retours DÉJÀ publiés** (`M1_ContactorsReleased_DI`, `M1_BrakeIsOpen_DI`, `Idx103_ContactorsReleased_DI`).
⛔ **`FB_Safety_Winch.st` reste INTERDIT** : **ne pas scinder le booléen de sécurité** `UncommandedActiveB`.
➡️ Si la qualification s'avère **impossible hors du FB de sécurité**, **ARRÊT** : le lot change de nature (**C4**, périmètre `FB_Safety_*`) et repasse par un **arbitrage humain**.

🚨 **COLLISION D'ÉCRITURE À VÉRIFIER AVANT D'ÉCRIRE** : au 2026-09-22, le lot **T387 est en cours sur `FB_Safety_Winch.st`** (non committé) et **T269**/**T386-B** visent aussi ce fichier. **Un seul écrivain par fichier** : relire `git status` **juste avant** chaque écriture.

---

## 6. PREUVES ATTENDUES (à coller dans la restitution)

1. **Tableau voie → cause réelle → vu aujourd'hui → attendu** (phase 0), avec fichier:ligne.
2. **ROUGE avant / VERT après** pour AC1, AC2 (×2 cas), AC5 (+ mutation), AC6.
3. **Baseline `AlarmArray`** avant/après pour les cas non concernés (AC3).
4. Bloc **`Auto-vérification liaison`** (G200 `--report`) **collé**.
5. `git hash-object` des fichiers touchés + `git diff --numstat` + **diff bundle** (liste des objets).
6. **Ce qui reste à observer sur machine** (action humaine).

## 7. CE QUE L'ORCHESTRATEUR VÉRIFIERA

Lecture du **`git diff` réel** · rejeu des preuves · **AC un par un** · périmètre (`FB_Safety_Winch` **intact** — c'est la vérification n°1) · **révision épinglée** cohérente · puis **visa** ou **rejet motivé**.

> ⛔ **Ce brief n'est pas un GO code** : la phase 0 est en lecture seule et son résultat doit être arbitré **avant** toute écriture.
