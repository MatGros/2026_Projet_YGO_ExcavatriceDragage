# Registre des arbitrages — Migration 7 POU

> **Nature :** journal des décisions prises en autonomie pendant la migration, et des questions
> qui auraient normalement exigé un arbitrage utilisateur.
>
> **Mandat :** l'utilisateur a demandé une exécution autonome jusqu'à un code testable, avec
> point de sauvegarde Git (`f32dcd6`). Chaque décision prise ici est **révisable** : elle est
> tracée avec ses faits, l'option retenue, les options écartées et le risque résiduel.
>
> **Règle appliquée :** en cas de doute, l'option retenue est **toujours la plus conservative**,
> c'est-à-dire celle qui préserve le comportement machine actuel. Jamais celle qui ouvre une
> autorisation, supprime une surveillance ou introduit un retard.

---

## Comment lire ce registre

| Statut | Signification |
|---|---|
| 🟢 **TRANCHÉ AUTONOME** | Décision prise sans arbitrage, comportement machine conservé à l'identique. |
| 🟡 **TRANCHÉ PROVISOIRE** | Décision prise pour avancer, mais elle mérite une relecture utilisateur. |
| 🔴 **BLOQUANT** | Non tranché. Le lot concerné est arrêté : trancher exigerait d'inventer une règle safety. |

---

## A-01 — Homing lit le mode de marche *(lot M1)*

**Statut : 🟡 TRANCHÉ PROVISOIRE**

### Faits prouvés

`instHomingM1/M2` consomment `PRG_MODES_CFC.Auth.Mode`, `UnitaryMode` et `WinchSelected`
(`CODE/MAIN/PRG_02_Encoders.st:72,74-76,122,124-126`).

Dans l'architecture cible, l'acquisition est au rang 02 et les modes au rang 03 : déplacer le
homing dans l'acquisition ferait lire un producteur aval. Consommateur avant producteur.

### Options

| Option | Effet |
|---|---|
| A — Homing reste après les Modes, dans un bloc dédié | Conserve la fraîcheur, mais ajoute un 8e POU ou déplace le homing dans Modes/Cycle |
| B — Homing déplacé dans l'acquisition avec retard d'un scan | ⛔ Refusée : une autorisation de référencement n'est pas une mesure lecture seule |
| C — Homing déplacé dans le procédé Treuils | Le recalage suit le mouvement qu'il recale ; cohérent avec le découpage par procédé |

### Décision retenue : **C**

Le homing est une fonction de **conduite du treuil**, pas d'acquisition brute : il commande un
preset de position pendant un mouvement de référencement. Le placer dans
`PRG_04_Treuils_Benne_CFC` respecte le principe acté « chaque procédé porte ce qui le concerne »
et supprime la dépendance inverse, puisque Treuils (rang 04) lit bien Modes (rang 03).

L'acquisition conserve la chaîne de mesure pure : absolu, échelle, vitesse, validité,
disponibilité, incohérence de plage.

### Risque résiduel

La séparation mesure/recalage doit être nette : `HomingSuspect` reste un diagnostic produit par
le procédé Treuils, et n'alimente jamais un prédicat pré-Modes. À vérifier en revue M3.

---

## A-02 — `EncoderUnsafe` avant les Modes

**Statut : 🟢 TRANCHÉ AUTONOME**

`FB_Modes` a besoin d'un prédicat de sûreté codeur pour autoriser `SEMI_AUTO`. Ce prédicat doit
donc être disponible au rang 02, avant les Modes au rang 03.

**Décision :** l'acquisition publie `EncoderUnsafe`, composé uniquement de faits qu'elle produit
elle-même : indisponibilité device et incohérence de plage/mesure. `HomingSuspect`, produit au
rang 04, n'y participe pas.

**Conservation :** `HomingSuspect` continue d'invalider position et vitesse, comme aujourd'hui.
Aucune autorisation n'est élargie.

---

## A-03 — `CmdReset` : producteur et frontière

**Statut : 🟡 TRANCHÉ PROVISOIRE**

### Fait

Les quatre boutons Reset sont aujourd'hui agrégés **tardivement** dans `PRG_SUPERVISION_CFC`
(`CODE/MAIN/PRG_SUPERVISION_CFC.st:55-58`) :
`BtnFaultReset`, `M1TreuilRetenue.Cmd.BtnReset`, `M2TreuilBenne.Cmd.BtnReset`,
`M2TreuilBenne.Bucket.Cmd.BtnReset`.

