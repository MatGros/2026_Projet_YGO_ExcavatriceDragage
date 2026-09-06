# T258 — Étude et plan d'exécution cycle semi-auto SAT

**Date** : 2026-09-05  
**Criticité** : C3 — mouvements réels M1/M2/benne  
**Stratégie** : patch ciblé, sans refonte d'architecture  
**Statut** : plan challengé — attente validation humaine avant code

## 1. Verdict des revues indépendantes

| Revue | Verdict initial | Condition de levée |
|---|---:|---|
| Automatisme / safety | **BLOCK** | Qualifier Y−/Y+, arrêt AX8 réel, géométrie M1/M2 séparée, Kobold réel et forçage transactionnel |
| CI / non-régression | **BLOCK** | Harness fidèle, tests scan par scan et preuve MAINT_N1/N2 |
| IHM / mise en service | **MAJOR** | État dégradé visible, motifs de refus et procédure opérateur en deux temps |

Le plan initial « inhiber toutes les erreurs » est refusé. Une erreur de procédé peut être
temporairement ignorée pour l'essai ; une protection machine ne peut jamais l'être.

## 2. Faits établis et points restant à confirmer

### Faits établis

- Le contacteur Kobold **alimente le capteur** ; aucun retour auxiliaire de contacteur n'existe.
- `M1_M2_KoboldBottomTouch_DI` est l'unique information du capteur Kobold.
- Le forçage actuel affecte `State`, puis exécute le `CASE` cible dans le même scan.
- `AX3_WAIT_DIVE_START=21` n'est pas traité par la plage de forçage `0..20`.
- AX9–AX12 utilisent une déflexion quelconque au lieu de l'intention Y+.
- AX8 temporise sans vérifier l'arrêt physique annoncé.
- AX9 et AX11 réutilisent la position M1 pour M2 ; AX11 compare un écart brut non compensé.
- Les tests actuels ne prouvent ni la séquence Kobold réelle, ni le forçage, ni l'inhibition,
  ni la barrière atomique réelle PRG04.

### À confirmer au SAT avant qualification finale

- Polarité et chronologie physiques Kobold : hypothèse active `0 hors eau → 1 immergé → 0 fond`.
- Temps minimal d'établissement après alimentation du capteur Kobold.
- Signe réel des positions câble et de `WinchSyncDeltaM` sur les deux sens.
- Valeurs RETAIN effectives : lancement Kobold, limites hautes, offset benne et tolérances.

## 3. Invariants de conception non négociables

1. Perte homme-mort ou direction attendue absente : toutes les demandes concernées tombent le même scan.
2. Une anomalie M1 ou M2 dans un mouvement couplé SEMI_AUTO neutralise les deux voies finales.
3. Aucun toggle d'essai ne modifie AU, `PowerCutOff`, codeurs, limites, synchronisme,
   interlocks finaux, homme-mort ou commande de sortie.
4. Aucun forçage ne produit de mouvement au scan de préparation ni tant qu'un nouveau geste
   opérateur n'a pas été reconnu.
5. Aucun registre de contexte non qualifié n'est consommé par une étape forcée.
6. Les chemins MAINT_N1 et MAINT_N2 restent identiques bit à bit.
7. Reset reste un front conscient ; inhibition et forçage n'acquittent jamais un défaut latché.

## 4. Matrice des contrôles du cycle

