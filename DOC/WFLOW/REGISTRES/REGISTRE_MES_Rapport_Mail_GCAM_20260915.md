# 📬 Rapport & Bilan de Mise en Service — Mail GCAM YGO (15/09/2026)

> **Document de traçabilité** : Synthèse d'avancement, arbitrages et reste à faire rédigés suite aux essais machine du 15/09/2026.  
> **Source** : Transmission d'information / retour d'essais GCAM YGO.  
> **Date** : 2026-09-15.

---

## 📝 1. Transcription intégrale du message

```text
En gros ce que j'ai en tête ... peut être oublié certaines choses...

Points vus, traités ou partiellement traités :
- 24 V variateurs : le 24 V doit rester alimenté au redémarrage, même AU relâché. Sans lui, les variateurs remontent en défaut, les codeurs sont en faux défaut, les positions ne sont pas disponibles et se mettent à jour trop tard après réarmement de la chaîne de sécurité.
- Bit de vie : abandonné. L’IHM ne permet pas de le récupérer simplement depuis le status word et son intérêt est faible au vu de l’usage limité du joystick manuel. Les bits libérés serviront à des alarmes utiles, notamment les discordances commande / retour contacteurs.
- Égouttage : la fonction est prête et testée en simulation. Pour une consigne de 10 s, le compteur décroît de 10 à 0 puis le cycle passe à l’étape suivante. Reste à injecter les variables dans l’IHM et à refaire l’essai machine.
- Descente cycle auto : testé en réel avec M1 palier 4 et M2 palier 5. Le gain est léger mais présent. Actuellement, l’option doit être activée à chaque démarrage ; si le fonctionnement se confirme, elle passera en fonctionnement nominal.
- Montée contrôlée : le palier 2 est nécessaire sur environ 1 m de remontée. Avec 0 m, les contacteurs de vitesse s’enchaînent trop vite et l’installation disjoncte... à voir le comportement si je gomme l'arrêt entre fermeture benne et remontée M1 M2.

Points techniques à traiter avant la semaine prochaine :
- % de fermeture benne avant remontée : les variables sont prêtes, mais aucune logique cycle n’est encore faite. La priorité est sur les autres fonctions pour l'instant...
- Transition fermeture / remontée en grappin : objectif = ne pas attendre la fermeture complète avant de monter avec les deux treuils, afin de soulager M2 seul. À simuler et tester avant toute mise en réel : passage AX10 → AX11, commandes, freins, contacteurs et continuité de mouvement.
- Fin de course haut en remontée : le logiciel réagit actuellement sur M2 alors que la référence nominale doit être M1 lorsque les deux treuils remontent ensemble. Le capteur de fin de course mécanique commun reste une protection séparée. Correctif à cadrer et valider avant essai.
- Discordance contacteurs : première détection validée en simulation. Si une commande est demandée alors que le retour indique les contacteurs au repos, alarme puis SafeStop après 3 s. Il faut compléter les causes multiples de discordance avec suffisamment de détail pour la maintenance en cas de blocage.
- Réglage montée contrôlée : retour essai à reporter dans le programme et la persistance : distance de montée contrôlée passée de 0,5 m à 1,0 m.
- Benne – erreur timeout d’ouverture AX15B : diagnostic à faire avant de toucher au timeout. Il faut déterminer s’il s’agit d’un mouvement trop lent, d’une perte d’autorisation, d’une mesure incohérente ou d’une commande interrompue.
- M3 : défauts encore à diagnostiquer aux arrivées Trémie / P1 (rebonds capteurs et retour frein). Pas de correction production tant que la trace réelle n’a pas confirmé la cause.

« Points techniques / reste à faire » :
- Translation M3 – fréquences variateur : prévoir deux paramètres persistants : vitesse nominale à 50 Hz et vitesse réduite en zone PV à 15 Hz. À intégrer sans modifier les rampes ni les sécurités existantes.
- Régression M3 sur butées Trémie / P1 : lors de l’arrivée sur une position, la translation peut continuer et dépasser le capteur. Cause non établie : rebond/clignotement capteur, effet de charge mécanique ou logique de séquence. À fiabiliser après analyse des traces et simulation de tous les cas de rebond ; aucune modification de FB_Brake sans preuve de cause.
- Armement joystick : le permit d’armement est parfois incohérent avec les autorisations réelles de mouvement. L’utilisateur peut voir le joystick armé alors que le mouvement est interdit, ce qui génère ensuite des défauts « commande sans mouvement ». À corriger pour que l’état d’armement reflète réellement les permis de déplacement.
- Passage des paliers treuils sous charge : prévoir, en complément des temporisations fixes, une condition de vitesse câble avant le passage à un palier supérieur. Le but est d’éviter l’enchaînement des contacteurs alors que le treuil n’a pas atteint une vitesse suffisante, avec risque de calage, surintensité et disjonction. Fonction désactivable depuis l’IHM, mémorisée en persistant, avec seuils distincts montée/descente et M1/M2, plus une hystérésis pour éviter les basculements instables. Sujet à simuler et valider avant machine.
- Cycle homing : intégration et test complet à faire. Le cycle est actuellement buggué : reproduire le défaut, corriger la séquence, valider en simulation puis tester sur machine.
- AX15B – ErrorID:03 ouverture benne : erreur rencontrée pendant les essais. Diagnostic à faire avant toute modification du timeout : déterminer si le faux défaut provient de la commande, d’une autorisation M2, de la mesure de position ou de la temporisation.
- Finaliser l’outil de recherche et d’export CSV/Excel des messages opérateur, alarmes et indications. La structure est prête ; restent à valider tous les textes de cause, conseils de maintenance et actions opérateur.
- GVL Troubleshooting : refactorer la présentation des informations pour qu’elle soit chronologique et directement exploitable en maintenance : comprendre rapidement pourquoi un moteur est bloqué, sans devoir parcourir le code.
- Raccourcis IHM de cycle : étudier quelques boutons de mise en service pour préparer des sauts contrôlés vers des étapes utiles (Trémie, P1, fond, etc.). À réserver au mode essai, avec préconditions, commandes neutres et reprise consciente ; jamais un saut direct sans les sécurités du cycle.
```

