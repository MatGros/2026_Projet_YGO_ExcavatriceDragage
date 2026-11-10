## 1. Loi de décélération / roulis inertiel des treuils

### 1.1 Principe physique retenu

À la coupure des contacteurs, il faut distinguer deux grandeurs :

- la **vitesse réelle au moment exact de la coupure** : \(v_0\) signée ;
- le **roulis total** à parcourir : \(D(v_0)\), dépendant du sens et de \(|v_0|\).

Les mesures montrent que le roulis n’est pas une simple temporisation à vitesse lente, mais un profil du type :

1. maintien quasi inertiel pendant une fraction du temps ;
2. décélération jusqu’à arrêt.

Un modèle très simple et cohérent avec les mesures est :

\[
D_{\text{roulis}} = K_{\text{dir}} \cdot |v_0|^{n_{\text{dir}}}
\]

avec :

- Montée positive :
  \[
  K_{\text{up}} \approx 0.449,\quad n_{\text{up}} \approx 1.445
  \]
  Cela donne :
  - \(v_0=1.14 \Rightarrow D \approx 0.543\,m\)
  - \(v_0=0.12 \Rightarrow D \approx 0.021\,m\)

- Descente négative :
  \[
  K_{\text{down}} \approx 0.671,\quad n_{\text{down}} \approx 1.445
  \]
  si l’on suppose la même forme de loi. Cela donne à \(1.50\,m/s\) environ \(1.205\,m\).
  À faible vitesse, il faudra valider par mesure ; si la gravité entraîne fortement le grappin même à basse vitesse, utiliser plutôt une interpolation en table ou un exposant plus faible.

Pour le profil temporel, les mesures sont cohérentes avec un coefficient :

\[
Q = \frac{D}{|v_0| \cdot T_{\text{roulis}}} \approx 0.73 \text{ à } 0.76
\]

On peut prendre \(Q \approx 0.74\). Alors :

\[
T_{\text{roulis}} = \frac{D}{Q |v_0|}
\]

\[
T_{\text{maintien}} = (2Q-1)T_{\text{roulis}} \approx 0.48T_{\text{roulis}}
\]

\[
T_{\text{decel}} = 2(1-Q)T_{\text{roulis}} \approx 0.52T_{\text{roulis}}
\]

Pendant \[0, T_{\text{maintien}}\], la vitesse reste proche de \(v_0\). Ensuite, décélération linéaire jusqu’à zéro. Cela reproduit correctement :
- la montée : arrêt assez court ;
- la descente : roulis plus long ;
- le jog : roulis faible, proportionnel à une puissance de la vitesse.

### 1.2 Où implémenter le calcul ?

**Ne pas piloter une distance fixe depuis `FB_SimBench` à chaque front.**

Le calcul doit être fait au plus près de l’axe, c’est-à-dire :

- soit directement dans `FB_Sim_Encoder` s’il conserve son rôle d’intégrateur mécanique ;
- soit, architecture plus propre, dans un `FB_SimAxisDynamics` dédié, et `FB_SimEncoder` ne fait plus que le comptage d’impulsions.

Recommandation :

- `FB_SimBench` doit fournir les **paramètres physiques** : \(K_{\text{up}}\), \(n_{\text{up}}\), \(K_{\text{down}}\), \(n_{\text{down}}\), \(Q\), butées, constante codeur.
- L’axe calcule \(D\) et le profil au moment exact où la commande tombe, avec la vitesse courante et le sens courant.

L’actuel `SimWinchCoast_M = 1.30 m` sur M1 et M2 doit être supprimé. Le \(1.30\,m\) appartient à la **cinématique de benne**, pas au roulis commun des deux treuils de levage.

---

## 2. Gestion de l’anticipation de la benne

### 2.1 Décomposition en deux degrés de liberté

Le problème vient du fait que M1 et M2 ne doivent pas recevoir tous les deux un roulis de \(1.30\,m\). Il faut séparer :

