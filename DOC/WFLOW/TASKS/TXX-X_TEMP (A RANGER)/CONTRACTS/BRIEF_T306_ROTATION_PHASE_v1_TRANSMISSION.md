# 📋 BRIEF T306 — DÉFAUT ROTATION DE PHASE : vérification de la chaîne complète
## v1 — PRÊT À TRANSMETTRE (agents de l'exploitant)

> 📅 2026-09-22 · 🏷️ Rédacteur : **DSH01** · 🎯 **Tâche** : **T306** (⬜, `agent: —`, **personne ne l'a prise**)
> 📄 Contrat existant (à amender) : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T306_VERIFICATION_DEFAUT_ROTATION_PHASE.yaml` (**C2**, écrit le 16/09)
> ⚡ Objet : `GVL_IHM.Commun.PhaseRotationFault` — chaîne `PhaseRotationOk_DI` → sécurité axes → interlocks → IHM
> ✅ **Vérification préalable DSH01** : **les 8 références de la chaîne fournies par l'exploitant sont EXACTES** (mesurées sur le code, voir §2). Les marques `✅ vérifié` ci-dessous sont de première main.

---

## 0. PRÉAMBULE OBLIGATOIRE (`TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — à lire en entier)

Automate **CODESYS 3.5**, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué **manuellement** par l'exploitant dans CODESYS. **Sécurité machine réelle.**

**Persona** : Expert Senior Automatisme / **Sécurité Machine (ISO 13849)** / CI-CD. **Challengeur anti-Yes-Man** : ce brief n'est pas parole d'évangile — s'il est faux, le dire **avant** d'agir. Distinguer **faits / hypothèses / incertitudes**. Répondre en **français**, direct, synthétique.

**Interdits absolus**
- ⛔ **Aucun commit, aucun push** sans accord humain explicite et distinct.
- ⛔ **Toute modification de fichier exige une validation préalable** (voir ARRÊTS §4).
- ⛔ Ne jamais modifier `PRJ_CODESYS/…/Device.export` · aucun scratch à la racine · aucune suppression/déplacement d'artefact.
- ⛔ **Ne JAMAIS affaiblir ni contourner la chaîne d'arrêt d'urgence physique** — voir §6.
- ⛔ Élargir le scope = **signaler, jamais décider**.

**Cas d'arrêt** : spec incomplète/ambiguë · nommage indécidable · interface FB incomplète · `Reset` hors front · **redémarrage automatique après défaut** · `SafeStop`/`StartStop` sur un FB non-mouvement.

**Devoir d'alerte** : toute incohérence, bug préexistant, risque hors scope ou **doute de sécurité** remonte **immédiatement**, jamais à la fin, jamais silencieusement.

**Vérification mécanique — minimum à CHAQUE livraison**
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers .st touches>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report       # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
⛔ Un bundle bien formé ou des tests verts **ne prouvent jamais** la liaison : seul `G200_check_linkage.py` le prouve, son bloc `Auto-vérification liaison` doit être **collé dans la restitution**.

**Heartbeat** : `python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <SESSION> <ETAPE> <etat> --agent <CC01|AGY01|CDX01|DSH01|OPC01> --msg "<résumé>"`

---

## 1. OBJECTIF (une phrase)

**Prouver par essai** que le défaut de rotation de phase **arrête la machine de façon sûre et contrôlée** (pas de mouvement possible sur M1/M2/M3), qu'il est **verrouillé sans réarmement automatique**, et que **rien ne peut le contourner** — **puis corriger** tout écart constaté **dans la chaîne de sécurité**, sans jamais toucher à l'AU physique.

---

## 2. LA CHAÎNE, VÉRIFIÉE (tes données, contrôlées ligne à ligne)

### 2.1 Acquisition et synthèse IHM — ✅ **VÉRIFIÉ**
| Élément | Emplacement | Contenu |
|---|---|---|
| `PhaseRotationOk_DI` | `PRG_02_Acquisition.st:190` ✅ | Entrée TOR du **relais de contrôle de phase** — polarité **fail-safe : `TRUE` = ordre & présence des phases OK**, `FALSE` = inversion ou coupure |
| `GVL_IHM.Commun.PhaseRotationFault` | `ST_CommunHMI.st:18` ✅ | Booléen de **synthèse IHM commun** (retour unique M1/M2/M3) : `TRUE` = défaut actif |
| **Génération** | `PRG_07_Supervision.st:407` ✅ | `GVL_IHM.Commun.PhaseRotationFault := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;` |

