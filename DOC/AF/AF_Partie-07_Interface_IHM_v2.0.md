# Analyse Fonctionnelle - Partie 7 : Interface IHM (v2.0)

> Role : definir le contrat structurel PLC ↔ IHM.
> Le detail des champs vit dans le code `CODE/SUPERVISION/_TYPES/`.

## 🧭 Sommaire

1. Principe
2. Frontiere `GVL_IHM`
3. Structures par domaine
4. Messages operateur
5. Troubleshooting
6. TBD

## 🧪 Points de validation

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| TC-P07-001 | IHM et PLC partagent les mêmes DUTs | Aucun miroir parallèle de variables | `💻 AUTO` | §1 |
| TC-P07-002 | Structures `Cmd/State/Cfg` par domaine | Convention respectée dans `GVL_IHM` | `💻 AUTO` | §3 |
| TC-P07-003 | IHM limitée aux variables de `GVL_IHM` | Zéro accès direct aux internes des FB | `💻 AUTO` | §1 |
| TC-P07-004 | Producteur unique par champ `State` | Un seul écrivain PLC par variable d'état | `💻 AUTO` | §1 |
| TC-P07-005 | Page Troubleshooting en lecture seule | Zéro écriture de commande/config/bypass | `💻 AUTO` | §5 |
| TC-P07-006 | Séparation messages action vs état | 2 familles distinctes, alarmes sur `ErrorId` | `⚡ SITE+AUTO` | §4 |
| TC-P07-007 | Warning auto-effaçable vs Fault sur Reset | Warning s'efface seul, Fault exige `Ack` | `⚡ SITE+AUTO` | §4 |

---

## 🎯 1. Principe

L'IHM et le PLC partagent les **memes structures**.

| Regle | Exigence |
|---|---|
| 🧱 Frontiere unique | `GVL_IHM` est le point d'echange IHM. |
| 🧩 Meme DUT | Producteur PLC et ecran utilisent la meme structure. |
| 🔒 Pas d'internes | L'IHM ne lit ni n'ecrit les variables internes des FB. |
| ✍️ Producteur unique | Chaque champ `State` a un seul ecrivain PLC. |
| 🎮 Commandes maintenues ou fronts | Les impulsions sont consommees sur front ; les maintenues gardent leur semantique. |

Pas de liste exhaustive de variables dans ce document.

---

## 🌐 2. Frontiere `GVL_IHM`

Domaines exposes a minima :

| Domaine | Structure |
|---|---|
| 🪝 Treuil M1 | `M1TreuilRetenue : ST_WinchHMI` |
| 🪝 Treuil M2 / Benne | `M2TreuilBenne : ST_WinchHMI` |
| ⚖️ Synchro | `M1M2Sync : ST_SyncHMI` |
| 🕹️ Joystick | `JOY1Joystick : ST_JoystickHMI` |
| 🎚️ Modes | `Modes : ST_ModesHMI` |
| ↔️ Translation | `TranslationM3 : ST_TranslationHMI` |
| 🔄 Cycle | `Cycle : ST_CycleHMI` |
| 🪨 Assistants | `DredgingAssist : ST_DredgingAssistHMI` |
| 📡 Reseau | `Network : ST_NetworkDiagHMI` |
| 🌐 Commun | `Commun : ST_CommunHMI` |

La reference des champs est le code actif des DUT.

---

## 🧱 3. Structures par domaine

Convention cible :

```text
Cmd    → IHM → PLC
State  → PLC → IHM
Cfg    → reglage borne / persiste
Bypass → maintenance consciente, si justifie
Test   → banc seulement, si justifie
Safety → diagnostics safety publies, si separes
```

| Sous-structure | Role |
|---|---|
| 🎮 `Cmd` | Demandes operateur. |
| 🚦 `State` | Etats, mesures, diagnostics produits par le domaine. |
| 🔧 `Cfg` | Reglages. Bornage PLC obligatoire. |
| 🛠️ `Bypass` | Degradations de maintenance visibles. |
| 🧪 `Test` | Stimuli de banc, jamais en production. |

Le mapping, la persistance et d'eventuels agregats restent **TBD**. Ils ne justifient pas automatiquement un programme CFC.

---

## 💬 4. Messages operateur

Deux familles a distinguer :

| Famille | Sens |
|---|---|
| 🎮 Action attendue | L'operateur doit faire quelque chose maintenant. |
| 🧭 Etat machine | Information d'etat, sans demande d'action. |

Cette distinction recoupe celle des defauts domaine : **Warning** (etat machine, s'efface seul
avec la cause, pas d'action requise) vs **Fault** (action attendue = acquittement conscient,
meme cause disparue). Pattern `Cause`/`Ack`, temporisation d'affichage anti-clignotement et regle
complete : `DOC/CODE_QUALITY_STANDARDS.md §9`. Pas reformule ici.

Format, priorites, concatenation et proprietaire exact : **TBD**.

Les alarmes restent portees par `Error` / `ErrorId` des domaines.

---

## 🔎 5. Troubleshooting

Le troubleshooting est une observation **lecture seule**.

| Regle | Exigence |
|---|---|
| 👁️ Observation | Affiche des structures publiques dans un ordre utile au debug. |
| 🚫 Ecriture | Aucune commande, config, bypass ou interlock. |
| 🧩 Source | Contrats publics des domaines, pas les internes FB. |

Type exact, programme eventuel et ordonnancement : **TBD**.

---

## ❓ 6. TBD

- Besoin ou non d'un programme ST de mapping/persistance.
- Contrat detaille des messages action/etat.
- Organisation finale troubleshooting.
- Eventuelle structure unique d'intention de conduite.

## 📚 Documents lies

- Partie 02 : frontieres IHM et troubleshooting.
- Partie 03 : contrats publics.
- Parties metier 04 a 14 : contenu semantique publie dans `State`/`Cmd`/`Cfg`.
- Code : `CODE/SUPERVISION/GVL_IHM.st` et `CODE/SUPERVISION/_TYPES/`.