- un **mode commun de levage** :
  \[
  z = \frac{M_1 + M_2}{2}
  \]
  C’est lui qui subit le roulis de montée/descente dû à la charge et à la gravité.

- un **mode différentiel de benne** :
  \[
  s = M_2 - M_1
  \]
  C’est lui qui représente l’ouverture/fermeture de la benne. C’est sur cet axe que l’on applique :
  - la dynamique d’ouverture/fermeture ;
  - la butée ouverte \(s=0.0\) ;
  - l’anticipation de \(1.30\,m\) à pleine vitesse d’ouverture.

Reconstruction :

\[
M_1 = z - \frac{s}{2} + \text{offset}_1
\]

\[
M_2 = z + \frac{s}{2} + \text{offset}_2
\]

Ainsi :
- un arrêt en montée fait rouler \(z\), donc M1 et M2 montent ensemble : physiquement correct ;
- une ouverture de benne fait évoluer \(s\), donc M2-M1, sans créer artificiellement une montée globale de \(1.30\,m\).

### 2.2 Anticipation automatique et mode manuel

Le modèle physique ne doit jamais connaître l’étape AX15B.

Architecture recommandée :

```text
Commande joystick manuel ─┐
                          ├──> MUX mode ──> commandes communes CmdHoist, CmdOpen, CmdClose
Commande cycle auto ──────┘
                                      │
                                      ├──> FB_SimAxisDynamics axe Z commun
                                      ├──> FB_SimAxisDynamics axe S benne
                                      └──> reconstruction M1, M2
```

L’étape AX15B peut calculer une anticipation, mais elle doit utiliser la même fonction \(D_{\text{benne}}(v)\) que le modèle physique :

```text
D_open = K_open * |v_open|^n_open
si s_benne <= D_open alors couper CmdOpen
```

À pleine vitesse d’ouverture, on calibre pour obtenir \(D_{\text{open}} \approx 1.30\,m\). À vitesse plus faible, l’anticipation diminue automatiquement.

Aucune condition du type :

```text
IF step = AX15B THEN SimWinchCoast_M := 1.30;
```

ne doit exister dans le modèle. La différence manuel/auto doit être uniquement en amont, dans la génération des commandes.

---

## 3. Cas limites et robustesse

### 3.1 Réenclenchement pendant le roulis

Si l’opérateur redonne une commande pendant le roulis :

- ne pas réinitialiser brutalement la vitesse ;
- conserver la vitesse courante \(v\) ;
- quitter l’état `COAST` ;
- repasser en `DRIVE` ;
- ramper vers la nouvelle consigne avec accélération/décélération limitées.

Ainsi, un réenclenchement dans le même sens reprend souplement. Un réenclenchement en sens inverse freine d’abord, passe par zéro, puis accélère dans l’autre sens. Il ne doit jamais y avoir de saut \(+v \rightarrow -v\).

### 3.2 Inversion de commande

Utiliser une seule variable de vitesse signée \(v\) et une rampe :

```text
si v < v_cmd alors v := MIN(v + a_acc*dt, v_cmd)
sinon si v > v_cmd alors v := MAX(v - a_dec*dt, v_cmd)
```

Le passage par zéro est naturel et sans discontinuité.

### 3.3 Butées mécaniques

Pour la benne :

- si \(s \le 0.0\) : forcer \(s=0.0\), \(v=0\), état `IDLE` ;
- anti-rebond : ne pas inverser automatiquement la vitesse à la butée ;
- autoriser une commande opposée à partir de la butée, avec rampe normale.

### 3.4 Cohérence de la vitesse mesurée

- Une seule source de vitesse doit être utilisée pour l’intégration : l’état interne de l’axe.
- La vitesse affichée/calculée depuis les impulsions peut être filtrée, mais le filtre ne doit pas servir à l’intégration.
- Utiliser un accumulateur réel d’impulsions pour éviter la dérive de quantification.
- Arrêter l’axe sous un seuil :
  \[
  |v| < V_{\min} \Rightarrow v=0
  \]
