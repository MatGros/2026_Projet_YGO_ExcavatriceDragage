# Politique de rédaction du code ST

## 1. Objectif

Produire du Structured Text CODESYS 3.5 lisible, importable, traçable et cohérent avec les
spécifications actives et les tests du projet.

## 2. Sources obligatoires avant modification

- `DOC/STDS/CODE_QUALITY_STANDARDS.md` (déclaration, liaison, POO — référentiel propriétaire)
- `DOC/STDS/NAMING_CONVENTION.md`
- `DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md`
- `DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md`
- la spécification métier active concernée
- les tests et le code des appelants impactés

`ARCHIVES/` n'est jamais une source active.

### Sources de vérité et artefacts dérivés

- Les sources de conception sont les fichiers ST et, quand ils existent, les POU XML natifs/CFC (ex. `PRG_GLOBAL_CFC.xml`). Le travail doit préserver la cohérence entre ces sources.
- Le bundle PLCopenXML (`CODE_XML/CODE_Bundle.xml`) est un artefact dérivé. Il est généré par l'outil dédié et doit être considéré comme résultat de compilation/import, pas comme une source à éditer à la main.
- Les agents doivent conserver la cohérence des noms de POU, des interfaces, des variables et des références entre le code ST et les objets XML natifs/CFC avant génération.
- Si un changement impacte un POU XML natif/CFC, l'agent doit le traiter comme une source métier à préserver et l'intégrer par le générateur, pas par une correction manuelle du XML final.
- L'outil ST2PY est un outil de simulation et de tests hors-PLC ; il aide à valider la logique et la non-régression, mais ne remplace ni la compilation CODESYS ni les essais terrain.

## 3. Nommage

- PascalCase partout, sans hongrois.
- Identifiants techniques en anglais selon la convention active.
- Commentaires en français.
- `FB_` : Function Block ; `ST_` : structure ; `E_` : enum.
- `PRG_XX_` : programme autonome numéroté.
- Avant toute écriture dans `CODE/MAIN/`, le contrat de tâche porte les deux objectifs
  structurels vérifiables : nom de fichier = nom de POU, et suffixe = langage généré
  dans le bundle. `check_task_contract.py` les refuse sinon ;
  `check_code_structure.py` les vérifie ensuite sur les sources et le bundle.
- Unités explicites : `_M`, `_Pct`, `_Ms`, `_Hz`.
- Entrées de commande : `Enable`, `Reset`, `StartStop` selon le profil.
- Sorties d'état : `Ready`, `Busy`, `Done`, `Error`, `ErrorId`, `State`, `StateAtError`.
- `ReqX` : requête brute ; `CmdX` : commande finale arbitrée.
- Ne pas créer de nouvelle abréviation sans justification dans la convention.

## 4. Profils FB

### FB standard métier

Interface selon Partie 3 : `Enable`, `Reset`, `EmergencyStopOk`, `Mode` et sorties standard.

### FB de mouvement

Ajoute `StartStop` et `SafeStop`.

Précédence obligatoire :

```text
Enable > SafeStop > StartStop
```

- `Enable=FALSE` : neutralisation et sorties coupées.
- `SafeStop=TRUE` avec `Enable=TRUE` : rampe rapide.
- `StartStop=FALSE` sans `SafeStop` : rampe normale.

### Brique réduite

Interface minimale autorisée uniquement si son rôle est documenté dans la spec.

### Interdictions

- `CoupeEnable`.
- `FB_Watchdog` applicatif.
- `SafeStop`/`StartStop` sur un FB qui n'est pas de mouvement.
- redémarrage automatique après défaut.
- réimplémentation d'une librairie CODESYS déjà disponible.

## 5. Programmation orientée objet et encapsulation

➡️ **Propriétaire unique de ces règles : [`DOC/STDS/CODE_QUALITY_STANDARDS.md`](../../../DOC/STDS/CODE_QUALITY_STANDARDS.md) §5.**

Responsabilité unique, producteur unique, composition sans héritage, internes privés,
commandes arbitrées avant l'appel, GVL = frontière et jamais canal caché, structure `ST_*`
seulement pour un contrat cohérent : tout y est, avec les exemples.

Ne pas reformuler ces règles ici — une règle écrite deux fois dérive toujours.

## 6. En-tête obligatoire

Chaque POU possède un en-tête court et lisible :

```pascal
(* ═══════════════════════════════════════════════════════════════
   🎯 Nom du POU — rôle métier
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-XX_...md §...
   🛡️ Sécurité : [règle ou domaine concerné]
   🧩 Dépendances : [FB/PRG principaux]
   ═══════════════════════════════════════════════════════════════ *)
```

Un en-tête décrit le rôle et les contraintes. Il ne recopie pas la spécification complète.

## 7. Commentaires

- Français, précis, orientés rôle/raison/risque.
- Emojis comme repères visuels, jamais comme décoration excessive.
- Une ligne pour une logique évidente ; détail obligatoire pour sécurité, interlock, temporisation,
  polarité, ordre d'appel et correction de bug.
- Commenter le **pourquoi** lorsqu'il n'est pas déductible du code.
- Conserver les références REX et dates lorsqu'elles justifient une décision.
- Ne pas commenter chaque affectation évidente.

Exemple :

```pascal
// 🛡️ SafeStop impose la rampe rapide ; Enable reste maintenu hors AU matériel.
```

## 8. Organisation d'un fichier

➡️ **Voir [`DOC/STDS/CODE_QUALITY_STANDARDS.md`](../../../DOC/STDS/CODE_QUALITY_STANDARDS.md) §7**
(ordre des sections d'un POU + en-tête minimal obligatoire).

## 9. Traçabilité

Toute modification CODE précise dans l'en-tête ou le contexte de tâche :

- document source ;
- section ;
- raison ;
- impact appelants ;
- tests attendus.

Le corps ST reste uniquement dans `CODE/`. La documentation métier référence le fichier sans le
recopier.

## 10. Contrôle avant livraison

```text
Scope → parsing → nommage/interdits → tests → bundle → review → validation CODESYS
```

La validation Python ne remplace pas la compilation/import CODESYS ni les essais terrain.
