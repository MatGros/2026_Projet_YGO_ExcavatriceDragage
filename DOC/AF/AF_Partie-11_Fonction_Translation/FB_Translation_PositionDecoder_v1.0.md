# FB_Translation_PositionDecoder — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.0.md`](../AF_Partie-11_Fonction_Translation_v2.0.md) §2.
> Rôle de **ce** document : décodage 5 capteurs TOR → mot de progression + butées extrêmes —
> et **catalogue unique** des `TC-P11-001`, `TC-P11-002`.
> Source code : `CODE/TRANSLATION/FB_Translation_PositionDecoder.st` · instance `Acquisition.instPositionDecoder`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Table de cohérence
3bis. Fronts d'arrivée (`TranslationAtXxx`)
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P11-001/002` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P11-001 | 6 mots capteurs valides acceptés (11111➔00000) ; autre ➔ `Incoherent` | `💻 AUTO` |
| TC-P11-002 | Mot incohérent ➔ `Incoherent=TRUE` ➔ bit7 Safety ➔ SafeStop+PowerCutOff | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

🧩 Brique technique (AF_Partie-03 §2) : contrat minimal, pas de StartStop/Enable/Reset/Mode.
Décode 5 capteurs TOR en mot de progression, dérive les butées extrêmes, détecte toute
combinaison incohérente (défense en profondeur M3) **et les fronts individuels par capteur**
(arrivée/cible — 🆕 2026-08-06, voir §3bis). Contient désormais 10 instances internes
`R_TRIG`/`F_TRIG` (une paire par capteur) pour la détection de front — n'est donc plus une pure
logique combinatoire au sens strict, mais reste sans `Enable`/`Reset`/`Mode` (contrat inchangé).

Instance : `Acquisition.instPositionDecoder`, exécutée **avant** Safety — les butées extrêmes
et l'incohérence sont consommées par `FB_Safety_Translation`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `SensorTremie` | BOOL | Capteur extrême Trémie |
| `SensorPV` | BOOL | Capteur pré-ralentissement (Point de Vitesse) |
| `SensorP2` | BOOL | Capteur zone travail P2 |
| `SensorP1` | BOOL | Capteur zone travail P1 |
| `SensorMaintenance` | BOOL | Capteur extrême Maintenance |

| Sortie | Type | Sens |
|---|---|---|
| `LimitSwitchFwd` | BOOL | Extrême Trémie confirmé (mot=11111) |
| `LimitSwitchRev` | BOOL | Extrême Maintenance confirmé (mot=00000) |
| `Incoherent` | BOOL | Mot hors 6 combinaisons valides |
| `SensorsWord` | BYTE | Diagnostic (bit4=Trémie…bit0=Maintenance) |
| `TranslationPosTremie/PV/P2/P1/Maintenance` | BOOL | 🆕 Passthrough brut des 5 capteurs (CUMULATIF — voir §3bis). Pilote le ralentissement d'approche (zone large) |
| `TranslationAtTremie/PV/P2/P1/Maintenance` | BOOL | 🆕 Front (1 cycle) de franchissement — voir §3bis. Pilote l'arrêt/cible, jamais le ralentissement |

---

## 3. Table de cohérence (6 mots valides)

| Mot (bin) | Zone |
|---|---|
| `11111` | Extrême Trémie |
| `01111` | Entre Trémie et PV |
| `00111` | P2 |
| `00011` | P1 |
| `00001` | Entre P1 et Maintenance |
| `00000` | Extrême Maintenance |

Tout autre mot ⇒ `Incoherent=TRUE`. Butées extrêmes dérivées **seulement** sur mot valide
(évite butée fantôme sur incohérence câblage).

---

## 3bis. Fronts d'arrivée (`TranslationAtXxx`) — 🆕 2026-08-06, REX terrain

**Historique du lot** (pour éviter de refaire les mêmes erreurs) : 3 conceptions testées en
direct sur machine réelle avant validation :
1. Mot EXACT (5 bits) — abandonné : un capteur décalé de quelques mm suffisait à sauter le mot
   cible (décalage came).
2. Front du capteur **précédent** dans la chaîne thermomètre (ex : arrivée à P1 = front
   descendant de P2) — abandonné : armait le point ~un cran trop tôt (dès l'entrée de la zone
   d'approche, pas le franchissement réel). Confirmé en direct : arrêt bloqué à P2 au lieu de P1.
3. **Retenu** : front du capteur **PROPRE** à chaque position (montant OU descendant).

Règle retenue : le franchissement d'un point Xi est marqué par SON PROPRE capteur qui bascule —
front descendant en venant de Trémie (on vient de le dépasser), front montant en venant de
Maintenance (on vient de l'atteindre). Extrémités (Trémie, Maintenance) : un seul sens
d'arrivée physiquement possible chacune, donc un seul front valide (montant pour Trémie,
descendant pour Maintenance).

| Sortie | Front(s) valides |
|---|---|
| `TranslationAtTremie` | Montant `SensorTremie` uniquement (arrivée venant de Maintenance) |
| `TranslationAtPV` | Montant OU descendant `SensorPV` |
| `TranslationAtP2` | Montant OU descendant `SensorP2` |
| `TranslationAtP1` | Montant OU descendant `SensorP1` |
| `TranslationAtMaintenance` | Descendant `SensorMaintenance` uniquement (arrivée venant de Trémie) |

⚠️ Signal **transitoire** (1 cycle) — distinct des `TranslationPosXxx` (niveau cumulatif,
réservé au ralentissement). L'appelant (`PRG_05_Translation.st` §0quater) le mémorise en verrou
bistable : armé sur le front, **libéré uniquement sur mouvement réel confirmé** (fréquence
mesurée `DriveActualFreqHz`, pas juste une consigne de sens) soutenu ≥1.5s — ni un rebond
capteur (filtré par la durée du seuil), ni un simple changement de sens instantané.

⚠️ **Calibration non re-confirmée sur site pour PV/P2** (seul le couple Trémie↔P1↔Maintenance
a été validé en direct le 2026-08-06) — à vérifier avant d'activer un `SelTarget` réel sur ces
2 points (actuellement code mort, T106).

---

## 4. Alertes et écarts

| # | Gravité | Point | Détail |
|---|---|---|---|
| 1 | ✅ résolu | Détection d'arrivée par mot exact puis front-capteur-adjacent, toutes deux abandonnées en direct terrain — voir §3bis pour l'historique complet et la conception retenue | REX 2026-08-06 |

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| AF11 (chapô) | Rôle machine, intégration programme |
| AF11 / FB_Safety_Translation | Consommateur `Incoherent`, `LimitSwitchFwd/Rev` |
| AF06 | 5 capteurs TOR M3 (E/S physiques) |
| Code | `CODE/TRANSLATION/FB_Translation_PositionDecoder.st` |