# 📘 T317 — Référence du prototype Python (pour portage futur en ST)

📌 **But de ce document** : décrire chaque fonction/calcul du prototype `sim_treuil_electrique.py`
+ `sim_treuil_gui.py`, pour qu'un futur portage en ST (CODESYS) sache quoi reprendre, avec quelles
formules et quelles limites. Ce n'est **pas** un contrat de tâche (voir
[TASK_CONTRACT_T317](TASK_CONTRACT_T317_SIMBENCH_TREUIL_ELECTRIQUE.yaml)) ni le plan P0
(voir [PLAN_T317](PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md)) — c'est la doc technique des calculs.

⚠️ **Statut** : prototype exploratoire hors CODESYS, tous les paramètres numériques sont
**SYNTHÉTIQUES** (non mesurés terrain). Rien ici n'est prêt à copier tel quel en ST — c'est la
logique et les formules qui sont réutilisables, pas les valeurs.

📂 Fichiers source : `TOOLS/AGENT_WORKFLOW/prototypes/sim_treuil_electrique.py` (moteur de calcul)
et `sim_treuil_gui.py` (interface Tkinter, non portable en CODESYS — sert juste à tester en Python).

---

## 🎯 Ce que fait l'outil en une phrase

Simule un treuil (moteur asynchrone à rotor bobiné + cascade de résistances rotoriques + groupe
électrogène) pour répondre à la question **"cette séquence de commande gradins, à telle charge,
va-t-elle caler le moteur / déclencher une protection / abîmer le matériel ?"** — utile en
debug/mise en service avant de tester sur la vraie machine.

---

## 🧩 Les briques de calcul (1 par phénomène physique)

### 1️⃣ Couple moteur — formule de Kloss

```
C(g) = 2·Cmax / (g/gmax + gmax/g)
```
- `g` = glissement = `1 - N/Ns` (Ns = vitesse synchrone)
- `gmax` = glissement au couple max, **dépend du gradin** : `gmax(gradin) = gmax0 × R2_total/R2_rotor`
- Plus de résistance rotorique ajoutée → `gmax` plus grand → plus de couple au démarrage, **Cmax ne change pas**
- 🔧 Fonction : `MotorParams.gmax()` + inline dans `WinchInstance.step()`
- ⚠️ Limite connue : formule valable loin de la saturation magnétique, résistance stator R1 négligée
  (correct si R1≪X1+X2, à vérifier avec la plaque signalétique réelle)

### 2️⃣ Couplage avec la tension réseau

```
C_motor_reel = C(g) × (U_reseau / U_nominal)²
```
- Le couple chute avec le carré de la tension → si le groupe électrogène s'effondre, le moteur perd
  du couple **en plus** de perdre en tension directement
- 🔧 Appliqué directement dans `WinchInstance.step()`, ligne du calcul `C_motor`

### 3️⃣ Dynamique mécanique (accélération/décélération)

```
dN/dt = (C_motor - C_resistant) / J_total
```
- Intégration simple (Euler explicite), pas de temps `dt` fixe (0.01s par défaut)
- `C_resistant` = couple de charge, dépend du `load_frac` (0=à vide, 1=pleine charge)
- 🔧 Fonction : `WinchInstance.couple_resistant()` + intégration dans `step()`

### 4️⃣ Courant stator — composition en quadrature (🆕 corrigé 2026-09-18)

```
I0 = I0_pu × In_stator                      (courant magnétisant, constant, ~35% In pour moteur lent)
I_actif = (C_motor / C_nominal) × sqrt(In²-I0²)   (proportionnel au COUPLE développé, pas au load_frac)
I1 = sqrt(I0² + I_actif²)                    (Pythagore vectoriel, PAS une addition simple)
```
- ⚠️ **Piège évité** : ne jamais faire `I1 = I0 + I_actif` (addition directe) — ça surestime le
  courant à faible charge. Le courant magnétisant est **réactif** (déphasé 90°), il se compose en
  quadrature avec le courant actif, pas en somme algébrique.
