# T428 J2 — Structure cible du snapshot

> ✅ **Décisions tranchées le 2026-11-08** (6 techniques par l'orchestrateur, GO J3 par l'exploitant). J3 : [J3_MAILLONS](J3_MAILLONS.md).
> 🟠 Retraits appliqués seulement à J4. Aucune ligne de `CODE/` n'a changé.
> Table complète : [TABLE_CORRESPONDANCE.csv](TABLE_CORRESPONDANCE.csv) · Revue : [RAPPORT_JUGE.md](RAPPORT_JUGE.md)

## 1. Résultat

| Mesure | Avant | Après retraits | Après ajouts J3 |
|---|---:|---:|---:|
| Variables du snapshot | 571 | **424** (-26 %) | **440** |

| Critère du plan J2 | Résultat |
|---|---|
| 100 % des variables classées | ✅ 574 variables décidées (571 de la liste, 3 déclarées hors liste) + 13 nouvelles |
| 0 doublon sans raison | ✅ Contrôle mécanique, sur les doublons que le script sait voir |
| Même ordre sur les 3 axes | ✅ 10 étapes non vides sur M1, M2, M3 |
| 0 retrait sans panne vérifiée | ✅ Revue à la source, avec la réserve du §7 |
| Rejeu papier publié | ✅ **Pas de gain mesuré** : voir §6 |

## 2. Ordre de lecture

| # | Niveau | Bloc |
|---|---|---|
| 1 | GÉNÉRAL | Contexte : mode, simulation, bypass communs, seuil commun |
| 2 | GÉNÉRAL | Puissance et AU |
| 3 | GÉNÉRAL | Opérateur et joystick |
| 4 | GÉNÉRAL | Capteurs communs : position haute, thermique frein, Kobold, câble tendu |
| 5-7 | AXE | M1, M2, M3, en 10 étapes |
| 8-11 | FONCTION | Référencement, Couplage, Benne, Cycle |

## 3. Fiche d'axe

| Étape | Question | M1 | M2 | M3 |
|---:|---|---:|---:|---:|
| 1 Bilan | Où la chaîne casse-t-elle ? | 13 | 13 | 13 |
| 2 Entrées brutes | Que disent les capteurs ? | 7 | 7 | 10 |
| 3 Mesures traitées | Que vaut la mesure calculée ? | 4 | 4 | 2 |
| 4 Mode et interdictions | Qu'est-ce qui interdit l'axe ? | 4 | 4 | 3 |
| 5 Demande | Qui demande quoi ? | 7 | 7 | 11 |
| 6 Sécurité axe | Un défaut bloque-t-il ? | 19 | 19 | 16 |
| 7 Permis | Le sens est-il autorisé ? | 11 | 11 | 4 |
| 8 Barrière finale | Que fait le dernier verrou ? | 20 | 19 | 6 |
| 9 Sorties | Quel ordre sort réellement ? | 8 | 8 | 5 |
| 10 Retour physique | La machine a-t-elle répondu ? | 2 | 2 | 2 |

🔑 **Freins, contacteurs retombés et fréquence brute restent en étape 10**, contre l'avis des 3 agents de parsing : on lit l'ordre, puis la réponse à cet ordre. Le juge confirme ce choix.

## 4. Règles

| Règle | Contenu | Lignes |
|---|---|---:|
| R0 | Variable à sa place naturelle | 292 |
| R1 | Copie pure : même source, même scan, une seule ancre conservée | 135 |
| R2 | Négation pure d'une variable conservée | 7 |
| R3 | Fait commun à plusieurs axes : ancre en GÉNÉRAL, ou Couplage | 60 |
| R4 | Maillon `Step*` ou `AllConditionsMet` gardé, même s'il recopie | 56 |
| R5 | Jamais écrite par la vue | 5 |
| R6 | Constante | 4 |
| R7 | Déclarée, absente de la liste | 3 |
| R8 | Correction issue de la revue | 25 |

**Renvoi :** une fonction ou un autre axe ne recopie plus une variable. La table donne l'ancre à lire.

## 5. Défauts trouvés dans le snapshot actuel

Vérifiés dans le code. Sans effet sur la commande machine, mais ils peuvent tromper un diagnostic.

