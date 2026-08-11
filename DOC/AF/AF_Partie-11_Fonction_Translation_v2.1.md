# Analyse Fonctionnelle — Partie 11 : Fonction Translation M3 (v2.1)

> 🎯 **Raison d'être & Responsabilité Unique** :
> - **Problème résolu** : Positionnement transversal du chariot/pont le long de la digue (Moteur M3 via variateur AC600 EtherCAT) et sécurisation contre les collisions physiques.
> - **Périmètre strict** : Gère la consigne de vitesse M3, le décodage de position 5 capteurs, la rampe de décélération, et les sécurités d'anti-télescopage Benne/Translation.
> - **Type de composant** : Domaine autonome Mouvement & Safety M3 (`PRG_05_Translation`).

---

## 🧭 Sommaire

1. Composition — fiches FB dédiées
2. Rôle machine & Responsabilités
3. Points de validation (`TC-P11-*`)
4. Intégration programme
5. Documents liés

---

## 🧪 Points de Validation (`TC-P11-*`)

Catalogue synthétique des **6 grands tests macro fonctionnels** du domaine Translation :

| <nobr>ID Unique</nobr> | Groupe | Comportement Attendu | <nobr>Type</nobr> | <nobr>Réf FB</nobr> |
|---|---|---|---|---|
| <nobr><code>TC-P11-010</code></nobr> | **Pos. & Butées** | 5 capteurs ➔ pos. qualifiée (Travail/Trémie/Extrêmes). Incohérence ➔ Défaut imm. | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_Translation_PositionDecoder</code></small> |
| <nobr><code>TC-P11-020</code></nobr> | **Sécurité M3** | Défaut thermique M3 / AC600 ➔ rampe rapide + alarme. | <nobr><code>⚡ AUTO+SITE</code></nobr> | <small><code>FB_Safety_Translation</code></small> |
| <nobr><code>TC-P11-030</code></nobr> | **Anti-télescopage** | Trans. bloquée si Benne bas (`BucketIsUpConfirmed=FALSE`). Descente bloquée si désaligné. | <nobr><code>⚡ AUTO+SITE</code></nobr> | <small><code>FB_Safety_Translation</code></small> |
| <nobr><code>TC-P11-040</code></nobr> | **Vitesse & Rampes** | Joystick/SemiAuto ➔ Rampe ➔ AC600. Ralentissement auto sur PV. | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_Translation</code></small> |
| <nobr><code>TC-P11-050</code></nobr> | **Barrière Sorties** | Agrégation AU + Safety + Interlocks. Zéro redémarrage auto. | <nobr><code>⚡ AUTO+SITE</code></nobr> | <small><code>FB_TranslationOutputInterlock_LD</code></small> |
| <nobr><code>TC-P11-060</code></nobr> | **Bypass & MAINT** | En `MAINT_N2`, sécurités actives par défaut. Neutralisation = action IHM dédiée. | <nobr><code>💻 AUTO</code></nobr> | <small><code>FB_Modes</code><br><code>FB_Translation</code></small> |

---

## 🧱 1. Composition — fiches FB dédiées

| Fiche | FB détaillé | Contenu |
|---|---|---|
| [`FB_Translation_PositionDecoder_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Translation_PositionDecoder_v1.0.md) | `FB_Translation_PositionDecoder` | 5 capteurs → mot, position qualifiée, incohérence |
| [`FB_Safety_Translation_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Safety_Translation_v1.0.md) | `FB_Safety_Translation` | 8 bits ErrorId, Méca A/B, anti-télescopage, bypass |
| [`FB_Translation_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_Translation_v1.0.md) | `FB_Translation` (+ `FB_Brake`, `FB_Ramp`) | Mouvement, rampe, mot AC600, ralentissement PV |
| [`FB_TranslationOutputInterlock_LD_v1.0.md`](AF_Partie-11_Fonction_Translation/FB_TranslationOutputInterlock_LD_v1.0.md) | `FB_TranslationOutputInterlock_LD` | Barrière finale, watchdog frein, anti-redémarrage |

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>FB_Translation_PositionDecoder</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Acquisition position qualifiée (5 capteurs)</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Pos. qualifiée & Défauts</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #f43f5e; padding:6px 10px; border-radius:4px; font-size:12px;">
    🛡️ &nbsp;<b>FB_Safety_Translation</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Anti-télescopage & Verrouillage M3</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Autorisations & Bypass</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #fbbf24; padding:6px 10px; border-radius:4px; font-size:12px;">
    ⚙️ &nbsp;<b>FB_Translation</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Rampe lissée & Consigne AC600</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Consigne vitesse & Sens AC600</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    🔒 &nbsp;<b>FB_TranslationOutputInterlock_LD</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Barrière finale matérielle outputs</span>
  </div>
</div>

---

## ⚙️ 2. Intégration programme & Architecture

- **POU cible unique** : `PRG_05_Translation` (ST/CFC).
- **Source des autorisations** : `ST_Modes_Autorisations` distribué par `PRG_03_Modes_Cycle`.
- **Image des sorties** : Transmise à `PRG_06_Outputs_LD` pour la barrière finale matérielle.