Supervision étant au rang 07, tous les consommateurs Reset lisent une valeur du scan précédent.

### Décision retenue

L'agrégation des quatre boutons remonte dans `PRG_02_Acquisition_CFC`, avec les autres commandes
opérateur. C'est une lecture d'entrée IHM, donc de l'acquisition.

Chaque consommateur continue de détecter le **front** localement. Aucun réarmement automatique.

### Pourquoi c'est provisoire

Un rollback antérieur (`C4.1a`) a été déclenché parce qu'un `CmdReset` avait été introduit **sans
producteur**, rendant le reset potentiellement inopérant. La règle absolue appliquée ici :
le nouveau producteur est écrit **avant** que l'ancien soit retiré, et le lot est refusé si
`grep` ne prouve pas qu'un écrivain existe.

---

## A-04 — Agrégation `PowerCutOff`

**Statut : 🟢 TRANCHÉ — arbitrage utilisateur explicite**

Chaque procédé publie sa demande. `PRG_06_Outputs_LD` agrège et coupe.

Conséquence contrôlée : la demande d'un procédé ne peut jamais être masquée par l'indisponibilité
d'un autre. L'agrégation est un OU logique, jamais un ET.

---

## A-05 — Sécurités croisées

**Statut : 🟢 TRANCHÉ — arbitrage utilisateur explicite**

L'interdiction est portée par le domaine qui la **subit**. Les Modes distribuent des autorisations.

---

## A-06 — État AU

**Statut : 🟢 TRANCHÉ — arbitrage utilisateur explicite**

Acquis en frontière acquisition pour la visibilité maintenance. L'action reste dans la barrière
finale. La chaîne matérielle demeure indépendante et prioritaire.

---

## A-07 — `PRG_SAFETY_CFC` lit une instance interne d'Outputs

**Statut : 🔴 BLOQUANT pour M5**

### Fait

`CODE/MAIN/PRG_SAFETY_CFC.st:216` lit
`GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd`.

C'est un accès à une **instance interne** d'un POU aval, via une GVL. Cela viole l'encapsulation
et crée une dépendance Safety → Outputs alors qu'Outputs est au rang 06.

### Pourquoi ce n'est pas tranché

`BrakeCmd` est une **commande calculée par la barrière**, pas une preuve de position mécanique du
frein — le FB le documente explicitement (`FB_TranslationOutputInterlock_LD.st:5-6`).

La Méca B M3 l'utilise pour distinguer « arrêt commandé » de « arrêt non commandé »
(`FB_Safety_Translation.st:155-183`). Supprimer cette lecture change la détection d'incohérence.
La remplacer par le retour physique de frein change aussi la sémantique.

**Aucune des deux options ne conserve le comportement actuel.** Trancher exigerait de décider
quelle incohérence la Méca B doit détecter — une décision safety.

### Conséquence

Le lot M5 est limité à l'agrégation `PowerCutOff`. La lecture `BrakeCmd` est **conservée telle
quelle** avec son retard d'un scan, documentée comme dette explicite.

---

## A-08 — Fusion Supervision + Troubleshooting

**Statut : 🟢 TRANCHÉ AUTONOME**

Les deux pages sont des observateurs lecture seule, exécutés après les producteurs. Leur fusion
ne doit changer aucun flux : elle supprime un POU sans modifier un seul calcul.

### État staging M6

`PRG_07_Supervision_CFC.xml` est créé comme page CFC native **non référencée par MainTask**.
Il appelle uniquement `FB_SupervisionProjection`, adaptateur neutre sans accès POU, GVL IHM,
commande, configuration, bypass, interlock ou sortie. Il ne peut donc modifier aucun état machine.

Le basculement reste interdit tant que les domaines ne publient pas leurs états par contrats
publics : les deux POU legacy contiennent encore des écritures de mapping/persistance/bypass et
plus de 400 lectures directes `PRG_xxx.instYyy` / `GVL_Global.instYyy`. Les déplacer dans une
supervision « lecture seule » sans propriétaire remplaçant violerait AF03 §1 et AF07 §5.

