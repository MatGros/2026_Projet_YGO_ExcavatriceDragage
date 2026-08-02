# Pi Coding — Signal Sonore à Chaque Réponse

## ✅ Solution opérationnelle

Depuis le terminal VS Code intégré, Pi Coding émet un **son de notification Windows** chaque fois qu'une réponse est complète.

### 📍 Installation

L'extension est placée à :
```
C:\Users\ZEDVICTUS\.pi\agent\extensions\sound-notifier.ts
```

### 🔧 Fonctionnement

- **Event** : `agent_settled` (déclenchement quand l'agent a complètement terminé)
- **Son** : `notify.wav` (notification système Windows standard)
- **Librairie** : Native PowerShell `System.Media.SoundPlayer` (joué en asynchrone avec `.Play()` et `child.unref()` pour ne pas bloquer la boucle d'événements Node/Pi Coding)

### 🎯 Utilisation

Aucune configuration supplémentaire nécessaire. À chaque réponse complète, tu entends le son.

### 🔄 Hot-reload

Si tu modifies l'extension :
```
/reload
```

### 📝 Personnalisation possible

| Élément | Fichier | Action |
|---------|---------|--------|
| Son alternatif | `sound-notifier.ts` | Modifier le chemin `.wav` |
| Comportement | `sound-notifier.ts` | Modifier l'event écouté (ex: `turn_end`) |

**Exemples de chemins alternatifs :**
- `$env:windir\Media\tada.wav` (succès)
- `$env:windir\Media\chord.wav` (autre)
- `$env:windir\Media\ding.wav` (notification)

---

**Créé** : 2025 (REX Pi Coding + VS Code Terminal)  
**Testé** : ✅ Windows PowerShell + VS Code Terminal  
**Status** : Opérationnel
