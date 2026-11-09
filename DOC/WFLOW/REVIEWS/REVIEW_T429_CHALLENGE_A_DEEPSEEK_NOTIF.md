# Rapport de revue indépendante — T429 / AC-F3.5 et AC-F3.9

## 1. Résumé exécutif

- **AC-F3.5 : FAIL.** Le clic sur la notification bureau ne propage ni la session ni l’alerte : `note.onclick` ne fait que `window.focus()` puis `note.close()`. La sélection de la bonne session/carte n’est faite qu’au chargement initial via `?session=&alert=`, donc elle n’est pas déclenchée si la page est déjà ouverte en arrière-plan.
- **AC-F3.9 : FAIL sur l’état démontré** si ce critère couvre le clic carte et/ou le son, ce que suggère le titre de la mission. Le verdict formel reste conditionné au libellé exact de AC-F3.9, non fourni dans les preuves.
- **Correctif chirurgical requis avant validation :** propagation des identifiants `session/alert` dans `note.onclick`, déclenchement de la sélection cible, politique d’audio débloquée par geste utilisateur, et déduplication explicite « une seule notification ».

---

## 2. Limites de preuve

Revue faite en **lecture seule**, sans exécution ni modification. Les conclusions reposent sur les extraits fournis :

- `TOOLS/AGENT_SUPERVISOR/ui/index.html` l. 472-478, 171, 599, 610 ;
- `TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/extension.js` l. 136-139 ;
- libellé AC-F3.5 fourni ;
- **libellé exact AC-F3.9 non fourni** ;
- bloc audio réel non fourni ;
- mécanisme producteur/déduplication des événements non fourni ;
- implémentation exacte de `openTarget` non fournie au-delà de l’appel.

Je ne peux donc pas certifier PASS sur une vérification non exécutée. Les points non prouvés ci-dessous sont marqués **non vérifiés**, pas PASS par défaut.

---

## 3. Verdicts et justification ligne par ligne

| Réf. | Constat technique | Impact |
|---|---|---|
| `ui/index.html` l. 472-478 | La notification bureau est créée sur nouveau Warning/Alarm. Le handler est `note.onclick = () => { window.focus(); note.close(); };`. | **Défaut bloquant AC-F3.5.** Le clic ne transporte aucune cible. Il ne met pas à jour l’URL, ne lit pas `requestedSupervisorSession`/`requestedSupervisorAlert`, et n’appelle aucun sélecteur de session/carte. |
| `ui/index.html` l. 171 | `requestedSupervisorSession` / `requestedSupervisorAlert` sont issus des paramètres d’URL, donc lus au chargement. | L’état est figé au chargement. Un clic sur notification ne réexécute pas cette lecture. |
| `ui/index.html` l. 599, 610 | La sélection de la bonne session/carte est appliquée lors du traitement initial des paramètres `?session=&alert=`. | C’est le seul chemin prouvé vers « bonne session + bonne carte ». Or `note.onclick` ne l’emprunte pas. |
| `extension.js` l. 136-139 | Le clic sur toast VS Code appelle `openTarget(target.session.id, target.alert.id)` et ouvre `http://127.0.0.1:8082/?session=...&alert=...`. | La cible est correctement propagée côté toast. Mais le résultat dépend du navigateur : nouvel onglet/rechargement = probablement correct ; réutilisation d’un onglet existant sans navigation = sélection non prouvée. |
| Audio, code non fourni | Aucun mécanisme visible de déblocage d’`AudioContext`. Un contexte créé ou repris hors geste utilisateur reste `suspended`. | Le son applicatif n’est pas garanti au premier Warning/Alarm après chargement. Si le son dépend uniquement de l’OS via `Notification`, le comportement dépend des réglages navigateur/OS et n’est pas déterministe. |
| Unicité, code non fourni | Aucune clé de déduplication visible dans les extraits. | « Une seule notification bureau, un son et un toast » n’est pas prouvé. Un retry, un reconnect ou un rechargement peut produire des doublons. |

### 3.1 AC-F3.5 — clic notification bureau

Le scénario critique est le suivant :

1. L’IHM est ouverte sur la session A, carte A1.
2. Un nouveau Warning/Alarm arrive sur la session B, carte B1.
3. Une notification bureau s’affiche.
4. L’utilisateur clique sur la notification.

Avec le handler actuel :