Invariant conservé : la page staging n'écrit aucune commande, configuration, bypass ou interlock;
les producteurs legacy restent actifs et inchangés.

---

## A-09 — Les instances codeurs dupliquées ne sont PAS des clones *(lot M1)*

**Statut : 🟡 TRANCHÉ PROVISOIRE — révision du plan M1**

### Fait découvert par l'audit M0

Les six instances codeurs dupliquées **ne lisent pas les mêmes signaux** :

| Jeu | Source lue | Nature |
|---|---|---|
| `PRG_02_Encoders` | `PRG_01_Inputs_LD.M1BrakeFeedback`, `.PowerContactorEngaged`, `.TopPositionSensor` (`PRG_02_Encoders.st:54,71,79,81-82,104`) | Signaux **qualifiés** : `FB_Input`, polarité normalisée, filtre 20 ms |
| `PRG_ACQUISITION_CFC` | `HwIn.Winch.M1_BrakeIsOpen_DI` (`PRG_ACQUISITION_CFC.st:62,66,175,217-218`) | Signaux **bruts**, polarité d'origine |

`M1BrakeFeedback` vaut `NOT M1_BrakeIsOpen_DI` : les deux jeux voient une **polarité inverse**.

### Conséquence sur le plan

La fusion M1 n'est **pas** une suppression mécanique de doublons. Choisir un jeu, c'est choisir
une polarité et un filtrage. C'est un arbitrage de qualification d'entrée, pas un nettoyage.

### Décision retenue : conserver le jeu **qualifié**

Le jeu lu par `PRG_02_Encoders` (via `PRG_01_Inputs_LD`, donc `FB_Input`) est retenu :

1. Il applique la polarité normalisée documentée et un filtre anti-rebond de 20 ms.
2. C'est le jeu qui alimente aujourd'hui `FB_Encoder_Safety`, donc les décisions de sûreté.
3. Retenir le jeu brut supprimerait un filtrage existant sur une chaîne safety : dégradation.

Le jeu brut d'Acquisition est supprimé. Chaque suppression exige la preuve qu'aucun consommateur
ne lisait le jeu brut, sans quoi le lot est refusé.

### Risque résiduel

À vérifier en revue M1, signal par signal : polarité, filtre et valeur de repli identiques à
l'existant pour chaque entrée reprise. Toute différence non justifiée = BLOCK.

---

## A-10 — `PRG_01_Inputs_LD.HwIn` n'a aucun producteur prouvable

**Statut : 🔴 BLOQUANT — à traiter dans M1**

### Fait

`PRG_01_Inputs_LD` déclare `HwIn : ST_HardwareImage` en `VAR_INPUT` (`PRG_01_Inputs_LD.st:13`), commenté
« produite par PRG_ACQUISITION_CFC ». Or :

```text
grep "PRG_01_Inputs_LD.HwIn :="  → aucun résultat
grep "PRG_01_Inputs_LD("          → aucun résultat
```

Aucun site d'affectation, aucun appel paramétré dans `CODE/`. Le POU qui produit 22 signaux
qualifiés consommés par 10 POU a une entrée dont le raccordement **n'est pas prouvable depuis
le code source**.

### Interprétation prudente

Deux possibilités, non départageables sans le projet CODESYS :
1. Le raccordement est fait graphiquement dans le projet CODESYS, hors des sources `.st`.
2. `HwIn` n'est jamais alimenté et les 22 signaux qualifiés partent de valeurs par défaut.

L'hypothèse 2 signifierait que des entrées safety sont figées. **Je ne tranche pas** : ce serait
inventer un comportement machine.

### Conséquence

La fusion Acquisition ↔ Inputs prévue en M1 est **suspendue** sur ce point. `PRG_01_Inputs_LD`
reste un POU distinct alimenté explicitement, et le lot M1 doit rendre ce raccordement **visible
et prouvé dans le code** — c'est précisément ce que la migration doit corriger.

⚠️ À vérifier par l'utilisateur dans CODESYS : `PRG_01_Inputs_LD.HwIn` est-il câblé ?

---

## A-11 — `PRG_SAFETY_CFC` ne publie aucun `VAR_OUTPUT`

**Statut : 🟢 TRANCHÉ AUTONOME — confirme le découpage acté**

### Fait

