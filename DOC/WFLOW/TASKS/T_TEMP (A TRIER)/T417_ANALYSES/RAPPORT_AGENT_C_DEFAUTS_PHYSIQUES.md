## Modèle SimBench M3 – analyse synthétique

### 1. Principe : simuler la physique et la logique réelle, pas injecter les pannes

Le défaut doit **émerger** de la confrontation entre :
- la physique du chariot : inertie, rampe variateur, frein mécanique, frottements ;
- les capteurs de cames : position réelle, hystérésis 2 cm, largeur de came, période d’échantillonnage API ;
- la logique automate de production : modes, cycle semi-auto, arrêts, latchs, diagnostics frein/variateur.

À éviter absolument : forcer un `ErrorId=64` à t=26,4 s, injecter un 0/1 sur P1/Trémie, ou imposer `v=0` à la butée. Le simulateur doit seulement fournir au programme API des entrées plausibles : `x`, `v`, `f_act`, `capteurs`, `frein_appliqué`, etc. Si le programme de production est correct, il ne se passe rien d’anormal ; si sa logique est insuffisante — non-latch, absence de contrôle de vitesse nulle, frein commandé trop tôt — l’anomalie apparaît naturellement.

Architecture recommandée :
- tâche simulation 10 ms : `FB_ChariotM3_Sim` ;
- programme API de production inchangé, mappé sur des E/S virtuelles ;
- aucun accès direct du simulateur aux sorties réelles ;
- paramètres séparés : positions cames, `h=0,02 m`, rampes, délais frein, `f_nom/v_nom`, seuils diagnostic.

---

### 2. Comment faire apparaître les anomalies sans les forcer

#### Anomalie 1 – Mode MANUEL : arrêt fin de course latché correct
Garder la chaîne réelle : fin de course MANUEL → arrêt latché → réarmement explicite. Le simulateur ne doit pas court-circuiter cette chaîne. Le mode MANUEL sert de référence : il doit continuer à fonctionner correctement même si le semi-auto présente un défaut. Cela valide que le modèle ne détruit pas les sécurités.

#### Anomalie 2 – Semi-auto : dépassement à P1/Trémie
À P1/Trémie, la demande cycle est retirée sur front de came. Si le programme ne mémorise pas proprement l’ordre d’arrêt et ne filtre pas les rebonds, la came qui rebascule réactive la demande. La physique ajoute l’élan du chariot : le variateur suit sa rampe de décélération, le frein n’est pas encore appliqué, et le chariot continue.

Pour reproduire cela naturellement :
- modèle de came avec hystérésis 2 cm ;
- légère oscillation mécanique résiduelle ou ondulation de couple du variateur autour du seuil ;
- même période d’échantillonnage que l’API ;
- aucune temporisation magique de 1 s : les 0/1 doivent venir du franchissement réel des seuils.

#### Anomalie 3 – t=26,4 s : frein appliqué alors que le variateur est à 10 Hz
Modéliser le frein comme un vrai frein à manque de courant :
- `C_frein = 1` → bobine alimentée, frein relâché ;
- `C_frein = 0` → bobine non alimentée, frein appliqué après délai mécanique `T_apply` ;
- le frein applique une décélération de `2 m/s²` ;
- si le variateur pousse encore, le frein peut patiner ou créer un conflit couple/vitesse.

Le diagnostic doit être identique à la production : si le frein est appliqué et que la fréquence variateur est encore supérieure au seuil de vitesse nulle, après un temps de confirmation, alors `State.ErrorId=64 / Safety.Error=1`. À t=26,4 s, l’erreur apparaît parce que la logique a appliqué le frein trop tôt, pas parce qu’on l’a forcée.

#### Ancien simulateur complaisant
Remplacer :
- arrêt instantané à la butée → par inertie + rampe variateur + frein ;
- attente `f ≤ 0,5 Hz` avant frein → par la vraie logique de commande du frein, avec délais et contrôle de vitesse nulle.

---

### 3. Équations simples

Variables :
- `x` : position chariot [m], `v` : vitesse [m/s] ;
- `f_ref`, `f_act` : fréquence référence/réelle [Hz] ;
- `a_b = 2 m/s²` : décélération mécanique du frein ;
- `h = 0,02 m` : hystérésis capteur ;
- `Δt` : période de simulation, idéalement 10 ms.

#### Inertie et dynamique du chariot

Masse équivalente :
```text
m_eq = m_chariot + J_moteur / (i² · R²)
```
avec `i` réduction et `R` rayon pignon/roue.

Équation fondamentale :
```text
m_eq · dv/dt = F_moteur + F_frein - F_frottement
```
Sous forme accélération :
```text
a = a_variateur + a_frein - a_resistif
```

