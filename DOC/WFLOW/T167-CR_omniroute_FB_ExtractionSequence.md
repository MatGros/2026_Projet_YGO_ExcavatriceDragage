# T167-CR — Rapport brut omniroute codex/gpt-5.6-terra-high

> Revue READ-ONLY (2e avis independant). Analyse orchestrateur + passe de durcissement H1-H5 : voir T167-CR_REVUE_INDEPENDANTE_CYCLES.md §5.

---

## Revue indépendante READ-ONLY — `FB_ExtractionSequence`

⚠️ **Périmètre réellement vérifiable** : uniquement le FB fourni.  
Je ne peux pas certifier la liaison `PRG_03`, le câblage effectif de `BucketMoveTimeout`, ni le comportement réel de `FB_FaultCore` / `FB_Bucket` sans leurs sources et sans exécution des gates.

### Écarts

| Sévérité | Preuve | Écart / impact |
|---|---|---|
| **C1 — Bloquant sécurité** | `FB_ExtractionSequence.st:220-231`, `234-245` ; `instFault` appelé ligne 153 **avant** la détection locale des défauts | **Coupure non déterministe au scan de détection** pour `BucketError`, `WinchSyncError`, `PositionsValid` et vitesses invalides. Exemple : en `CLOSING_BUCKET`, `BucketCloseRequest` est d’abord activé ligne 222, puis `BucketErrorFault := TRUE` ligne 226. `Fault.Error` ne voit ce latch qu’au scan suivant. Même phénomène pour `AscentPermit` en `CONTROL_ASCENT` (ligne 236 avant défaut lignes 240-241). Les sorties `[ACT]` peuvent donc rester actives un cycle complet après réception d’un signal `[SAFE]` de défaut. Cela ne permet pas de certifier « jamais active sans permis positif » ni la coupure immédiate attendue. |
| **C2 — Majeur** | Lignes `122-130` | **Reset conditionné**, contrairement au critère demandé : `IF ResetEdge.Q AND NOT ErrorCausePresent AND NOT MotionRequestActive THEN`. Le reset est bloqué si une demande de mouvement est encore présente. De plus, il efface les latches locaux sans vérifier que `BucketError`, `WinchSyncError`, `PositionsValid`, `M1MeasuredSpeedValid` et `M2MeasuredSpeedValid` sont revenus à un état sûr. Un défaut matériel persistant peut donc être acquitté en `WAIT_BOTTOM_CONFIRMATION`, puis seulement redétecté plus tard lors de la séquence. |
| **C2 — Majeur** | Entrée `Mode` ligne 14 ; aucune utilisation dans l’implémentation | `Mode` est documenté comme « mode de fonctionnement arbitré », mais **n’intervient dans aucun permis**. Le FB peut émettre `BucketCloseRequest` / `AscentPermit` si `Enable`, contacteur, état interne et demande de mouvement sont vrais, quel que soit le mode effectif. Sans preuve que `Enable` est matériellement et exclusivement asservi au mode semi-auto dans l’appelant, le permis de commande est incomplet. |
| **C2 — Majeur** | Lignes `104-105` | Robustesse numérique incomplète : la division est protégée par une constante non nulle et un plancher de distance est présent, mais la conversion `REAL_TO_UDINT` n’est **ni bornée ni contrôlée** avant `UDINT_TO_TIME`. Une valeur IHM anormale, non finie ou trop grande peut provoquer un dépassement / comportement dépendant runtime. Le calcul doit être borné à la plage `TIME` admissible et la plage IHM doit être prouvée. |
| **C2 — Majeur de certification** | Lignes `32-33`, `98-101` ; sources `PRG_03` et `FB_Bucket` absentes | L’ordre nominal des watchdogs est codé : `CfgBucketCloseTimeout <= BucketMoveTimeout` déclenche bien un défaut de configuration. Toutefois, la revue ne peut pas prouver que `BucketMoveTimeout` est effectivement la même référence que `FB_Bucket.CfgTimeoutDuration`, ni que `BucketError` est publié avant le backstop. L’exigence « le watchdog benne reste visible en premier » est donc **non certifiable au niveau intégration**. |
| **C3 — Diagnostic / traçabilité** | Lignes `167-183` | Le gate remet systématiquement `StepAtFault := WAIT_BOTTOM_CONFIRMATION` (ligne 176). Le latch de défaut local survit bien au cycle `Enable`, mais l’étape du défaut initial est perdue dès qu’un `Enable := FALSE` survient. Cela semble compatible avec la tolérance AF indiquant `WAIT_PRECONDITIONS` après traversée du gate, mais ce comportement doit être explicitement accepté pour l’exploitation/IHM. |

---

### Points conformes observés

| Critère | Constat |
|---|---|
| Front Reset | ✅ `ResetEdge(CLK := Reset)` ligne 95 : pas de reset par niveau. |
| Latches locaux | ✅ Causes 1 à 5 configurées avec `Latching := TRUE` lignes `132-150`. Les variables locales de défaut ne sont pas effacées par le gate `Enable`. |
| `StepAtFault` avant `ERROR_HOLD` | ✅ En fonctionnement nominal, la capture est exécutée lignes `157-162`, avant le passage à `ERROR_HOLD` lignes `196-199`. `PrevState` est mémorisé en fin de scan ligne 262. |
| Commandes résiduelles sur `NOT Enable` | ✅ Gate explicite : `BucketCloseRequest`, `AscentPermit`, `ForceMinSpeedStep` sont forcés à `FALSE`, puis `RETURN` lignes `167-183`. |
| Commandes résiduelles dans `ERROR_HOLD` | ✅ Les sorties sont remises à `FALSE` avant le `CASE` lignes `189-194`; `ERROR_HOLD` ne les réactive pas. |
| Formule timeout remontée contrôle | ✅ Formule runtime cohérente avec AF §3bis : plancher `0,1 m`, vitesse `0,15 m/s`, marge `2,0`, conversion en ms. |
| Backstop > watchdog benne | ✅ Le contrôle runtime `CfgBucketCloseTimeout <= BucketMoveTimeout` est présent lignes `98-101`. |

---

### Limites ISO 13849

Une certification ISO 13849 ne peut pas être prononcée sur ce seul FB : il faut au minimum l’analyse de risque, le PLr, l’architecture SRP/CS, les catégories, MTTFd/DCavg/CCF, la chaîne matérielle des actionneurs, les temps de réponse mesurés et les preuves de validation.

Ici, indépendamment de cette limite système, l’écart **C1** est déjà incompatible avec le critère demandé sur les sorties `[ACT]`.

```text
Auto-vérification liaison (G200_check_linkage.py) — NON VÉRIFIABLE
  Sources PRG_03 / FB_Bucket / FB_FaultCore et exécution des outils non fournies.

Gates : structure / style / liaison / persistance / bundle / pytest = NON EXÉCUTÉS
Fichiers modifiés : aucun (revue READ-ONLY)
Hors scope constaté (devoir d’alerte) :
  - Liaison effective BucketMoveTimeout <-> FB_Bucket.CfgTimeoutDuration non prouvée.
  - Contrat et comportement Enable/Reset de FB_FaultCore non prouvés.
  - Architecture ISO 13849 système non fournie.
```

# VERDICT = **REJETÉ**

Motifs bloquants : maintien possible d’ordres `[ACT]` un scan après un défaut `[SAFE]`, Reset conditionné et non cohérent avec des défauts matériels persistants, permis de mode non consommé.