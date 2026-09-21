# 🕵️ Session de Troubleshooting — T367 : réarmement AU vs acquittement défauts

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T367_REARMEMENT_ACQUITTEMENT_20260921.md`
> 📅 Date : 2026-09-21 · 🧊 Situation : [SITE] observation exploitant 2026-09-21 · 📄 Statut : [RÉSOLUE] (verdict doctrinal tranché) — correctif **non** implémenté
> 🏷️ Acteur : DSH26 · 🔒 Verrou : T367 · Cible catalogue : T367 (C2, domaine `SECURITE_ET_AU / IHM`)

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte

Observation exploitant du **2026-09-21** (verbatim catalogue T367) : *« au réarmement, il faut appuyer sur
2 boutons distincts — le réarmement physique du contacteur AU (`PowerContactorEngaged_DI`) ET un bouton
logiciel séparé d'acquittement défaut (`GVL_IHM BtnFaultReset` → `FaultMachineReset_IHM`). Juge absurde :
un arrêt d'urgence a un bouton d'arrêt et un bouton de réarmement, pas deux réarmements. »*

Question posée par le brief T367 : **pourquoi les deux étaient-ils séparés — doctrine ou oubli ?**

Ancrage : arbre de travail au **2026-09-21T08:07+02:00**. `CODE/` **non propre vs HEAD** (lots T364 et
simulation en vol, cf. `git status --short -- CODE`) — l'analyse ci-dessous porte sur le **contenu réel
des fichiers lus**, chaque constat étant référencé `fichier:ligne`.

### Variables & valeurs

| Élément | Variable / référence complète | Valeur / état | Horodatage |
|---|---|---|---|
| Réarmement physique (retour HW) | `PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI` (`CODE/M_MAIN/PRG_02_Acquisition.st:188`) | BOOL, consommé par `FB_Safety_EmergencyManagement.PowerContactorEngaged` (`:233`) | 2026-09-21T08:07 |
| Acquittement logiciel (producteur) | `PRG_07_Supervision.FaultMachineReset_IHM` (`CODE/M_MAIN/PRG_07_Supervision.st:18`) | produit `:123` depuis `GVL_IHM.Modes.Cmd.BtnFaultReset` | 2026-09-21T08:07 |
| Portée du reset | sites d'appel `FaultMachineReset_IHM` dans `CODE/**/*.st` | **31 occurrences / 7 fichiers** (PRG_02 ×6, PRG_04 ×10, PRG_05 ×4, PRG_06 ×5, PRG_07 ×4, PRG_03 ×1, `FB_Hmi_BannerFormatter` ×1) | 2026-09-21T08:07 |
| Commande d'armement opérateur | `GVL_IHM.Emergency.Cmd.BtnEmergencyArming` → `FB_Safety_EmergencyManagement.ArmRequest` (`CODE/M_MAIN/PRG_06_Outputs.st:487`) | front, jamais automatique | 2026-09-21T08:07 |
| Écrivain de `BtnFaultReset` | `grep 'BtnFaultReset\s*:='` sur `CODE/**/*.st` | **0 résultat** → écrit par l'**IHM externe** (Kobold), hors PLC | 2026-09-21T08:07 |
| Doctrine §7.3/§7.4 | `DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md:360` et `:370/:372` | « deux actions **distinctes** » / « acquitter **puis** réarmer » | introduite le 2026-08-26 |
| Origine historique de la séparation | commit `8116e79d` (2026-07-07, Mathieu Gros) | message : « **split Reset signals** » | 2026-07-07T16:02 |

## 2. 🎯 Symptôme

Deux gestes distincts exigés de l'opérateur pour repartir après un arrêt/défaut : **armer la chaîne AU**
(un appui) puis **acquitter les défauts** (un second appui) — permanence du comportement, à chaque
récupération (`T367` : « juge absurde »).

## 3. 🧩 Indices / historique

- **Archéologie Git (décisive)** :
  - `8116e79d` — 2026-07-07T16:02, auteur **Mathieu Gros** (humain), message :
    *« encoders, modes, joystick: fix simulation aiguillage bug, **split Reset signals**, remove PasswordOk gate »*.
    Le diff de ce commit **crée** les affectations `Reset := PRG_09_Supervision.FaultMachineReset_IHM`
    (≈20 sites) **et** sépare explicitement les resets dédiés, avec ce commentaire toujours présent dans
    le code d'aujourd'hui : `// 🔧 REX 2026-07-07 : dédié, jamais mélangé au reset défauts général`
    (aujourd'hui `CODE/G_CYCLE/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st:9`).
    ➡️ La séparation n'est pas un état initial subi : c'est une **décision corrective datée**, prise après
    retour d'expérience, dont la leçon est **encore écrite dans le code courant**.
  - `b599d031` — **2026-08-26**, auteur **Mathieu Gros**, *« docs(af): mise en conformite AF-01
    (chaine AU/reamement) + fiche FB_Safety_EmergencyManagement v1.2 »* : c'est ce commit qui **écrit la
    phrase de doctrine** « Acquittement d'un defaut metier et rearmement du contacteur = deux actions
    distinctes » (`AF_Partie-01…v2.1.md:360`) et la table §7.4.
- **Derniers changements** : aucun changement récent sur ce point (la doctrine est stable depuis le
  2026-08-26 ; le câblage du `Reset` AU n'a jamais été relié à `PowerContactorEngaged` — `git log -S`
  sur la forme `Reset := …FaultMachineReset_IHM` dans `PRG_02_Acquisition.st` = **0 résultat**).
- **Déjà essayé** : rien — aucune tentative de fusion tracée dans le catalogue ni dans les REX.
- **Alarmes** : sans objet (pas de défaut machine ; sujet d'ergonomie de récupération).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| H1 | **Doctrine écrite** : acquitter et réarmer sont 2 actions distinctes par choix | Texte de spec | existence d'une règle explicite (AF-01 §7.3) | `AF_Partie-01…v2.1.md:360` « deux actions distinctes » + §7.4 `:370/:372` « acquitter **puis** réarmer » | ✅ **CONFIRMÉE** |
| H2 | **Doctrine répétée dans le code** (pas seulement dans la doc) | Commentaire d'interface du FB AU | le code cite la règle | `FB_Safety_EmergencyManagement.st:192-193` : « Conforme AF-01 §7.4 […] acquitter est une action distincte du réarmement » | ✅ CONFIRMÉE |
| H3 | **Doctrine portée jusqu'à l'IHM** (le poste de conduite guide l'opérateur dans cet ordre) | Checklist safety IHM | séquence documentée | `ST_SafetyChecklist.st:26` : « Armable ; **acquitter si nécessaire puis** générer un front BtnEmergencyArming » | ✅ CONFIRMÉE |
| H4 | **Interdit normatif explicite** sur la forme proposée | Standard qualité §9 | la forme `reset` liée à `PowerContactorEngaged` est-elle admise ? | `CODE_QUALITY_STANDARDS.md:670-679` : contre-exemple ❌ **littéral** `IF ResetEdge.Q THEN IF PowerContactorEngaged THEN…` → « Reset conditionné par un état externe » | ✅ CONFIRMÉE (forme **interdite**) |
| H5 | **Origine = décision corrective datée** (et non état initial) | Historique Git | commit d'introduction | `8116e79d` (2026-07-07) « **split Reset signals** » + REX « jamais mélangé au reset défauts général » | ✅ CONFIRMÉE |
| H6 | **Simple oubli / câblage manquant** | Écart entre spec et câblage | le code contredit la spec | aucun écart : le code **applique** la spec (H2), la doc est **datée et humaine** (H5) | ❌ **RÉFUTÉE** |
| H7 | **Ergonomie voulue par l'exploitant** (2 gestes = 2 intentions) | AF-01 §7.3 | la séparation est-elle motivée en ergonomie ? | §7.3 `:356-360` : « Jamais automatique », « Front commande opérateur seulement », « deux actions distinctes » → séparation **voulue**, mais **aucune justification d'ergonomie opérateur** n'est écrite | ❓ **PARTIELLE** — c'est le point d'arbitrage réel de T367 |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
QUESTION T367 : pourquoi rearm physique et acquittement logiciel sont-ils séparés ?

├── BRANCHE A — « oubli de câblage ? »
│   └── [spec AF-01 §7.3 :360] "deux actions distinctes" :STRING ✅ DOCTRINE ÉCRITE
│       ├── [code AU :192-193]   cite AF-01 §7.4          :BOOL=1 ✅ cohérent
│       ├── [checklist IHM :26]  "acquitter puis armer"   :BOOL=1 ✅ cohérent jusqu'à l'IHM
│       └── [STD §9 :670-679]    forme proposée = ❌ interdit
│           ➔ H6 (OUBLI) : ❌ RÉFUTÉE — aucune divergence spec/code
│
├── BRANCHE B — « doctrine ? »  ➔ ✅ OUI
│   ├── [2026-07-07 8116e79d] "split Reset signals", Mathieu Gros (humain)
│   │   └── [ST_CycleCmd.st:9] "REX 2026-07-07 : dédié, JAMAIS MÉLANGÉ" :BOOL=1 ✅ leçon encore active
│   └── [2026-08-26 b599d031] doctrine formalisée AF-01 §7.3/§7.4 (humain)
│       ➔ séparation = DÉCISION CORRECTIVE DATÉE, pas un état subi
│
└── BRANCHE C — « l'ergonomie opérateur a-t-elle été arbitrée ? »
    ├── [AF-01 §7.3 :356-358] "jamais automatique" / "front opérateur seulement" :BOOL=1 ✅
    ├── [justification d'UX]  AUCUNE :STRING="" ❌
    └── [observation T367]    2 gestes vécus comme absurdes :BOOL=1 ❌
        ➔ ❓ TROU RÉEL = le CANAL du geste, pas la séparation des ACTIONS
           (arbitrage humain : option A retenue — 1 bouton IHM séquencé)
```

**Résumé une ligne** : `[AF-01:360 doctrine=1] → [code AU:192 cohérent=1] → [STD:670 forme proposée=0] → [8116e79d split=1] ⇒ séparation DOCTRINALE, jamais un oubli ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais

- Lecture `FB_Safety_EmergencyManagement.st:189-208` (§4 acquittement) : `ResetEdge.Q → Ack := TRUE`,
  purge des causes d'auto-test ; commentaire de doctrine `:192-196`.
- Lecture `FB_Safety_EmergencyManagement.st:257-277` (§5 préconditions) :
  `Armable_NoBlock := NOT EmergencyArmingLockoutActive AND NOT PowerContactorEngaged` — l'armement
  **exige le contacteur au repos**, donc le front de réarmement **arrive après** l'armement, jamais avant.
- Lecture `FB_Safety_EmergencyManagement.st:400-427` (§5 étape CONFIRM) :
  `IF PowerContactorEngaged OR BypassArmingPreconditions THEN …` — sous **bypass MES**, la confirmation
  est validée **sans retour contacteur réel** : `PowerContactorEngaged` peut ne **jamais** monter au banc.
- Lecture `FB_AutoResetTransientDiag.st:1-10` : ce FB **implémente déjà** le pattern « front contacteur →
  impulsion de reset », avec un cadrage **explicite** : « ⛔ Ce FB ne reset **jamais** la chaîne AU, les
  sécurités mouvement, les codeurs de sécurité, les contacteurs, les freins ou les défauts mécaniques ».
  ➡️ Le besoin a déjà été rencontré et **volontairement borné**.
- `git log -S "deux actions distinctes" -- DOC/AF` → 1 commit d'écriture : `b599d031` (2026-08-26).
- `git log -S "FaultMachineReset_IHM" -- CODE` (ordre chronologique) → 1ᵉʳ commit = `8116e79d`
  (« split Reset signals »).
- `grep 'BtnFaultReset\s*:=' CODE/**/*.st` → **0 écrivain PLC** : la commande vient de l'IHM externe.

### Chronogramme (geste opérateur actuel vs geste proposé)

| Événement | `BtnEmergencyArming` (CMD) | `PowerContactorEngaged` (HW) | `FaultMachineReset_IHM` | Défauts latés |
|:---:|:---:|:---:|:---:|:---:|
| T1 — défaut présent, chaîne non armée | 0 | 0 | 0 | █ latché |
| T2 — opérateur appuie « Armer » | █ front | 0 | 0 | █ latché |
| → séquence (test A/B → pulse → confirm) | 0 | 0 → █ | 0 | █ latché |
| T3 — contacteur confirmé | 0 | █ | **0 (état actuel)** | █ latché |
| T4 — opérateur appuie « Reset défauts » | 0 | █ | **█ front** | 0 effacé |
| **T3′ — variante T367 (fusion)** | 0 | █ front | **█ auto** | 0 effacé **sans 2ᵉ appui** |

⬆️ La variante T367 supprime T4 en générant le front d'acquittement **sur un état matériel** (`T3′`).
C'est précisément la forme interdite par `CODE_QUALITY_STANDARDS.md:670-679`, et cela applique le front
d'acquittement aux **31 sites d'appel** (tous domaines) sans vérifier que la **cause a disparu**.

## 7. 🏁 Conclusion

- **Cause racine** : les deux gestes sont séparés **par doctrine écrite et datée**, à deux niveaux :
  1. **2026-07-07** (`8116e79d`, Mathieu Gros) — la séparation des resets est une **décision corrective**
     issue d'un REX (« dédié, jamais mélangé au reset défauts général »), toujours citée dans le code
     courant (`ST_CycleCmd.st:9`).
  2. **2026-08-26** (`b599d031`, Mathieu Gros) — formalisation AF-01 §7.3/§7.4 :
     « acquittement d'un défaut métier et réarmement du contacteur = **deux actions distinctes** »,
     « acquitter **puis** réarmer », « jamais automatique ».
  Puis relayée jusqu'à l'IHM (`ST_SafetyChecklist.st:26`), l'interface de commande
  (`ST_EmergencyCmd.st:16`) et le socle standard (`CODE_QUALITY_STANDARDS.md:670-679`).
- **Verdict sur la question du brief** : **DOCTRINE — pas un oubli** (7 hypothèses instruites, H6 réfutée
  sur preuve, aucune divergence spec/code détectée).
- **Trou réel identifié** : la doctrine tranche la **séparation des actions**, elle ne justifie **pas**
  l'obligation de **deux gestes physiques distincts** côté opérateur. Le manque est donc **d'ergonomie
  IHM**, pas de câblage — ce qui ouvre une voie de correction **sans toucher à la sécurité**.
- **Statut** : RÉSOLUE (question tranchée) — **aucun code modifié**, aucun commit.

## 8. 🛠️ Proposition de correction

> Arbitrage humain rendu le **2026-09-21T08:1x** : **option A — fusion UX IHM uniquement**
> (bouton unique qui enchaîne *acquitter PUIS réarmer*). **Zéro** touche au câblage de sécurité,
> **zéro** modification de la doctrine AF-01/STD.

- **Option 1 retenue (immédiat, PLC non touché)** — bouton unique côté **IHM externe** (macro qui écrit
  `BtnFaultReset` puis `BtnEmergencyArming`, dans cet ordre, 2 fronts successifs).
  - ✅ Répond exactement au grief (« un seul geste »).
  - ✅ **Aucune** ligne de `CODE/` : ni nouvelle variable, ni nouveau trigger → **risque machine nul**.
  - ⚠️ Hors dépôt PLC → doit être tracé comme évolution de l'interface IHM (`AF_Partie-07`), pas comme
    lot ST. Vérifier que l'IHM sait générer 2 fronts séquencés ; sinon basculer sur l'option 2.
  - ⚠️ Contrainte d'ordre **non négociable** : acquitter **puis** réarmer (AF-01 §7.4) — l'inverse
    ferait acquitter sur une chaîne déjà armée, c'est-à-dire hors de l'esprit de la spec.
- **Option 2 (définitif, PLC)** — séquence PLC : sur **front de la commande opérateur**
  (`ArmRequest`/`BtnEmergencyArming`, geste humain prouvé), émettre 1 impulsion `FaultMachineReset_IHM`
  **puis** lancer la séquence d'armement ; garde **cause disparue** par domaine et **exclusion** des
  causes latées AU/mouvement.
  - ⚠️ Modifie le sens de la doctrine (AF-01 §7.3 « deux actions distinctes ») → **amendement de spec
    obligatoire** avant tout code, + contrat C2 + test CI **rouge avant**.
- **Option 3 (REJETÉE)** — front de `PowerContactorEngaged` → `FaultMachineReset_IHM` automatique
  (brief initial littéral). Rejet argumenté :
  1. **forme interdite** (`CODE_QUALITY_STANDARDS.md:670-679`, contre-exemple littéral) ;
  2. **réarmement automatique** (`ST_EmergencyCmd.st:16`, AF-01 §7.3 « jamais automatique ») ;
  3. **portée machine entière** : 31 sites d'appel, 7 fichiers, tous domaines → acquitte des latches dont
     la **cause persiste** (viole « cause disparue + appui conscient », objectif 3 de T367) ;
  4. **inopérant au banc/MES** : sous `BypassArmingPreconditions`, la confirmation est validée sans retour
     contacteur (`FB_Safety_EmergencyManagement.st:417`) → le front n'arrive jamais ;
  5. **séparation déjà arbitrée après REX** (`8116e79d`) → réintroduirait le problème d'origine.
- **⚠️ Validation requise** : [humaine] — le choix du canal d'implémentation (IHM seule vs séquence PLC)
  est **requis avant** tout contrat TASK_CONTRACT_T367 et tout code.

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ Hand-off humain : la correction (§8) doit être validée avant application. Aucun code n'a été modifié.

- **Option 1 (IHM seule)** : essai banc — 1 appui → la chaîne s'arme **et** le bandeau se vide ;
  vérifier qu'aucun défaut dont la cause persiste n'est effacé (relâcher puis re-provoquer la cause) ;
  vérifier l'ordre des deux fronts à l'oscilloscope/trace (`BtnFaultReset` avant `BtnEmergencyArming`).
- **Option 2 (PLC)** : test CI **écrit et exécuté rouge avant** le correctif (exigence du brief) ;
  cas à couvrir : front commande opérateur → acquittement unique + armement ; **cause encore présente →
  jamais acquittée** ; causes AU/mouvement **exclues** ; `Enable=FALSE` ; bypass MES.
- **Non-régression attendue** : aucun test existant ne porte sur un trigger matériel du reset
  (`BtnFaultReset` n'a **aucun** écrivain PLC) → l'option 1 ne peut pas régresser la CI ;
  l'option 2 doit prouver `delta = 0` sur les rouges préexistants (palier C).
- **Preuves obligatoires avant restitution** (si option 2) : bundle complet + diff bundle + `G200 --report`
  + palier C **avant/après**.

## 10. 📝 Journal (chronologique)

- **2026-09-21** : création de T367 (C2, `SECURITE_ET_AU / IHM`) sur observation exploitant.
- **2026-09-21T08:07** : prise du sujet par DSH26 ; relevé du contenu réel des fichiers (ancrage ci-dessus).
- **2026-09-21T08:1x** : archéologie Git — `8116e79d` (2026-07-07, « split Reset signals », REX
  « jamais mélangé ») et `b599d031` (2026-08-26, doctrine AF-01 §7.3/§7.4), tous deux de la main de
  l'humain → **verdict : DOCTRINE, pas un oubli**.
- **2026-09-21T08:1x** : **arbitrage humain** — option A retenue (fusion **UX IHM** uniquement, bouton
  unique séquencé *acquitter puis réarmer*), rejet argumenté du brief littéral (front contacteur).
- **2026-09-21T08:1x** : alerte tracée avant tout code — le brief initial était porteur de 3 non-conformités
  (ordre inversé, trigger non humain, portée machine entière).
- **À suivre** : décision humaine sur le **canal** d'implémentation (IHM seule / séquence PLC) →
  contrat `TASK_CONTRACT_T367_*.yaml` → preuve CI rouge avant → implémentation → gates.

---

📖 **Documentation complète** (comment remplir chaque section, exemples) : `GUIDE_Troubleshooting.md` (même dossier).
