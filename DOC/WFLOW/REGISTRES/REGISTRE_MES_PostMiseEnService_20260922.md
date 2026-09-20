# 📬 Post Mise en Service — 22/09/2026 — Rafraîchissement du mail GCAM (15/09/2026)

> **Nature** : ce document n'est **pas** un nouveau mail. L'utilisateur a recollé le 20/09 le texte
> du mail GCAM du **15/09/2026**, déjà versionné intégralement dans
> [`REGISTRE_MES_Rapport_Mail_GCAM_20260915.md`](REGISTRE_MES_Rapport_Mail_GCAM_20260915.md).
> Ce registre **rafraîchit** le rapprochement tâches de ce mail avec l'état du catalogue au
> **2026-09-22** (avancement, urgence), sans dupliquer la transcription du mail.
> Aucune copie du mail original n'a été retrouvée ailleurs dans le dépôt.

---

## 📊 Ventilation — état au 2026-09-22

Légende **Difficulté** : 🟢 simple (config/paramétrage) · 🟡 modérée (1 FB, logique locale) · 🟠 élevée (plusieurs FB, séquence) · 🔴 forte (sécurité machine, multi-axe, mesure/trace requise).
Légende **Phase** : `P0` diagnostic/cadrage encore nécessaire · `P1` design/plan à valider · `P2` implémentation · `P3` tests/gates · `P4` essai machine/recette.

