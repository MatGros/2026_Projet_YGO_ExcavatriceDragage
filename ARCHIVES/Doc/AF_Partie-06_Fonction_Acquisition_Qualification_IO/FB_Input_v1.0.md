# Fiche FB_Input v1.0

> Brique de qualification d'entrée TOR (inversion NO/NC, filtrage anti-rebond, diagnostic voie/carte).
> Profil AF03 §1bis : brique réduite, pas de contrat FB standard (pas d'Enable/StartStop/Mode/State/StateAtError).
> Source : `CODE/COMMUN/FB_Input.st` · instances : 22 dans `PRG_01_Inputs_LD` (toutes les entrées TOR — liste exhaustive `AF_Partie-06 §4`).

## 🎯 Rôle

Conditionne un signal TOR brut en un fait qualifié :
1. **Inversion NO/NC** — normalise la polarité physique vers la convention logique du nom (`<Domaine>_<ÉtatQuandTRUE>_DI`).
2. **Filtrage anti-rebond** — temporise le changement d'état pour éliminer les rebonds de contact.
3. **Diagnostic voie/carte** — force l'état sûr si la voie ou la carte d'entrée est en défaut.

Aucune décision métier (SafeStop, mode, commande). Brique bas niveau composée directement dans `PRG_01_Inputs_LD`.

## 🧪 Points de validation (`TC-P06-002` — polarité unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P06-002 | Polarité normalisée une seule fois à l'acquisition — zéro ré-inversion dans les FB métier | `💻 AUTO` |
| TC-P06-IN1 | `State` reflète `InputRaw XOR InvertLogic` après filtrage `FilterTime` | `⚡ AUTO_PLC` |
| TC-P06-IN2 | `Error = TRUE` si `ChannelOk = FALSE` — `State` conserve sa dernière valeur (hold), le consommateur décide l'état sûr | `⚡ AUTO_PLC` |
| TC-P06-IN3 | Premier scan : `State` prend `ValueRaw` directement (pas d'attente filtre) | `⚡ AUTO_PLC` |

## 📥 Entrées

| Port | Type | Défaut | Rôle |
|---|---|---|---|
| `InputRaw` | BOOL | — | Signal brut carte d'entrée (physique) |
| `InvertLogic` | BOOL | FALSE | TRUE = NC (logique inversée). FALSE = NO (direct). **Doit être câblé par l'appelant** — pas de valeur implicite. |
| `FilterTime` | TIME | T#0 | Tempo anti-rebond. **Doit être câblé** — T#0 = pas de filtre. |
| `ChannelOk` | BOOL | — | Diagnostic device temps réel — état opérationnel du module d'entrée TOR (`GetDeviceState() = RUNNING`). **Pas de constante TRUE** — câblé au diagnostic device comme tous les autres devices du projet (`CANbus.GetBusState()`, `COD1_CODEUR.GetDeviceState()`, etc.). FALSE = carte/voie HS → `Error` signalé au consommateur. |

## 📤 Sorties

| Port | Type | Rôle |
|---|---|---|
| `State` | BOOL | Signal conditionné, prêt à l'emploi (polarité normalisée + filtré) |
| `Error` | BOOL | Voie en défaut (`ErrorId <> 0`) |
| `ErrorId` | WORD | bit0 = "Défaut matériel entrée (carte HS)" — voie/carte HS |

## 🔧 Logique interne

```
ValueRaw := InputRaw XOR InvertLogic;          (* 1. Inversion NO/NC *)
State := ValueRaw;                              (* 2a. Premier scan : direct *)
FilterTon(IN := (ValueRaw <> State), PT := FilterTime);
State := ValueRaw;                              (* 2b. Après filtre *)
IF NOT ChannelOk THEN
    ErrorId := ErrorId OR 16#0001;               (* 3. Signal d'erreur — State conserve sa dernière valeur (hold) *)
END_IF;
```

## 📐 Règles d'usage

| Règle | Exigence |
|---|---|
| **Câblage obligatoire** | `InvertLogic`, `FilterTime`, `ChannelOk` DOIVENT être câblés par l'appelant. Aucune valeur implicite n'est acceptable — le générateur LD doit les connecter. |
| **Polarité unique** | L'inversion se fait ICI, une seule fois. Aucun FB métier ne doit ré-inverser (`TC-P06-002`). |
| **Convention nom** | Le nom du DI (`<Domaine>_<ÉtatQuandTRUE>_DI`) porte la polarité logique. `InvertLogic` corrige l'écart physique ↔ logique (ex: contact NC → `InvertLogic := TRUE`). |
| **État sûr délégué** | `ChannelOk = FALSE` → `Error = TRUE` + `State` conserve sa dernière valeur. Le consommateur lit `Error` et applique **sa propre** logique d'état sûr (il connaît sa safety). FB_Input ne force pas `State` — il ne connaît pas l'état sûr du signal. |
| **Premier scan** | `State` prend `ValueRaw` sans attendre le filtre (évite les fausses alarmes transitoires au boot). |

## 🚨 Alertes et écarts

- **`FilterTime = T#0`** = pas de filtrage. Si le générateur LD ne câble pas `FilterTime`, les entrées ne sont pas filtrées → **rebonds de contact non éliminés**.
- **`InvertLogic` non câblé** = FALSE implicite. Pour un contact NC (ex: frein à manque de courant), l'appelant DOIT passer `InvertLogic := TRUE`.

## 📚 Documents liés

- [`AF_Partie-06_Acquisition_Qualification_IO_v2.0.md`](../AF_Partie-06_Acquisition_Qualification_IO_v2.0.md) §2 (rôle, chaîne d'acquisition)
- [`NAMING_CONVENTION.md`](../NAMING_CONVENTION.md) (polarité lisible dans le nom, REX C1)
- [`FB_Acquisition_Preflight_v1.0.md`](./FB_Acquisition_Preflight_v1.0.md) (consommateur des sorties)