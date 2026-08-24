# Accès LM Studio Distant (`PC-Z-AREA51`)

Ce dossier documente et fournit un exemple d'intégration Python pour interroger le serveur local **LM Studio** hébergé sur la machine distante **`PC-Z-AREA51`**.

---

## 🌐 Configuration Réseau & Serveur

- **Machine distante** : `PC-Z-AREA51` (`pczarea51`)
- **Base URL** : `http://100.112.201.46:1234/v1`
- **Protocole API** : Compatible OpenAI (`openai-completions` / `/v1/chat/completions`)
- **Authentification** : Clé API configurée côté client (si requise par l'instance)

---

## ⚙️ Configuration DeepSeek Harness (DSH)

Configuration type du provider custom dans l'interface / settings de DeepSeek Harness :

| Paramètre | Valeur |
|---|---|
| **Display name** | `PC-Z-AREA51` |
| **Base URL** | `http://100.112.201.46:1234/v1` |
| **API Protocol** | `openai-completions` |
| **API Key** | *(Configured)* |

### Catalogue de Modèles

| Modèle (ID LM Studio) | Nom d'affichage (Display Name) |
|---|---|
| `openai/gpt-oss-20b` | `PC-Z-AREA51/openai/gpt-oss-20b` |
| `text-embedding-nomic-embed-text` | `PC-Z-AREA51/text-embedding-nomic-embed-text` |
| `qwen3.8-27b` | `PC-Z-AREA51/qwen3.8-27b` |
| `qwen3.8-27b@q4_0` | `PC-Z-AREA51/qwen3.8-27b@q4_0` |
| `qwen3.8-27b@iq2_s` | `PC-Z-AREA51/qwen3.8-27b@iq2_s` |
| `qwen3.8-27b@q2_k_xl` | `PC-Z-AREA51/qwen3.8-27b@q2_k_xl` |

---

## 🐍 Utilisation en Python (`stream_lmstudio.py`)

Le script [`stream_lmstudio.py`](stream_lmstudio.py) fournit un exemple complet d'appel en streaming avec gestion du TTFT (*Time To First Token*) et calcul de la vitesse de génération en tokens/s.

### Lancement

```powershell
python TOOLS/LM_STUDIO/stream_lmstudio.py
```

### Extrait du payload

```python
URL = "http://100.112.201.46:1234/v1/chat/completions"

payload = {
    "model": "qwen3.8-27b@q2_k_xl",
    "messages": [
        {"role": "user", "content": "Explique le fonctionnement de Modbus TCP en cinq points."}
    ],
    "temperature": 0.2,
    "max_tokens": 300,
    "stream": True,
    "stream_options": {
        "include_usage": True
    }
}
```

---

## 📖 Notice LM Studio

### 1. Présentation
LM Studio permet de télécharger et d’exécuter des modèles d’intelligence artificielle directement sur un ordinateur. Il peut être utilisé comme application de discussion ou comme serveur API pour connecter un script, un logiciel ou une application externe.

### 2. Installation
1. Télécharger LM Studio depuis son site officiel.
2. Installer le programme.
3. Ouvrir LM Studio.
4. Rechercher un modèle, par exemple Qwen, Llama, Gemma ou DeepSeek.
5. Télécharger le modèle adapté à la mémoire disponible sur l’ordinateur.
> *Note : Un modèle quantifié (ex. Q4, Q2) consomme moins de mémoire mais peut offrir une qualité légèrement inférieure.*

### 3. Choisir un modèle
Le choix dépend principalement de :
- La mémoire RAM ou VRAM disponible ;
- La taille du modèle ;
- La vitesse souhaitée ;
- La qualité attendue ;
- La langue utilisée.

Pour une machine limitée, choisir un modèle quantifié plus petit. Pour une meilleure qualité, utiliser un modèle plus grand avec une quantification supérieure.

### 4. Charger le modèle
Dans LM Studio :
1. Ouvrir la section **Chat**.
2. Sélectionner le modèle téléchargé.
3. Charger le modèle en mémoire.
4. Attendre la fin du chargement.
5. Tester une question directement dans l’interface.

*Si le modèle ne se charge pas, réduire la taille du modèle ou la longueur du contexte.*

### 5. Démarrer le serveur API
Pour utiliser LM Studio avec un script :
1. Ouvrir l’onglet **Developer**.
2. Sélectionner le modèle.
3. Activer **Start Server**.
4. Vérifier l’adresse et le port utilisés (port par défaut : `1234`).

- En local : `http://localhost:1234`
- Depuis un autre ordinateur du réseau : `http://192.168.1.50:1234` (ou IP Tailscale/VPN comme `http://100.112.201.46:1234`)

LM Studio fournit des endpoints compatibles avec l’API OpenAI, notamment `/v1/models` et `/v1/chat/completions`.

### 6. Vérifier le serveur
Dans PowerShell, tester la liste des modèles :
```powershell
# En local
Invoke-RestMethod http://localhost:1234/v1/models

# Depuis une autre machine
Invoke-RestMethod http://ADRESSE_IP_DU_PC:1234/v1/models
```
Si une liste de modèles apparaît, le serveur répond correctement.

**En cas d’échec :**
- Vérifier que le serveur est démarré (`Start Server`) ;
- Vérifier l’adresse IP et le port 1234 ;
- Vérifier le pare-feu Windows ;
- Vérifier que le modèle est bien chargé en mémoire.

### 7. Utilisation avec un script
Un script compatible OpenAI doit généralement utiliser :
- Base URL : `http://ADRESSE_IP:1234/v1`
- Endpoint Chat : `/v1/chat/completions`

**Flux de communication :**
`Script` ➔ Envoie la question ➔ `LM Studio` ➔ Transmet au modèle ➔ `Modèle` génère ➔ `LM Studio` renvoie au script ➔ `Script` affiche le résultat.

Avec `stream: true`, la réponse arrive progressivement (SSE) au lieu d’attendre la fin complète de la génération.

### 8. Affichage des accents & Encodage UTF-8
Si des caractères corrompus apparaissent (`Ã©`, `Ã¨`, `Ã®`, `â€™`), il s'agit d'un problème d'encodage console / Python.

Avant de lancer le script sous PowerShell :
```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$env:PYTHONIOENCODING = "utf-8"
```
Puis exécuter Python :
```powershell
python -X utf8 mon_script.py
```
*(Vérifier aussi que le fichier `.py` est bien enregistré au format UTF-8).*

### 9. Vitesse de génération
La vitesse s’exprime en **tokens/s** (nombre de tokens générés chaque seconde).

Notions clés :
- **TTFT** (*Time To First Token*) : temps avant l’apparition du premier token.
- **Temps de génération** : durée de production de la réponse (après premier token).
- **Vitesse (tokens/s)** :
  $$\text{tokens/s} = \frac{\text{nombre de tokens générés}}{\text{temps de génération}}$$

### 10. Statistiques de tokens
En streaming, demander les métriques via :
```json
"stream_options": {
  "include_usage": true
}
```
- `prompt_tokens` : tokens envoyés en entrée.
- `completion_tokens` : tokens générés en sortie.
- `total_tokens` : total cumulé.

### 11. Accès depuis un autre PC
1. Démarrer le serveur LM Studio.
2. Autoriser les connexions réseau dans LM Studio.
3. Identifier l’adresse IP du serveur (`ipconfig`).
4. Autoriser le port `1234` dans le pare-feu.
5. Exemple d'URL : `http://100.112.201.46:1234/v1/chat/completions`

> ⚠️ *Éviter d’exposer directement ce port sur Internet sans protection. Préférer un VPN (Tailscale, Wireguard), un réseau privé ou un tunnel sécurisé.*

### 12. Dépannage rapide

| Problème | Vérification |
|---|---|
| **Le serveur ne répond pas** | Vérifier que `Start Server` est activé |
| **Erreur de connexion** | Vérifier l’IP, le port et le pare-feu |
| **Modèle introuvable** | Vérifier le nom exact retourné par `/v1/models` |
| **Réponse très lente** | Réduire le modèle ou la taille du contexte |
| **Caractères comme `Ã©`** | Forcer UTF-8 dans PowerShell et Python (`chcp 65001`, `python -X utf8`) |
| **Pas de tokens/s** | Vérifier `stream_options.include_usage` ou calculer le débit localement |
| **Réponse interrompue** | Augmenter le timeout HTTP du script |
| **Mémoire insuffisante** | Utiliser un modèle plus petit ou plus fortement quantifié (Q4, Q2) |

### 13. Configuration recommandée

```text
Modèle       : Adapté à la RAM/VRAM disponible
Serveur      : Activé dans Developer
Port         : 1234
Endpoint     : /v1/chat/completions (ou /api/v1 pour la nouvelle API native)
Encodage     : UTF-8
Streaming    : Activé (stream: true)
Statistiques : stream_options.include_usage: true
```
