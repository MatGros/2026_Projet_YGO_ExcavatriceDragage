# Patch proposé — messages opérateur capteur haut et mou de câble (non appliqué)

> **PROPOSITION.** Écriture dans `CODE/` refusée à TORC-CC10 par la deny-list (hook `PreToolUse`).
> À appliquer par T417-C (déjà sur `CODE/` et le DiffBundle) ou par l'exploitant. Rédigée le 2026-11-17.
> Fichier unique : `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st`. Aucun DUT, aucun PRG touché.

## 1. Constat (vérifié dans le code)
- Capteur haut `M1M2_TopPositionFree_DI` (contact NC) : déclenché, non raccordé ou câble coupé ⇒ cause 5 de `FB_Safety_Winch` (`:309-316`, live, non latchée) ⇒ `AscentPermit` à FALSE (`:574-577`).
- Le bandeau n'affiche aucun message pour cette cause : « Montée interdite - limite haute » vient de la limite **logicielle** (`CableLimitAscent`, ≥ 7,7 m) ; « capteur haut » n'apparaît que pour MecaD (`ErrorID:12`).
- AF-07 §6 dit que l'action opérateur pour le bit 5 « est déjà publiée par la branche limite haute » : c'est faux dans le code. Ce patch aligne le code sur l'intention de l'AF. Le carrousel d'alarmes n'est **pas** touché (exemption nominative du bit 5 conservée, gate G506 inchangé).
- Mou de câble `M2_TensionedCable_DI` (NC) : message existant « Descente interdite - Mou de cable detecte ».

## 2. Source du signal
`WinchM1Safety.ErrorId` / `WinchM2Safety.ErrorId` (vue LIVE, `ST_SafetyWinch.st:9`). Bit 5 = `16#0020`. Déjà respecte bypass et mode référencement (cause 5 = FALSE dans ces cas). Pas de nouvelle entrée de FB, pas de modification de `PRG_07`.

## 3. Modifications (5 hunks)

**H1 — constantes** (après la constante bit 6, `:174`)
```st
    CST_WinchErrorIdTopSensor         : WORD := 16#0020; // . [LOC] Bit 5 ErrorId : fin de course haut capteur
```

**H2 — variable locale** (après `OperatorActionCandidate`, `:102`)
```st
    TopSensorIsTripped        : BOOL;          // . [LOC] Capteur haut M1 OU M2 declenche ou cable coupe (bit 5 ErrorId, live)
```

**H3 — calcul** (juste avant le commentaire « Mou de câble : vue LIVE seule », `:666`)
```st
    // Capteur haut physique (contact NC) : cause 5 live, non latchée ; déclenché, non raccordé ou câble coupé.
    TopSensorIsTripped := ((WinchM1Safety.ErrorId AND CST_WinchErrorIdTopSensor) <> 0)
                       OR ((WinchM2Safety.ErrorId AND CST_WinchErrorIdTopSensor) <> 0);
```

**H4 — branche descente** (`:740`)
```st
            OperatorActionCandidate := '[TREUIL] Descente interdite - Mou de cable (ou capteur non raccorde)';
```

**H5 — branche montée** : nouveau `ELSIF` **après** MecaD (`:753-755`)
```st
    ELSIF TopSensorIsTripped THEN
        // 🛡️ Montée bloquée par fin de course haut physique (NC) : déclenché, non raccordé ou câble coupé.
        // Placé après MecaD (non-arrêt confirmé, plus grave) : les deux causes coexistent quand le capteur est dépassé.
        OperatorActionCandidate := '[TREUIL] Montée interdite - fin de course haut (declenche ou cable coupe)';
```

## 4. Arbitrage de priorité (vérifié, change l'avis du sous-agent)
Le sous-agent (glm-5.3-flash) proposait le capteur **avant** MecaD. Vérifié dans `FB_Safety_Winch.st:376-381` : MecaD exige `NOT TopPositionSensor`, donc **les deux causes sont actives ensemble** quand le capteur est dépassé. Placer le capteur avant MecaD masquerait le défaut le plus grave. Retenu : capteur **après** MecaD ; « limite haute » (logicielle, 7,7 m) reste devant car elle se déclenche avant le capteur (≈ 8,5 m).

## 5. Points de vigilance
- Anti-clignotement : le champ action passe par `AntiFlickOperator` (maintien ~500 ms, AF-07 §5.3). Un rebond de contact ne fera pas clignoter le texte.
- Longueurs : 73 et 68 caractères, STRING(120). Littéraux ASCII sauf `é` déjà toléré dans ce fichier (G405 à lancer).
- Pas de message par treuil (capteur commun M1/M2).
- Le capteur haut n'étant pas encore raccordé : **ce message s'affichera tant qu'il ne l'est pas** (voulu).

## 6. Vérifications à lancer par l'appliquant
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/G405_check_st_string_ascii.py
python TOOLS/AGENT_WORKFLOW/scripts/G506_check_anyfault_banner_labels.py
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
Essai machine après import : couper le câble du capteur haut (ou débrancher) puis pousser le joystick en montée ⇒ le texte « fin de course haut (declenche ou cable coupe) » doit apparaître ; débrancher le détecteur de mou ⇒ « Mou de cable (ou capteur non raccorde) » en descente.

## 7. À faire en plus
- Corriger la phrase d'AF-07 §6 (« action déjà publiée par la branche limite haute ») : décision exploitant (dérogation en place comme T255-D, ou nouvelle version).
- Vérifier qu'aucun test ni document ne cite l'ancien texte « Mou de cable detecte » (ma recherche sur tout le dépôt a dépassé le délai, non conclue).
