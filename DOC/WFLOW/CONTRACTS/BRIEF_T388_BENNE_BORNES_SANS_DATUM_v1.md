# 📋 BRIEF — BORNES BENNE **RELATIVES À UN DATUM INVALIDE** (au boot, M1/M2 non référencés)
## v1 — PRÊT À TRANSMETTRE · tâche **T388** · parent **T364** (homing)

> 📅 2026-09-22 · 🏷️ Rédacteur : **DSH01** (orchestrateur) · ⚡ **Défaut constaté en session par l'exploitant** (recette du 22/09, homing repris sur T364)
> 🔎 **Faits VÉRIFIÉS de première main par l'orchestrateur** (§2, fichier:ligne) · 🎯 Objectif : **libérer la benne tant que le datum n'est pas valide — sans jamais retirer la protection physique**

---

## 0. PRÉAMBULE OBLIGATOIRE (`TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — à lire en entier)

**CODESYS 3.5**, machine de dragage réelle. Code ST dans `CODE/`, appliqué manuellement par l'exploitant. **Sécurité machine réelle.**

**Persona** : Expert Senior Automatisme / Sécurité Machine (ISO 13849) / CI-CD. **Challengeur anti-Yes-Man** : ce brief n'est pas parole d'évangile — s'il est faux, le dire **avant** d'agir. Distinguer **faits / hypothèses / incertitudes**. Répondre en **français**, direct.

**Interdits** : ⛔ aucun commit/push sans accord humain explicite · ⛔ toute modification exige une validation préalable · ⛔ `PRJ_CODESYS/…/Device.export` · ⛔ scratch à la racine · ⛔ **élargir le scope = signaler, jamais décider**.

**Cas d'arrêt** : spec ambiguë · nommage indécidable · interface FB incomplète · `Reset` hors front · redémarrage automatique après défaut · **toute modification qui retirerait une protection physique**.

**Devoir d'alerte** : toute incohérence, bug préexistant, risque hors scope ou doute de sécurité remonte **immédiatement**.

**Vérification mécanique** (à chaque livraison) :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers .st touches>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report      # BLOQUANT -> coller le bloc
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
🔒 **Règle de preuve imposée** : toute mesure **épingle la révision** (`git hash-object <fichier>`, en précisant que le hash porte sur le **blob**, pas sur le fichier de travail). Un snapshot avant/après est un **complément**, jamais une preuve suffisante.

---

## 1. OBJECTIF (une phrase)

**Au démarrage (`HX0`), tant que M1/M2 ne sont pas référencés, les BORNES RELATIVES de benne ne doivent PLUS brider le jog benne — la protection PHYSIQUE reste, elle, intégralement active.**

---

## 2. LE FAIT — constat exploitant + mesure orchestrateur

**Constat en session (22/09)** :
```
boot : HX0 - M1+M2 NON references  -> homing unitaire possible            OK
je peux bouger la benne au joystick                                       OK
MAIS M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits = 1
     -> « il ne faut pas etre limite car M1/M2 pas homed »
WinchSel := 2                                                             (selecteur unitaire M2)
```

**Mesure de première main (orchestrateur)** :
```text
CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketCmd.st:18
    TglManualBucketLimits : BOOL := TRUE;   // « jog unitaire M2 borne + palier 1 par defaut »

CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketHMIState.st:13
    ManualBucketLimitsActive  // « Butées relatives benne actives en jog M2 MANUEL
                              //  (TglManualBucketLimits ET selecteur arbitre = 2, hors phase T248) »

CODE/M_MAIN/PRG_04_Treuils_Benne.st:787-789   <-- LA CONDITION D'ACTIVATION
    ManualBucketLimitsActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits
      AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2)
      AND NOT PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked;

CODE/M_MAIN/PRG_04_Treuils_Benne.st:807  <-- BORNE RELATIVE (ouverture)
    AND NOT (ManualBucketLimitsActive AND (EncoderM2.CablePosM <=
              (EncoderM1.CablePosM + Cfg.OffsetOpenM + Cfg.OpenAnticipationM)))
CODE/M_MAIN/PRG_04_Treuils_Benne.st:818  <-- BORNE RELATIVE (fermeture)
    AND NOT (ManualBucketLimitsActive AND (EncoderM2.CablePosM >=
              (EncoderM1.CablePosM + Cfg.OffsetCloseM - Cfg.CloseAnticipationM)))
```

### 🎯 Le défaut, en une ligne
Les bornes sont **relatives à `M1_CablePosM`** — donc elles supposent un **datum valide**. Or la condition d'activation (`:787`) **ne contient AUCUNE vérification de référencement / fiabilité** (`HomedM1`, `HomedM2`, `HomedAndReliableM1/M2`, `BucketReferenced`). **Au boot, les positions ne sont pas référencées : les bornes calculées sont alors dénuées de sens et peuvent refuser tout mouvement de benne** — c'est le symptôme constaté.

**Les notions de validité EXISTENT déjà dans le projet** (à réutiliser, ne rien inventer) :
```text
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:34/35   HomedM1 / HomedM2
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:36/37   HomedAndReliableM1 / HomedAndReliableM2
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:206-207 HomingPositionValid := HomedAndReliableM1 AND HomedAndReliableM2 ...
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:419-420 BucketState.BucketReferenced := TRUE  (si HomedAndReliableM1 ET M2)
```

