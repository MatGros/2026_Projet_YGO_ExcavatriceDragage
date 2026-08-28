## 🎯 Audit & Challenge Lot T127 — Réponse Expert Senior

### 1. Granularité des tâches — Verdict : ✅ Globalement cohérent, 2 points de vigilance

| Tâche | Criticité | Statut | Analyse |
|-------|-----------|--------|---------|
| T127-A | C2 | ✅ Validé | Harmonisation interfaces — RAS, mais vérifier que le retrait des doublons n'a pas cassé des références dans d'autres FB (ex: `FB_TroubleshootingView`). |
| T127-B | C4 | ✅ Validé | Logique Grafcet — RAS, mais attention : la logique est validée **unitairement**, pas en intégration. Le raccordement final (T127-D) peut révéler des défauts d'interface. |
| T127-C | C2 | ✅ Validé | Diagnostic — RAS, mais vérifier que les Idx 209..216 sont bien exposés dans l'IHM et que les bannières sont cohérentes avec les états réels. |
| T127-D | C4 | ⬜ Bloqué | **Point de vigilance** : le blocage par T165-C2 est-il justifié ? Si T165-C2 est un prérequis pour le bus d'arbitrage, il faut vérifier que l'interface de `PRG_03.Data` est stable. Sinon, on peut avancer en parallèle avec un contrat d'interface gelé. |
| T127-E | C1 | ⬜ À faire | **Trou potentiel** : la campagne de tests CI est C1 (critique) mais planifiée après T127-D. Or, les tests d'intégration devraient être écrits **en parallèle** de T127-D pour valider le raccordement. Suggestion : déplacer T127-E en amont ou au moins écrire les tests d'intégration avant de finaliser T127-D. |
| T127-F | C2 | ⬜ À faire | **Chevauchement possible** avec T127-C : la fiche visuelle doit inclure les bannières de diagnostic. Vérifier que T127-C a bien documenté les messages et que T127-F les réutilise sans les dupliquer. |

