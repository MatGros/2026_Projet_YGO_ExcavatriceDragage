# 🔎 Revue indépendante — Interfaces HMI & Troubleshooting

📅 2026-08-24 · 🤖 Sous-agent read-only (Expert Automatisme/IHM) · 🚫 Aucune modification de code

## 🎯 Périmètre

`GVL_IHM`, `GVL_Troubleshooting`, `FB_TroubleshootingView`, `FB_Hmi_BannerFormatter`,
`FB_AntiFlickerText`, `PRG_07_Supervision`, `_TYPES/` (8 sous-dossiers — 2 de plus que prévu
dans la mission, `7_COMMUN_CONFIG`/`8_BANDEAU_ET_IHM`, traités quand même), `_BRIDGES/` (7
fichiers). Focus : cohérence avec l'architecture cible 7 POU + capacité de dépannage
chronologique.

## ✅ Synthèse par fichier

| Fichier | Verdict | Findings |
|---|---|---|
| `GVL_IHM.st` | 🟢 PASS | 0 |
| `GVL_Troubleshooting.st` | 🟡 MINOR | 1 (structurel — snapshots, pas d'historique) |
| `FB_TroubleshootingView.st` | 🟡 MINOR | 0 bloquant, TBD documentés proprement |
| `FB_Hmi_BannerFormatter.st` | 🟠 MAJOR | 2 (commentaires-journal REX, condition 5 termes) |
| `FB_AntiFlickerText.st` | 🟢 PASS | 0 |
| `PRG_07_Supervision.st` | 🟠 MAJOR | 2 (calcul métier inline hors doctrine, duplication ×10) |
| `_TYPES/*` (14 fichiers ouverts) | 🟡 MINOR | 5 (4× vocabulaire abandonné + 1 commentaire garbled) |
| `_BRIDGES/*` (7 fichiers) | 🟢 PASS | 0 |

**Verdict global : 🟠 MAJOR** — aucun risque sécurité direct (troubleshooting reste lecture
seule), mais 2 MAJOR à traiter avant clôture de lot.

## 🟠 Points MAJOR

### 1. Commentaires-journal interdits — `FB_Hmi_BannerFormatter.st:478-540`
3 blocs de commentaires type journal de chantier (« corrigés ici bit à bit », « ajouté ici
après lecture du FB source »…) — interdits par `CODE_QUALITY_STANDARDS.md §2ter`. À purger,
historique éventuel → `VERSION_HISTORY.md`/Git.

### 2. `PRG_07_Supervision` déborde de son rôle « lecture seule stricte »
- L.333-335 : `LimitLegalReached` **calculé inline** (comparaison de seuil) — contredit la
  doctrine documentée (« n'écrit ni commande, ni configuration, ni interlock »). À trancher :
  acceptable comme état public agrégé, ou à faire migrer vers un domaine métier producteur ?
- L.169-295 : ~10 blocs quasi identiques de sync bypass IHM↔RETAIN — dette de duplication,
  candidate à extraction FC dédiée.

### 3. Condition composée 5 termes — `FB_Hmi_BannerFormatter.st:341-342`
`CriticalActionActive` dépasse le seuil de 3 termes (`CODE_QUALITY_STANDARDS.md §2quater`).

## 🕐 Constat chronologie troubleshooting — trou structurel confirmé

**Non, la vue ne permet pas un dépannage chronologique intuitif — snapshot instantané
uniquement.** Aucune des ~14 structures `ST_Chain*`/`ST_*Checklist` ne porte d'horodatage, de
séquence d'événements ou de pile d'historique. `FB_TroubleshootingView` écrit en recopie pure
à chaque scan (10 ms) — la valeur précédente est systématiquement écrasée.

⚠️ Plus large que le trou déjà connu T129 (M3 ErrorId/Direction, ⏳ en attente) : c'est une
**propriété structurelle** de `GVL_Troubleshooting` dans son ensemble, tous domaines confondus
(M1, M2, Benne, AU, Joystick, Cycle) — aucune mémorisation temporelle au-delà des `*AtError`
déjà portés ponctuellement par certains FB sources.

## 📎 Findings MINOR — vocabulaire abandonné (commentaires uniquement, zéro risque fonctionnel)

| Fichier:ligne | Nom abandonné trouvé |
|---|---|
| `ST_WinchFinalInterlockRequest.st:4-5` | `PRG_TREUILS_CFC`, `PRG_10_Outputs_LD` |
| `ST_TranslationCmd.st:14` | `PRG_10_Outputs_LD` |
| `ST_Modes_Autorisations.st:6,8` | `PRG_MODES_CFC` (×2) |
| `ST_CommunHMI.st:22,42` | `PRG_AUXILIARY_CFC`, `PRG_SUPERVISION_CFC` |

+ `ST_TranslationHMI.st:16` : commentaire syntaxiquement cassé (reliquat d'édition).

## 🚨 Signalements hors périmètre (devoir d'alerte)

- Ambiguïté doctrine `PRG_07` (lecture-seule stricte vs `LimitLegalReached` inline) — à trancher.
- 2 sous-dossiers `_TYPES/` non prévus dans le périmètre initial de la mission, traités quand
  même par prudence (écart signalé par le sous-agent lui-même).

---
*Rapport intégral du sous-agent conservé dans la transcription de session — ce document en est
la synthèse actionnable.*