| ⚠️ Fait | Preuve | Conséquence |
|---|---|---|
| `I/J.Idx505_CmdBrakeRelease_RQ` n'est pas la sortie frein | `FB_WinchStateProjection:108`, `PRG_06:306-307,330-331,375` | Frein forcé en N2 alors que le snapshot affiche 0 |
| `L.Idx501` et `L.Idx503` affichent la demande | `PRG_05:739,744`, `PRG_06:458,462` | Mot affiché non nul alors que la sortie réelle est à 0 |
| `M3_TremieHardStopActive` est invisible | `PRG_06:431,441-449` | M3 coupée sans variable lisible |
| `T.M1/M2Safety*Permit` valent le permis Effective | `FB_WinchStateProjection:232`, `PRG_04:1067,1113` | Un refus Process accuse à tort la sécurité |
| Contacteurs de palier 2 et 3 absents de la fiche | `PRG_06:371-374` | Palier réel illisible |

**J3, sans PLC :** ajouter les vraies valeurs à la liste. **J4 :** rebrancher ou renommer les 8 variables `CABLER_J4`.

Chemins ajoutés à vérifier en lecture réelle à J3 : `PRG_06_Outputs.M3_CommandWord`, `PRG_06_Outputs.M3_TremieHardStopActive` et `PRG_04_Treuils_Benne.SafetyPermitM*_*` sont des variables locales de POU.

## 6. Preuves

**Doublons, sur 94 snapshots :** 5 105 paires de copies dans un même lot de lecture, 2 écarts ; 191 écarts entre lots différents. Les 2 écarts : `K.Idx501`, constante corrigée au lot 1, et le joystick brut à 4847 contre 4849. Une partie des 75 désaccords connus vient donc de la lecture par lots. Moins de copies supprime ces faux écarts.

**Rejeu papier :** mêmes 5 incidents, mêmes 3 modèles, 15 diagnostics, deux passes de notation.

| Exécution | Table | Cause, plus faible passe | Maillon, plus faible passe |
|---:|---|---:|---:|
| 1 | Avant revue | 0 | 3 |
| 2 | Après revue | 0 | 2 |
| 3 | Après revue | 0 | 4 |
| 4 | **Finale** | **0** | **3** |
| Référence | Actuelle | 0 | 1 à 6 |

La structure seule **n'améliore pas** le diagnostic par modèle. L'écart entre exécutions montre que le rejeu est instable et qu'une différence de 1 ou 2 points ne veut rien dire. Les anciens snapshots ne contiennent ni les ajouts J3 ni les corrections du lot 1 : le rejeu ne les mesure pas.

Sur le cas Kobold, un retrait a été contrôlé : le DI brut reste présent, aucune information n'est perdue.

## 7. Limites

- 🟠 La revue indépendante a jugé les 109 premiers retraits. Les retraits ajoutés ensuite, 38 de plus au solde net, viennent du juge, avec références de code. L'orchestrateur a relu à la source les plus lourds ; ils n'ont pas eu de seconde revue indépendante.
- 🟠 35 retraits reposent sur le code seul : aucune paire disponible dans un même lot de snapshot.
- 🟠 Le contrôle des doublons compare la source déclarée. Il ne traverse pas seul les FB : les doublons cachés ont été trouvés par le juge.
- 🟠 Aucun test sur automate. Les snapshots datent d'avant le lot 1 et mêlent plusieurs versions du code.
- 🟠 L'ordre réel de la MainTask reste à confirmer selon l'AF-02.

## 8. Consommateurs à migrer à J4

| Consommateur | À faire |
|---|---|
| 15 variables retirées et lues par des listes de trace | Colonne `listes_trace` de la table |
| `test_fb_troubleshootingview.st` | 6 assertions |
| `MOCK_GVL_Troubleshooting.st`, types `ST_Chain*`, `AF_Partie-14` | Suivre la nouvelle structure |
| `PRG_T409_M3_FmuBridge_IMPLEMENTATION.st` | Lit `L.Idx403`, conservée |
| `codesys_m3_roundtrip_poc.py` | Lit `L.Idx107` |
| Code ST et gates | Aucun lecteur hors de la vue, selon le juge |

## 9. Décisions pour l'exploitant

| # | Décision | Proposition |
|---:|---|---|
| 1 | Valider l'ordre et la fiche en 10 étapes | ✅ Oui |
| 2 | Valider les 147 retraits | ✅ Oui, appliqués seulement à J4 |
| 3 | Freins en étape 10 plutôt qu'en étape 2 | ✅ Étape 10 |
| 4 | `Idx203_BypassSensorsGlobal`, constante FALSE | Câbler ou retirer ; préférence : retirer tant qu'il n'y a pas de source |
| 5 | `P.Step8_InterlockState/Reason` | Renommer à J4 : ce n'est pas une barrière M3 |
| 6 | `Idx401_SyncMotionAllowed`, jamais écrite | Remplacée à J3 par `SyncOperationPermit`, lu directement |
| 7 | Poursuivre J3 malgré le rejeu sans gain | ✅ Oui : J3 apporte les vraies valeurs |
