# 05 — BRIEF DE RECHERCHE EXTERNE · Moteur de treuil, réducteur et charge (benne preneuse)

> 🎯 **Destinataire** : agent de recherche **externe au projet** (recherche web + calcul).
> ⛔ **Tu n'as PAS accès au dépôt de code.** Toutes les données nécessaires sont **recopiées dans ce document**.
> Les mentions `fichier:ligne` sont là **uniquement pour la traçabilité** de l'origine de la donnée — ne cherche pas à ouvrir ces fichiers.
> ✅ Ton livrable : des **valeurs sourcées** (avec URL) + des **calculs vérifiables**.
> 🚫 Tu ne modifies rien, tu ne codes rien, tu produis un rapport.

---

## 1. Contexte machine (pour comprendre à quoi sert chaque valeur)

Automate **CODESYS 3.5** pilotant une **excavatrice de dragage** (benne preneuse) travaillant dans une **carrière noyée**. La machine extrait du matériau au fond de l'eau avec une benne suspendue à un câble.

**Chaîne d'entraînement d'un treuil** (il y a **2 treuils identiques**, appelés **M1** et **M2**) :

```text
[Groupe électrogène 400 V]
        │
        ▼
[Moteur asynchrone À ROTOR BOBINÉ (~200 A stator), 50 Hz, ~1500 tr/min]
        │      ← démarrage par CASCADE DE RÉSISTANCES ROTORIQUES
        │        (contacteurs de "gradins" / paliers qui retirent la résistance
        │         progressivement pour accélérer)
        ▼
[Réducteur mécanique (rapport INCONNU)]
        │
        ▼
[Tambour d'enroulement Ø ~0,64 m (2,0 m de câble par tour)]
        │
        ▼
[Câble] → [Benne preneuse (grappin)]
```

- **M1** = treuil de retenue · **M2** = treuil de benne (le câble de la benne).
- Les **5 « paliers » (gradins)** de résistance rotorique sont numérotés 1 → 5. Chaque palier = un état du coffret de résistances.
- 🔒 Enjeu : des valeurs de couple/courant fausses dans le **simulateur** de l'automate peuvent faire **valider à tort** une logique de sécurité (ex. « l'enchaînement des gradins est assez lent, donc pas de surintensité »). D'où l'exigence de **sourcer chaque chiffre**.

---

## 2. Données disponibles — avec leur statut de fiabilité