| # | Sujet du mail (15/09) | Tâche | Avancement | Difficulté | Urgence | Phase actuelle | Phase suivante |
|---|---|---|---|---|---|---|---|
| 1 | 24 V variateurs maintenu au redémarrage | *(câblage, hors catalogue logiciel)* | 100 % | 🟢 | — | clos | — |
| 2 | Abandon bit de vie, bits réaffectés discordance contacteurs | *(décision actée)* | 100 % | 🟢 | — | clos | — |
| 3 | Égouttage AX13 — IHM + essai machine restant | T289 | ~70 % (logique OK, IHM à faire) | 🟡 | 🟠 à programmer | P2→P3 (injection IHM) | P4 essai machine |
| 4 | Descente auto M1=P4/M2=P5 — passer en nominal si confirmé | T291-A | 100 % | 🟢 | — | clos | — |
| 5 | Montée contrôlée : palier 2 nécessaire ~1 m | T298 | 100 % | 🟢 | ✅ clos | clos | — |
| 6 | % fermeture benne avant remontée — logique cycle non faite | T262 | ~30 % (cadrage fait, logique cycle non écrite) | 🟠 (multi-axe M1/M2/benne) | 🔴 bloquant | P0→P1 (dépend résultat T328) | P2 implémentation |
| 7 | Transition fermeture/remontée en grappin (AX10→AX11) | T262 | idem #6 | 🟠 | 🔴 | idem #6 | idem #6 |
| 8 | FDC haut en remontée : référence M1 pas M2 en Both | **T291-B** (T301 mail = doublon de numéro, sans rapport) | B0+B1 : 100 % livrés/validés ; B2 : 0 % | 🔴 (sécurité, Both M1/M2) | 🔴 sécurité | P3 (B1 testé OK) → **bloqué avant P2 de B2** | attend plan T330 validé |
| 9 | Discordance contacteurs — détailler causes maintenance | T288 | ~40 % (détection OK, détail causes à faire) | 🟡 | 🟠 | P2 (enrichissement causes) | P3 tests |
| 10 | Réglage montée contrôlée 0,5→1,0 m | T298 | 100 % (doublon #5) | 🟢 | — | clos | — |
| 11 | AX15B timeout ouverture benne — diagnostic avant correctif | T295 | 0 % | 🟠 (diagnostic multi-hypothèses) | 🟠 | P0 diagnostic non démarré | P1 plan |
| 12 | M3 — défauts Trémie/P1, pas de correction sans trace | T287 (+ T300 P-A, T333, T334) | ~45 % (trace analysée, 2 causes identifiées, correctifs en cours) | 🔴 (sécurité, 3 sous-chantiers) | 🔴 sécurité | P2 en cours sur T333 ; P0 sur T300/T334 | P3 gates, puis P4 |
| 13 | Translation M3 — fréquences persistantes 50/15 Hz | T296 | 0 % | 🟢 (paramétrage persistant) | 🟡 | P0/P1 non démarré | P2 |
| 14 | Régression M3 butées — dépassement, cause non établie | T287/T334 | idem #12 | 🔴 | 🔴 | idem #12 | idem #12 |
| 15 | Armement joystick incohérent avec permis réels | T224 | **statut catalogue vide/anormal** — avancement inconnu | 🟡 (à confirmer) | 🟠 à auditer | inconnu | audit du catalogue d'abord |
| 16 | Paliers treuils sous charge — condition vitesse câble | *(aucune tâche — numéro T300 réutilisé)* | 0 % | 🟠 (seuils M1/M2 montée/descente + hystérésis + persistant) | 🟡 | **P0 : tâche à créer** | — |
| 17 | Cycle homing buggué — reproduire, corriger, valider | *(aucune tâche — numéro T302 réutilisé)* | 0 % | 🔴 (reproduction du bug non faite) | 🔴 potentiellement sécurité | **P0 : tâche à créer** | — |
| 18 | Outil export CSV/Excel messages/alarmes — valider textes | T255 | ~50 % (structure prête, textes à valider) | 🟡 | 🟡 | P3 (validation contenu) | P4 |
| 19 | GVL Troubleshooting — vue chronologique | T313 (probable, à confirmer vs T303 du mail) | 0 % | 🟡 | 🟡 | P0/P1 non démarré | P2 |
| 20 | Raccourcis IHM sauts d'étape (mode essai) | T297 | 0 % | 🟡 (sécurités reprise consciente) | 🟢 | P0/P1 non démarré | P2 |

---

## 🆕 Chantiers ouverts depuis le 15/09, non couverts par le mail (contexte utile)

| Tâche | Sujet | Statut 22/09 |
|---|---|---|
| T327 | MAINT WinchSel=0 — ManualBucketLimits fuit en phase JOG auto | ✅ correctif livré, test visuel « semble OK » (22/09) |
| T328 | SimBench couplage M1/M2, rattrapage mâchoires | ❌ **test 22/09 ÉCHEC** — écart 5 % benne ne se résorbe pas à la montée, ni en cycle ni en MAINT ; relancé |
| T330 | Invariant position homing TOP / FDC logiciel haut | ⏳ plan v1.2 en cours, bloque T291-B phase B2 |
| T333 | Estimateur position M3 — recalage un seul sens | ⏳ correctif GO donné 20/09 |
| T334 | M3 — deux chemins de commande manuel vs cycle auto + dépassement P1/Trémie | ⬜ brief transmis 20/09 |
| T335 | Bandeau IHM — 4 TC rouges préexistants découverts | ⬜ créée 20/09 |
| T255-D | Défaut silencieux FDC bas — AnyFault sans message | ⏳ diagnostic accepté 20/09 |
| T332 | Hooks Claude Code — latence outillage | ⏳ bloquée, attend accord humain sur fichier hors dépôt |

---

## ⚠️ Points d'attention pour l'orchestrateur / l'utilisateur

1. **3 numéros de tâche "à créer" du mail 15/09 (T300, T301, T302) ont depuis été réutilisés pour d'autres sujets.** Les 3 sujets originaux ("paliers sous charge / vitesse câble", "FDC haut référence M1", "cycle homing buggué") doivent être re-identifiés :
   - FDC haut / M1 en Both → couvert par **T291-B** (confirmé, pas de nouvelle tâche à créer).
   - GVL Troubleshooting chronologique → probablement **T313** (à confirmer).
   - **Paliers sous charge (vitesse câble)** et **cycle homing buggué** : **aucune tâche identifiée** au 22/09 → à créer si toujours d'actualité.
2. **T224** (armement joystick) a un statut vide anormal dans `TASKS.yaml` — à auditer.
3. Ce registre ne remplace pas `REGISTRE_MES_Rapport_Mail_GCAM_20260915.md` (texte source) ni `TASKS.yaml` (source de vérité) — il sert de pont daté entre les deux.

---

*Rédigé par CC01 (orchestrateur), 2026-09-22, sur demande explicite de rapprocher le mail GCAM du 15/09 avec l'état courant du catalogue.*
