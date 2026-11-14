# Historique de commandes par terminal VS Code

> 🎯 Objectif : dans chaque terminal intégré VS Code, **↑ retrouve les commandes de CE terminal**,
> et elles **survivent au redémarrage** de la fenêtre.
>
> Portée : **poste de travail** (profil PowerShell utilisateur), donc **tous les projets** ouverts
> dans VS Code, pas seulement celui-ci.

---

## 1. Le problème d'origine

Par défaut, PowerShell (`PSReadLine`) écrit l'historique dans **un seul fichier partagé** :

```text
%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

Conséquence : ↑ dans l'onglet Claude Code remonte une commande tapée dans l'onglet Codex.
Gênant dès qu'on a une dizaine de terminaux ouverts.

Un premier correctif avait donné à chaque terminal son **propre** fichier, nommé par le PID du
shell (`term_<PID>.txt`). Il corrigeait le mélange… mais cassait la persistance : **le PID change à
chaque démarrage**, donc chaque nouveau shell repartait sur un fichier vide. Historique perdu.

---

## 2. Principe de la solution

La clé d'identification doit être **stable** et **connue avant le démarrage du shell**.

```text
.vscode/sessions.json
   │  "env": { "TK_HIST": "claude-code" }
   ▼
VS Code createTerminal({ env })      ← la variable existe AVANT le shell
   ▼
profile.ps1  (exécuté au démarrage du shell)
   │  $__key = $env:TK_HIST
   ▼
Set-PSReadLineOption -HistorySavePath "...\terminal-sessions\claude-code.txt"
   ▼
↑ lit et écrit ce fichier, à chaque session, indéfiniment
```

Trois pièces, une seule responsabilité chacune :

1. **`.vscode/sessions.json`** — nomme le terminal (`env.TK_HIST`).
2. **`profile.ps1`** — traduit ce nom en chemin de fichier d'historique.
3. **PSReadLine** — fait le reste (lecture ↑, écriture incrémentale).

---

## 3. Pièce 1 — `.vscode/sessions.json`

Chaque entrée active porte une clé **unique et lisible** :

```json
{
    "name": "🧠 Claude Code",
    "env": { "TK_HIST": "claude-code" },
    "autoExecuteCommands": true,
    "commands": ["claude"]
}
```

Pourquoi ça marche : Terminal Keeper construit les options du terminal en recopiant les clés
inconnues de l'entrée (`dist/extension.js`, `buildTerminal`, spread `...x`) et les passe telles
quelles à `vscode.window.createTerminal`. `env` est une option officielle de cette API VS Code.
La variable est donc posée **par VS Code**, au moment de créer le terminal — pas par une commande
tapée ensuite.

### ➕ Ajouter un terminal

1. Ajouter l'entrée dans `sessions.json` avec un `env.TK_HIST` **neuf** (pas de doublon).
2. Rien à faire côté profil : le fichier d'historique se crée tout seul au premier démarrage.
3. Clés en minuscules, sans espace : `[A-Za-z0-9._-]` (les autres caractères sont remplacés par `-`).

### ⚠️ Ne pas faire

- ❌ Poser `$env:TK_HIST='x'; <commande>` **dans** `commands`. Le profil s'exécute **avant** la
  commande : la variable est encore vide, tous les terminaux retombent sur `default`.
- ❌ Nommer le fichier d'historique par `$PID` : instable entre deux lancements.

---

## 4. Pièce 2 — `profile.ps1`

Fichier : `C:\Users\<user>\Documents\PowerShell\profile.ps1` (profil *AllHosts* de PowerShell 7).

```powershell
if ((Get-Module -ListAvailable -Name PSReadLine) -and ($env:TK_HIST -or $env:TERM_PROGRAM -eq 'vscode')) {
    $__histDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\PowerShell\PSReadLine\terminal-sessions'
    if (-not (Test-Path -LiteralPath $__histDir)) {
        New-Item -ItemType Directory -Path $__histDir -Force | Out-Null
    }
    $__key = if ($env:TK_HIST) { $env:TK_HIST } else { 'default' }
    $__key = ($__key -replace '[^A-Za-z0-9._-]', '-')
    Set-PSReadLineOption -HistorySavePath (Join-Path $__histDir "$__key.txt")
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
    Set-PSReadLineOption -MaximumHistoryCount 4096
}
```

Lecture des trois lignes clés :

- `HistorySavePath` → un fichier **par clé**, donc par terminal.
- `HistorySaveStyle SaveIncrementally` → écrit **après chaque commande** : rien n'est perdu si la
  fenêtre est tuée brutalement.
- `MaximumHistoryCount 4096` → taille du tampon ↑.

`default.txt` sert aux terminaux **hors** Terminal Keeper (Ctrl+Shift+`). Ils partagent ce fichier
entre eux, mais n'interfèrent pas avec les autres.