| Cause actuelle | Nature | Inhibable en essai | Comportement retenu |
|---:|---|:---:|---|
| 0 Limite légale | Protection profondeur | **Non** | Arrêt/repli toujours actif |
| 1 Synchronisme bloquant | Protection M1/M2 | **Non** | Arrêt commun toujours actif |
| 2 Écart vitesse confirmé | Protection mouvement couplé | **Non** | Arrêt commun ; temporisation calibrée |
| 3 Perte IHM | Permis de conduite | **Non** | Neutralisation et repli |
| 4 Timeout maximal d'étape | Contrôle procédé | **Oui** | Diagnostic conservé, pas de latch/repli sous mode essai |
| 5 Contrôle montée/écart | Protection extraction | **Non** | Corriger avec delta compensé, puis garder bloquant |
| 6 Anti-télescopage | Protection mécanique | **Non** | Toujours actif |
| 7 Hors fenêtre haute pendant M3 | Protection collision | **Non** | Toujours actif |
| 8 Palier supérieur à 4 sous Kobold | Protection mesure/mécanique | **Non** | Toujours actif, coupure même scan |
| 9 Palier 4 non confirmé | Contrôle procédé | **Oui, après délai** | Avertissement ignoré possible ; palier >4 reste interdit |
| 10 Arrêt incomplet avant plongée | Protection départ couplé | **Non** | Aucun départ ; défaut/repli |

Le mode essai sera nommé **« contrôles procédé cycle inhibés »**, non persistant, effectif seulement
avec commissioning + SEMI_AUTO. Il retombe sur Abort, sortie de mode et fin de cycle. Les contrôles
ignorés restent calculés et publiés avec cause, étape et texte.

## 5. Étude transitionnelle AX4 → AX12

| Étape | Action autorisée | Transition robuste | Défense principale |
|---|---|---|---|
| AX4 descente lancement | Y− + homme-mort, M1=M2, palier 4 | Altitude M1 de lancement atteinte | Limite légale, sync, palier >4 |
| AX5 alimentation Kobold | Descente maintenue + alimentation capteur | Fin du délai d'établissement | Aucun pseudo-feedback contacteur |
| AX6 immersion | Descente maintenue, DI observée | DI haute stable pendant délai | Palier 4 stable avant interprétation |
| AX7 recherche fond | Descente maintenue | DI haute qualifiée puis basse stable | DI basse initiale interdite comme fond |
| AX8 arrêt fond | Toutes demandes à zéro, Kobold OFF | Vitesses valides basses + contacteurs relâchés + freins serrés, stables | Timeout d'arrêt non inhibable |
| AX9 prétension | Y+ + homme-mort, palier 1 | M1 et M2 atteignent chacun `TouchMx + RaiseOffBottom` | Deux cibles distinctes |
| AX10 fermeture | Y+ + homme-mort, treuils neutres | `Done` + fermé ou approximativement fermé | Aucun ordre montée avant validation |
| AX11 montée contrôle | Y+ + homme-mort, palier 1/2 | Distance relative M1/M2 atteinte + delta compensé dans tolérance | Écart vitesse temporisé + sync |
| AX12 montée chargée | Y+ + homme-mort, palier borné | Limite haute qualifiée | Barrière atomique PRG04 |

## 6. Forçage GRAFCET retenu

### Transaction PLC en deux temps

1. **Préparer** : front IHM, commissioning actif, SEMI_AUTO, joystick neutre et machine arrêtée.
2. Le PLC valide la cible et ses préconditions, mémorise la cible et neutralise toutes les demandes.
3. L'IHM affiche `Prepared` ou `Rejected` avec motif ; aucun mouvement n'est possible.
4. **Reprendre** : action distincte puis nouveau geste directionnel + homme-mort.
5. Abort, défaut, sortie de mode ou désactivation commissioning annulent la préparation.

### Politique des cibles

| Famille | Politique |
|---|---|
| AX0, AX1 | Autorisées sans contexte mouvement |
| AX2, AX3, AX4, AX5 | Autorisées seulement si posture physique requise confirmée |
| AX6, AX7 | Refusées sans historique d'immersion qualifié ; préférence à préparer AX5 |
| AX8, AX9 | Refusées sans positions fond M1/M2 valides |
| AX10 | Autorisée si fond/cibles valides et arrêt mécanique confirmé |
| AX11, AX12 | Autorisées si benne fermée/approximative, contexte fond valide et arrêt confirmé |
| AX13–AX18 | Autorisées selon positions hautes, benne et translation compatibles |
| AX_STAB | Jamais sélectionnable |
| AX_DIVING_RETRY | Autorisée seulement Kobold OFF et intention de dégagement Y+ |
| AX3_WAIT_DIVE_START (21) | Cible explicite autorisée si benne ouverte ; jamais traitée implicitement par une plage numérique |

