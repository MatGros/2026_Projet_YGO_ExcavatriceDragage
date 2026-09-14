# 🚨 ALERTE — Permis directionnels non intégrés à la barrière finale (treuils M1/M2)

- **Date** : 2026-09-01
- **Auteur** : Orchestrateur DSH (consolidation audits T216)
- **Niveau** : 🚨 **ALERTE SÉCURITÉ — à trancher humainement avant poursuite**
- **Machine** : dragage en carrière noyée (sécurité réelle)

---

## 1. Le problème en une phrase

> **Les permis directionnels (montée/descente, y compris Both agrégé) ont été créés pour bloquer physiquement le mouvement — mais ils ne sont PAS câblés à la barrière finale `FB_WinchOutputInterlock`.** Ils n'interdisent le mouvement que par la rampe interne de `FB_Winch`. Un test banc le confirme : **FDC max length = 1, et la descente reste possible.**

---

## 2. Preuve par le code (fichier:ligne)

### La coupure par le permit existe au niveau RAMPE uniquement

| Étape | Fichier:ligne | Rôle |
|---|---|---|
| Permit produit | `FB_Safety_Winch.st:455-464` (`DescendPermit`), `:466-474` (`AscentPermit`) | interlock directionnel |
| Permit effectif | `PRG_04:823-826` (`EffectivePermitM*/_Ascent/_Descend`) ; Both agrégé `:873-874` | fusion safety+process+safestop+couplage |
| Routage Both/unité | `PRG_04:996-999` (`M1/M2*PermitUse := SEL(WinchBothMotionActive, Effective, Both)`) | choix du permit consommé |
| Input `FB_Winch` | `PRG_04:1047-1048` (`DescendPermit := M1DescendPermitUse`, `AscentPermit := M1AscentPermitUse`) | entre dans le gate |
| **Gate de rampe** | `FB_Winch.st:163` (`EffectiveSafeStop := SafeStop OR (dir>0 AND NOT AscentPermit) OR (dir<0 AND NOT DescendPermit)`) | ✅ coupure rampe |
| **Résultat rampe** | `FB_Winch.st:205` (`RampTargetStep:=0`), `:267-276` (`RelayFwd/Rev`) | StepNumber=0 → relay off |

### La barrière finale ne voit PAS le permit — c'est le trou

| Étape | Fichier:ligne | Rôle |
|---|---|---|
| Barrière M1 | `PRG_06_Outputs.st:112-116` `instWinchOutputInterlockM1(SafeStop := WinchM1FinalInterlockRequest.SafeStop)` | son SafeStop = **défauts + couplage synchro**, PAS le permit |
| Barrière M2 | `PRG_06_Outputs.st:185-189` (idem) | idem |
| Définition SafeStop barrière | `PRG_04:817-818` (`SafeStopM*/_Active`) | dérivé de SafeStopM*/_Raw + synchro, **jamais du permit** |
| Coupure barrière | `FB_WinchOutputInterlock.st:164-167` (commentaire « SafeStop coupe RelayFwd/Rev/contacteurs/frein indépendamment de FB_Winch ») ; `:168` (`MotorRequest`) ; `:412-428` (§5) | la coupure dure existe, mais sur SafeStop/PowerCutOff uniquement |

> **Conséquence** : il n'existe **aucun chemin** où un permit FALSE force matériellement la barrière finale à couper. La seule interdiction est logique (rampe `FB_Winch`), dépendante du bon fonctionnement de ce FB. En défense en profondeur, c'est **insuffisant** : si `FB_Winch` est contourné ou son `EffectiveSafeStop` dégradé, la machine peut bouger hors permis.

---

## 3. Preuve physique (banc)

- Symptôme opérateur : **FDC (fin de course) max length = 1** → la descente des treuils **reste possible**.
- Cohérent avec le constat ci-dessus : le FDC descente est une cause du permit (`FB_Safety_Winch:455-457`), qui coupe la rampe — mais en banc, le mouvement est encore commandable ⇒ le veto ne tient pas jusqu'à la DQ.

---

## 4. Pourquoi c'est un vrai problème (et pas une nuance)

1. **C'est l'usage même des permis** : un permis directionnel a été introduit pour être la barrière de mouvement. S'il n'est pas consommé à l'acteur, sa création est **inefficace sur le plan de la sécurité mécanique**.
2. **AC2/AC3 de T216** (`TASK_CONTRACT_T216...yaml:26-34`) :
   - AC3 : « Un permis FALSE dans l'IHM/diagnostic interdit réellement la sortie correspondante » → **partiellement non satisfait** (interdit la rampe, pas la DQ en dernier recours).
   - AC2 : « Une commande Both ne produit jamais un départ isolé » → la coupure Both repose sur la rampe, pas sur une barrière commune.
