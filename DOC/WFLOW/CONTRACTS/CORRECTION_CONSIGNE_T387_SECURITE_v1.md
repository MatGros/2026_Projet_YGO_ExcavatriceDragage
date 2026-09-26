# 🛑 CORRECTION DE CONSIGNE — LOT T387 — URGENCE SÉCURITÉ
## v1 · 2026-09-22 · émetteur : DSH01 (orchestrateur) · **REMPLACE le point 4 du message précédent**

---

## ⛔ CE QUI EST ARRIVÉ — et pourquoi la consigne précédente était FAUSSE

Ma consigne précédente demandait d'**inhiber la cause 4** (`HomingMotionWithoutReference`) quand
`(Mode = MAINT_N1 OR MAINT_N2) AND NOT (HomedM1 AND HomedM2)`. **Elle a été appliquée** — le code en
working tree porte désormais :
```st
FB_Bucket.st ~:292-296
HomingMotionWithoutReference := (ReqAscent OR ReqDescend OR CmdOpen_IHM OR CmdClose_IHM OR ProgramBucketDriveActive)
  AND NOT MachineHomingActive
  AND NOT (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2)     <-- AJOUT
  AND NOT (HomedM1 AND HomedM2);
```

**J'avais supposé que la frontière physique restait active. C'EST FAUX.** Mesure de première main :
```st
FB_Bucket.st:446   ClassCanRun := HomedM1 AND HomedM2 AND NOT SevereError;
FB_Bucket.st:603   RecoilLimitReachedNow := ClassCanRun AND (...)
```
⇒ **sans datum (M1/M2 non référencés) `ClassCanRun` est FALSE ⇒ la frontière physique est INACTIVE.**

### 🚨 L'ÉTAT DANGEREUX QUE ÇA CRÉE (en MAINT / homing, M1/M2 non référencés)

| Barrière possible | État réel |
|---|---|
| Bornes **logicielles** benne | désactivées (spec HX1) |
| **Frontière physique** `RecoilLimitActive` | **INACTIVE** (`ClassCanRun` = FALSE) |
| **Alarme** cause 4 | **INHIBÉE** par la modification ci-dessus |
| **Butée mécanique** | **IL N'Y EN A PAS** — information exploitant : **la benne est suspendue par les câbles** |

⇒ **Aucune limite + aucune alarme + aucune butée** : l'opérateur peut **tendre les câbles à l'aveugle**.
C'est exactement le risque que la section **3bis** du brief `BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md`
demandait de **ne pas accepter sans vérification** (« benne pilotée à l'aveugle, sans FDC logiciel ET sans
position encodeur fiable »).

---

## ✅ CONSIGNE CORRIGÉE (3 actions, dans cet ordre)

### 1. REVENIR SUR L'INHIBITION — l'alarme cause 4 reste ACTIVE
La cause 4 est **vraie** : en homing les codeurs **ne sont pas référencés**, c'est un fait.
Elle est **NON LATCHANTE** (`FB_Bucket.st:298 Latching := FALSE`) ⇒ **elle n'empêche rien, elle informe.**
➡️ **Retirer le terme `AND NOT (Mode = MAINT_N1 OR Mode = MAINT_N2)`.**
Le défaut « `ErrorID:05` pendant le homing » **n'est pas un faux défaut** : c'est un **message mal contextualisé**.

### 2. CORRIGER LE MESSAGE (dans la couche IHM) — pas la détection
Le message doit dire **l'étape** et **l'action**, pas seulement « codeurs non référencés ». Exemples (≤ 70 car.) :
- en homing / MAINT : `[BENNE] Referencement en cours - codeurs non references (normal)`
- hors homing : message actuel inchangé.
⛔ Ne pas toucher à la **détection** ni à `FB_Safety_Winch` : **la logique IHM seule**.

### 3. AJOUTER UNE VRAIE BORNE À LA MANOEUVRE AVEUGLE DE HX1 (le correctif de fond)
Puisque **ni la borne logique, ni la frontière physique, ni une butée mécanique ne protègent** cette phase,
il faut **introduire une limite** — au choix (à arbitrer, mais **il en faut une**) :
- **(A) borne de course en HX1** : une limite basée sur la **mesure disponible** (vitesse/retour contacteurs) ou une **durée maximale de jog** ;
- **(B) borne temporelle** : le jog benne en HX1 est **borné en temps** (ex. quelques secondes) avec arrêt puis message ;
- **(C) borne de sécurité par le retour de tension câble / couple** si l'information existe (à vérifier) ;
- ⛔ **(D) ne PAS se contenter de l'alarme** : une alarme non latchante **n'arrête aucun mouvement**.

➡️ **Phase 0 complémentaire exigée** : lister les **informations réellement disponibles** en HX1 pour borner ce
mouvement (retours contacteurs, vitesse mesurée, retour frein, tension/couple disponible ou non) ⇒ **arrêt humain**,
puis choix de la borne avec l'exploitant.

---

## 📌 CE QUI RESTE VALIDE du message précédent
- **Défaut 1** : phase 0 manquante (`BucketCloseAscentGrant` + `WaitingForOperator`) — à mesurer avant tout code.
- **Défaut 2** : la spec (HX1/HX1a) est la bonne référence — FDC benne **désactivé à HX1**, **réactivé à HX1a**
  (et non un gating par le datum). ⛔ **Mais voir l'action 3 : ce n'est acceptable QUE si une borne existe.**
- `OffsetCloseM = 15,0 m` (`GVL_PERSISTENT.st:67`) : **à confirmer par l'exploitant** avant de gater quoi que ce soit dessus.
- Preuves : ROUGE avant / VERT après + **mutation** + **révision épinglée** + `G200 --report` collé.
- **Un seul écrivain** sur `FB_Bucket` / `PRG_04`.

---

> ⚠️ **Cet écran est un BLOCAGE de sécurité, pas une remarque.** Tant que les actions 1 et 3 ne sont pas traitées,
> la séquence de homing **ne doit pas** être considérée comme livrable ni testée machine en l'état.
