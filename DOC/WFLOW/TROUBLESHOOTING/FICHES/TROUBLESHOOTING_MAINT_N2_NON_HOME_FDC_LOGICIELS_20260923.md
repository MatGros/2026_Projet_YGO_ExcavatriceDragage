# Session de Troubleshooting — MAINT_N2 non homé et FDC logiciels

> Date : 2026-09-23 · Situation : contexte terrain exact à confirmer · Statut : DIAGNOSTIC STATIQUE CONFIRMÉ / validation live restante

## 1. Contexte figé

Signalement opérateur : après boot, machine non homée et encore dans les premières étapes du cycle de homing ; passage en `MAINT_N2`, puis possibilité rapportée de monter/descendre. Aucun snapshot live n'est utilisé dans cette conclusion.

## 2. Symptôme

Les treuils peuvent recevoir une commande de mouvement en `MAINT_N2` avant référencement ; question associée : les FDC logiciels de position sont-ils alors réellement protecteurs ?

## 3. Indices / historique

- Preuve statique forte : AF10 §7.7 documente que `CablePosM` est potentiellement faux et que les protections logicielles de position sont inertes tant que M1/M2 ne sont pas `HomedAndReliable`.
- Preuve statique forte : `PRG_04_Treuils_Benne.st` §5ter autorise ce mouvement mais bride montée et descente au palier 1.
- Preuve statique forte : `FB_Safety_Winch.st` ne conditionne le FDC haut logiciel qu'à `Homed AND NOT HomingSuspect`.
- Incertitude terrain : valeurs live des références, permis, positions et bypasses non acquises pendant cette session.

## 4. Arbre des causes & hypothèses

| # | Hypothèse | Variable / code de décision | Attendu | Preuve | Verdict |
|---|---|---|---|---|---|
| 1 | Tout mouvement est interdit si non homé | `PRG_04` §5ter | Interdiction totale | Le code bride seulement `CommonMaxStep* := 1` | Éliminée |
| 2 | FDC haut logiciel protège avant homing | `FB_Safety_Winch.AscentPermit` | Comparaison `CablePosM >= TopLimitM` active | Conditionnée par `Homed AND NOT HomingSuspect` | Éliminée |
| 3 | FDC haut physique reste actif | `TopPositionSensor` / `AscentPermit` | Montée coupée sur contact haut | Condition indépendante de `Homed` hors homing actif | Confirmée statiquement |
| 4 | Limite basse logicielle est fiable avant homing | `CablePosM <= CfgCableLimitDescentM` | Position absolue qualifiée | Comparaison présente mais `CablePosM` est non fiable avant homing | Non démontrable / protection non crédible |
| 5 | Vitesse est réduite avant homing | `CommonMaxStepAscent/Descent` | Palier 1 | Affectation explicite si M1 ou M2 non fiables | Confirmée statiquement |

## 5. Arbre vertical

```text
Boot PLC
  -> HomedAndReliable M1/M2 = FALSE
  -> MAINT_N2 autorise la conduite manuelle
  -> PRG_04 bride montée + descente au palier 1
  -> FB_Safety_Winch délivre les permis directionnels
       montée : FDC haut physique actif ; FDC haut logiciel désactivé faute de Homed
       descente : comparaison limite basse exécutée sur CablePosM non qualifié
  -> FB_WinchOutputInterlock réapplique le permis à la sortie finale
```

Résumé : `[HomedAndReliable=0] -> [MAINT_N2] -> [MaxStep=1] -> [mouvement possible] ; [FDC logiciel haut inerte]`.

## 6. Lectures & essais

- Analyse statique de `AF_Partie-10_Fonction_Winch_v2.1.md` §7.7.
- Traçage `PRG_04_Treuils_Benne` → `FB_Safety_Winch` → `FB_WinchOutputInterlock`.
- Les variables nécessaires existent dans `GVL_Troubleshooting` et dans `troubleshooting_variables.txt` ; un snapshot unique peut confirmer l'état live sans forçage.

## 7. Conclusion

- Cause racine : posture de conception explicite — récupération à vue autorisée avant homing, limitée au palier 1 ; les protections de position absolue ne peuvent pas être considérées fiables.
- Alerte : la descente non homée ne dispose pas, dans la chaîne analysée, d'une barrière physique basse équivalente au FDC haut physique ; la comparaison logicielle basse sur une position non référencée n'est pas une garantie.
- Statut : comportement statique confirmé ; état exact machine/bypasses à confirmer par snapshot avant tout essai.

## 8. Proposition

- Immédiat : ne pas essayer ce déplacement hors zone dégagée ; conserver homme-mort, vitesse palier 1, observation directe et capacité d'arrêt ; ne jamais considérer les FDC logiciels comme actifs avant homing.
- Définitif à arbitrer : définir une enveloppe de récupération non homée (sens autorisés, conditions physiques indépendantes, course/temps borné, alarme et recette), puis ajouter un garde automatique. Modification C4 soumise à contrat et GO humain.

## 9. Non-régression à prévoir

- Non homé : palier 1 maximum dans les deux sens.
- FDC haut physique : montée toujours coupée.
- Homé fiable : FDC logiciels haut/bas actifs aux seuils configurés.
- Aucun redémarrage automatique après perte de permis ou défaut.

## 10. Journal

- 2026-09-23 : diagnostic statique réalisé ; aucune modification de `CODE/`, aucun forçage, aucun mouvement demandé.