3. **Sécurité multi-niveaux** : SafeStop et PowerCutOff ont bien une coupure dure à la barrière finale. Les permis, eux, n'en ont **pas**. Incohérence d'architecture de sécurité.

---

## 5. Ce qu'il faut décider (humain)

**Option A (recommandée) — défense en profondeur** : intégrer le permit à la barrière finale
- `FB_WinchOutputInterlock.st` : ajouter une coupure dédiée
  `EffectiveSafeStopFinal := SafeStop OR (dir<0 AND NOT DescendPermit) OR (dir>0 AND NOT AscentPermit)` coupant `RelayFwd/Rev` + contacteurs + frein (`:168`, `:412-428`).
- Câbler le permit (routage Both/unité `PRG_04:996-999`) vers le `SafeStop`/signal dédié de la barrière (`PRG_06_Outputs:116/189`).
- **Sans** générer de FAULT/latch, **sans** toucher `Enable`/`StartStop` : c'est une interdiction **momentanée** (le permit n'est pas un défaut), l'anti-redémarrage `RestartInhibit` reste intact.

**Option B — documenter la limite** : acter que les permis n'agissent que par la rampe (`FB_Winch`), et non à la barrière finale.
- Recommandé **seulement** si une analyse de risque (ISO 13849) prouve que la rampe suffit (FB_Winch infaillible). Compte tenu du test banc, **risque élevé** — déconseillé sans preuve.

---

## 6. Impact & priorité

- **Priorité** : 🚨 **BLOCK** pour la sécurité mécanique tant que la décision (A/B) n'est pas prise + implémentée.
- **Effet de bord** : raccorder le permit à la barrière doit être testé (pas de redémarrage auto, pas de blocage permanent, pas d'impact sur l'anti-redémarrage chaud 1,5 s).
- **Périmètre** : `FB_WinchOutputInterlock.st`, `PRG_06_Outputs.st`, `PRG_04` (routage), éventuellement `ST_*FinalInterlockRequest`, AF_Partie-10, tests CI `fix`+`guard`.

---

## 7. Liens

- Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T216_PERMITS_DIRECTIONNELS_UNIQUES.yaml` (AC2/AC3/AC6bis)
- Audit préalable : `DOC/WFLOW/AUDITS/AUDIT_PERMITS_DIRECTIONNELS_20260901.md`
- Devoir d'alerte connexe : S5 (`SpeedGuardEnable=FALSE`, `FB_WinchRateInterlock` inexistant)

**Statut** : ✅ ALERTE TRAITÉE — défense en profondeur implémentée (voir §7bis). Restent les gates pré-existants G100/G340/G390 à traiter séparément.

## 7bis. Correction implémentée (2026-09-01)

Conformément à la correction utilisateur (retirer la dépendance N-1 PRG_04→PRG_06 et déplacer la coupure en PRG_06) :

1. **PRG_04** — retiré `BothFinalInterlockReady` (lecture directe de `PRG_06_Outputs.instWinchOutputInterlockM1/M2`) et le bloc forçant les 2 `M*LogicRequestStartStop` sur cette donnée N-1. PRG_04 ne garde que les producteurs canoniques (`EffectivePermitM1/M2_*` + `BothAscentPermit`/`BothDescendPermit`).
2. **Publication** — `BothActive/BothAscentPermit/BothDescendPermit` déjà dans `ST_WinchInterPrg` et publiés dans `Data` (`PRG_04:1424-1426`).
3. **PRG_06 (défense en profondeur)** — avant les DQ M1/M2 :
   ```
   BothOutputAllowed := NOT BothActive
      OR ((demande montée M1/M2) AND BothAscentPermit)
      OR ((demande descente M1/M2) AND BothDescendPermit);
   IF BothActive AND NOT BothOutputAllowed THEN → relais+contacteurs+frein M1/M2 = 0;
   ```
   Le gate lit **les bits canoniques de PRG_04 via Data** (pas le Ready local). Aucun nouveau permit.
4. **Ready** — non utilisé pour autoriser le départ Both (retiré de PRG_04) ; reste un état local PRG_06 publié pour l'IHM/diagnostic.
5. **Vérif** : bundle 254/254 0 erreur, G200 PASS (0 erreur, 1649 instances), G430 PASS. Gates pré-existants G100/G340/G390 non imputables à cette correction.

**Chaîne nette** : PRG_04 produit le permis unique → FB_Winch coupe la demande → PRG_06 reconsomme ce permis et coupe physiquement les deux axes → PRG_07 affiche le même état.