## 7. Phasage d'exécution et portes GO/NO-GO

### T258-A — Socle de preuve

- Adapter le harness `FB_CycleSemiAuto` aux entrées réelles.
- Exercer la logique réelle d'atomicité PRG04 ou extraire une unité commune testable.
- Ajouter tests direction, priorités même scan et neutralité maintenance.
- Ajouter les gardes automatiques `fix:` + `guard:`.

**GO B/C/D** : tests existants toujours verts et nouveaux tests rouges uniquement sur les défauts ciblés.

### T258-B — Diving et Kobold

- Direction Y− stricte.
- Suppression de `KoboldContactorFeedback`.
- Délai alimentation → immersion haute stable → fond bas stable.
- Arrêt physique confirmé en AX8.

**GO C** : nominal, rebonds, DI basse initiale, perte homme-mort et timeout arrêt couverts.

### T258-C — Extraction

- Direction Y+ stricte.
- Captures `TouchPositionM1/M2` et cibles séparées.
- AX11 sur `WinchSyncDeltaM` compensé.
- Validation même-scan de l'arrêt commun en cas d'anomalie asymétrique.

**GO E** : AX9→AX12 nominal + bords de tolérance + défaut unilatéral passent.

### T258-D — Mise en service et forçage

- Toggle non persistant limité aux causes 4 et 9.
- Avertissement ambre permanent et diagnostic des contrôles ignorés.
- Forçage `Prepare/Resume/Cancel`, résultat et motif.
- Préconditions par cible et nouveau geste obligatoire.

**GO E** : toutes combinaisons Force/Fault/Abort/mode/joystick testées scan par scan.

### T258-E — Intégration et livraison

- Revue mentale puis mécanique `PRG02 → PRG03 → PRG04 → PRG06`.
- AF04/AF10/AF12/AF14 alignées au code réellement testé.
- Tests FB cycle, PRG03, PRG04 et WINCH_INTEG.
- Bundle frais, G200, palier C puis suite complète des gates.
- Revue indépendante finale du diff et checklist SAT.

**GO CODESYS** : zéro gate rouge, bundle frais, G200 PASS et aucune régression maintenance.

## 8. Matrice minimale de preuve

- Directions : Y−, Y+, X, neutre, perte homme-mort sur chaque étape de mouvement.
- Kobold : `0→1 stable→0`, rebonds haut/bas, DI bloquée, perte alimentation.
- AX8 : retrait successif de chaque fait d'arrêt et timeout.
- Extraction : positions absolues décalées mais déplacements relatifs égaux.
- Inhibition : chaque cause avec commissioning OFF/ON ; cause non inhibable toujours bloquante.
- Forçage : cible valide/invalide, bouton maintenu, joystick déjà poussé, Abort/Fault simultané.
- Atomicité : readiness/fault/direction divergents sur une seule voie → sorties M1=M2=0.
- Maintenance : mêmes vecteurs N1/N2 avant/après → sorties strictement identiques.

La CI prouve la logique déterministe, les temporisations simulées et la liaison source/bundle.
Elle ne prouve pas polarité physique, inertie, freinage réel, simultanéité électrique ni valeurs RETAIN :
ces éléments restent des critères SAT CODESYS tracés.

## 9. Décision demandée

Validation humaine requise sur trois décisions avant code :

1. Matrice d'inhibition limitée aux causes procédés **4 et 9**.
2. Forçage en deux temps avec préconditions et nouveau geste joystick.
3. Hypothèse Kobold `0 hors eau → 1 immergé → 0 fond`, à confirmer physiquement avant qualification.

