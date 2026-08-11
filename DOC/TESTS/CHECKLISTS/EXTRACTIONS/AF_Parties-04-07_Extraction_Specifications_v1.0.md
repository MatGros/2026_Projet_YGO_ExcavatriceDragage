# Extraction de specifications - AF Parties 04 a 07 (v1.0)

> Statut : conservation avant refonte. Toute ligne `TBD` est une incertitude ou
> une divergence a trancher ; elle ne constitue pas une exigence active.

## 🔄 Partie 04 - Cycle et sequences

### A conserver

- `FB_Cycle` reste un sequencer ST a machine d'etat ; il produit des demandes, jamais des sorties physiques.
- Les mouvements semi-auto restent soumis a une presence operateur/homme-mort : relachement = `StartStop=FALSE`, etape conservee, aucune reprise automatique.
- `SafeStop` du domaine concerne mene a `ERROR_HOLD` ; sortie seulement apres cause disparue, Reset sur front et nouvel ordre explicite.
- `FB_DiveSearch` et `FB_ExtractionSequence` sont des assistants reutilisables en maintenance et en cycle ; ils consomment une intention deja arbitree.
- La benne suspend la synchronisation normale pendant sa desynchronisation volontaire.
- Le cycle publie etat, etape, diagnostics et information operateur ; les alarmes restent dans `Error`/`ErrorId`.

### TBD

| Sujet | Incertitude |
|---|---|
| Etapes et transitions | La sequence complete, ses positions initiales et ses conditions de redemarrage doivent etre revalidees avec la future architecture. |
| Compteur prelevements | Retention, evenement d'incrementation et reset IHM a confirmer. |
| Kobold | Semantique precise 0->1->0, seuils eau/fond et comportements en defaut a garder dans un contrat capteur dedie. |
| Synchronisation | **Aucun asservissement continu de vitesse** : les deux treuils recoivent la meme commande ; l'equilibrage mecanique des charges est attendu en fonctionnement nominal. |
| Seuil synchro 1 | Si le premier seuil d'ecart est depasse pendant un mouvement synchronise, arreter le mouvement principal. Le rattrapage de l'axe en retard est autorise seulement dans une phase dediee, puis la marche synchronisee peut reprendre. |
| Escalade synchro | Si l'ecart persiste, s'aggrave ou que l'arret n'est pas confirme, escalader vers le defaut safety applicable. |
| Rattrapage | Manuel par l'operateur ou automatique sous conditions : **TBD**. Aucun ajustement automatique en plein mouvement synchronise n'est autorise. |
| Seuils | Vitesses, distances, offsets, timeouts et surveillance d'ecart sont `TBD` tant qu'ils ne sont pas qualifies terrain. |
| Messages | Contrat des messages d'action et d'etat IHM : `TBD` Partie 07. |

## 🎚️ Partie 05 - Modes et maintenance

### A conserver

- Modes machine confirmes : Manuel, Maintenance N1, Maintenance N2, Semi-auto.
- `FB_Modes` est l'arbitre des droits, permissions et sources de commande ; il ne produit pas les sorties physiques.
- En nominal, le joystick pilote M1 et M2 ensemble.
- En `MAINT_N2`, une selection explicite autorise le pilotage independant de M1 ou M2. Le treuil non selectionne reste non commande, frein serre et safety active ; il n'est pas inhibe.
- `SyncEnable` est une fonction/autorisation de synchronisation, actionnable en N1/N2 ; il ne constitue pas un mode machine.
- `FB_DiveSearch` (Diving/plongee Kobold) et `FB_ExtractionSequence` (Extraction) sont des petits cycles ST de maintenance reutilisables par le cycle semi-auto ; ils ne constituent pas des modes machine.
- La limite legale est une interdiction d'exploitation, pas une fonction safety.
- N2 exige une action consciente/authentifiee et rend visible toute degradation de protection.
- L'inhibition d'un treuil neutralise son mouvement et impose les consequences de synchronisation associees.
- Un defaut de device ou de commande arrete le domaine par `SafeStop`, puis impose une reprise explicite en maintenance selon les droits.