**ET LA PROTECTION PHYSIQUE, ELLE, DOIT RESTER** (c'est le point de sécurité du lot) :
```text
CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:114-115  RecoilLimitReachedNow / RecoilLimitActive
                                                 « Recul au bord de la frontiere PHYSIQUE benne »
```

---

## 3. CORRECTIF ATTENDU (direction, pas implémentation)

1. **Gater les bornes RELATIVES par la validité du datum** : `ManualBucketLimitsActive` doit devenir **FALSE** tant que les positions ne sont pas exploitables (réutiliser **la condition existante** — `HomedAndReliableM1 AND HomedAndReliableM2` et/ou `BucketState.BucketReferenced` — **sans créer de nouvelle variable d'état**).
2. **NE PAS toucher à la limite PHYSIQUE** (`RecoilLimit*`) : elle **doit rester active** en toutes circonstances ⇒ un jog benne non référencé reste **borné par la mécanique**.
3. **Informer l'opérateur** : si un geste benne est refusé **ou** si les bornes relatives sont désactivées faute de datum, **le message doit le dire** (pas de refus silencieux — cf. le lot T375).
4. **Aucune modification** des permis, de la chaîne de sécurité, des temporisations moteur/frein, ni des seuils `OffsetOpenM/OffsetCloseM/anticipations`.

---

## 4. PHASAGE

```text
PHASE 0 — MESURER (lecture seule, OBLIGATOIRE, aucun code)
  Reproduire en simulation avec WinchSel=2 et TglManualBucketLimits=TRUE :
    (a) M1/M2 NON references  -> la benne est-elle refusee ? relever les 2 comparaisons :807/:818
        avec les valeurs reelles de EncoderM1/M2.CablePosM (positions non referencees) ;
    (b) M1/M2 references       -> les bornes se comportent-elles correctement (non-regression) ?
  Livrable : tableau (positions lues / comparaison / decision mouvement) + conclusion.
  ⛔ ARRET HUMAIN : restitution + arbitrage AVANT toute ecriture (le lot touche un chemin de COMMANDE).

PHASE 1 — CORRIGER (apres GO)
  Ajouter la condition de validite du datum a la SEULE activation des bornes relatives.
  Ne pas deplacer la logique, ne pas la dupliquer, ne pas toucher aux seuils.

PHASE 2 — PROUVER
  Test CI ROUGE avant / VERT apres + test de MUTATION (datum retire => le cas echoue).
  Test dedie : « datum invalide => bornes relatives INACTIVES et benne libre » ET
               « datum valide => bornes relatives ACTIVES (non-regression) » ET
               « protection physique TOUJOURS active dans les deux cas ».

PHASE 3 — RECETTE MACHINE (action HUMAINE)
  Au boot HX0 : bouger la benne au joystick (WinchSel=2) => mouvement possible ;
  referencer M1/M2 puis benne => bornes de nouveau actives.
```

---

## 5. CRITÈRES TESTABLES

- **AC1** : `ManualBucketLimitsActive` est **FALSE** (ou inopérant) quand M1/M2 ne sont pas référencés/fiables ⇒ **le jog benne n'est plus bridé par une borne relative**.
- **AC2** : `ManualBucketLimitsActive` reste **TRUE** et les bornes restent appliquées **quand le datum est valide** ⇒ **zéro régression** sur le jog borné normal.
- **AC3** : **la limite PHYSIQUE de recul reste active dans les DEUX cas** (`RecoilLimitActive`) ⇒ preuve explicite, c'est **la** condition de sécurité du lot.
- **AC4** : aucune nouvelle variable d'état / aucun nouveau paramètre persistant / aucun bypass ⇒ réutilisation des notions existantes.
- **AC5** : un refus de mouvement benne est **nommé à l'IHM** (pas de refus silencieux) ; message ≤ 70 car.
- **AC6** : **ROUGE avant / VERT après** + **mutation** (retirer la condition de datum ⇒ le test AC1 échoue) ; **révision épinglée** (`git hash-object`) ; **`G200 --report` collé** ; palier C sans rouge nouveau.

---

## 6. PÉRIMÈTRE ET INTERDITS

| | |
|---|---|
| **Attendu** | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (la condition d'activation) · le **fichier de test CI** de l'entrée concernée · une note d'application |
| **Probable (à justifier)** | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` **uniquement** si la validité du datum y est déjà calculée et non exportée |
| ⛔ **INTERDIT** | `CODE/B_AU_SECURITE/**` · toute temporisation moteur/frein · tout **bypass** · les seuils `Offset*`/anticipations · `DOC/AF/**`, `DOC/STDS/**`, `PRJ_CODESYS/**`, `Device.export` |

🚨 **COLLISION D'ÉCRITURE** : `PRG_04_Treuils_Benne.st` et `FB_Safety_Winch.st` sont **au cœur de lots en cours** (T387 fenêtre benne, T381, T386-B). **Un seul écrivain par fichier** : relire `git status` **juste avant** chaque écriture, et **ne jamais** réécrire un fichier en bloc.

---

## 7. PREUVES ATTENDUES

1. Tableau de phase 0 (positions lues / comparaisons :807/:818 / décision).
2. **ROUGE avant / VERT après** pour AC1, AC2, AC3 (+ mutation).
3. `git hash-object` des fichiers touchés + `git diff --numstat` + **diff bundle** (objets listés).
4. Bloc **`Auto-vérification liaison`** (G200 `--report`) collé.
5. Ce qui reste à observer **sur machine** (action humaine).

## 8. CE QUE L'ORCHESTRATEUR VÉRIFIERA

Lecture du **`git diff` réel** · rejeu des preuves · **AC un par un** · **la protection physique TOUJOURS active** (vérification n°1) · aucune protection retirée · **révision épinglée** · puis **visa** ou **rejet motivé**.

> ⛔ **Ce brief n'est pas un GO code** : la phase 0 est en lecture seule, son résultat doit être **arbitré avant** toute écriture.