---

## 📊 2. Ventilation technique & Correspondance Catalogue (`TASKS.yaml`)

| Domaine | Sujet technique | Statut / Décision | Tâche projet |
|---|---|---|---|
| **Matériel / 24 V** | Maintien de l'alimentation 24 V variateurs au redémarrage | Contrainte électrique validée (évite les faux défauts codeurs/variateurs). | Matériel / Câblage |
| **IHM / Bus** | Abandon du bit de vie status word | Réaffectation des bits libérés pour les discordances contacteurs. | Validé |
| **Cycle (AX13)** | Égouttage godet | Prêt en simulation (10s ➔ 0s) ; intégration IHM à finaliser. | `T289` |
| **Treuils (Descente)** | Plongée M1=P4 / M2=P5 | Validé en réel (gain léger) ; à pérenniser en nominal si confirmé. | `T291-A` |
| **Cycle (AX11)** | Montée contrôlée portée à 1,0 m (Palier 2) | Nécessaire pour éviter la disjonction de puissance au décollage du fond. | [`T298`](../CONTRACTS/TASK_CONTRACT_T298_EXTRACTION_CONTROL_DISTANCE.yaml) |
| **Cycle (AX10➔AX11)** | Transition en grappin (remontée avant fermeture complète) | Soulager M2 seul ; étude chronogramme continue freins/contacteurs. | `T262` |
| **Treuils (Sécurité)** | Fin de course haut calé sur M1 en Both | M1 doit être la référence nominale en Both (M2 reste barrière de sécurité). | **`T301`** (à créer) |
| **Sécurité / Puissance** | Détection discordance contacteurs | Phase 1 validée simu (alarme + SafeStop 3s) ; détailler les causes maintenance. | `T288` |
| **Benne (AX15B)** | Diagnostic timeout ouverture benne ErrorID:03 | Cartographier et diagnostiquer la cause réelle avant de toucher au timeout. | [`T295`](../CONTRACTS/TASK_CONTRACT_T295_AX15B_BUCKET_OPEN_TIMEOUT.yaml) |
| **Translation M3** | Fréquences 50 Hz nominal / 15 Hz en zone PV | Deux paramètres configurables et persistants sans modifier les sécurités. | [`T296`](../CONTRACTS/TASK_CONTRACT_T296_M3_FREQUENCES_PERSISTANTES.yaml) |
| **Translation M3** | Dépassement sur butées Trémie / P1 | Analyse des rebonds capteurs et arrêt mécanique avant patch. | `T287` / `T288` |
| **Joystick** | Armement (`ArmingPermit`) cohérent avec permis | Éviter le faux état armé qui génère "commande sans mouvement". | `T224` |
| **Treuils (Contrôle)** | Paliers sous charge conditionnés par la vitesse câble | Éviter calage et disjonction ; condition vitesse + tempo, seuils débrayables. | **`T300`** (à créer) |
| **Cycle Homing** | Fiabilisation cycle référencement | Reproduire le bug, corriger la séquence, valider en simu puis machine. | **`T302`** (à créer) |
| **Supervision / Outils** | Outil export CSV/Excel alarmes et messages | Valider textes, causes et conseils opérateur. | `T255` |
| **Supervision** | Refonte chronologique GVL Troubleshooting | Vue temporelle directe pour diagnostic rapide sans ouvrir le code. | **`T303`** (à créer) |
| **IHM / Essais** | Raccourcis / sauts d'étapes (AX7, Trémie...) | Sauts contrôlés pour essais avec préconditions et reprise consciente. | [`T297`](../CONTRACTS/TASK_CONTRACT_T297_CYCLE_IHM_FORCE_AX7.yaml) |
| **Cycle (Compteur)** | Compteur de prélèvements (dépose trémie) + RAZ | Incrément en AX18 vérifié + bouton RAZ IHM à ajouter. | [`T299`](../CONTRACTS/TASK_CONTRACT_T299_CYCLE_SAMPLE_COUNT.yaml) |
