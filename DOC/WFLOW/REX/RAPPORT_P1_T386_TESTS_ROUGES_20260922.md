# 📋 RAPPORT P1 — T386 : préparation & mesure des tests ROUGES

- **Tâche** : T386 (C4, parent T306) — rotation de phase → PowerCutOff
- **Date** : 2026-09-22 · **Agent** : DSH01
- **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T386_ROTATION_PHASE_POWERCUTOFF.yaml` (amendé, PASS 0/0)
- **Périmètre de ce rapport** : P0 (contrat) + P1 (tests ROUGES) uniquement. **AUCUNE modification du code de sécurité** (FB_Safety_Winch, FB_Safety_Translation, PRG_06, AU).

---

## 1. Amendement du contrat (P0) — réalisé, PASS 0/0

Suivant la consigne, le contrat intègre :
- **P3 = 3 modifications INSEPARABLES dans PRG_06_Outputs.st** :
  1. UNE seule affectation canonique de `PowerCutOffReq` (ligne 317), retrait de la redondance ligne 480 ;
  2. ajout de `OR NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` (phase contrôlée en DISABLE aussi) ;
  3. **masquage des bypass AU effectifs** (`BypassAuPowerCutOff`, `BypassAuArmingPreconditions`) LORSQUE la phase est non OK (au site d'appel `instSafetyEmergencyManagement`, sans toucher `FB_Safety_EmergencyManagement`).
- **Test P1e** ajouté : « retour phase OK alors que les bypass RETAIN AU restent actifs ».
- **AC2 corrigé** : distingue commandes LOGIQUES (`PowerCutOff`, `PowerCutOffReq`) des CONTACTEURS PHYSIQUES (retombée = essai machine SAT, pas CI).
- **AC3** : les 3 modes (DISABLE, MAINT_N2, SEMI_AUTO) testés explicitement, un cas nommé chacun.
- **Chemin YAML corrigé** : `CODE/I_TRANSLATION/FB_Safety_Translation.st` propre (le `#` collé au nom de fichier a été retiré du scope.allowed).
- PREG1 = EN_ATTENTE (schéma électrique, bloquant le patch mais PAS la préparation) · PREG2 = ARBITRÉE (coupure sans exception).

## 2. Git status & hashes (point 2)

État courant (2026-09-22) — `git hash-object` :
| Fichier | Hash blob | Statut |
|---|---|---|
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | `9e578388` | ⚠️ **modifié — lot T387** |
| `CODE/I_TRANSLATION/FB_Safety_Translation.st` | `ad73b454` | libre |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3` | libre |
| `TOOLS/.../test_fb_safety_winch.st` | `93412a4d` | ⚠️ **modifié — lot T387** |
| `TOOLS/.../test_fb_safety_translation.st` | `03a869a9` (après mon ajout) | libre → **ma modif P1** |
| `TOOLS/.../test_prg_06_outputs.st` | `d373bade` | libre |

**Collision identifiée** : `FB_Safety_Winch.st` + `test_fb_safety_winch.st` sont modifiés par le **lot T387** (fenêtre benne `BucketCloseAscentGrant` + MecaB boutons). **Je n'ai rien écrit dans ces fichiers** et ne prends pas leur verrou sans coordination. Les cas T386 M1/M2 seront **rédigés dans le contrat** et attendent la libération.

## 3. Test préparé (P1, fichiers libres)

**M3 — `test_fb_safety_translation.st`** : ajout **additif** (+35, 0 suppression) de `TC-T386-M3-001` :
- `PhaseRotationOk:=FALSE` ⇒ `SafeStop=TRUE` ET `PowerCutOff=TRUE` (cible T386) ;
- retour `PhaseRotationOk:=TRUE` **sans front Reset** ⇒ reste verrouillé (`Fault.Latched=TRUE`).
- Aucune assertion existante modifiée ni affaiblie.

## 4. Test ROUGE exécuté (point 4) — résultat mesuré

Commande : `run_tests.py --fb FB_Safety_Translation` (état courant = avant patch P2).

```
FAIL  FB_Safety_Translation (5/6)
  PASS  TC-P11-SAF-001 / 002 / 003 , TC-T300-SAF-060 / 061     ← 5 préexistants intacts
  FAIL  TC-T386-M3-001 Defaut rotation phase M3 => PowerCutOff (ROUGE/VERT)
        ASSERT_TRUE: FB.POWERCUTOFF expected TRUE, got FALSE
        -- Defaut rotation phases -> PowerCutOff TRUE (cible T386)
1 FB testes, 0 PASS, 1 FAIL
```

- **Échec attendu** précis : `PowerCutOff` doit devenir `TRUE` sous rotation de phase après patch P2.
- **Échec observé** : `PowerCutOff` reste **FALSE** (état actuel : la phase ne coupe pas) → écart exact à corriger.
- **Ce n'est PAS un échec de compilation/harnais** : les 5 autres TC compilent et passent ; l'unique FAIL porte sur l'assertion `PowerCutOff`. **Preuve ROUGE valide.**

⚠️ Remarque : `TC-P11-SAF-002` (afﬁrme actuellement « rotation phase → PAS de PowerCutOff ») passe encore car il documente le comportement actuel. Il devra être **révisé en P2** (aligné sur la nouvelle sémantique) pour éviter une contradiction après le patch — signalé ici, pas fait maintenant.

## 5. Limitation constatée (devoir d'alerte) — test intégration AU

Le **test d'intégration AU (P1c/d/e)** n'est **pas réalisable** dans le harnais actuel : `FB_TestHarness_PRG_06` **n'expose pas** `PhaseRotationOk_DI` ni le chemin AU global (il isole uniquement les barrières finales M1/M2/M3). Le tester exigerait d'enrichir le harnais (hors périmètre) ou un test de niveau PRG_06 complet. **Signale, non implémenté.**

## 6. Décisions encore bloquantes (point 5)

| # | Décision | Statut |
|---|---|---|
| D1 | **PREG1** — référence/alimentation/comportement du relais `PhaseRotationOk_DI` contacteur ouvert (responsable électrique) | ⛔ **EN_ATTENTE** — bloque validation design final + patch P2/P3, PAS la préparation P1 |
| D2 | **Bypass aval AU** sur défaut phase | ✅ ARBITRÉE : coupure SANS exception (bypass masqués si phase non OK) |
| D3 | **Révision `TC-P11-SAF-002`** (assert phase sans PowerCutOff) — à faire au moment du patch P2 | ⏳ à faire en P2 |
| D4 | **Libération de `FB_Safety_Winch` + test** (lot T387) pour écrire les cas M1/M2 | ⏳ en attente de coordination |

**GO pour P2/P3 : NON demandé** — le patch métier ne sera engagé qu'après un nouveau GO explicite (règle C4 / ARRÊT HUMAIN), a fortiori avec D1 non levée.
