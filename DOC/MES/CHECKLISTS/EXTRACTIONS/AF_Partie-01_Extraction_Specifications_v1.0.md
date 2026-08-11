# Extraction de specifications - AF Partie 01 (v1.0)

> Source analysee : `ARCHIVES/Doc/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md`.
> Statut : fiche de travail de conservation et de controle. Elle ne remplace pas l'AF01.
> Objectif : preparer une reecriture plus concise sans perdre une exigence, une polarite,
> une condition, une temporisation, une responsabilite ou un risque de securite.

---

## Regle d'utilisation

- Une exigence `VERIFIEE` provient de l'AF01 actuelle ou du code lu ; elle doit survivre a la reecriture, sauf decision explicite.
- Une exigence `A CONFIRMER` provient d'un commentaire utilisateur ou revele un ecart ; elle ne devient pas une regle active sans validation.
- Toute decision de nommage E/S doit etre verifiee contre les devices reels/export CODESYS avant propagation documentaire et code.
- La passe de correction des liens et versions sera faite apres la revue de fond de toutes les parties.

---

## 1. Perimetre et objet machine

| Statut | Sujet | Specification a conserver ou a confirmer |
|---|---|---|
| VERIFIEE | Projet | Excavatrice de dragage en carriere noyee, automatisee sous CODESYS 3.5. |
| VERIFIEE | Perimetre IHM | Le graphisme et l'ergonomie IHM sont hors perimetre. L'automate doit toutefois fournir une interface structuree de variables, en lecture/ecriture, pour l'IHM. |
| VERIFIEE | M1 | Treuil 1 avec codeur absolu `COD1`. |
| VERIFIEE | M2 | Treuil 2 avec codeur absolu `COD2`. |
| A CONFIRMER | M3 | Translation : deplacement du chariot/pont, pilote par variateur AC600 sur EtherCAT. Cette description est pedagogique ; elle n'impose pas un nom de variable ou de POU. |
| VERIFIEE | Benne | Pas de moteur propre : ouverture/fermeture par desynchronisation commandee des treuils M1/M2. |

---

## 2. Fonctions a distinguer

| Nature | Fonction | Responsabilite |
|---|---|---|
| Metier | Joystick | Produit un ordre de marche, une direction et une demande de vitesse. Selon le mode et les etats autorises, il permet de manipuler les treuils, la translation ou l'ouverture/fermeture de la benne. |
| Metier | Treuil x2 | Direction, vitesse par paliers, frein, position, limites et execution du mouvement. |
| Metier | Translation | Deplace le chariot/pont vers la position demandee. |
| Metier | Benne | Orchestre la desynchronisation M1/M2 necessaire a son ouverture/fermeture. |
| Metier | Cycle | Orchestre une sequence semi-automatique repetable. |
| Metier | Modes | Arbitre les modes de marche et les autorisations. |
| Transverse | Simulation | Permet le travail hors ligne et sans materiel. Ce n'est pas une fonction metier, mais une capacite requise du projet. |
| Systeme | Diagnostic devices | Surveille la disponibilite et l'etat des devices/bus afin que la machine atteigne un etat sur en cas de defaillance pertinente. |
| Securite | Safety | Surveille les incoherences dangereuses de mouvement, de commande et d'organes ; declenche l'action de protection appropriee. |
| Securite materielle | Arret d'urgence / coupure puissance | Coupe l'energie des moteurs et actionneurs par contacteur general, sans couper l'automate. |

---

## 3. Equipements et mesures

| Sujet | Specification |
|---|---|
| Treuils | Chaque treuil possede deux contacteurs de sens de marche et quatre contacteurs de vitesse. |
| Paliers | Cinq paliers de vitesse sont definis par une table de masques de quatre bits, independante pour M1 et M2. L'ordre d'actionnement est explicite dans la table. |
| Codeurs | Les codeurs fournissent position et vitesse. Ils servent au suivi altimetrique/profondeur pour l'operateur, aux limites, au synchronisme M1/M2, a la detection d'anomalies de mouvement et a la determination d'etats mecaniques, notamment benne ouverte/fermee. |
| Freins | Freins manque-courant : le frein est serre au repos. |
| Briques | Les fonctions standards CODESYS disponibles doivent etre composees et non reimplementees sans justification. |

