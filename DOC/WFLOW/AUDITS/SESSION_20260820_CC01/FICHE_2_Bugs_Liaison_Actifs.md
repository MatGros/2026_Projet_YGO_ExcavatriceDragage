# 🐛 Fiche 2 — Défauts de liaison actifs

> 📅 2026-08-20 · 🤖 `CC-01` · 🔍 Read-only — **aucune correction appliquée**
> 🎯 **But** : deux défauts présents dans le code qui rendent le diagnostic machine aveugle.
> ⚠️ Les deux passent **tous les gates au vert**. C'est le motif exact du REX `PRG_10_Outputs_LD`.

---

## 🔴 Défaut 1 — `M3_SensorsWord` : consommé, jamais alimenté

### Ce qui se passe

Le mot d'état des 5 capteurs de translation M3 est **lu** par le programme Translation, mais
**personne ne l'écrit**. Il vaut donc `0` en permanence.

| Étape | Emplacement | État |
|---|---|:---:|
| Le décodeur **calcule** le mot | `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st:71-76` | ✅ |
| Le décodeur est **instancié** | `CODE/M_MAIN/PRG_02_Acquisition.st:466` | ✅ |
| L'acquisition **publie** le mot sur le bus | `CODE/M_MAIN/PRG_02_Acquisition.st:487` | ❌ **manquant** |
| La translation **consomme** le mot | `CODE/M_MAIN/PRG_05_Translation.st:400` | ✅ |

Le commentaire à la ligne 487 acte lui-même le trou :
> *« déclaré dans `ST_AcquisitionInterPrg`, jamais assigné ici (écart préexistant, hors périmètre
> de ce lot) »*

Les 15 champs voisins (`TranslationPosTremie`, `M3_LimitSwitchFwd`, `M3_SensorWordIncoherent`…)
sont tous publiés normalement aux lignes 474-486. **Une seule ligne manque.**

### Pourquoi c'est grave

Le mot capteurs est la **vue synthétique de la position M3** (bit4 = Trémie, bit3 = PV, bit2 = P2,
bit1 = P1, bit0 = Maintenance). Il remonte à l'IHM et au troubleshooting via
`ST_TranslationState.SensorsWord`. À `0` constant, l'opérateur et le dépanneur lisent une position
**fausse et muette**.

> 🔒 Les sécurités M3 ne dépendent **pas** de ce champ : elles consomment les booléens individuels,
> qui sont correctement câblés. Le défaut est de **diagnostic**, pas de sécurité directe.
> Il devient critique dès qu'on cherche *pourquoi* la machine s'est arrêtée.

### Correction proposée

Publier la valeur déjà calculée par le décodeur, à la suite des 15 champs voisins — **une ligne**,
strictement alignée sur le motif existant. Périmètre : `PRG_02_Acquisition`. Criticité : C3.

---

## 🔴 Défaut 2 — Troubleshooting Translation : les 2 champs décisifs absents (T129)

### Ce qui se passe

La structure de diagnostic Translation expose 8 indicateurs (`Idx301` à `Idx308`) — tous booléens,
tous des *symptômes*. Il manque les deux données qui donnent la **cause** :

| Donnée manquante | Où elle vit dans le code | Ce qu'elle apporterait |
|---|---|---|
| `ErrorId` de la sécurité M3 | `CODE/M_MAIN/PRG_05_Translation.st:424` | **Quel** défaut s'est déclenché, parmi la dizaine possible |
| Sens de marche actif M3 | `CODE/M_MAIN/PRG_05_Translation.st:28` | Dans **quelle direction** la machine allait au moment du blocage |

Vérification : `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_Chain_Translation_Safety.st:3-10`
ne contient ni l'un ni l'autre. Les deux valeurs **existent déjà** dans le programme — elles ne
sont simplement pas recopiées vers le bus de dépannage.

### Pourquoi c'est grave

C'est ce qui rend l'**éjection en mode semi-automatique indiagnosticable** : les instantanés
montrent qu'un défaut est actif, sans dire lequel ni dans quel sens la machine se déplaçait.
Le dépanneur voit `Idx302_SafeStopActive = 1` et n'a aucun moyen de remonter à la cause.

### Correction proposée

Étendre la structure de diagnostic Translation avec les deux champs et les alimenter depuis les
valeurs existantes. Périmètre : structures `J_SUPERVISION` + `FB_TroubleshootingView`. Criticité : C2
(lecture seule, aucun effet sur la commande).

---

## 🛡️ Garde-fou proposé (règle `fix:` + `guard:`)

> `AGENTS.md` : *« tout bug détecté donne deux livrables — la correction **et** un garde-fou
> automatique. Une réponse purement documentaire à un incident est insuffisante. »*

**Constat de fond** : les bus DUT inter-programmes (`ST_*InterPrg`) créent une classe d'erreur que
les contrôles actuels ne voient pas. Un champ peut être *déclaré*, *consommé*, et **jamais
alimenté** : la compilation passe (le champ existe), la vérification de liaison passe (elle
contrôle les instances de blocs, pas les champs de structure).

**Garde-fou** : un contrôle qui, pour chaque champ d'un bus inter-programmes, vérifie qu'il existe
**au moins un producteur** (une écriture) dès lors qu'il existe un consommateur. Un champ consommé
sans producteur = échec bloquant.

Bénéfice : ce contrôle aurait attrapé `M3_SensorsWord` **au moment de sa création**, sans dépendre
d'une relecture humaine.

---

## ❓ Décision attendue

| # | Question | Enjeu |
|---|---|---|
| Q1 | Les 4 types `ST_*InterPrg` sont présents sur le disque mais **non suivis par git**. Qui les a créés — toi, ou un agent ? Faut-il les verser au dépôt ? | 🚨 `AGENTS.md` : *« si un fichier que tu n'as pas modifié apparaît dans le diff → STOP et demande à l'humain »*. **Je n'y touche pas sans réponse.** |
| Q6 | Corrige-t-on les défauts 1 et 2 **avant** les essais ? | Sans eux, les essais terrain sont aveugles : on observera des blocages sans pouvoir les expliquer |