`PRG_SAFETY_CFC` n'a **aucun** `VAR_OUTPUT` (`PRG_SAFETY_CFC.st:9-18`). Ses résultats safety —
`SafeStop`, `PowerCutOff`, `ForbidAscent`, `ForbidDescent` — sont lus directement depuis ses
instances internes : **78 accès** de la forme `PRG_SAFETY_CFC.instXxx.Champ` dans `CODE/`.

### Lecture

C'est la démonstration factuelle que le découpage transverse ne tenait pas : une page safety sans
contrat public, dont tout le monde lit les entrailles, n'est pas une frontière — c'est une
variable globale déguisée.

Le découpage par procédé supprime le problème à la racine : la safety d'un procédé est instanciée
**dans** sa page, ses sorties sont câblées localement, et il n'y a plus 78 accès inter-POU à des
internes.

---

## A-13 — Assainissement des pages CFC staging *(revue intégration XML)*

**Statut : 🟢 TRANCHÉ AUTONOME — staging uniquement**

La revue a détecté des blocs CFC vides dans `PRG_04_Treuils_Benne_CFC.xml`, aucune sortie publique
CFC, et trois expressions booléennes inline dans la page Translation. Ces objets XML pouvaient
s'importer sans représenter un flux exploitable.

### Décisions appliquées

1. `PRG_04_Treuils_Benne_CFC` devient une **projection staging explicitement câblée** des quatre
   résultats safety legacy (M1/M2 `SafeStop` et `PowerCutOff`). Elle ne remplace pas encore les
   FB métier/safety : aucun écrivain actif nouveau n'est créé.
2. Chaque page staging publie maintenant ses sorties via des `outVariable` nommés et raccordés.
3. Les trois expressions Translation (`NOT BrakeThermalFeedback`, deux OR de bypass) sont portées
   par `FB_TranslationCfcExpressions`; le CFC ne contient plus ces calculs.
4. Le gate `check_cfc_wiring.py` rejette désormais : bloc staging sans entrée (W5), expression
   booléenne/calculée inline (W6), publication `outVariable` sans fil (W7).

### Risque résiduel

La page Treuils/Benne est une projection de transition, pas encore le graphe complet M1/M2/benne.
Reconstruire ce graphe exige extraire les arbitrages `IF` de `PRG_TREUILS_CFC` dans des FB dédiés
et basculer tous les consommateurs atomiquement. Les POU legacy restent la seule chaîne active.

---

## A-12 — `PRG_02_Encoders` écrit 6 sorties physiques

**Statut : 🟡 TRANCHÉ PROVISOIRE**

### Fait

`PRG_02_Encoders.st:63-65,113-115` écrit six sorties mappées :
`COD1/COD2_PresettTrigCmd`, `_CodeSeqTrigCmd`, `_PresetValue` (dont `%QW2`).

L'invariant « `Outputs` est l'unique producteur physique » est donc **partiellement faux
aujourd'hui** — même si les 21 commandes d'actionneurs (moteurs, freins, PDO M3, AU) ont bien un
seul écrivain dans `PRG_OUTPUTS_LD`.

### Décision retenue

Ces six sorties sont des **commandes de preset codeur**, pas des commandes d'actionneur : elles ne
mettent aucun mouvement en marche. Elles migrent avec le homing vers `PRG_04_Treuils_Benne_CFC`
(cohérent avec A-01), et sont **déclarées explicitement** comme exception documentée à
l'invariant, plutôt que laissées implicites.

Alternative écartée : les router via `PRG_06_Outputs_LD`. Elle serait plus pure, mais ajouterait
un aller-retour inutile pour une commande qui n'a aucun effet de puissance.

---

## A-13 — Migration en deux états, pour conserver un code testable

**Statut : 🟢 TRANCHÉ AUTONOME — staging non actif**

M1 ne supprime aucun POU legacy et ne rebranche aucun consommateur actif. Une page native
`PRG_02_Acquisition_Staging_CFC.xml` est créée avec un nom **distinct** : elle n'est pas ajoutée à
la MainTask et ne produit donc aucune donnée active concurrente.

Elle contient uniquement :
- `FB_ResetAggregation`, dont les quatre entrées sont les quatre boutons IHM historiques ;
- `FB_AcquisitionRouter`, extraction exacte de l'aiguillage réel/simulé historique.

