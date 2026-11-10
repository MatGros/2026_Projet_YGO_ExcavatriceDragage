# NOTE D'APPLICATION — TASK T387 FÊNETRE BENNE

Criticité : C4 (sécurité machine) · Stratégie : patch
Lot : T387_FENETRE_BENNE · Fichier source unique : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T387_FENETRE_BENNE.yaml`

---

## 1. Décision safety (revue C4 + arbitrage exploitant 2026-09-22)

**Défaut prouvé en recette :** en SEMI_AUTO AX15D (fermeture benne sur place à la trémie), la
fermeture ne fait bouger aucun treuil puis part en défaut `[BENNE] ErrorID:03` (timeout).

**Cause racine :** fermer la benne = MONTER M2 RELATIVEMENT à M1 (`FB_Bucket` : M2_RunRequest sur
`ReqAscent AND EffectivePermitBucket_Close`). Benne en position haute, la butée haute coupe
l'AscentPermit de M2 (`FB_Safety_Winch` §3 : cause 5 / TopPositionSensor) → M2_RunRequest ne part
pas → le budget timeout se consume → ErrorID:03.

**Arbitrage exploitant (validé) :** la manipulation benne seule = M1 FIXE → l'ensemble M1/M2 ne
change **PAS** d'altimétrie → la butée haute ne doit **pas** bloquer la fermeture benne sur place.

**Décisions de conception retenues :**
1. **Butée géométrique relative étendue à la FERMETURE AUTO** (déjà en place pour le jog benne
   manuel) : `TopLimitM2_M := M1_CablePosM + OffsetCloseM + 2.0` en fenêtre « fermeture benne
   active » (le FdC logiciel M2 suit la géométrie, pas l'altitude absolue).
2. **Relaxation étroite du FdC MATÉRIEL haut de M2**, STRICTEMENT BORNÉE à la **fermeture AUTO**
   (4 verrous TOUS requis, grant), jamais celle de M1 (barrière absolue épinglée au sommet, AC3).
   Le **jog benne MANUEL** n'est volontairement PAS couvert par le grant (hors périmètre
   contractuel validé ; à arbitrer séparément par l'exploitant) : en jog, le FdC matériel M2 reste
   la barrière dure.
3. **Timeout → « en attente de permis »** quand la fermeture est refusée par un permis NUL (budget
   gelé), mais le vrai grippage (permis OK, aucun mouvement) **latch toujours 03** (AC4, non-vacuité).
4. **Fix MecaB trace (AC10, T387-001)** : `UncommandedActiveB` ne s'arme plus sur le seul
   `JoystickYNeutral` mais sur `NOT MovementCommanded` (cause 8, FB_Safety_Winch). Justification :
   en commande PAR BOUTON IHM le joystick reste au neutre alors que le mouvement est commandé →
   MecaB se déclenchait à tort. Non-régression : un vrai non-arrêt SOUS COMMANDE latche toujours
   (TC-P10-002). Le FdC haut, MecaD, le timeout, etc. sont inchangés.

---

## 2. Fichiers modifiés (unique écrivain : DSH01)

| Fichier | Modifications |
|---|---|
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | Nouvel input `BucketCloseAscentGrant` ; relaxation de la barrière matérielle M2 dans `AscentPermit` (§3) uniquement sous grant, M1 jamais relaxé ; **fix MecaB T387-001 (cause 8, AC10)**. |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | Butée géométrique relative étendue à la fermeture AUTO (§5-0) ; calcul du grant `BucketCloseAscentGrant` (4 verrous, **fermeture AUTO seule**) et câblage (`FALSE` sur M1, vraie valeur sur M2) (§5bis) ; **nouvelle VAR_OUTPUT `BucketWaitingForOperator`** = `instBucket.WaitingForOperator`. |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | Gel du budget timeout en « attente de permis » (sous-fenêtre `CloseReq ∧ permis nul`) ; nouvelle sortie `WaitingForOperator`. |

Tests CI :
| Fichier | Test |
|---|---|
| `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st` | `T387-FB-002` grant : AscentPermit relaxé sous grant, actif hors fenêtre (AC2) ; `T387-001` fix MecaB (AC10). |
| `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st` | `T387-FB-003` permis nul → pas de 03 + `WaitingForOperator` ; mise à jour `TC-P10-046.1` (permis OK → 03, non-vacuité). |

Doc : `DOC/WFLOW/CONTRACTS/NOTE_APPLICATION_T387_FENETRE_BENNE.md` (cette note) ; `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T387_FENETRE_BENNE.yaml` (AC10 MecaB ajouté).

---

## 3. Logique des 4 verrous du grant M2 (fermeture AUTO uniquement)

```
v1 FenetreBenne  := instBucket.Lifecycle.Busy AND ReqClose AUTO        (jog manuel EXCLU)
v2 M1Maintenu    := instBucket.Lifecycle.Busy            (M1 épinglé par la benne)
v3 M1HorsMontee  := NOT M1LogicReqAscent                 (jamais montée de charge/extraction de M1)
v4 AvantArrivee  := NOT instBucket.CloseReached          (relaxation éteinte AVANT HoldAscentP1AfterClose/AX10B)

BucketCloseAscentGrant := v1 ∧ v2 ∧ v3 ∧ v4
```
Signal « fermeture AUTO » choisi : `ReqProgram.ReqBucket.ReqClose ET instBucket.Lifecycle.Busy`
(ReqClose est FALSE en AX10B → auto-exclusion du raccordement/transfert de montée couplée).

**Observabilité `WaitingForOperator` (MAJOR-1) :** signal produit par `FB_Bucket` (sortie
`WaitingForOperator`), lu et ré-agrégé par `PRG_04` en **VAR_OUTPUT `BucketWaitingForOperator`**
(sortie programme consommable en mapping IHM / diagnostic, SANS toucher aux `_TYPES/**` IHM).
L'**affichage visuel** dans la page « Ouverture/Fermeture Benne » (champ `ST_ChainBucket` /
GVL_Troubleshooting) est un **câblage IHM de suivi** qui exigerait d'ajouter un champ `_TYPES`
(hors périmètre du lot) — le signal est déjà disponible et prêt sur la sortie PRG_04.

---

## 4. Preuves mécaniques

- Bundle complet : `CODE_XML/CODE_Bundle.xml` (PASS freshness).
- Diff bundle : `CODE_XML/CODE_DiffBundle.xml` — objets : FB_Bucket, FB_Safety_Winch, PRG_04_Treuils_Benne.
- G200 liaison : **PASS (0 erreur)**.
- Gates palier C : G507 (timeout benne) **PASS** ; 4 gates en échec **préexistants** et hors scope
  (G300 structure, G340 liens doc, G430 commentaires REX hérités, G483 matrice maintenance).
- CI unit : FB_Bucket **39/39 PASS** ; FB_Safety_Winch 14/21 (7 échecs **préexistants** hors scope :
  fenêtre de référence 2 s vs tests ~20 ms, identique au HEAD) ; `T387-FB-002`, `T387-FB-003`,
  `T387-001` ROUGE avant / VERT après.