- Ne pas utiliser `MinSpeedMps` pour faire avancer le roulis jusqu’à épuisement d’un nombre de points : c’est ce qui rend le mouvement non physique.

---

## 4. Proposition d’implémentation ST

### 4.1 Schéma algorithmique de l’axe

```text
État IDLE
  └─ commande active ─> DRIVE

État DRIVE
  ├─ rampe vitesse vers consigne
  ├─ commande coupée et |v| > seuil :
  │     capturer v0
  │     calculer D_roulis selon sens et |v0|
  │     calculer T_roulis, T_maintien, T_decel
  │     └─> COAST
  └─ commande maintenue : rester DRIVE

État COAST
  ├─ commande réapparaît : retour DRIVE sans saut de vitesse
  ├─ pendant T_maintien : v = v0
  ├─ pendant T_decel : décélération linéaire vers zéro
  └─ fin : v=0, IDLE
```

### 4.2 Exemple de bloc `FB_Sim_Encoder` avec loi de roulis intégrée

Ce squelette remplace la logique actuelle `CoastPtsLeft` à vitesse `MinSpeedMps`.

```iecst
FUNCTION_BLOCK FB_Sim_Encoder
VAR_INPUT
    RelayFwd      : BOOL;
    RelayRev      : BOOL;

    SpeedCmdMps   : REAL := 1.14;   // magnitude du palier actif
    AccelMps2     : REAL := 1.0;
    DecelMps2     : REAL := 1.0;
    DeltaTimeS    : REAL := 0.01;

    // Loi de roulis
    CoastKUp      : REAL := 0.449;
    CoastNUp      : REAL := 1.445;
    CoastKDown    : REAL := 0.671;  // à recalibrer si mesures basse vitesse descente
    CoastNDown    : REAL := 1.445;  // ou 1.0 selon essais
    CoastQ        : REAL := 0.74;   // D / (|v0| * T)

    VMinMps       : REAL := 0.005;
    CoastMaxM     : REAL := 10.0;

    PosMinM       : REAL := -1.0E6;
    PosMaxM       : REAL :=  1.0E6;

    PointsPerRev  : REAL := 1000.0;
    CableMPerRev  : REAL := 1.0;
END_VAR

VAR_OUTPUT
    PositionM     : REAL;
    SpeedMps      : REAL;
    PulseCount    : DINT;
    Coasting      : BOOL;
END_VAR

VAR
    state         : INT := 0;    // 0=IDLE, 1=DRIVE, 2=COAST
    cmd           : INT;
    v             : REAL;
    pos           : REAL;
    pulseAcc      : REAL;

    vCmd          : REAL;
    v0            : REAL;

    Dcoast        : REAL;
    Tcoast        : REAL;
    Thold         : REAL;
    Tdec          : REAL;
    tCoast        : REAL;
END_VAR

VAR CONSTANT
    ST_IDLE  : INT := 0;
    ST_DRIVE : INT := 1;
    ST_COAST : INT := 2;
END_VAR

// ------------------------------------------------------------
// Décodage des commandes
// ------------------------------------------------------------
cmd := 0;
IF RelayFwd AND NOT RelayRev THEN
    cmd := 1;
ELSIF RelayRev AND NOT RelayFwd THEN
    cmd := -1;
END_IF

// ------------------------------------------------------------
// Machine d'états
// ------------------------------------------------------------
CASE state OF

ST_IDLE:
    v := 0.0;
    IF cmd <> 0 THEN
        state := ST_DRIVE;
    END_IF

ST_DRIVE:
    vCmd := DINT_TO_REAL(cmd) * SpeedCmdMps;

    // Rampe signée : gère aussi le passage par zéro sans saut
    IF v < vCmd THEN
        v := MIN(v + AccelMps2 * DeltaTimeS, vCmd);
    ELSIF v > vCmd THEN
        v := MAX(v - DecelMps2 * DeltaTimeS, vCmd);
    END_IF

    // Coupure de commande
    IF cmd = 0 THEN
        IF ABS(v) > VMinMps THEN
            v0 := v;

            // Roulis selon sens réel de déplacement
            IF v0 > 0.0 THEN
                Dcoast := CoastKUp * EXPT(ABS(v0), CoastNUp);
            ELSE
                Dcoast := CoastKDown * EXPT(ABS(v0), CoastNDown);
            END_IF

            Dcoast := MIN(Dcoast, CoastMaxM);

            IF Dcoast > 0.0001 THEN
                Tcoast := Dcoast / (CoastQ * ABS(v0));

                Thold := (2.0 * CoastQ - 1.0) * Tcoast;
                IF Thold < 0.0 THEN
                    Thold := 0.0;
                END_IF

                Tdec := 2.0 * (1.0 - CoastQ) * Tcoast;
                IF Tdec < DeltaTimeS THEN
                    Tdec := DeltaTimeS;
                END_IF

                tCoast := 0.0;
                state := ST_COAST;
            ELSE
                v := 0.0;
                state := ST_IDLE;
            END_IF
        ELSE
            v := 0.0;
            state := ST_IDLE;
        END_IF
    END_IF

ST_COAST:
    // Réenclenchement pendant le roulis : reprise sans saut
    IF cmd <> 0 THEN
        state := ST_DRIVE;
    ELSE
        tCoast := tCoast + DeltaTimeS;

        IF tCoast <= Thold THEN
            v := v0;
        ELSIF tCoast <= (Thold + Tdec) THEN
            v := v0 * (1.0 - (tCoast - Thold) / Tdec);
        ELSE
            v := 0.0;
            state := ST_IDLE;
        END_IF
    END_IF

END_CASE

// ------------------------------------------------------------
// Intégration position et butées
// ------------------------------------------------------------
pos := pos + v * DeltaTimeS;

IF pos <= PosMinM THEN
    pos := PosMinM;
    IF v < 0.0 THEN
        v := 0.0;
    END_IF
    IF state = ST_COAST THEN
        state := ST_IDLE;
    END_IF

ELSIF pos >= PosMaxM THEN
    pos := PosMaxM;
    IF v > 0.0 THEN
        v := 0.0;
    END_IF
    IF state = ST_COAST THEN
        state := ST_IDLE;
    END_IF
END_IF

// ------------------------------------------------------------
// Conversion position -> impulsions codeur
// Accumulateur réel pour éviter la dérive de quantification
// ------------------------------------------------------------
pulseAcc := pulseAcc + v * DeltaTimeS / CableMPerRev * PointsPerRev;
PulseCount := REAL_TO_DINT(pulseAcc);

PositionM  := pos;
SpeedMps   := v;
Coasting   := (state = ST_COAST);
```