- `window.focus()` peut ramener l’onglet au premier plan, mais il ne change pas la sélection interne ;
- `note.close()` ferme la notification ;
- aucune URL n’est modifiée ;
- le code des l. 599/610 n’est pas rappelé ;
- l’utilisateur reste sur la session A/carte A1, ou sur l’état courant, pas nécessairement B/B1.

Donc **le clic n’ouvre pas la bonne session et la bonne carte** au sens de AC-F3.5. Le fait que `window.focus()` fonctionne ou non est secondaire : même s’il fonctionne, il ne sélectionne pas la cible.

Cas faux positif à éviter : si une seule session existe, ou si la cible est déjà sélectionnée, le clic semble « marcher ». Ce n’est pas une preuve de conformité. Le test doit utiliser au moins deux sessions et une alerte non active.

### 3.2 AC-F3.5 — toast VS Code

Le chemin toast est meilleur : `openTarget(target.session.id, target.alert.id)` construit bien l’URL avec les deux identifiants. Si le navigateur charge cette URL dans un onglet, le traitement initial l. 171/599/610 peut sélectionner la cible.

Risque résiduel : `openTarget` utilise probablement `vscode.env.openExternal`. Selon le navigateur et l’état de l’onglet, l’URL peut :

- ouvrir un nouvel onglet et exécuter le chargement initial : OK probable ;
- réutiliser l’onglet existant sans rechargement : la query string peut ne pas être retraitée, donc pas de sélection ;
- focaliser l’onglet existant sans navigation : pas de sélection.

Ce point doit être testé en intégration. Il ne compense pas le défaut certain du clic sur notification bureau.

### 3.3 AC-F3.5 — son et politique AudioContext

Deux cas doivent être distingués :

1. **Son applicatif via Web Audio / `AudioContext`.**  
   Les navigateurs créent souvent l’`AudioContext` en état `suspended`. `resume()` doit être appelé dans un geste utilisateur fiable. Un Warning/Alarm déclenché par polling ou websocket n’est pas un geste utilisateur. Le son peut donc être bloqué, ou mis en attente indéfiniment.

2. **Son OS via `Notification`.**  
   Si la notification n’est pas `silent: true`, l’OS peut jouer un son. Mais ce n’est pas contrôlé par l’application et dépend des réglages de notification, du mode Ne pas déranger, du navigateur et de l’OS. Ce n’est pas une preuve déterministe.

Conclusion : **AC-F3.5 ne peut pas être PASS sur le volet son** sans préciser si le critère accepte le son OS ou exige un son applicatif. Si le critère exige un son applicatif garanti, il faut un déblocage explicite par geste utilisateur et un fallback visible.

### 3.4 AC-F3.5 — « une seule » notification / son / toast

Les extraits ne montrent pas de clé de déduplication. Il faut vérifier :

- que la détection « nouveau » se fait sur transition d’état, pas sur snapshot complet ;
- qu’un retry ou reconnect ne rejoue pas la même alerte ;
- que le toast VS Code et la notification bureau ne sont pas émis deux fois pour le même événement ;
- que le son n’est pas joué deux fois — une fois par l’OS, une fois par l’application.

Sans cette preuve, le critère « une seule » reste **non vérifié**.

### 3.5 AC-F3.9

Le libellé exact n’est pas fourni. Si AC-F3.9 couvre le clic carte ou l’audio — ce que suggère le titre — le verdict est **FAIL** pour la notification bureau et **non concluant** pour le toast tant que le test navigateur n’est pas fait. Je ne peux pas attribuer PASS sans le texte exact du critère et le code correspondant.

---

## 4. Risques résiduels et faux positifs

- **Faux positif « une seule session »** : si une seule session est ouverte, le clic sur notification peut sembler correct alors que la logique ne sélectionne rien.
- **Faux positif « audio déjà débloqué »** : si l’utilisateur a déjà interagi avec la page, `AudioContext` peut être `running`. Le test doit être fait après un chargement à froid, sans clic préalable.
- **Réutilisation d’onglet par le navigateur** : le toast peut ouvrir l’URL sans recharger l’onglet existant ; la query string n’est alors pas retraitée.
- **Rechargement après clic notification** : si le correctif recharge la page, il peut rejouer la détection et recréer une notification. Il faut une déduplication persistante ou une sélection en mémoire sans reload.
- **Captures de boucle** : si `note.onclick` utilise des variables mutables de boucle (`var`), toutes les notifications peuvent pointer vers la dernière alerte. Les identifiants doivent être capturés par valeur (`const`) dans la portée de la notification.
- **Mode Ne pas déranger / permissions** : une notification peut être silencieuse ou non affichée ; ce n’est pas une preuve de non-conformité du code, mais cela empêche un test PASS fiable.
- **VS Code n’est pas une source audio fiable** : `showWarningMessage` n’est pas un mécanisme audio garanti. Ne pas compter le toast VS Code comme « son » sans preuve.