### 2.2 Treuils M1 & M2 — ✅ **VÉRIFIÉ**
```text
FB_Safety_Winch.st:302   IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
FB_Safety_Winch.st:303       PhaseRotationFaultLatched := TRUE;
FB_Safety_Winch.st:305   instCauses[4].Active := PhaseRotationFaultLatched;   (* Latching := TRUE *)
FB_Safety_Winch.st:498   CausePhaseRotationActive := instCauses[4].Active;    (* bit 4 / 16#0010 *)
FB_WinchStateProjection.st:241  WinchM1Safety.ErrorPhaseRotation := (SafetyM1.Fault.ErrorId AND 16#0010) <> 0;
FB_WinchStateProjection.st:269  WinchM2Safety.ErrorPhaseRotation := (SafetyM2.Fault.ErrorId AND 16#0010) <> 0;
```

### 2.3 Translation M3 — ✅ **VÉRIFIÉ**
```text
FB_Safety_Translation.st:140  IF NOT (BypassProcess OR BypassPhaseRotation) AND NOT PhaseRotationOk THEN
FB_Safety_Translation.st:141      PhaseRotationFault := TRUE;
FB_Safety_Translation.st:143  instCauses[2].Active := PhaseRotationFault;    (* bit 2 / 16#0004 *)
```

### 2.4 Barrière finale, diagnostics, préflight — ✅ **VÉRIFIÉ**
| Niveau | Preuve |
|---|---|
| Bandeau IHM | `FB_Hmi_BannerFormatter.st:924` **`[M1] ErrorID:05 - rotation phases`** · `:972` **`[M2] ErrorID:05`** · `:1011` **`[M3] ErrorID:03`** · `:1191` (historique) ✅ |
| Préflight machine | `FB_Acquisition_Preflight.st:76` **`IF NOT PhaseRotationOk THEN PreflightErrorId := PreflightErrorId OR 16#0100`** ✅ |
| Bypasses ingénierie | `FB_Safety_Winch.st:74 BypassPhaseRotation` · `FB_Safety_Translation.st:43` · **câblage réel** : `PRG_04_Treuils_Benne.st:984 := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation` ✅ |

**Effets physiques attendus** (à **prouver**, pas à supposer) : `SafeStop` → permis de montée/descente annulés → **rampe d'arrêt + serrage des freins** ; **pas de `PowerCutOff` brutal** (défaut géré en `SafeStop` contrôlé) ; interlocks finaux forcés : `RelayFwd/RelayRev = FALSE`, `Contactor1..4 = FALSE`, `BrakeCmd = FALSE`.

### 2.5 🚨 **LE BLOCAGE CONNU — le défaut n'est PAS injectable en simulation** — ✅ **VÉRIFIÉ**
```text
FB_SimBench.st:690   Machine.PhaseRotationOk_DI := TRUE;
```
**⚠️ Annotation DSH01 (PAS un commentaire du code — correction de brief du 2026-09-22, relevée par la revue phase 0)** : cette écriture a lieu **à chaque scan**, elle **écrase donc tout forçage opérateur**. Le code réel ne porte **aucun** commentaire à cet endroit ; la rédaction initiale laissait croire à une citation. **Erreur corrigée ici.**
➡️ **Conséquence** : en simu, le défaut de phase **ne peut pas être déclenché** — donc **T306 est aujourd'hui intestable**, et `PhaseRotationOk_DI` reste figé `TRUE`. **C'est l'objet de la phase 1 du phasage.**

