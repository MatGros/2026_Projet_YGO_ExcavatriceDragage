# Politique de rédaction du code ST

## 1. Objectif

Produire du Structured Text CODESYS 3.5 lisible, importable, traçable et cohérent avec les
spécifications actives et les tests du projet.

## 2. Sources obligatoires avant modification

- `DOC/NAMING_CONVENTION.md`
- `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md`
- `DOC/AF_Partie-02_Architecture_Programme_v2.12.md`
- la spécification métier active concernée
- les tests et le code des appelants impactés

`ARCHIVES/` n'est jamais une source active.

## 3. Nommage

- PascalCase partout, sans hongrois.
- Identifiants techniques en anglais selon la convention active.
- Commentaires en français.
- `FB_` : Function Block ; `ST_` : structure ; `E_` : enum.
- `PRG_XX_` : programme autonome numéroté.
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

## 5. En-tête obligatoire

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

## 6. Commentaires

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

## 7. Organisation d'un fichier

```text
En-tête
Déclarations d'interface
Déclarations internes
Initialisation / gates
Reset sur front
Sécurité et défauts
Logique métier
États et sorties
Diagnostic / IHM
```

Les sections sont séparées par des commentaires courts et stables.

## 8. Traçabilité

Toute modification CODE précise dans l'en-tête ou le contexte de tâche :

- document source ;
- section ;
- raison ;
- impact appelants ;
- tests attendus.

Le corps ST reste uniquement dans `CODE/`. La documentation métier référence le fichier sans le
recopier.

## 9. Contrôle avant livraison

```text
Scope → parsing → nommage/interdits → tests → bundle → review → validation CODESYS
```

La validation Python ne remplace pas la compilation/import CODESYS ni les essais terrain.