---

## 4. Chaine de commande et arrets

| Niveau | Declencheur / condition | Effet impose |
|---|---|---|
| Commande normale | `StartStop = FALSE`, `Enable = TRUE`, pas de `SafeStop` | Deceleration normale. |
| Arret rapide logiciel | `SafeStop = TRUE`, `Enable = TRUE` | Deceleration rapide ; le FB de mouvement reste actif jusqu'a l'arret. |
| Neutralisation | `Enable = FALSE` ou `PowerContactorEngaged = FALSE` | Sorties du FB neutralisees. |
| Safety mouvement | Defaut dangereux detecte par le bloc safety du domaine | `SafeStop` et, si le risque le justifie, demande de coupure totale de puissance. |
| Arret d'urgence / coupure puissance | Bouton AU physique, perte du maintien PLC, ou demande safety majeure | Coupure materielle de l'energie moteurs/actionneurs par le contacteur general ; l'automate reste alimente. |

### Frein - exigence a formaliser dans les parties mouvement

| Statut | Exigence |
|---|---|
| VERIFIEE | La commande de frein doit respecter une sequence physique : relachement apres conditions d'etablissement moteur ; serrage apres deceleration. |
| A CONFIRMER | Au relachement du joystick, le mouvement doit basculer tres rapidement vers la petite vitesse et les contacteurs de sens doivent etre coupes. |
| A CONFIRMER | Le serrage du frein doit etre conditionne par la vitesse lineaire cable mesuree et par une temporisation. Une temporisation maximale de securite doit provoquer le serrage meme si la vitesse n'est pas confirmee nulle. |
| A DEFINIR | Seuil de vitesse de serrage, temporisation nominale, temporisation maximale, comportement par sens et comportement en perte de mesure vitesse. |

---

## 5. Securite electrique et rearmement

| Element | Role a conserver |
|---|---|
| Automate | Reste alimente en permanence pour surveiller les retours et gerer le rearmement. |
| Boucle AU physique | Boutons coup-de-poing en serie ; elle coupe le contacteur general independamment de toute decision logicielle. |
| Deux sorties relais PLC | Integrees a la boucle AU pour permettre une coupure puissance demandee par l'automate dans certains cas safety. |
| Retour boucle | Indique que les conditions electriques d'armement sont reunies ; ce n'est pas le portail maitre des FB mouvement. |
| Retour contacteur | Confirme que le contacteur de puissance est reellement engage ; il devient le portail `PowerContactorEngaged` des FB mouvement. |
| Commande de rearmement | Impulsion PLC commandee explicitement par l'operateur depuis l'IHM ; elle remplace fonctionnellement un bouton de rearmement, elle n'est pas un rearmement automatique. |
| Anti-auto-rearmement | Le retour a une boucle saine ne doit jamais, a lui seul, reenclencher le contacteur. |
| Requete de rearmement | Front montant, boucle saine, contacteur ouvert, aucune impulsion/verrouillage deja actif. |
| Temporisations | Impulsion : 1 s. Verrouillage apres impulsion : 5 s. Echec si le retour contacteur n'est pas confirme sous 2 s. |
| Acquittement | Acquitter un defaut safety et rearmer le contacteur sont deux actions distinctes. |
| Fail-safe | En etat sain, les deux voies PLC doivent etre maintenues actives. Perte PLC, perte alimentation ou watchdog doit faire retomber les sorties et couper la puissance. |
| Redondance | Les deux canaux sont logiquement identiques ; l'independance effective depend du cablage reel. Un essai canal par canal est requis. |

---

## 6. Protections mouvement

| Protection | Condition resumee | Reponse |
|---|---|---|
| Mouvement non commande | Deplacement detecte alors que contacteurs et frein sont confirmes au repos. | Coupure puissance majeure. |
| Pilotage sans commande operateur | Organes de puissance encore engages alors que l'operateur ne commande plus depuis un temps anormal. | Coupure puissance majeure. |
| Glissement charge / benne | Apres une demande d'arret ou pendant l'action benne, mouvement/position incoherent indiquant une charge entrainante, un frein defaillant ou une incoherence de commande. | Protection en profondeur ; escalade possible vers coupure puissance majeure. |
| Benne couche 1 | `FB_Bucket` detecte le glissement M1. | `SafeStop`. |
| Benne couche 2 | Surveillance safety rattachee a M1, si la couche 1 est insuffisante. | Coupure puissance majeure. |
| Limite legale | Interdiction reglementaire de travailler sous une cote. | Interdiction normale geree par les modes, pas une fonction safety. |

