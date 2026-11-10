# 🧪 PLAN DE TEST — T383 / AX15D « MODULE BENNE À LA TRÉMIE » (SIMULATION)
## 🎯 Objectif : ouvrir **ET** refermer la benne **SUR PLACE** à la trémie — **sans jamais sauter vers AX10**

> 📅 2026-09-22 · 🏷️ DSH01 · 🧩 Lot : **T383 phases 1+2** (C4) — **code écrit par tes agents, non encore accepté**
> 📦 **Import** : `CODE_XML/CODE_DiffBundle.xml` → objets **`E_AutoCycleStep` · `FB_CycleSemiAuto` · `FB_Hmi_BannerFormatter` · `PRG_02_Acquisition`**
> ✅ Vérifié par l'orchestrateur sur le **diff réel** : déviation `AX15B → AX10` **RETIRÉE** (`FB_CycleSemiAuto.st:1565` envoie vers `AX15D`) · `AX15D_DUMP_BUCKET_JOG := 23` · **G200 PASS**

---

## 🗺️ 0 — LA CARTE (il n'existe **pas** d'étape « AX15 » seule)

| Étape | N° | Rôle |
|---|---|---|
| `AX15A_DUMP_ARRIVE` | **15** | Arrivée trémie : treuils arrêtés, attente geste |
| `AX15B_DUMP_OPEN` | **16** | **Vidage** : ouverture benne, treuils à 0 |
| `AX15C_DUMP_REPOSITION` | **17** | Repositionnement couplé M1+M2 (option IHM) |
| 🆕 **`AX15D_DUMP_BUCKET_JOG`** | **23** | **Module benne SUR PLACE** — *le nouveau* |

⚠️ **Le numéro 23 est volontaire** : les valeurs 18→22 sont déjà prises (`AX18`, `AX_STAB`, `AX_DIVING_RETRY`, `AX3_WAIT_DIVE_START`, `AX10B_RACCORDEMENT_P1`). La famille « AX15 » est donc regroupée **par le nom**, pas par la valeur.

---

## ✅ 1 — PRÉ-REQUIS

| ☐ | Quoi |
|---|---|
| ☐ | Import du **diff bundle** (4 objets ci-dessus) |
| ☐ | Mode **SEMI_AUTO**, homme-mort armé |
| ☐ | Dérouler le cycle **jusqu'à `AX15B`** (vidage à la trémie) — `CycleStep = 16` |

---

## 🎯 2 — LE TEST PRINCIPAL : le module benne (le nouveau)

| # | Geste | Attendu | À relever |
|---|---|---|---|
| **1** | Depuis **AX15B**, **TIRER** le joystick (Y+) | **`CycleStep` → 23 (`AX15D`)** — ⛔ **plus jamais 10 (`AX10`)** | `G_CycleSemiAuto.Idx206_Step` |
| **2** | **POUSSER** (Y−) | `BucketCmd.ReqOpen = TRUE` → **la benne s'OUVRE** | ouverture benne |
| **3** | **TIRER** (Y+) | `BucketCmd.ReqClose = TRUE` → **la benne se FERME** | fermeture benne |
| **4** | **RELÂCHER** (centre) | `ReqOpen = ReqClose = FALSE` → **arrêt de la benne**, puis **retour `AX15B`** (`CycleStep = 16`) | `Idx206_Step` |
| **5** | 🔒 **TREUILS** pendant 1→4 | `WinchM1Cmd/M2Cmd` **tous à FALSE**, `StepTgt = 0`, translation 0 ⇒ **AUCUN mouvement de treuil** | sorties M1/M2 |

**Message attendu (bandeau)** : **`AX15d - Pousser : ouvrir benne. Tirer : fermer. Relacher : retour.`**

---

## 🚨 3 — LES 3 VÉRIFICATIONS QUI COMPTENT (l'objet de la correction)

| # | Ce qu'on prouve | Comment |
|---|---|---|
| **A** | ⛔ **Le saut `AX15B → AX10` a DISPARU** | à AX15B, tirer Y+ → **on doit aller en 23, JAMAIS en 10** · aucun passage vers 22/11/12 (AX10B/AX11/AX12) |
| **B** | 🪣 **La fermeture sur place fonctionne** | tirer → `ReqClose` vrai, la benne se ferme, **on reste en 23** |
| **C** | 🛡️ **Aucun mouvement de treuil** dans AX15D | `WinchM1Cmd/M2Cmd` à 0 pendant toute la manipulation |

---

## 📌 4 — CAS PARTICULIER À VÉRIFIER

| Situation | Attendu (lu dans le code, à confirmer) |
|---|---|
| **Pousser** (ouvrir) jusqu'à **benne ouverte + contenu vidé** (`Benne_Done AND Benne_IsOpen`) | **`CycleStep` → 18 (`AX18` = fin de passe)** — sortie « vidage terminé » |
| ⚠️ **Priorité** : relâcher **alors que** la benne est ouverte/vidée | Le code évalue **d'abord le relâchement** → **retour `AX15B`**. *À confirmer comme comportement voulu (arbitrage n°1)* |

---

## 📝 5 — RELEVÉ

| # | Test | Valeur lue | OK ? |
|---|---|---|---|
| 1 | AX15B + tirer → **23** (et pas 10) | | ☐ |
| 2 | Pousser → ouverture benne | | ☐ |
| 3 | Tirer → fermeture benne | | ☐ |
| 4 | Relâcher → arrêt + retour **16** | | ☐ |
| 5 | Treuils à 0 pendant tout | | ☐ |
| 6 | Pousser + vidé → **18** | | ☐ |
| 7 | Message `AX15d - …` affiché | | ☐ |

---

## 🧰 6 — SI ÇA BLOQUE

1. 🧊 **Pas de Reset** avant d'avoir relevé.
2. 📸 Snapshot pendant/juste après.
3. 📨 Envoie-moi le CSV.

---

## ⚖️ 7 — STATUT D'HONNÊTETÉ DU LOT

- ✅ **Ce qui est prouvé** : déviation retirée · step 23 déclaré et câblé · G200 **PASS** · bundle **frais**.
- ⏳ **Ce qui reste** : palier C + CI cycle (en cours) · **double revue C4** (règle C4) · **commit** (ton accord) · **validation a posteriori de la phase 0** (l'amendement GEL était « à valider » quand le code a été écrit).
- 🔎 **Point d'attention relevé** : `PRG_02_Acquisition.st` a été modifié — `AX15D` est ajouté à **`DirectInversionPermit`** (inversion Y sans neutre). **Cohérent** (comme `AX15B` l'était déjà) **et sans risque** : en `AX15D` **aucun** ordre de treuil n'est émis — mais c'est un **permis**, donc à **acter** explicitement.