- 📐 Calage : à `C_motor = C_nominal`, `I1 = In_stator` exactement (garantit que le paramètre
  "courant nominal" affiché dans l'IHM signifie vraiment quelque chose)
- 🔧 Fonction : `MotorParams.courant_stator(C_motor)`
- Source recherche : décomposition Fresnel/cercle de Heyland, cours électrotechnique standard

### 5️⃣ Tension groupe électrogène — réponse à l'appel de courant

```
Xpp_ohm = Xpp_pu × U_nom / I_nom_groupe        (réactance subtransitoire en ohms)
U_instantané = U_nom - Xpp_ohm × I_total       (I_total = somme courants tous treuils + charge de base)
U_reseau += (U_instantané - U_reseau) × dt/Tavr   (relaxation AVR premier ordre, Tavr~0.4s)
```
- 🔧 Fonction : `simulate_multi()`, boucle principale
- ⚠️ Limite connue (challenge expert 2026-09-18) : premier ordre seulement → **sous-estime** les
  oscillations si plusieurs appels de courant se chevauchent (2 treuils qui démarrent presque en
  même temps). Pas de second ordre implémenté.
- 📚 Source : X"d/X'd/Tavr typiques catalogue alternateurs industriels, norme ISO 8528-5

### 5️⃣bis Mode bidirectionnel + génératrice (🆕 2026-09-18)

```
N stocke en repere de commande (N_rel = N_physique × direction, direction=+1 montee/-1 descente)
g = 1 - N_rel/Ns          (formule INCHANGEE -- Kloss est impaire en g, gere le freinage seul)
Cr = C_frottements + direction × load_frac × C_nominal_charge
     (montee : Cr>0 gravite s'oppose ; descente : Cr peut devenir negatif = gravite aide,
      le moteur doit alors freiner -- regime genarateur automatique, aucun code special)
N_rpm affiche = N_rel × direction × 60/(2π)   (signe = sens physique reel)
```
- 🔧 Fonction : `WinchInstance.couple_resistant()`, `step()`, `_safe_g()`
- ⚠️ Piège évité : `g_eff = max(g, 1e-4)` écrasait le signe de g négatif (survitesse) → `_safe_g()`
  préserve le signe, indispensable pour que le freinage électrique se calcule correctement
- Pas de clamp `N ≥ 0` : le moteur peut reculer physiquement (glissement arrière sous charge trop
  lourde) ou dépasser le synchronisme (freinage génératrice) — les deux sont réalistes

### 5️⃣ter Transitoire de commutation de gradin (🆕 2026-09-18 — demande explicite)

```
tau_rotor(gradin) = (X2 / (2π·f_nom)) / R2_total(gradin)     (L2/R2, decroit avec la resistance)
A la bascule i->j au glissement g courant :
  saut = |I1(g, gradin=j) - I1(g, gradin=i)|   (calcule via courant_stator, meme instant)
  I_transitoire += k_inrush × saut              (k_inrush=1.0 par defaut, HYPOTHESE si >1)
Chaque pas : I_transitoire *= exp(-dt / tau_rotor(gradin_actif))
I1_brut = I1_quasi_statique + I_transitoire     (NON lisse par Tau_elec -- c'est le pic reel)
```
- 🔧 Fonctions : `MotorParams.tau_rotor()`, `_couple_kloss()`, bloc "Detection de commutation" dans `step()`
- Répond au risque terrain : "enchaîner trop vite les gradins = surintensité". `w.commutations`
  liste `(t, saut, pic_estimé)` par bascule, affiché dans `print_summary()`
- ⚠️ Modélise le pic de **courant** (circuit rotorique L2/R2), pas encore le pic de **couple**
  mécanique (pulsation électromagnétique transitoire) — le choc réducteur reste donc probablement
  sous-estimé, avertissement conservé dans `print_summary()`

### 6️⃣ Détection décrochage (calage moteur)

```
Test predictif au gradin courant : couple a glissement bloque (g=1) < couple resistant ?
C_locked_rotor = C(g=1, gradin_actuel) × (U/U_nom)²
Si N < 3 rad/s ET C_locked_rotor < C_resistant → decrochage
```
- ⚠️ **Ce n'est pas une mesure d'arrêt réel** — c'est une prédiction "ce gradin peut-il, à l'arrêt,
  développer plus que la charge ?". Reste correct tant que N est proche de 0.
- 🆕 Deux flags séparés : `stalled` (état instantané, peut se relever) et `ever_stalled` (jamais
  réinitialisé, sert au verdict final — corrige un bug où un décrochage transitoire suivi d'un
  rattrapage était rapporté "OK" à tort)
- 🔧 Fonction : `WinchInstance.step()`, bloc "Test predictif"

### 7️⃣ Protection thermique relais — image I²t

```
theta_cible = (I/Ith_reglage)²
theta += (theta_cible - theta) × dt/tau        (tau dérivé de la classe 10/20/30, IEC 60947-4-1)
Déclenchement si theta >= 1.0
```
- 🔧 Classe : `ThermalRelayParams` + `ThermalImage`
- 📚 Norme : IEC 60947-4-1 (temps de déclenchement à 7,2×In selon classe)

### 8️⃣ Vieillissement isolant bobinage — loi de Montsinger

```
theta_bobinage_cible = theta_ambiante + delta_theta_nominal × (I/In)²
theta_bobinage += (theta_cible - theta_bobinage) × dt/tau_th_winding   (tau ~1200s, 20min)

F_AA = 2^((theta_bobinage - theta_nominale) / delta_T_montsinger)   (facteur accélération, delta_T~10°C)
vieillissement_cumulé += F_AA × dt/3600   (en heures-équivalentes classe consommées)
```
- 🆕 Ce n'est **pas** juste trip/no-trip comme la protection relais — c'est un **compteur cumulatif**
  qui progresse même sous le seuil de déclenchement (usure qui s'accumule à bas bruit)
- 🔧 Classe : `InsulationParams` + `WindingThermalAging`
- 📚 Normes : IEC 60034-1 (classes B=130°C/F=155°C/H=180°C), IEC 60085, IEEE 1-2000

### 9️⃣ Choc mécanique réducteur — facteur de service + jerk

```
ratio = |C_motor| / C_nominal_reducteur
jerk = (C_motor(t) - C_motor(t-dt)) / dt
Si ratio > SF_choc_admissible (2.5x defaut) → choc detecte
Si en plus |jerk| > seuil → choc SEVERE
```
- 🔧 Classe : `GearboxParams` + `GearboxShockDetector`
- 📚 Source : AGMA 6011, ISO 6336, FEM 9.511/9.751 (catégorie levage = choc sévère, 2.5-3× admissible)
- ⚠️⚠️ **LIMITE MAJEURE non résolue** : `C_motor` utilisé ici est la valeur **quasi-statique** de
  Kloss, sans terme transitoire électromagnétique de commutation. Le vrai pic de couple/courant à
  la bascule d'un gradin (constante L2/R2, flux rémanent) n'est **pas modélisé** → ce détecteur
  **sous-estime probablement** un vrai choc. Un avertissement est affiché dans `print_summary()`
  à chaque exécution pour rappeler cette limite — **ne pas le retirer lors d'un futur portage**
  tant que le terme transitoire n'est pas ajouté.

---

## 🖥️ Interface graphique — ce qui existe

| Mode | Ce qu'il fait |
|---|---|
| Un treuil | 1 moteur, charge + séquence de gradins réglables |
| Comparaison charge/à vide | Lance 2 simulations (même séquence gradins), superpose sur le même graphe |
| Deux treuils simultanés | 2 moteurs partageant le même groupe électrogène (teste la coïncidence de charge) |
| Rejeu d'incident | Charge un JSON décrivant une séquence terrain observée, **le JSON fait foi** (les champs avancés du GUI sont grisés/ignorés dans ce mode) |

Bloc "caractéristiques techniques" : Cmax, In stator, inertie J, tension/courant nominal groupe
électrogène, seuil de choc réducteur — modifiables sans toucher au code.

---

## 🚧 Ce qui N'EST PAS dans le prototype (à ajouter si besoin avant portage ST)

- ❌ Terme transitoire électromagnétique de commutation de gradin (limite #9 ci-dessus)
- ❌ Second ordre pour le groupe électrogène (oscillations si appels rapprochés)
- ❌ Mode génératrice/descente (freinage électrique, R1 stator négligée — problématique dans ce quadrant)
- ❌ Référentiel R2/X2 stator vs rotor non tracé explicitement (à vérifier avant tout calage terrain)

---

## 🔜 Pour porter en ST (CODESYS)

1. **Ne pas copier les valeurs numériques** — elles sont SYNTHÉTIQUES, à recaler avec la plaque
   signalétique réelle moteur + fiche groupe électrogène (registre P0 dans le plan T317)
2. **Les formules 1️⃣ à 9️⃣ ci-dessus sont portables telles quelles** (arithmétique simple, pas de
   bibliothèque Python spécifique — `math.sqrt`, `math.log`, opérations de base)
3. **Respecter le pas de temps de la tâche CODESYS** (10ms selon `AF_Partie-02`) — le prototype
   utilise 10ms par défaut, cohérent
4. **Décision à prendre avant codage** : ce module doit-il vivre dans `FB_SimBench` (simulation
   uniquement) ou devenir un vrai outil de diagnostic embarqué utilisable avec des capteurs réels
   (courant/tension mesurés) ? Change complètement l'architecture cible — objet du registre
   Q4 du plan T317 (portée sécurité vs macro).
5. Ne pas retirer les avertissements de limite (transitoire commutation, second ordre GE) — ce
   sont des garde-fous contre la fausse confiance, pas de la prose superflue.