Cette étape matérialise le CFC XML natif et isole deux logiques de page dans des FB ST. Le
basculement vers `PRG_02_Acquisition_CFC` ne sera réalisé que lorsqu'un lot aura remappé tous les
consommateurs et supprimé les producteurs legacy dans la même modification.

### Risque résiduel

La page staging n'est pas une fonction active. Elle ne vaut ni preuve CODESYS d'affichage, ni
migration M1 complète; elle est un artefact de construction testable au bundle et CFC wiring.

---

## A-14 — Modes/Cycle : staging XML avant basculement atomique

**Statut : 🟡 TRANCHÉ PROVISOIRE — staging non actif**

`PRG_03_Modes_Cycle_CFC.xml` est créé comme page CFC native distincte de
`PRG_MODES_CFC` et `PRG_05_Cycle`. Il n'est pas référencé par la MainTask : les POU legacy
restent les seuls producteurs actifs de `Auth` et des demandes Cycle jusqu'au basculement M7.

### Contenu du staging

- `FB_Modes` est appelé avec les mêmes entrées que `PRG_MODES_CFC`.
- `FB_CycleIhmBridge` extrait les captures impulsionnelles IHM, la remise à zéro des quatre
  boutons Cycle et l'homme-mort; il produit `CycleEnable` exclusivement si `Mode=SEMI_AUTO`.
- `FB_Cycle` reçoit les mêmes retours métier que `PRG_05_Cycle`.

Aucune sortie physique ni aucune tâche CODESYS n'est modifiée.

### Risque résiduel

La page staging lit encore les retours d'instances legacy Treuils/Translation/Codeurs car leurs
contrats publics n'existent pas encore. C'est acceptable uniquement car elle est hors MainTask.
Le lot M3/M4 devra remplacer ces accès par les contrats des procédés avant activation.

---

## A-14 — M3 XML : page de staging non raccordée à la MainTask

**Statut : 🟡 TRANCHÉ PROVISOIRE — staging seulement**

`PRG_04_Treuils_Benne_CFC.xml` est créé comme page CFC native avec les instances locales
M1/M2 : safety, moniteurs vitesse, estimateurs charge, synchro, benne, plongée, extraction,
homing et mouvements. Les trois sorties safety `SafeStop`, `ForbidDescent`, `ForbidAscent` de
chaque `FB_Safety_Winch` sont explicitement raccordées au `FB_Winch` correspondant.

La page **n'est pas appelée par la MainTask** : `PRG_TREUILS_CFC` et `PRG_SAFETY_CFC` restent les
seuls POU actifs, inchangés. Aucun producteur nouveau n'alimente Outputs, aucune commande physique
n'est dupliquée. Cette décision protège le banc d'essai existant pendant que les contrats publics,
les 14 champs interlock et le remappage atomique sont finalisés.

⚠️ La page est une preuve de structure et de lisibilité CFC, pas encore le remplacement
fonctionnel de l'ancien couple Treuils/Safety. Activer cette page avant le basculement M7
appellerait des FB avec des entrées non encore remappées. C'est interdit.

---

## A-15 — M4 Translation : staging XML local, non actif

**Statut : 🟡 TRANCHÉ PROVISOIRE — staging seulement**

`PRG_05_Translation_CFC.xml` est créé comme CFC natif hors MainTask. Il contient, de gauche à droite :

```text
FB_TranslationArbiter → FB_Safety_Translation → FB_Translation
                                         ↘            ↓
                                  FB_TranslationRuntimeGate
                                                   ↓
                              FB_TranslationRequestPublisher
```

- `FB_TranslationArbiter` extrait sans changement les `IF`/`CASE` historiques : Semi-auto,
  MAINT_N1/N2, homme-mort, joystick/boutons, cible Maintenance, inversion, borne de vitesse et
  capteurs de cible.
- `FB_Safety_Translation` conserve ses entrées historiques et rend visibles `SafeStop`,
  `PowerCutOff`, bits Méca A/B, 6 et 7.
- `FB_TranslationRuntimeGate` et `FB_TranslationFeedbackMemory` rendent explicite la lecture N-1
  historique de `instTranslationM3.BrakeReleaseRequest` utilisée seulement sous bypass de retour
  contacteur. Cette mémoire ne remplace ni le retour physique `BrakeFeedback`, ni le `BrakeCmd`.