---

## 5. Patch recommandé

### 5.1 Correctif minimal du clic notification

À appliquer dans le bloc de création de notification, l. 472-478. Les identifiants doivent être ceux de l’alerte courante, capturés dans la portée de la notification. Le diff ci-dessous suppose des variables `session.id` et `alert.id` ; à aligner sur les noms réels du fichier.

```diff
--- a/TOOLS/AGENT_SUPERVISOR/ui/index.html
+++ b/TOOLS/AGENT_SUPERVISOR/ui/index.html
@@
-    note.onclick = () => { window.focus(); note.close(); };
+    note.onclick = () => {
+      note.close();
+      window.focus();
+      const target = new URL(window.location.href);
+      target.searchParams.set('session', session.id);
+      target.searchParams.set('alert', alert.id);
+      window.location.assign(target.toString());
+    };
```

Effet : le clic provoque une navigation vers l’URL contenant `?session=&alert=`, ce qui réutilise le traitement initial l. 171/599/610 et sélectionne la bonne session/carte. C’est le correctif le plus chirurgical si aucune fonction interne de sélection n’est disponible.

Limite : ce patch recharge la page. Si le chargement rejoue la détection d’alerte, ajouter une déduplication persistante, par exemple avec `sessionStorage`, pour éviter une nouvelle notification au reload.

Alternative préférable si le code possède déjà une fonction de sélection : extraire la logique des l. 599/610 dans `applySupervisorTarget(sessionId, alertId)`, puis appeler cette fonction directement depuis `note.onclick`, sans reload.

### 5.2 Déduplication « une seule notification »

Avant création de la notification, ajouter une clé stable :

```js
const targetKey = `${session.id}:${alert.id}:${alert.level ?? ''}:${alert.updatedAt ?? ''}`;
if (alreadyNotified(targetKey)) return;
markNotified(targetKey);
```

La clé doit inclure un identifiant d’alerte et, si disponible, une révision/mise à jour. Sinon une alerte mise à jour peut être considérée comme déjà notifiée, ou l’inverse.

### 5.3 Déblocage audio

À intégrer dans le module audio existant. Le principe est de créer/reprendre l’`AudioContext` sur le premier geste utilisateur, puis de jouer le son en attente une seule fois.

```js
let audioCtx = null;
let pendingSound = false;

function unlockAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume().then(() => {
      if (pendingSound) {
        pendingSound = false;
        playAlertSound();
      }
    });
  } else if (pendingSound) {
    pendingSound = false;
    playAlertSound();
  }
}

window.addEventListener('pointerdown', unlockAudio, { once: true });
window.addEventListener('keydown', unlockAudio, { once: true });

function playAlertSound() {
  if (!audioCtx || audioCtx.state !== 'running') {
    pendingSound = true;
    return;
  }
  // Conserver ici l'implémentation audio existante.
}
```

Prévoir aussi un indicateur discret du type « Son bloqué par le navigateur — cliquez pour activer » si `pendingSound` reste vrai. Et ne pas compter sur `new Notification(...)` seul pour garantir le son.

---

## 6. Décision recommandée

**Ne pas valider T429 en l’état.**

Décision recommandée :

1. **Bloquant AC-F3.5** : corriger `note.onclick` pour propager `session/alert` et sélectionner la cible.
2. **Bloquant ou réserve AC-F3.9** : obtenir le libellé exact, puis vérifier le volet audio/clic carte.
3. **Preuve d’intégration obligatoire** : test à froid avec deux sessions, alerte non active, clic notification, vérification de la session/carte affichée.
4. **Preuve d’unicité** : test retry/reconnect/reload pour compter une seule notification, un seul son, un seul toast.
5. **Preuve audio** : test après chargement sans interaction, puis après premier geste utilisateur.

Tant que ces preuves ne sont pas fournies, le verdict reste **FAIL AC-F3.5** et **FAIL/PARTIEL AC-F3.9 selon le libellé exact**.