---

## 7. Modes, cycle et referencement

| Sujet | Specification |
|---|---|
| Maintenance N1 | Doit permettre l'ensemble des manoeuvres necessaires, de maniere non cyclee mais restant autorisee et encadree. |
| Semi-auto | Graphe d'etats / cadence une sequence des manoeuvres faisables en maintenance N1. |
| Cycle auto | Sequence et boucle definies ; l'AF01 ne doit pas figer ici le detail qui appartient a la Partie 04. |
| Cycle indicatif actuel | Descente benne ouverte, fond touche, synchronisation/recalage, remontee, egouttage, translation vidange, descente/ouverture, retour travail. |
| Plan de reference | Le toucher eau est le plan affiche a 0 m. |
| Offset codeur | Le preset brut est positif et distinct de l'affichage. |
| Convention position | Remontee/enroulement positif ; descente sous l'eau negatif. |

---

## 8. Contrat IHM PLC a conserver

| Categorie | Besoin |
|---|---|
| Commandes | Structures d'echange IHM vers PLC pour ordres, selections, reglages et acquittements autorises. |
| Etats et mesures | Structures PLC vers IHM pour mode, etat machine, etapes, position, profondeur, diagnostics et disponibilites. |
| Message operateur d'action | Champ texte ou liste de messages indiquant clairement l'action attendue de l'operateur, par exemple une action joystick ou un rearmement. |
| Message d'etat | Champ texte ou liste de messages indiquant l'etat courant sans demander une action : mode, etape de sequence, attente interne, etc. |
| Presentation | Plusieurs messages peuvent devoir etre affiches simultanement ou concatenees ; priorisation et format restent a specifier dans la Partie 07. |

---

## 9. Points ouverts et controles avant reecriture AF01

| Priorite | Point | Action requise |
|---|---|---|
| Haute | Noms des E/S safety | Verifier les noms finaux sur les devices reels et/ou l'export CODESYS avant de retenir `EmergencyChainClosed`, `PowerKeepAlive`, `PowerCutOff` ou leurs suffixes. |
| Haute | Polarite des sorties safety | Verifier sur le cablage et les devices que `TRUE` maintient bien chaque voie en etat sain et que l'absence de commande ouvre la boucle. |
| Haute | Redondance A/B | Essai terrain de coupure independant par canal et verification de l'absence de retour de divergence. |
| Haute | Frein | Definir seuil vitesse, temporisations, source de vitesse fiable et repli en cas de perte de mesure. |
| Moyenne | Safety Translation | Confirmer quelles surveillances mouvement M3 sont actives ; l'AF01 indique aujourd'hui que `PowerCutOff` M3 est constamment a `FALSE`. |
| Moyenne | IHM | Specifier en Partie 07 le contrat des messages d'action, messages d'etat, priorites et affichage multiple. |
| Moyenne | Liens documentaires | Corriger en fin de revue les versions de liens et les references de POU, sans melanger cette correction avec la refonte de fond. |
| Moyenne | Vocabulaire | Conserver des noms de protections descriptifs ; ne pas propager les anciens suffixes alphabetiques de cas safety. |

## Incoherences constatees dans la source

- `PowerKeepAlive_A_RQ/B_RQ` et `PowerCutOff_A_RQ/B_RQ` sont employes pour le canal fail-safe. La formule et le fichier code cite emploient `PowerCutOff`, tandis que le texte explique une commande de maintien. Aucun renommage ne doit etre fait avant verification materiel/export.
- L'AF01 cite `Outputs_Outputs`, alors que le fichier ST actif observe est `CODE/MAIN/Outputs (Ladder).st`.
- Les liens vers les Parties 02, 03 et 09 citent des versions anciennes. Cette fiche enregistre le sujet, mais ne corrige pas encore les liens.