### TBD

| Sujet | Incertitude |
|---|---|
| Droits N1/N2 | Les modes et leurs droits principaux sont confirmes. La matrice exhaustive des bypass, son authentification et sa tracabilite restent `TBD`. |
| SyncEnable | Son role est confirme ; le detail de tous ses effets par defaut safety sera porte par les contrats Safety/Winch. |
| Limite legale | Regle cible par mode et par direction a valider ; aucun seuil ne doit etre recopie hors proprietaire. |
| Source commande | Contrat cible joystick, boutons IHM et cycle a definir dans AF02/AF03. |

## 📥 Partie 06 - Conditionnement E/S

### A conserver

- Frontiere unique : materiel brut -> image reelle/simulee -> image qualifiee -> consommateurs.
- Polarite normalisee une seule fois en acquisition ; aucun FB metier ne reinverse un signal.
- Les noms E/S viennent du device/export CODESYS et doivent dire ce que signifie `TRUE`.
- `PowerContactorEngaged` confirme le contacteur puissance ; `EmergencyChainClosed` confirme la boucle AU.
- Les barrieres finales sont en Ladder dans `PRG_OUTPUTS_LD` et sont seules productrices des commandes physiques.
- `SafeStop` laisse la deceleration metier se terminer ; `Enable=FALSE`, perte contacteur, timeout ou defaut final provoquent la coupure finale appropriee.

### TBD

| Sujet | Incertitude |
|---|---|
| CFC acquisition | Representation CFC de l'acquisition et des codeurs a definir sans modifier la frontiere fonctionnelle. |
| FB_Output | Son maintien comme POU non instancie est transitoire ou definitif : `TBD`. |
| Noms A/B maintien puissance | **Confirmes export/device** : `PowerKeepAlive_A_RQ`, `PowerKeepAlive_B_RQ`, `EmergencyArming_RQ`, `EmergencyChainClosed_DI`, `PowerContactorEngaged_DI`. |
| Filtrage | Les 20 ms cites sont l'etat actuel ; durees par signal et qualification terrain : `TBD`. |

## 🖥️ Partie 07 - Interface IHM

### A conserver

- `GVL_IHM` est la frontiere d'echange IHM.
- Chaque domaine utilise les memes structures dediees : `Cmd`, `State`, `Cfg` et, si justifie, `Bypass`/`Test`.
- `Cmd` est ecrit par l'IHM et consomme par un arbitre ; `State` est produit par le domaine ; `Cfg` est borne et persiste selon regle validee.
- L'IHM ne lit ni n'ecrit les internes des FB.
- Distinguer message d'action operateur et message d'etat machine.

### TBD

| Sujet | Incertitude |
|---|---|
| Mapping | Le besoin d'un programme ST de mapping/persistance/agregation est `TBD`; il n'est pas automatiquement un CFC. |
| Messages | Conserver la distinction action attendue / etat machine. Format, priorites et concatenation : `TBD`. |
| Troubleshooting | Structures lecture seule, ordre d'affichage, programme eventuel et ordonnancement : `TBD`. |
| Types actuels | AF07 v1.7/v1.9 contient des exemples obsoletes ; la future AF07 se limite au contrat structurel et renvoie au code pour les champs. |

## 🚨 Regles de refonte 04 a 07

- Une exigence de mouvement, safety, E/S ou IHM n'apparait qu'une fois chez son proprietaire ; les autres parties renvoient.
- Toute valeur terrain non qualifiee est `TBD`, jamais une valeur par defaut transformee en exigence.
- Aucun texte ne decrit une autonomie de mouvement si l'homme-mort reste requis.
- La future architecture CFC n'autorise ni sortie physique, ni arbitrage de commande, ni logique de sequence dans une page CFC.
