# 📐 Guide d'Édition des Analyses Fonctionnelles (AF) (v1.0)

> 📌 **Standard normatif d'ingénierie** pour la rédaction, le versionnement et la structuration des spécifications fonctionnelles sous `DOC/AF/`.
> Tout agent ou développeur modifiant une AF **doit** se conformer à ce guide.

---

## 🎯 1. Raison d'être & Responsabilité Unique (En-tête obligatoire)

Toute fiche AF doit commencer par un paragraphe **court, clair et synthétique (3-4 lignes max)** qui explique pourquoi ce document existe :

```markdown
# AF_Partie-XX : [Nom du Domaine / Fonction]

## 🎯 Raison d'être & Responsabilité Unique
- **Problème résolu** : [Expliquer le besoin physique/opérateur résolu par la fonction]
- **Périmètre strict** : [Ce que la fonction fait / Ce qu'elle ne fait absolument pas]
- **Type de composant** : [Producteur d'intention / Brique E/S / Commande Mouvement / Safety]
```

---

## 🛡️ 2. Philosophie des Modes & Sécurités Machine (ISO 13849)

### Règle d'or du Mode `MAINT_N2` (Maintenance Étendue) :
- **Pas de déverrouillage automatique** : Le simple basculement en mode `MAINT_N2` **ne désactive aucune sécurité par défaut**.
- En `MAINT_N2`, l'automate se comporte exactement comme en `MAINT_N1` (toutes les sécurités, fins de course et anti-télescopages restent **100% actifs**).
- **Dérogation consciente & individuelle** : Le bypass d'une sécurité spécifique (ex: dépassement FDC, désynchronisation M1/M2) nécessite **deux conditions cumulees** :
  1. Être en mode `MAINT_N2`.
  2. Une **action volontaire IHM spécifique** (appui bouton dédié/maintien), journalisée et affichée à l'écran.

---

## 🧪 3. Points de Validation (`TC-Pxx-nnn`)

### Règle des Identifiants (Immuabilité & Synthèse) :
1. **Numérotation Immuable** : `TC-P<Partie>-<Numéro>` (ex: `TC-P11-010`, `TC-P11-020`).
2. **ID 1 Ligne Stricte (Obligatoire)** : L'ID doit **toujours** être contenu sur 1 seule ligne (ne jamais broken/wrapper sur plusieurs lignes). Utiliser `<nobr><code>TC-Pxx-010</code></nobr>`.
3. **Incrémentation par pas de 10** (`010`, `020`, `030`) pour insérer des sous-cas sans casser la séquence.
4. **Non-réutilisation absolue** : Un ID supprimé ou obsolète n'est **jamais réutilisé** pour un autre test.
5. **Regroupement Macro (Pas de bruit)** :
   - Fini la démultiplication de micro-tests sur des détails ST internes.
   - **3 à 6 grands tests Macro maximum** par domaine AF.

### 📐 Formatage Ultra-Compact & Compacité Maximale du Tableau :
- **ID Unique (Cellules)** : Encadré par `<nobr><code>TC-Pxx-010</code></nobr>` (verrouillage mono-ligne strict).
- **Réf FB** : Écrire en police réduite (`<small>`) et **découper sur plusieurs lignes** (ex: `<small><code>FB_Modes</code><br><code>FB_Translation</code></small>`) pour compacter la colonne au minimum.
- **Intitulés de Colonnes Concis** : Préférer `<nobr>ID Unique</nobr>`, `Groupe`, `Comportement Attendu`, `<nobr>Type</nobr>`, `<nobr>Réf FB</nobr>` pour éviter les espaces inutiles.
- **Comportement Attendu (Hauteur & Densité)** : Formulations concises et denses (1 à 2 phrases ultra-courtes avec flèches `➔`) pour éviter d'étirer inutilement le tableau.