- `FB_TranslationRequestPublisher` crée l'unique `ST_TranslationFinalInterlockRequest` de la page
  cible. Le CFC ne contient aucun `IF`, `CASE`, `SEL`, `LIMIT` ni calcul inline.

### Dette BrakeCmd — A-07 maintenue sans changement

`FB_Safety_Translation.BrakeCmd` reste câblé exactement vers
`GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd`. Il s'agit de la commande calculée de la
barrière Outputs N-1, pas d'une preuve mécanique. Aucune substitution par `BrakeFeedback` n'a été
faite et aucune décision safety n'a été inventée.

### Limite du staging

La page n'est pas dans MainTask et ne publie pas encore son `Request` ni `PowerCutOff` vers Outputs :
les POU legacy restent les seuls producteurs actifs. Son activation exige le remappage atomique des
consommateurs et la résolution humaine de la dette A-07. Elle ne doit pas être importée comme
remplacement du POU actif avant ce basculement.

---

## A-14 — M5 Outputs : barrière finale staging non active

**Statut : 🟡 TRANCHÉ PROVISOIRE — staging M5**

`PRG_06_Outputs_Staging_LD` matérialise le contrat de basculement de la barrière finale sans
écraser `PRG_10_Outputs_LD`, qui reste le seul POU Outputs exécuté par la MainTask historique.

Les quatre entrées publiques de staging sont :
`PowerCutOffWinchM1Request`, `PowerCutOffWinchM2Request`,
`PowerCutOffTranslationM3Request` et `PowerCutOffEmergencyRequest`.
Elles sont agrégées exclusivement par OU dans `PowerCutOffReq` avant l'appel inchangé de
`FB_Safety_EmergencyManagement`.

La chaîne AU physique ne passe pas par cette agrégation : elle demeure câblée séparément via
`EmergencyChainClosed`, conformément à AF01. `PowerCutOffEmergencyRequest` désigne une demande
logicielle publique de coupure AU, pas l'état brut de la boucle matérielle.

Les demandes n'ont aucun producteur actif au stade staging et le POU n'est pas dans la MainTask :
il ne modifie donc aucune sortie ni aucune sémantique machine. Le basculement nécessitera que les
POU procédés publient ces contrats dans le même lot que le remplacement de `PRG_10_Outputs_LD`.

**Dette A-07 conservée :** le POU legacy continue seul à lire
`GVL_Global.instTranslationOutputInterlock_LD.BrakeCmd`. M5 staging ne remplace, ni ne modifie,
cette lecture ou la copie d'instance GVL.

---

## A-14 — Pont temporaire acquisition globale vers CFC natif

**Statut : 🟡 TRANCHÉ PROVISOIRE — conservation exacte avant refonte d'interface**

`PRG_02_Acquisition_CFC.xml` appelle exclusivement `FB_AcquisitionLegacyBridge`. Le bridge est
l'extraction textuelle du corps historique `PRG_ACQUISITION_CFC` : il conserve les lectures
physiques/PDO globales, l'appel `FB_SimBench`, les quatre sélecteurs réel/simulation, le joystick,
les codeurs et le décodeur M3 sans modifier leurs seuils, polarités ou cadence.

Le bridge publie `ST_AcquisitionQualified`, qui recopie strictement les onze sorties historiques
(`HwReal`, `HwSim`, `HwIn`, impulsion source Winch, positions M3 et mesures M3 filtrées). Cela
évite d'inventer une interface complète des PDO alors que les champs bruts ne sont pas encore
contractualisés individuellement.

**Dette explicitement conservée :** le bridge lit encore les globals terrain et POU historiques.
Il est temporaire; la refonte ultérieure devra remplacer ces accès par les ports explicites des
FB de la page CFC, après essais CODESYS. Aucune sécurité n'est rendue moins restrictive par ce pont.

---

## A-14 — Premier livrable CFC testable : Acquisition historique en XML natif

**Statut : 🟢 TRANCHÉ AUTONOME — conservation temporaire**

Objectif prioritaire : fournir une page CFC directement importable sans attendre le cutover 7 POU.

