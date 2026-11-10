# 📋 Table d'échange IHM — Compteurs de prélèvements/déversements (T299)

> **État source** : implémenté et testé (CI 26/31 PASS, gates PASS), **pas encore committé**
> (revue indépendante en cours). Ces adresses sont stables (contrat déjà PASS), mais le
> correctif final peut encore bouger avant clôture — à reconfirmer avant mise en service réelle.

## 🔢 Compteur JOURNALIER

| Champ | Valeur |
|---|---|
| **Adresse GVL_IHM** | `GVL_IHM.CycleSemiAuto.State.SampleCount` |
| Type | `INT` |
| Sens | Lecture seule côté IHM |
| Rôle | Nombre de déversements du jour |
| Remise à zéro | Bouton IHM `GVL_IHM.CycleSemiAuto.Cmd.BtnResetSampleCount` (`BOOL`, front montant / impulsion) |
| Mode auto-reset | `GVL_IHM.CycleSemiAuto.Cfg.SampleCountResetMode` (`E_CycleSampleCountResetMode`, persistant) |
| Valeurs du mode | `NEVER := 0` (défaut, aucun changement) · `ON_FIRST_START := 1` (1er démarrage depuis mise sous tension) · `ON_SAFETY_REARM := 2` (réarmement sécurité) |

## 🔒 Compteur TOTALISATEUR

| Champ | Valeur |
|---|---|
| **Adresse GVL_IHM** | `GVL_IHM.CycleSemiAuto.State.SampleCountTotal` |
| Type | `UDINT` |
| Sens | **Lecture seule uniquement** — aucune commande d'écriture n'existe, jamais remis à zéro |
| Rôle | Total cumulé depuis la mise en service (persistant, survit aux coupures et rechargements programme) |

## ⚙️ Événement d'incrément (identique pour les 2)

Incrémentés **ensemble**, une seule fois par cycle, à l'étape **AX18** (fin de cycle après vidage trémie).

## ⚠️ Point de commissioning obligatoire (CODESYS)

`GVL_PERSISTENT._CycleSampleCountTotal : UDINT := 0;` doit être **créée manuellement dans
CODESYS** lors de l'import (les variables PERSISTENT sont exclues du bundle PLCopenXML, gérées
directement par le runtime) — sinon le programme ne compile pas.

---
*Généré par CC01 le 2026-09-20 à la demande de l'utilisateur, avant clôture finale de T299 —
table à réémettre si la revue indépendante fait bouger une adresse.*