| <nobr>ID Unique</nobr> | Groupe | Comportement Attendu | <nobr>Type</nobr> | <nobr>Réf FB</nobr> |
|---|---|---|---|---|
| <nobr><code>TC-Pxx-010</code></nobr> | **[Nom Groupe]** | [Comportement physique et logique ultra-synthétique en 1-2 phrases] | <nobr><code>⚡ AUTO+SITE</code></nobr> | <small><code>FB_NomComposant1</code><br><code>FB_NomComposant2</code></small> |

---

## 🔄 3bis. Représentation du Flux de Données & Séquencement FB (Cartes Compactes & Flèches Vectorielles SVG)

- **Design Hybride Ultra-Compact & Vectoriel** :
  - **Cartes ultra-étroites (`padding: 6px 10px`)** : Suppression de 100% du vide des générateurs automatiques.
  - **Émoji collé directement à gauche** : `🛡️ &nbsp;<b>FB_Safety_Translation</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Rôle</span>`.
  - **Vraies Flèches Vectorielles SVG** : Éléments vectoriels SVG (`<svg>`) assortis à la couleur de chaque bloc, avec étiquette explicite du signal transmis.

```html
<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>FB_Acquisition</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Acquisition position qualifiée</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Signaux qualifiés & Défauts</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #f43f5e; padding:6px 10px; border-radius:4px; font-size:12px;">
    🛡️ &nbsp;<b>FB_Safety</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Verrouillages & chaînes de sécurité</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Autorisations & Bypass</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #fbbf24; padding:6px 10px; border-radius:4px; font-size:12px;">
    ⚙️ &nbsp;<b>FB_Commande</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Génération intention & rampes</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Consigne vitesse & Sens physiques</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    🔒 &nbsp;<b>FB_OutputInterlock_LD</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Barrière finale matérielle outputs</span>
  </div>
</div>

---

## 🏷️ 3ter. Dictionnaire des Émojis Standards & Cartouche ST

Pour assurer la lisibilité visuelle et supprimer tout risque de dérive entre les schémas AF et le code ST :

| Domaine Fonctionnel | Émoji | Couleur Bordure | Exemples de FB / POU |
|---|---|---|---|
| **Acquisition & Diag Device** | 📡 | Cyan (`#38bdf8`) | `FB_Translation_PositionDecoder`, `FB_Encoder_Abs`, `FB_Diag_Ethercat` |
| **Référencement & Homing** | 🎯 | Cyan (`#38bdf8`) | `FB_Encoder_Homing`, `FB_Encoder_Scale` |
| **Sécurité & Verrouillages** | 🛡️ | Rouge (`#f43f5e`) | `FB_Safety_Translation`, `FB_Safety_Winch`, `FB_Safety_EmergencyManagement` |
| **Mouvement & Commandes** | ⚙️ | Jaune (`#fbbf24`) | `FB_Translation`, `FB_Winch`, `PRG_04_Treuils_Benne` |
| **Barrière Finale Sorties** | 🔒 | Vert (`#4ade80`) | `FB_TranslationOutputInterlock_LD`, `PRG_06_Outputs_LD` |
| **Supervision & Dépannage** | 🖥️ / 🩺 | Bleu-Gris | `PRG_07_Supervision_CFC`, `FB_Acquisition_Preflight` |

- **Alignement Strict des Titres et Rôles** : Le nom du FB, la description de son rôle et l'émoji du cartouche `.st` doivent être **exactement identiques** à ceux présentés dans le tableau de composition de la spec AF (`DOC/AF/`).

---

## 🧱 4. Structure d'un Dossier AF

- **Chapô principal (`AF_Partie-XX_*.md`)** : Porte le résumé machine, l'intégration programme et le **Catalogue Synthétique des TC Macro**.
- **Fiches FB sous-dossier (`AF_Partie-XX_*/FB_*.md`)** : Si un détail technique est nécessaire, il décline sous forme d'étapes `TC-Pxx-010.1`, `TC-Pxx-010.2` sans inventer de nouveaux identifiants racine.