#### Variateur AC600

Conversion fréquence → vitesse :
```text
v_ref = (f_ref / f_nom) · v_max
```
Suivi de rampe simplifié :
```text
a_variateur = clamp( (v_ref - v) / τ_v , -a_dec_max , +a_acc_max )
```
Si STO ou variateur désactivé :
```text
a_variateur = 0
```

#### Frein mécanique à manque de courant

Commande :
```text
C_frein = 1  → frein relâché
C_frein = 0  → frein appliqué après T_apply
```
Application retardée :
```text
b_app = delay( NOT C_frein , T_apply )
```
Décélération frein :
```text
a_frein = -sign(v) · a_b · b_app      si |v| > ε
a_b = 2 m/s²
```
Si `|v| < ε` et que le couple moteur ne dépasse pas le couple de maintien :
```text
v = 0
```

Intégration :
```text
v(k+1) = v(k) + a · Δt
x(k+1) = x(k) + v(k+1) · Δt
```
ou forme trapézoïdale :
```text
x(k+1) = x(k) + v(k)·Δt + 0,5·a·Δt²
```

Distance d’arrêt sur frein seul :
```text
d_frein = v² / (2 · a_b) = v² / 4
t_frein = v / a_b = v / 2
```
Exemple : à `v=0,2 m/s`, `d=0,01 m` et `t=0,1 s`. Si le variateur continue de pousser, l’arrêt n’est pas garanti : c’est exactement le conflit frein/variateur à diagnostiquer.

#### Franchissement des cames avec hystérésis 2 cm

Pour un capteur i centré sur `x_i` :
```text
SI s_i(k-1)=0 ET x(k) >= x_i + h/2 ALORS s_i(k)=1
SINON SI s_i(k-1)=1 ET x(k) <= x_i - h/2 ALORS s_i(k)=0
SINON s_i(k)=s_i(k-1)
```
avec :
```text
h = 0,02 m
h/2 = 0,01 m
```
Pour une came de largeur `w_i`, appliquer le même principe sur le front d’entrée et le front de sortie. En mouvement négatif, inverser les seuils ou utiliser `sign(v)`. Les rebonds de 0/1 doivent apparaître lorsque la position réelle oscille autour de ces seuils, pas être injectés.

---

### 4. Garde-fous stricts pour préserver l’automate de production

1. **Séparation physique/logique** : SimBench sur runtime ou projet séparé. Le programme de production ne doit pas pouvoir écrire directement sur les vraies sorties. Utiliser E/S virtuelles, OPC UA en lecture seule, ou automate de test dédié.

2. **Mode simulation verrouillé** : clé physique + autorisation maintenance + `SIM_MODE` non modifiable depuis l’HMI seule. En production, le code de simulation doit être absent ou compilé hors service.

3. **Sécurité indépendante ISO 13849** : E-stop, STO/SS1, fins de course de sécurité, contrôle de vitesse nulle et frein de sécurité restent hardwired ou safety PLC. Le simulateur ne doit jamais écrire sur les entrées/sorties de sécurité. La simulation ne vaut pas validation PL ; elle aide seulement à comprendre le comportement.

4. **Watchdog simulateur/API** : heartbeat entre modèle et automate. Perte de heartbeat → arrêt sécurisé et défaut latché, pas de poursuite du cycle.

5. **Limites et plausibilité** : clamps sur `x`, `v`, `a`, `f_ref` ; refus des NaN ; timeouts ; contrôle de cohérence frein/variateur ; contrôle position/capteurs ; contrôle vitesse nulle. Les défauts doivent être latchés et réarmés explicitement.

6. **Pas de simulation des sécurités sur machine en service** : pour tester le frein, utiliser charge isolée, moteur débrayé ou banc de test. Ne jamais désactiver STO/frein sécurité pour “voir ce que fait le modèle”.

7. **Traçabilité** : même nommage de signaux que la trace site (`x`, `v`, `f_act`, `C_frein`, `b_app`, capteurs, mode, `State.ErrorId`, `Safety.Error`). Comparer la trace simulée à t=26,4 s : si l’erreur apparaît avec des paramètres réalistes et la logique de production inchangée, le modèle est utile ; si elle n’apparaît qu’avec un forçage, il est invalide.

En synthèse : le modèle SimBench M3 doit être un **jumeau physique et temporel**, pas un générateur de pannes. On règle les délais de frein, les rampes, l’hystérésis 2 cm, l’inertie et la période d’échantillonnage. Ensuite, les dépassements de P1/Trémie, les rebonds de cames et le conflit frein/variateur à 10 Hz apparaissent comme conséquences naturelles de la logique réelle — tout en gardant la chaîne de sécurité de production totalement isolée et prioritaire.