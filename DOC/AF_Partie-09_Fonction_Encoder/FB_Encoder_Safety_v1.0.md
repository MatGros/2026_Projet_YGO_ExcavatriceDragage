# FB_Encoder_Safety — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §4.  
> Rôle de **ce** document : bornage de la position dans l'enveloppe de sécurité et détection d'incohérence/dépassement.  
> Source code : `CODE/CODEURS/FB_Encoder_Safety.st` · instances `instEncoderSafetyM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Bornage et levée d'alarme
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-010/011/012` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-010 | Bornage [-99;+99] m dépassé ➔ position gelée + `EncoderIncoherent = TRUE` | `💻 AUTO` |
| TC-P09-011 | `EncoderFaultPresent = TRUE` interdit la bascule en mode `SEMI_AUTO` | `⚡ AUTO_PLC` |
| TC-P09-012 | Méca D (Capteur haut sans arrêt) ➔ `SafeStop` + `PowerCutOff` après 3s | `🟢 SITE` |

---

## 1. Rôle et profil

Brique de **sécurité et de qualification de mesure** : vérifie que la position mesurée reste dans l'enveloppe physique acceptable (intervalle `[-99.0 ; +99.0]` mètres) et qualifie les défauts codeur qui doivent interdire le mode automatique.

---

## 2. Interface (vérifiée `CODE/CODEURS/FB_Encoder_Safety.st`)

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable` | BOOL | Standard |
| `Reset` | BOOL (front) | Acquittement — bit0 uniquement (bit1 suit `HomingSuspect`, voir §3bis) |
| `PowerContactorEngaged` | BOOL | Standard |
| `Mode` | E_Mode | Contexte (pas encore exploité ce lot) |
| `CablePosM` | REAL | Position mesurée issue de `FB_Encoder_Scale` |
| `HomingSuspect` | BOOL | Sortie `FB_Encoder_Homing` DE CE TREUIL (déjà calculé, §3.7) |
| `PositionMinM` | REAL := -99.0 | Bornage physique dur |
| `PositionMaxM` | REAL := 99.0 | Bornage physique dur |
| `BypassGlobal` | BOOL := FALSE | 🌐 Force `ErrorId = 0`, ignore le bornage — doctrine projet (voir fiche Homing §3bis) |

⚠️ **Pas de port `EncoderAvailable` ni `Homed`** en entrée de ce FB — la disponibilité bus est
gérée en amont (`FB_Encoder_Abs` gèle déjà `RawPos`), et `Homed` seul n'entre pas dans le calcul
d'incohérence de ce FB (voir §3).

**Sorties** :
- `CablePosMSafe : REAL` : `CablePosM` gelée sur dernière valeur plausible si hors plage.
- `EncoderIncoherent : BOOL` : `TRUE` si position hors `[PositionMinM ; PositionMaxM]` OU
  `HomingSuspect` (= `Error`).

⚠️ **Pas de port `EncoderFaultPresent`** — voir §3.

---

## 3. Bornage et levée d'alarme

- Si la position mesurée dépasse `PositionMaxM`/`PositionMinM`, `CablePosMSafe` est **gelée** à la
  dernière valeur valide et `EncoderIncoherent` est activé.
- `ErrorId` (numérotation **locale**, différente de `FB_Encoder_Homing`) : bit0 = "Position câble
  hors plage" (hors plage physique) ; bit1 = "Incohérence position boot" (miroir `HomingSuspect`).
- 🔴 **`EncoderFaultPresent` n'est PAS une sortie de ce FB** : c'est `CODE/MAIN/PRG_02_Encoders.st`
  qui l'agrège (`EncoderFaultPresentM1 := instEncoderSafetyM1.EncoderIncoherent`, idem M2, puis
  `EncoderFaultPresent := M1 OR M2`), consommé par `FB_Modes` (1 cycle de retard) pour refuser
  `SEMI_AUTO`. Producteur : `PRG_02_Encoders`, pas ce FB — ne pas le documenter comme sortie FB
  dans une future implémentation sans en faire un choix d'architecture explicite.
- ⚠️ **Comportement réel** : `EncoderFaultPresent` vient de `EncoderIncoherent`
  (bornage + `HomingSuspect` relayé), **pas** de `Homed = FALSE` directement. Un treuil jamais
  référencé (mais jamais mis en doute) ne bloque donc pas `SEMI_AUTO` par ce mécanisme —
  comportement voulu, voir fiche Homing §4 pour le traitement cible de ce cas (signalement +
  vitesse forcée palier 1).
- 🔴 **Trou de sécurité à instruire (hors périmètre doc)** : perte de bus codeur ⇒ `RawPos` gelé
  par `FB_Encoder_Abs` ⇒ position reste dans la plage ⇒ `EncoderIncoherent = FALSE` ⇒ `SEMI_AUTO`
  reste autorisé sur une position figée, sans alerte dédiée à la perte de bus elle-même dans ce
  FB. À traiter dans un lot dédié (cross-ref `EncoderAvailable`, `FB_Encoder_Abs`).

---

## 4. Alertes et écarts

- Le gel de position empêche des dérives catastrophiques dans la machine d'état du cycle en cas de rupture de signal codeur.
- Voir §3 pour le trou de sécurité perte-bus non couvert par ce FB.

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)