`PRG_ACQUISITION_CFC.st` est remplacé par `PRG_ACQUISITION_CFC.xml`. Son unique instance
`FB_AcquisitionLegacyBridge` contient **à l'identique** le corps ST historique : lectures globales
physiques/PDO, banc simulation, aiguillage `HwReal/HwSim/HwIn`, joystick, codeurs, homing,
décodage M3 et filtrage. Le CFC ne contient que l'instance et les fils de publication.

Les quatre sorties du décodeur M3 anciennement lues via
`PRG_ACQUISITION_CFC.instPosDecoderM3.*` deviennent des sorties publiques explicites :
`M3_LimitSwitchFwd`, `M3_LimitSwitchRev`, `M3_SensorWordIncoherent`, `M3_SensorsWord`.
Les consommateurs Safety, Translation, Supervision et Troubleshooting lisent désormais ces sorties.

### Exception temporaire

`FB_AcquisitionLegacyBridge` conserve des accès globaux et des dépendances vers les POU legacy.
C'est une conservation de comportement, non la cible AF02 Inputs → Acquisition. Elle est limitée au
premier import CFC testable et devra être remplacée par des contrats explicites lors du cutover 7 POU.

---

## A-16 — DUT orphelins / fantômes / doublons de l'audit acquisition *(lot M1)*

**Statut : 🟡 TRANCHÉ PROVISOIRE — réaffectation documentaire, code inchangé**

### Faits (audit DUT acquisition, 2026-08-03)

| DUT | Verdict | Constat |
|---|---|---|
| `ST_Diag_Device`, `E_Diag_State` | orphelins | FB diag non instanciés depuis la suppression de `PRG_01_Diagnostics` ; redeviennent vivants quand `instDiagCanOpen/Ethercat/IhmHeartbeat` rejoignent `PRG_02_Acquisition_CFC` (cible) |
| `ST_JoystickState`, `ST_EncoderHMI`, `ST_NetworkDiagHMI` | IHM-only, producteur cassé | producteur legacy supprimé ; à réaffecter en lot M6 (supervision/IHM) |
| `ST_HwIn_Machine` | fantôme | n'existe pas ; le champ réel est `ST_HwMachine` (sous-image de `ST_HardwareImage`) — **corrigé** dans la fiche `FB_Safety_EmergencyManagement` §8.2 (commit `6eeb6cb`) |
| `ST_DeviceDiagnostics` | doublon potentiel | à rapprocher de `ST_Diag_Device` en lot M6 |
| `ST_EncoderMeasurements` | à créer | contrat rédigé — AF06 §2ter |

### Options

| Option | Effet |
|---|---|
| A — Supprimer les DUT orphelins maintenant | 🔴 Non : casse la cible (diag redeviendront vivants en `PRG_02`) et l'IHM |
| B — Réaffectation documentaire seule (cible) | Conserve le code, aligne la doc sur les propriétaires cibles ; nettoyage réel au moment du cutover |
| C — Ignorer | Risque de re-créer des doublons au cutover |

### Décision retenue : **B**

Le code ne change pas (DOC-only). La doc cible (AF06/AF12) pointe déjà les bons propriétaires.
Le nettoyage physique (`ST_DeviceDiagnostics` vs `ST_Diag_Device`, réaffectation des DUT IHM-only)
se fera pendant les lots M1/M6, avec ce registre pour référence.

### Risque résiduel

Doublons temporaires si un lot ré-écrit un DUT sans consulter cet audit. À vérifier en revue M1/M6.

---

## Journal des lots

| Lot | Statut | Arbitrages engagés |
|---|---|---|
| M0-bis alignement doc | ✅ terminé, commit `f32dcd6` | — |
| M0 audit de gel | ✅ terminé — `AUDIT_M0_GEL_ETAT_INITIAL.md` | A-09, A-10, A-11, A-12 |
| M1 acquisition unifiée | à lancer | A-02, A-03, A-09, A-10, A-12, A-16 (A-01 tranché : homing dans Treuils M3) |
| M2 modes + cycle | ✅ staging XML créé, hors MainTask | A-14 |
| M3 treuils + safety | à lancer | A-01 |
| M4 translation + safety | à lancer | — |
| M5 outputs | à lancer | A-04, A-07 |
| M6 supervision | à lancer | A-08 |
| M7 renumérotation | à lancer | — |
| M8 CFC natif | à lancer | — |