**Classification imposée** (le projet l'utilise déjà) :
`MESURÉE` = relevé terrain · `DOCUMENTÉE` = écrite dans un document/constante du projet · `ESTIMÉE` = estimation utilisateur ou calcul non validé · `SYNTHÉTIQUE` = valeur posée à la main dans le code, **sans base physique** · `INCONNUE` = inconnue.

| # | Donnée | Valeur | Statut | Origine |
|---|---|---|---|---|
| 1 | Courant stator nominal moteur | **≈ 200 A** | ESTIMÉE (oral utilisateur) | `PLAN_T317…md:51` |
| 2 | Fréquence / pôles | **50 Hz, ~1500 tr/min ⇒ 4 pôles** | ESTIMÉE (oral utilisateur) | oral |
| 3 | Type de moteur | **asynchrone à rotor bobiné**, piloté par cascade de résistances rotoriques | DOCUMENTÉE | oral + code |
| 4 | Chute de tension groupe sous appel de charge | **400 V → 360 V** (un seul point de mesure) | **MESURÉE (1 point, non tracé)** | `PLAN_T317…md:52` |
| 5 | Développement câble par tour de tambour | **2,0 m/tour** (⇒ Ø ≈ 0,637 m) | DOCUMENTÉE — « périmètre tambour **confirmé 2026-07-02** », mais autre note « **à confirmer sur tambours machine** » | `PRG_02_Acquisition.st:73` |
| 6 | Charge suspendue de référence | **≈ 10 t = MASSE TOTALE SUSPENDUE (SWL)** : benne vide ≈ **4,5-5 t** + matière ≈ **5-5,5 t** — **ARBITRÉ le 2026-09-20** | **ESTIMÉE (décision humaine 2026-09-20)** (raisonnement physique : si les 10 t étaient la charge utile *seule*, la masse totale atteindrait 18-20 t ⇒ **208-231 kW** à 1 m/s, impossible avec ~110 kW ⇒ le treuil calerait) | décision humaine 2026-09-20 ; `PLAN_T300…md:13` |
| 7 | Vitesse câble (mémoire utilisateur) | **≈ 60-75 m/min** (l'utilisateur a dit « 60-75 m/s », **impossible** : cela ferait 216-270 km/h ⇒ à interpréter en **m/min**) | ORALE, **À CONFIRMER** | oral |
| 8 | Nombre de gradins rotoriques | **5 paliers dans le simulateur** (probablement **4 gradins réels**) | SYNTHÉTIQUE | code + `PLAN_T317…md:53` |
| 9 | Valeurs de résistance rotorique par gradin | **[3,6 ; 1,9 ; 0,9 ; 0,35 ; 0,0] Ω** | **SYNTHÉTIQUE** (aucune base coffret) | code |
| 10 | Couple max (décrochage) du moteur | **3800 Nm** | **SYNTHÉTIQUE** | code |
| 11 | Couple de charge « pleine charge » | **2500 Nm** | **SYNTHÉTIQUE** | code |
| 12 | Frottements résiduels « à vide » | **80 Nm** | **SYNTHÉTIQUE** | code |
| 13 | Inertie ramenée sur l'arbre moteur | **45 kg·m²** | **SYNTHÉTIQUE** | code |
| 14 | Glissement au couple max (rotor court-circuité) | **0,08 (8 %)** | **SYNTHÉTIQUE** | code |
| 15 | Résistance propre du rotor | **0,08 Ω** | **SYNTHÉTIQUE** | code |
| 16 | Plaque signalétique moteur (référence, tension stator **et rotor**, In exact, cosφ, rendement, vitesse nominale) | — | **INCONNUE** | `PLAN_T317…md:54` |
| 17 | Nombre réel de gradins + Ω par gradin du coffret | — | **INCONNUE** | `PLAN_T317…md:53` |
| 18 | Puissance du groupe électrogène (kVA) | — | **INCONNUE** | `PLAN_T317…md:55` |
| 19 | Rapport de réduction réel du réducteur | — | **INCONNUE** | vérifié : aucune constante dans le projet |
| 20 | Masse de la benne **VIDE** | — | **INCONNUE** | vérifié : absente de tout le projet |
| 21 | Ø tambour **mesuré** (et effet des couches de câble) | — | **INCONNUE** | déduit de la donnée #5 |

> 🚫 **AUCUNE VITESSE N'A JAMAIS ÉTÉ MESURÉE SUR CETTE MACHINE.**
> Le projet embarque une **fonction d'apprentissage** des vitesses réelles par palier (table `RETAIN` `[axe][sens][chargé/vide][palier]`), **mais l'apprentissage n'a jamais été lancé** — la table est vide. C'est précisément pour ça que le modèle est construit **en théorique** aujourd'hui : il sera **recalé plus tard**, en mise en service, avec les valeurs réellement mesurées.
> ⇒ **Conséquence pour toi** : il n'existe **aucune donnée terrain de vitesse**, ni de couple, ni de courant. Toutes les valeurs de ce document sont **théoriques, estimées ou synthétiques**. Ne suppose jamais qu'une mesure existe — et signale explicitement toute valeur qui **ne pourrait être confirmée que par une mesure**.

---

## 3. Ce que le simulateur calcule aujourd'hui (pour savoir où vont les valeurs)

Formules **exactes** utilisées par le code (à ne pas confondre avec la physique réelle — plusieurs termes manquent) :

```text
Couple asynchrone (Kloss) :   C(s) = 2·Cmax / ( s/gmax + gmax/s ) · (U/Un)²
   avec (U/Un)² = 1,0 en permanence (la tension est figée à 400 V dans le simulateur)

Glissement au couple max, par palier :
   gmax(palier) = gmax_base · (R2 + R_ext(palier)) / R2
   gmax_base = 0,08   R2 = 0,08 Ω   R_ext = [3,6 ; 1,9 ; 0,9 ; 0,35 ; 0,0] Ω

Dynamique mécanique :         ω ← ω + (C_moteur − C_résistant) / J · Δt      (Δt = 0,01 s, J = 45 kg·m²)

Couple résistant appliqué :   C_résistant = 80 Nm (frottement) + taux_charge × 2500 Nm (+ terme de couplage)
```

**Ce que le modèle ne fait PAS (confirmé par vérification de code)** — c'est justement là que tes valeurs servent :
- ❌ **aucun calcul de courant** (ni stator, ni rotor) → aucun pic de courant observable
- ❌ **aucun terme transitoire** de commutation de gradin (le pic de courant à la fermeture d'un contacteur de gradin n'existe pas)
- ❌ **aucun échauffement des résistances** (R constante, pas de R(T), pas d'image thermique I²t)
- ❌ **aucune inertie validée** (J = 45 posé à la main)
- ❌ **aucune chute de tension** du groupe électrogène (400 V figé)

---

## 3bis — Sources : rejetées et cibles autorisées *(verrouillé 2026-09-20)*

### ❌ Sources REJETÉES — ne pas citer, ne pas s'en servir
| Source | Pourquoi |
|---|---|
| **Firgelli** (`firgelliauto.com`) | Revendeur d'**actionneurs linéaires légers**, page de vulgarisation « How it works » → **hors sujet dragage / travaux publics**. Ne peut pas fonder un ratio tare/SWL |
| **Kinshofer KM 605U / DMS GS10050** | Bennes preneuses de pelle **~600 L / ~400 kg** → **hors échelle** pour un SWL de 10 t |
| **NEETS (US Navy) Module 05** | Cours généraliste d'électricité → **inadéquat** pour un coffret de résistances rotoriques industriel |
| Tout **contenu généré par IA** (rapport Gemini/ChatGPT) présenté comme « source » | Non vérifiable par construction |
| Tout lien `google.com/search?q=…` | **Une requête n'est pas une source** |
| « Normes … » **sans numéro ni éditeur** | Référence vide |

### ✅ Sources CIBLES autorisées (citer l'URL du **document**, jamais d'un moteur de recherche)
| Item | Cibles |
|---|---|
| **P1 — benne** | **Nemag** ([clamshell grab](https://www.nemag.com/products/clamshell-grab) · [Nemax](https://www.nemag.com/products/nemax-grab) · [comparateur](https://www.nemag.com/comparison-calculator)) · **Verstegen Grabs** (dragage / carrière) · **Negrini** |
| **P4 & P6 — gradins / décrochage** | **Schneider Cahier Technique n° 207** ([éduscol STI](https://eduscol.education.fr/sti/ressources_techniques/les-moteurs-electriques-cahier-technique-ndeg-207) · [PDF](http://posteselectriques.o.p.f.unblog.fr/files/2014/10/moteurs-electriques.pdf)) · **CEI 60947-4-1** · **Leonhard, *Control of Electrical Drives*** |
| **P2, P3, P5 — moteur** | **VEM** (séries SBRE/SBER) · **Leroy-Somer** (FLSES/LSMV) · **WEG W22** — catalogues de moteurs à bagues, **service levage S3/S4** |

### 🎯 Normalisation OBLIGATOIRE du ratio de benne
Deux normalisations circulent et **semblent** se contredire :
- **tare / charge utile** : 0,8-1,2 (vrac) → 1,2-1,5 (dragage dur)
- **tare / SWL** : 25-40 % (vrac) → 45-55 % (dragage lourd)

✅ Elles sont **cohérentes** (tare/utile = 1,0 ⟺ tare/SWL = 50 %).
⇒ **Toujours livrer les DEUX** : la **tare en kg** **ET** le **dénominateur du ratio** (« rapporté au SWL » ou « à la charge utile »). Jamais un ratio sans son dénominateur — c'est exactement l'ambiguïté qui a faussé le premier rapport.

---

## 4. Les 7 questions de recherche

Pour chaque item : **requêtes suggérées** (français **et** anglais/allemand — les catalogues constructeur sont souvent en EN/DE), **donnée attendue**, **ce que ça calibre** dans le simulateur.

### 🔴 P1 — Masse à vide d'une benne preneuse de capacité ~10 t
- **Pourquoi** : le simulateur ne compte que 80 Nm « à vide », ce qui ignore totalement le poids de la benne vide.
- **Requêtes** : `Nemag clamshell grab own weight kg SWL` · `Verstegen grab dredging tare weight` · `dredging grab empty weight to payload ratio` · `benne preneuse de dragage poids propre fiche technique`
- **Attendu** : **tare en kg** pour 2-3 modèles de **SWL ≈ 10 t**, en distinguant **vrac** vs **dragage lourd**, **ET** le **dénominateur du ratio** (rapporté au SWL **ou** à la charge utile — voir §3bis).
- **Rappel de contexte** : la masse totale suspendue de cette machine est de **10 t** (benne + matière) ⇒ tare attendue de l'ordre de **4,5-5 t**.
- **Calibre** : le terme « benne vide » du couple résistant.

### 🔴 P2 — Inertie rotor (J, kg·m²) d'un moteur ~110 kW, 4 pôles
- **Pourquoi** : J = 45 kg·m² est SYNTHÉTIQUE ; un ordre de grandeur a été trouvé (3-5 kg·m²) **mais il doit être sourcé**.
- **Requêtes** : `Leroy-Somer LSMV moment of inertia kgm2` · `WEG W22 110 kW 4 poles frame 315 J kgm2` · `VEM slip ring motor catalogue moment of inertia chapter 6` · `moteur 110 kW 1500 tr/min inertie rotor kg.m2 levage`
- **Attendu** : **J en kg·m²**, avec **puissance + nb de pôles + carcasse**. Une fourchette **+** le modèle constructeur cité vaut mieux qu'une valeur unique non sourcée.
- **Calibre** : `Inertie_KgM2 = 45` du simulateur.

### 🔴 P3 — Caractéristiques d'un moteur à rotor bobiné de levage
- **Requêtes** : `moteur asynchrone rotor bobiné couple de décrochage rapport couple nominal levage` · `wound rotor motor breakdown torque ratio hoist crane duty 2.5` · `rotor bobiné glissement nominal 3% tension rotor à l'arrêt E2` · `LSMV moteur de levage rotor bobiné caractéristiques`
- **Attendu** : ① **Cmax/Cnom** (couple de décrochage / couple nominal) ; ② **glissement nominal** ; ③ **tension rotor E2 à l'arrêt** typique ; ④ rapport **R2/X2** typique.
- **Calibre** : `MaxTorque_Nm`, `SlipAtMaxTorqueBase_Ratio`, `RotorResistanceOwn_Ohm`.

### 🟠 P4 — Nombre et valeurs des gradins d'un démarreur rotorique
- **Requêtes** : `démarreur rotorique nombre de gradins résistances démarrage étages` · `démarrage rhéostatique rotor bobiné rapport entre gradins` · `wound rotor starter resistance steps number typical`
- **Attendu** : **combien de gradins** typiquement pour un moteur de levage de cette taille, et le **rapport entre deux gradins successifs**. Signale si le rapport doit être **constant** (cas classique) ou peut varier.
- **Calibre** : `CST_RotorExtResistanceStep_Ohm = [3,6 ; 1,9 ; 0,9 ; 0,35 ; 0,0]` (**⚠️ indice : voir §6, contrainte C4**).

### 🟠 P5 — cosφ et rendement d'un moteur de levage 90-130 kW / 4 pôles
- **Requêtes** : `cos phi rendement moteur asynchrone 110 kW 4 pôles levage` · `hoist duty motor 110 kW 4 pole efficiency power factor` · `IE3 moteur 110 kW 1480 tr/min cos phi rendement`
- **Attendu** : **cosφ** et **η** à pleine charge, **avec** la puissance et la carcasse. Signale la dépendance à la charge (cosφ chute à faible charge).
- **Calibre** : la puissance estimée (hypothèses actuelles : cosφ = 0,85 et η = 0,90).

### ⭐ P6 — LA référence technique qui documente le décrochage par gradin — **priorité sécurité**
- **Pourquoi** : le projet a besoin d'une source qui **énonce la règle**, pas d'un chiffre. Le simulateur ne peut pas qualifier un délai minimal entre gradins, ce qui peut faire **accepter à tort** un enchaînement trop rapide.
- **Requêtes** : `enlèvement prématuré résistances rotoriques décrochage` · `rhéostatique démarrage gradin trop tôt couple décrochage` · `cahier technique Schneider démarrage rotorique gradins` · `rotor resistance short-circuiting too early pull-out torque collapse` · `wound rotor motor starting step too early stall current peak`
- **Attendu** : ① une **source normative ou technique reconnue** (Cahier Technique Schneider, Techniques de l'Ingénieur, manuel constructeur, norme) qui **décrit** : le **pic de courant** à la commutation de gradin, le **décrochage** si on retire un gradin trop tôt, **et** si possible une **règle** du type « ne pas passer le gradin avant que le glissement soit descendu sous X % ».
- **Calibre** : rien directement — **débloque la décision de sécurité de la tâche T317**.

### 🟠 P7 — Thermique / dérive en température des résistances rotoriques
- **Requêtes** : `résistance rotorique fonte grille coefficient de température dérive` · `rotor resistor bank cast iron grid temperature coefficient` · `résistance de démarrage régime de service S3 échauffement`
- **Attendu** : **matériau** usuel (fonte, alliage inox), **coefficient de température**, et **régime de service** admis.
- **Calibre** : un futur modèle R(T) + I²t (image thermique).

---

## 5. Les calculs à produire (avec formules — refais-les et montre l'arithmétique)

Constantes physiques : `g = 9,81 m/s²`. Unités SI (sauf mention m/min pour les vitesses câble).

| # | Grandeur | Formule | Notes |
|---|---|---|---|
| F1 | Vitesse synchrone | `ns = 120·f / p` | f = 50 Hz, p = nb de pôles ⇒ 1500 tr/min si p = 4 |
| F2 | Puissance apparente | `S = √3 · U · I` | en VA |
| F3 | Puissance mécanique | `P = S · cosφ · η` | cosφ et η **à sourcer (P5)** |
| F4 | Couple nominal moteur | `Cnom = P / (2π · n / 60)` | **donne n** (nominal plaque, pas la vitesse synchrone) |
| F5 | Rayon tambour | `r = développement_par_tour / (2π)` | développement = 2,0 m/tour ⇒ r ≈ 0,318 m |
| F6 | Couple au tambour | `T_tambour = m · g · r` | m = masse suspendue totale |
| F7 | Rapport de réduction | `i = n_moteur · développement_par_tour / (60 · v_câble)` | équivalent : `v_câble = développement · n_moteur / (60 · i)` |
| F8 | Couple moteur pour une charge | `T_moteur = T_tambour / i` | |
| F9 | Puissance de levage | `P_levage = m · g · v / η_total` | η_total = réducteur + treuil (**à appliquer vraiment**) |
| F10 | Vitesse max pour une puissance donnée | `v_max = P · η_total / (m · g)` | |
| F11 | Inertie de la charge ramenée | `J_charge = m · r² / i²` | |
| F12 | Couple Kloss à un glissement s | `C(s) = 2·Cmax / ( s/gmax + gmax/s )` | |
| F13 | Fenêtre de tenue d'un palier pour une charge L | résoudre `C(s) = L` ⇒ 2 solutions `s_min` (stable) et `s_max` (**décrochage au-delà**) | ex. `x + 1/x = 2·Cmax/L` avec `x = s/gmax` |
| F14 | Courant rotor à couple et glissement figés | `I2 ∝ 1/√(R2_total)` | ⚠️ ordre de grandeur seulement (ignore le transitoire) |

### 🧩 4 contraintes de cohérence à vérifier explicitement

- **C1** — `P_levage` pour la charge maxi doit être **compatible avec la puissance moteur (F3)**. Signale tout jeu de valeurs incompatible.
- **C2** — `T_moteur` pour la charge maxi doit être **≤ Cnom × (1,3 à 1,5)** (marge de couple normale en levage) ; au-delà, l'hypothèse de masse ou de réducteur est suspecte.
- **C3** — La **vitesse câble** doit rester **< vitesse synchrone / i** convertie : un moteur asynchrone ne peut pas dépasser sa vitesse synchrone **en levage**. Si une combinaison (vitesse, Ø tambour, i) l'exige, elle est **impossible** — dis-le.
- **C4** — **Rapport entre gradins successifs** (`R2+R_ext`) : calcule les 4 rapports successifs de la liste `[3,6 ; 1,9 ; 0,9 ; 0,35 ; 0,0]` (avec R2 = 0,08 Ω) et dis si la **non-uniformité du dernier rapport** est physiquement plausible pour un démarreur réel.

---

## 6. Résultats numériques actuels — **à croiser, pas à recopier**

Ces valeurs ont été calculées **par le projet**, sous les hypothèses indiquées. **Ton rôle est de les casser ou de les confirmer.**

| Résultat | Valeur | Hypothèses dont il dépend |
|---|---|---|
| S (400 V, 200 A) | 138,6 kVA | In = 200 A (ESTIMÉE), U = 400 V (non confirmée) |
| P à 400 V | 106 kW | **+ cosφ 0,85 et η 0,90 (non sourcés)** |
| Cnom à 400 V | **675-700 Nm** | + 1450 ou 1500 tr/min |
| S / P / Cnom à 690 V | 239 kVA / 183 kW / **1164-1204 Nm** | idem |
| Rayon / Ø tambour | 0,318 m / 0,637 m | développement 2,0 m/tour |
| T_tambour (10 t) | 31,2 kNm | 10 t = ESTIMATION |
| i = 48 | v = **1,01 m/s (60 m/min)**, T = 650 Nm, P = **99 kW** | Ø tambour + 1450 tr/min |
| i = 39 | v = 1,24 m/s (74 m/min), T = 800 Nm, P = **121 kW** | idem |
| i = 24 | v = 2,01 m/s (121 m/min), T = **1300 Nm**, P = **198 kW** | idem |
| v_max à 106 kW | 10 t → **1,08 m/s (65 m/min)** · 6 t → 1,80 (108) · 5 t → 2,16 (130) | η ≈ 1 (donc **vitesses réelles 5-15 % plus basses**) |
| gmax par palier | [3,68 ; 1,98 ; 0,98 ; 0,43 ; 0,08] | liste R_ext SYNTHÉTIQUE |
| Couple à l'arrêt (s=1) par palier | **[1923 ; 3058 ; 3799 ; 2758 ; 604] Nm** | Cmax = 3800 SYNTHÉTIQUE ⇒ **l'ordre relatif est robuste, les valeurs absolues non** |
| Palier au meilleur couple de démarrage | **palier 3** (gmax ≈ 1), pas le 1 | physique générale : couple max à l'arrêt quand gmax ≈ 1 |
| Fenêtre au palier 5 pour 2000 Nm | s ∈ [0,0228 ; 0,2812] ⇒ décrochage sous **1078 tr/min** | Cmax 3800 SYNTHÉTIQUE |
| Emballement après décrochage | −31 à −44 rad/s² (−296 à −424 tr/min/s) | J = 45 SYNTHÉTIQUE |
| Facteur courant rotor palier 1 → 5 | ×6,8 | `√(3,68/0,08)` ; suppose couple et glissement figés ⇒ **ordre de grandeur only** |

⚠️ **Alerte de fond** : `Cmax = 3800 Nm` correspond à **≈ 5,6 × Cnom** si le moteur fait ~675-700 Nm, alors qu'un rotor bobiné de levage a typiquement **Cmax/Cnom ≈ 2 à 2,5** ⇒ cette constante serait **~2,5 × trop grande**. À confirmer avec **P3**.

---

## 7. Format de sortie imposé

### Tableau A — Données sourcées (obligatoire)
| Item | Valeur | Unité | Conditions (puissance, pôles, tension, service) | Constructeur / modèle ou norme | URL | Type de source | Fiabilité |
|---|---|---|---|---|---|---|---|

`Type de source` : `catalogue constructeur` · `norme` · `ouvrage technique` · `cours universitaire` · `site revendeur` · **`inconnu/BLOG`** (= à écarter).

### Tableau B — Calculs (obligatoire)
| Calcul | Formule utilisée | Résultat | Contrainte C1-C4 vérifiée ? | Confirme / infirme la valeur du §6 |
|---|---|---|---|---|

### Fiches P1 → P7
Pour chaque item : `TROUVÉ` / `PARTIELLEMENT TROUVÉ` / **`INTROUVABLE`** + la valeur + l'URL + **ce qui manque pour conclure**.

### Verdict final (5 lignes max)
1. Quelle(s) combinaison(s) `{tension, puissance, i, vitesse}` sont **cohérentes** ?
2. Quelle valeur de **Cnom** et donc de **Cmax** retenir ?
3. Le point de mesure **400 → 360 V** est-il cohérent avec la puissance estimée ? (le groupe peut-il fournir l'appel de courant ?)
4. Quel **rapport poids benne vide / charge utile** retenir ?
5. Les 3 inconnues que **seule la machine** peut donner (et qu'aucune recherche ne résoudra).

---

## 8. Règles de preuve — non négociables

1. **Sources primaires d'abord** : catalogue constructeur, norme, ouvrage technique. **Refuse** les blogs, forums et contenus générés par IA comme preuve.
2. **Jamais de valeur sans unité + conditions.** « 110 kW » ne suffit pas : il faut pôles, tension, carcasse, type de service.
3. **Distingue** explicitement : *valeur constructeur mesurée* / *plage de catalogue* / *règle de l'art* / *ton estimation*.
4. **Si tu ne trouves pas** : écris **`INTROUVABLE`**. Ne comble **jamais** un trou par extrapolation silencieuse. Une extrapolation assumée est acceptable **si elle est étiquetée**.
5. **Cite l'URL exacte** de la page (pas la page d'accueil du site) et, si possible, la **section / le tableau**.
6. Une valeur **contradictoire** entre deux sources est une **information utile** : donne les deux et signale le conflit.

## 9. Hors périmètre — ne pas chercher

❌ La plaque signalétique du moteur **de cette machine** · ❌ le nombre de gradins **de ce coffret** · ❌ le **Ø tambour mesuré** · ❌ le **rapport de réduction de ce réducteur** · ❌ la **masse réelle de cette benne**.
Ces données n'existent que sur la machine. **Internet ne peut donner que des ordres de grandeur** — c'est explicitement ce qui est demandé, et c'est suffisant.

## 10. Priorités et budget d'effort

| Priorité | Items | Attendu |
|---|---|---|
| 🥇 Indispensable | **P1** (benne vide), **P2** (inertie), **P3** (Cmax/Cnom) | 1 valeur sourcée chacune minimum |
| 🥈 Important | **P6** (référence décrochage gradin), **P5** (cosφ/η) | 1 source technique reconnue + 1 fourchette |
| 🥉 Utile | **P4** (gradins), **P7** (thermique) | ordres de grandeur + règle de l'art |

**Restitution attendue : courte et dense.** Tableaux > prose. Emojis comme repères. En **français**.
Si une information est incertaine, **dis-le** — une réponse honnête « introuvable » vaut mieux qu'un chiffre inventé.