Remarque : selon la convention du codeur, utiliser `ROUND` ou `TRUNC` et adapter le signe. L’important est de conserver un accumulateur réel.

### 4.3 Assemblage recommandé dans `FB_SimBench`

L’architecture la plus propre est :

```iecst
FUNCTION_BLOCK FB_SimBench
VAR
    // Axe commun de levage z = (M1+M2)/2
    fbHoistCommon : FB_Sim_Encoder;

    // Axe différentiel de benne s = M2-M1
    fbBucketDiff  : FB_Sim_Encoder;

    // Commandes finales sélectionnées manuel/auto
    cmdHoistUp    : BOOL;
    cmdHoistDown  : BOOL;
    cmdOpen       : BOOL;
    cmdClose      : BOOL;

    zCommonM      : REAL;
    sBucketM      : REAL;

    M1M           : REAL;
    M2M           : REAL;

    OffsetM1      : REAL := 0.0;
    OffsetM2      : REAL := 0.0;

    fDeltaTime    : REAL := 0.01;
END_VAR
```

Sélection unique des commandes avant toute physique :

```iecst
// Exemple de MUX : aucun AX15B dans les modèles physiques
IF bAuto THEN
    cmdHoistUp   := autoHoistUp;
    cmdHoistDown := autoHoistDown;
    cmdOpen      := autoOpen;
    cmdClose     := autoClose;
    // L'anticipation auto doit être calculée en amont avec la même loi D(v)
ELSIF bManual THEN
    cmdHoistUp   := joyHoistUp;
    cmdHoistDown := joyHoistDown;
    cmdOpen      := joyOpen;
    cmdClose     := joyClose;
END_IF
```