---

## 5. Pièce 3 — persistance VS Code (`.vscode/settings.json`)

```json
"terminal.integrated.enablePersistentSessions": true,
"terminal.integrated.persistentSessionReviveProcess": "onExitAndWindowClose",
"terminal.integrated.persistentSessionScrollback": 5000
```

- `enablePersistentSessions` : VS Code garde les terminaux d'une fenêtre à l'autre (défaut `true`).
- `persistentSessionReviveProcess` : restaure aussi à la **fermeture d'une fenêtre**, pas seulement
  à la sortie complète de l'application (défaut `onExit`).
- `persistentSessionScrollback` : nombre de lignes de **scrollback** restaurées (défaut `100`,
  volontairement relevé).

🔎 À ne pas confondre : ceci restaure **le buffer affiché**. L'historique ↑ est géré par
`profile.ps1`, indépendamment.

---

## 6. Réglages Terminal Keeper associés

```json
"activateOnStartup": false,
"keepExistingTerminals": true,
"noClear": true
```

- `activateOnStartup: false` → l'extension ne relance rien au démarrage : VS Code restaure les
  terminaux tels quels, **noms et titres conservés**.
- `keepExistingTerminals: true` → une activation manuelle ne tue pas les terminaux existants.
- `noClear: true` → **attention à la casse**, c'est `noClear` et pas `noclear`. La propriété
  inconnue est ignorée silencieusement et `cls` est envoyé quand même.

⚠️ Terminal Keeper **crée toujours un terminal neuf** (`createTerminal` n'a aucune logique de
réutilisation par nom) : activer une session avec `keepExistingTerminals: true` ouvre des doublons.
C'est le prix de la conservation de l'existant.

---

## 7. Vérifier que ça marche

Dans le terminal concerné :

```powershell
$env:TK_HIST
(Get-PSReadLineOption).HistorySavePath
```

Attendu, par exemple pour l'onglet Claude Code :

```text
claude-code
C:\Users\<user>\AppData\Local\Microsoft\Windows\PowerShell\PSReadLine\terminal-sessions\claude-code.txt
```

Si `$env:TK_HIST` est **vide** : le terminal a été créé avant la modification → le fermer et le
relancer. Si le chemin se termine par `default.txt` alors que la variable est renseignée : le
profil n'est pas chargé (vérifier `$PROFILE.CurrentUserAllHosts`).

Test complet : taper une commande dans deux onglets, redémarrer VS Code **proprement**, rouvrir → ↑
doit rendre une commande différente à chacun.

---

## 8. Fichiers touchés

| Fichier | Emplacement | Rôle |
|---|---|---|
| `sessions.json` | `<repo>\.vscode\` | clé `env.TK_HIST` par terminal |
| `settings.json` | `<repo>\.vscode\` | persistance et scrollback VS Code |
| `profile.ps1` | `%USERPROFILE%\Documents\PowerShell\` | choix du fichier d'historique |

📌 `profile.ps1` est **hors dépôt** et **global au poste** : il s'applique à tous les projets
ouverts dans VS Code, et n'est pas versionné. Toute modification doit être reportée à la main sur
un autre poste.

---

## 9. REX

- 🔴 **PID n'est pas une identité** : il change à chaque lancement. Pour identifier un terminal de
  façon durable, il faut un nom fourni à la création.
- 🔴 **Ordre d'exécution** : un profil de shell s'exécute *avant* les commandes envoyées dans ce
  shell. Une variable posée par une commande ne peut pas influencer le démarrage.
- 🟡 **Les propriétés inconnues d'un JSON de config sont ignorées sans erreur.** `noclear` au lieu
  de `noClear` n'a produit aucun message : seul le symptôme l'a révélé.