**Recommandation** : 
- Clarifier la dépendance T127-D ↔ T165-C2. Si T165-C2 est un prérequis pour le bus, il faut un contrat d'interface écrit et gelé avant de commencer T127-D.
- Déplacer T127-E en **parallèle** de T127-D (écrire les tests d'intégration avant le code final) pour éviter une non-régression silencieuse.

---

### 2. Challenge scénarios de test T127-F — Cas limites manquants

Les scénarios proposés sont bons, mais **incomplets** pour une machine réelle. Voici les cas à ajouter impérativement :

| # | Scénario | Pourquoi c'est critique | Résultat attendu |
|---|----------|------------------------|------------------|
| 1 | **Coupure secteur pendant le cycle** | Perte de l'état Grafcet, reprise au démarrage ? | Le séquenceur doit reprendre à l'étape `PausedState` ou à l'état initial selon la spec. Vérifier la persistance. |
| 2 | **Collage contacteur (M1 ou M2)** | Le contacteur ne s'ouvre pas → mouvement incontrôlé. | Détection par retour de confirmation, passage en défaut, coupure générale. |
| 3 | **Absence de retour contacteur (défaut de câblage)** | Le contacteur est commandé mais le retour DI ne change pas. | Détection de défaut, arrêt immédiat, message explicite. |
| 4 | **Surcharge treuil (déclenchement thermique)** | Le moteur s'arrête, la benne peut tomber. | Détection par variateur ou relais, arrêt d'urgence, maintien de la charge ? |
| 5 | **Fin de course haute (treuil M1)** | La benne atteint la butée haute. | Arrêt de la montée, pas de sur-course. |
| 6 | **Fin de course basse (treuil M2)** | La benne touche le fond, Kobold non détecté (panne capteur). | Le séquenceur doit gérer l'absence de contact fond : temporisation, alarme, arrêt. |
| 7 | **Inversion M1/M2 (erreur de câblage)** | La benne se comporte inversement. | Détection par sens de rotation, défaut, blocage. |
| 8 | **Lâcher de manche pendant la descente avec Kobold** | L'opérateur relâche le joystick en plein mouvement. | Arrêt immédiat, maintien de la position, pas de chute. |
| 9 | **Bascule de mode pendant la phase de fermeture** | L'opérateur passe en Maintenance alors que la benne se ferme. | Mémorisation de l'étape, neutralisation des commandes, reprise après `BtnStart`. |
| 10 | **Défaut de communication IHM** | Perte de la liaison avec la supervision. | Le séquenceur continue en local, alarme IHM. |
| 11 | **Saccade lors des transitions** | L'opérateur perçoit un à-coup entre fermeture et décollage. | Vérifier que les paliers s'enchaînent sans interruption (test de continuité de mouvement). |
| 12 | **Palier 5 sous Kobold (déjà listé)** | OK, mais ajouter le cas où le palier 5 est demandé par l'opérateur **pendant** que Kobold est actif. | Le séquenceur doit refuser le palier 5, pas seulement le bridage en interne. |

**Recommandation** : Ajouter un scénario de **reprise après défaut** : après un arrêt d'urgence, le séquenceur doit reprendre à l'étape mémorisée, pas au début. Vérifier que `PausedState` est bien restauré.

---

### 3. Interconnexion PRG_03 (T127-D) — Points de vigilance

L'encapsulation privée de `instCycleSemiAuto` est une bonne pratique, mais voici les pièges :

| Point | Risque | Action |
|-------|--------|--------|
| **Accès résiduels** | D'autres PRG (PRG_07, PRG_04, IHM) peuvent encore référencer `instCycleSemiAuto` directement. | Faire une recherche globale `grep -r "instCycleSemiAuto"` dans `CODE/` et vérifier que seuls `PRG_03` et les FB internes y accèdent. |
| **Bus d'arbitrage** | `PRG_03.Data.ReqProgram` et `SequenceState` doivent être **cohérents** : si une requête est émise mais que le séquenceur est en défaut, que se passe-t-il ? | Définir une matrice de requêtes valides selon l'état. Ex: `ReqProgram` ne doit pas être actif si `SequenceState` est en défaut. |
| **Priorité des requêtes** | Si plusieurs sources (IHM, auto, manuel) émettent des requêtes simultanément, il faut une priorité claire. | Documenter l'ordre de priorité (ex: défaut > maintenance > auto > manuel). |
| **Synchronisation** | Le passage par `PRG_03.Data` introduit un délai d'un cycle. Vérifier que ce délai ne casse pas la continuité du mouvement (règle 1). | Tester avec un oscilloscope logique (ou chronogramme) que les transitions d'étapes ne créent pas de saccade. |
| **Non-régression** | Les tests unitaires de T127-B ne couvrent pas le raccordement. | Écrire des tests d'intégration qui simulent `PRG_03` et vérifient que les requêtes arrivent bien au séquenceur. |
| **Gestion des erreurs** | Si `PRG_03.Data` est corrompu (ex: écriture par un autre FB), le séquenceur peut recevoir des commandes incohérentes. | Ajouter un contrôle de cohérence (checksum ou validation de plage) sur les données du bus. |

**Recommandation** : Avant de commencer T127-D, faire un **état des lieux des accès** à `instCycleSemiAuto` (grep) et documenter le contrat d'interface de `PRG_03.Data` (types, plages, priorités). Ensuite, implémenter l'encapsulation avec des tests d'intégration dédiés.

---

### 4. Recommandations pour fiches de test & diagnostic

#### Fiches de test CI visuelle (T127-F)
- **Ajouter des captures d'écran** de chaque étape du Grafcet avec les valeurs des variables clés (palier, Kobold, état).
- **Chronogrammes synchronisés** : afficher sur un même axe temporel les signaux (joystick, contacteurs, Kobold, étapes) pour visualiser les transitions.
- **Critères de réussite mesurables** : pour chaque scénario, définir des valeurs attendues (ex: temps de réponse < 100 ms, pas de saccade > 5 % de variation de vitesse).
- **Injection de défauts** : prévoir un mode "simulation de pannes" où l'opérateur peut forcer un défaut (ex: coller un contacteur) et vérifier la réaction.

#### Diagnostic Troubleshooting (T127-C)
- **Ajouter un historique** : mémoriser les 10 derniers événements avec horodatage pour faciliter le dépannage après coup.
- **Messages explicites** : remplacer les codes numériques par des libellés compréhensibles (ex: "Défaut contacteur M1 - Vérifier le câblage").
- **Conseils de dépannage** : pour chaque défaut, afficher une suggestion d'action (ex: "Contrôler le retour DI 3.2").
- **Lien avec la fiche visuelle** : le diagnostic doit pouvoir être superposé à l'animation pour visualiser la cause.

---

## 🚨 Devoir d'alerte

1. **Blocage T127-D par T165-C2** : Je ne connais pas T165-C2. Si c'est un prérequis pour le bus d'arbitrage, il faut un contrat d'interface écrit et gelé avant de commencer. Sinon, on peut avancer en parallèle.
2. **T127-E planifié après T127-D** : Les tests d'intégration devraient être écrits **en même temps** que le code pour valider le raccordement. Sinon, risque de non-régression silencieuse.
3. **Scénario de reprise après coupure secteur** : Absent de la liste T127-F. C'est un cas critique en carrière (coupure EDF). À ajouter.

---

## 📋 Synthèse

| Mission | Verdict | Actions clés |
|---------|---------|--------------|
| Granularité | ✅ OK avec 2 ajustements | Déplacer T127-E en parallèle, clarifier dépendance T165-C2 |
| Scénarios T127-F | ⚠️ Incomplet | Ajouter 12 cas limites (coupure, collage, fin de course, etc.) |
| Interconnexion PRG_03 | ⚠️ Vigilance | Faire un grep des accès, définir matrice de requêtes, tester la continuité |
| Fiches & diagnostic | ✅ Améliorations | Ajouter historique, messages explicites, critères mesurables |

**Prochaine étape** : Valider ces recommandations avec l'orchestrateur avant de lancer T127-D. Je reste disponible pour détailler un point spécifique.