Puis :

```iecst
// Axe commun de levage
fbHoistCommon(
    RelayFwd      := cmdHoistUp,
    RelayRev      := cmdHoistDown,
    SpeedCmdMps   := vHoistCmd,
    AccelMps2     := aHoistAcc,
    DecelMps2     := aHoistDec,
    DeltaTimeS    := fDeltaTime,
    CoastKUp      := KHoistUp,
    CoastNUp      := NHoistUp,
    CoastKDown    := KHoistDown,
    CoastNDown    := NHoistDown,
    CoastQ        := QHoist,
    PosMinM       := -100.0,
    PosMaxM       :=  100.0
);

// Axe différentiel de benne
fbBucketDiff(
    RelayFwd      := cmdOpen,       // signe à adapter selon convention
    RelayRev      := cmdClose,
    SpeedCmdMps   := vBucketCmd,
    AccelMps2     := aBucketAcc,
    DecelMps2     := aBucketDec,
    DeltaTimeS    := fDeltaTime,
    CoastKUp      := KBucketOpen,
    CoastNUp      := NBucketOpen,
    CoastKDown    := KBucketClose,
    CoastNDown    := NBucketClose,
    CoastQ        := QBucket,
    PosMinM       := 0.0,           // butée ouverte
    PosMaxM       := sBucketClosedMax
);

zCommonM := fbHoistCommon.PositionM;
sBucketM := fbBucketDiff.PositionM;

// Reconstruction M1 / M2 selon la cinématique réelle
// Ici hypothèse s = M2 - M1
M1M := zCommonM - sBucketM / 2.0 + OffsetM1;
M2M := zCommonM + sBucketM / 2.0 + OffsetM2;
```

Ensuite, deux cas :

- si `FB_Sim_Encoder` ne fait que le comptage, lui fournir `M1M` et `M2M` comme position mécanique ;
- si l’on conserve `instSimEncoderM1/M2` comme intégrateurs, ne pas leur injecter un `CoastDistanceM=1.30` commun. Les faire piloter par les positions reconstruites `M1M` et `M2M`, ou migrer vers l’architecture axe commun + axe benne.

---

## 5. Synthèse des choix recommandés

1. **Remplacer le roulis à distance fixe par une loi dépendante de la vitesse et du sens** :
   \[
   D=K_{\text{dir}}|v_0|^{n_{\text{dir}}}
   \]

2. **Utiliser un profil maintien + décélération linéaire**, avec \(Q\approx 0.74\), pour respecter à la fois la distance et le temps mesurés.

3. **Supprimer `SimWinchCoast_M = 1.30 m` sur M1/M2.** Le \(1.30\,m\) est une propriété de l’axe différentiel de benne, pas du levage commun.

4. **Décomposer en axe commun \(z=(M1+M2)/2\) et axe benne \(s=M2-M1\)**, puis reconstruire M1 et M2.

5. **Un seul chemin de commande physique**, que le mode soit manuel ou auto. AX15B ne doit intervenir que dans la génération d’ordres et l’anticipation, jamais dans la loi de roulis.

6. **Machine d’états `IDLE / DRIVE / COAST`**, avec reprise sans saut, inversion par rampe, butées et anti-rebond.

7. **Comptage codeur avec accumulateur réel**, pas de saut de vitesse, pas de cumul de réserves obsolètes après réenclenchement.