> 📌 **Précision apportée par la revue phase 0** (`DOC/WFLOW/REX/REX_T306_PHASE0_VERIFICATION_ROTATION_PHASE_20260922.md`) : `PRG_02_Acquisition.st:190` est une **affectation** (`HwReal.Machine.PhaseRotationOk_DI := PhaseRotationOk_DI;`) dont la **source est la variable d'E/S globale** (`GVL_Device_IO.st:53`) — ce n'est **pas** une déclaration `VAR_INPUT`. La polarité fail-safe (`TRUE` = OK) est documentée **côté FB** (`FB_Safety_Translation.st:22`), pas à `PRG_02:190`. **Producteur unique confirmé** : `PRG_02:446 SEL(...)` → tous les consommateurs lisent `HwIn.Machine.PhaseRotationOk_DI`.

---

## 3. MISSION — 5 questions à trancher, par la MESURE

| # | Question | Pourquoi c'est décisif |
|---|---|---|
| **Q1** | La chaîne est-elle **réellement câblée de bout en bout** jusqu'aux **sorties** (interlocks `FB_WinchOutputInterlock` / `FB_TranslationOutputInterlock`) ? | Un `SafeStop` logique qui n'atteint pas le relais est **un faux sentiment de sécurité**. Preuve exigée : `G200_check_linkage.py --report` + lecture des consommateurs finaux |
| **Q2** | Le défaut est-il **injectable** ? (simu **et** CI) | Aujourd'hui **NON** (`FB_SimBench.st:690`). Sans injection, rien n'est prouvable |
| **Q3** | La réaction est-elle **conforme** : rampe + freins, **sans coupure brutale**, `SafeStop` (et non `StartStop`), `Enable` maintenu ? | Conformité au principe non négociable `Enable > SafeStop > StartStop` |
| **Q4** | Le **verrouillage** est-il effectif : aucun réarmement automatique si les phases redeviennent bonnes, `Reset` **sur front** uniquement, re-verrouillage immédiat si la cause est encore présente ? | Règle projet : **jamais de redémarrage auto après défaut** |
| **Q5** | Les **bypass** sont-ils **encadrés** (réservés à un niveau de maintenance, tracés, visibles à l'IHM, impossibles en production) ? | Un bypass qui **silencie** un défaut de sécurité est **le danger principal** de cette chaîne |

---

## 4. PHASAGE (4 phases — 4 contrats, **1 seul import** final)

```text
PHASE 0 — VERIFICATION EN LECTURE SEULE (aucune ecriture)
   Livrable : rapport avec les 5 reponses + preuves fichier:ligne + G200 --report colle.
   Verifier AUSSI : polarite fail-safe de la DI, et que PhaseRotationFault IHM reflete bien la
   MEME source que celle utilisee par les FB de securite (producteur unique).
   ⛔ ARRET HUMAIN : restitution + arbitrage avant toute ecriture.

PHASE 1 — RENDRE LE DEFAUT INJECTABLE (simu + CI)
   Livrable : une entree de simulation dediee permettant de forcer PhaseRotationOk_DI a FALSE
              (remplacant le TRUE code en dur de FB_SimBench.st:690), + un cas de test CI qui
              declenche le defaut et verifie l'arret sur M1, M2 ET M3.
   ⚠️ Ne change RIEN au comportement de production (perimetre simu/CI seulement).
   Preuve : CI ROUGE avant / VERT apres ; le test DOIT echouer si l'injection est debranchee.

PHASE 2 — CORRECTION DES ECARTS CONSTATES (uniquement ceux prouves en phase 0/1)
   ⛔ ARRET HUMAIN OBLIGATOIRE : toute correction touche la chaine de securite.
   Regle : la reaction doit rester un SafeStop CONTROLE via la chaine de securite —
   jamais une coupure brutale ajoutee, jamais un contournement de l'AU physique.

PHASE 3 — RECETTE MACHINE (action HUMAINE)
   Livrable : procedure d'essai (couper/inverser une phase, verifier l'arret sur les 3 axes,
   l'acquittement sur front, et l'absence de redemarrage automatique), listee comme action
   humaine non delegable.
```

**Chaque phase** : contrat validé par `check_task_contract.py` **avant** sa première ligne + **challenge** du plan + **revue indépendante** du diff (`BLOCK/MAJOR/MINOR/PASS`). **Criticité proposée** : **C2 pour la vérification (phase 0)**, **C4 dès qu'une correction touche la chaîne de sécurité (phases 1-2)**.

---

## 5. CRITÈRES TESTABLES

- **AC1** : les 5 questions du §3 sont répondues **avec preuve** (fichier:ligne + mesure), y compris la **polarité fail-safe** de `PhaseRotationOk_DI`.
- **AC2** : `G200_check_linkage.py --report` **PASS**, bloc `Auto-vérification liaison` **collé** — prouvant que `ErrorPhaseRotation` atteint les **consommateurs finaux** (interlocks, sorties).
- **AC3** : le défaut est **injectable** en simulation **sans** casser le comportement de production (preuve : le test échoue si l'injection est retirée — **ROUGE avant / VERT après**).
- **AC4** : le déclenchement du défaut entraîne, sur **M1, M2 et M3** : `SafeStop` actif, permis annulés, **freins serrés**, **relais/contacteurs forcés FALSE** — preuve par test (valeurs observées), pas par lecture d'intention.
- **AC5** : **aucun réarmement automatique** : retour des phases OK → axes **toujours bloqués** ; `Reset` **hors front** → aucun effet ; cause encore présente → **re-verrouillage immédiat au même scan**.
- **AC6** : les **bypass** sont encadrés (niveau d'accès + traçabilité + visibilité IHM) — ou l'écart est **formellement signalé** comme risque à arbitrer (ne pas l'implémenter sans décision).
- **AC7** : **la chaîne d'arrêt d'urgence physique n'est ni modifiée ni contournée** ; `git diff --numstat` documenté, aucune temporisation moteur/frein modifiée.
- **AC8** : messages IHM conformes et non trompeurs : `[M1]/[M2] ErrorID:05`, `[M3] ErrorID:03`, `PreflightErrorId` bit `16#0100`.

---

## 6. PÉRIMÈTRE ET INTERDITS

| | |
|---|---|
| **Probablement nécessaire** | `FB_SimBench.st` (injection simu), le fichier de test CI concerné, la note d'application |
| **Sous réserve d'arbitrage humain** | `FB_Safety_Winch.st`, `FB_Safety_Translation.st`, `PRG_06_Outputs.st`, `FB_WinchOutputInterlock.st`, `FB_TranslationOutputInterlock.st`, `FB_Acquisition_Preflight.st` |
| ⛔ **INTERDIT** | `CODE/B_AU_SECURITE/**` · **toute** modification qui **affaiblit ou contourne l'AU physique** · `DOC/AF/**`, `DOC/STDS/**` (lecture seule) · `PRJ_CODESYS/**` · `Device.export` · **toute** modification de temporisation moteur/frein sans contrat dédié |

---

## 7. PREUVES ATTENDUES DANS LA RESTITUTION

1. Réponses Q1→Q5 avec **preuve fichier:ligne** (et marquage `VÉRIFIÉ / DÉDUIT / INDÉTERMINÉ`).
2. Bloc **`Auto-vérification liaison`** (G200 `--report`) **collé**.
3. **ROUGE avant / VERT après** pour l'injectabilité et pour la réaction des 3 axes.
4. `git diff --numstat` des fichiers touchés + **VIDE** sur le périmètre interdit du §6.
5. Bundle complet **et** diff bundle (avec la liste des objets), bandeaux standard.
6. Ce qui **reste à prouver sur machine** (action humaine), listé explicitement.

## 8. CE QUE L'ORCHESTRATEUR VÉRIFIERA SUR LE RAPPORT RENVOYÉ

Lecture du **`git diff` réel** (jamais la restitution seule) · **rejeu** des preuves · **AC un par un** (refus si une preuve manque) · **périmètre** (`B_AU_SECURITE/**` et temporisations **intacts**) · cohérence entre ce qui est **affirmé** et ce qui est **mesuré** · puis **visa** dans le contrat de tâche ou **rejet motivé**.

> ⛔ **Ce brief n'est pas un GO** : il cadre le travail. Le GO est la validation humaine de la **phase 0**, et un **arrêt humain séparé** est exigé avant toute correction touchant la chaîne de sécurité.
