# 🧭 Décision requise — Preset codeur : transaction matérielle ou echo ?

> **Statut** : OUVERTE · **Bloque** : `TASK_CONTRACT_ENCODER_INTERFACE_CONFORMANCE.yaml` (lot E1)
> **Décideur** : humain avec connaissance du codeur absolu EtherCAT réel (pas un agent)
> **Créé** : 2026-08-27 · Origine : revue façade `FB_Encoder` (agent externe) + audit orchestrateur

---

## Le fait

`FB_Encoder_Homing` pose `Calib.Homed := TRUE` (référence validée, écrite en RETAIN)
**avant** d'avoir la confirmation matérielle du preset (`instAbs.PresetAck`). Les sorties
`instAbs.PresetAck` / `PresetNak` **existent** mais ne sont consommées par personne pour
gater le commit RETAIN. `AF_Partie-09 §4 / §5 / F09.01` décrit une « séquence d'écriture
preset (déclenchement, tolérance, timeout) » sans dire si son **succès** conditionne
`Homed`.

Conséquence du flou : un homing peut inscrire une référence en mémoire persistante alors
que le preset matériel a échoué → **mauvaise position absolue qui survit au reboot**, sans
alarme.

## La question

**Le preset SDO/PDO vers le codeur est-il une vraie transaction dont le succès est requis,
ou un simple aller optionnel dont on ignore le retour ?**

## Options

| # | Décision | Ce que ça implique dans le code |
|---|---|---|
| **A** | **Vraie transaction** — le succès du preset est requis | `Calib.Homed := TRUE` **uniquement** sur `PresetAck` (dans la fenêtre timeout). `PresetNak` (ou timeout) → homing refusé, `ErrorId` bit dédié, `Homed` inchangé. `Calib.HomingRefRaw` committé au même instant que `Homed`, jamais avant. |
| **B** | **Echo optionnel** — le retour n'est pas fiable / pas utilisé | Supprimer la pseudo-transaction : retirer `PresetAck`/`PresetNak` de l'interface `ST_EncoderHw` (→ `ST_fbEncoder_HwIn`), retirer le séquencement timeout de `FB_Encoder_Abs`, documenter en clair que `Homed` repose sur le calcul interne seul (`RawPos` lu, pas confirmé côté device). |
| **C** | **Autre** — préciser | (décrire) |

## Impact aval selon la réponse

- **A** : lot E1 ajoute un état d'attente de confirmation dans `FB_Encoder_Homing` +
  1 bit `ErrorId`. `CodeSeqTriggerCmd` (aujourd'hui à 0 par construction, `AF-09 §11 TBD`)
  reste à trancher séparément.
- **B** : lot E1 simplifie — moins de ports, moins d'états, interface publique réduite.
- Dans **les deux cas** : `Homed`/`HomingSuspect`/`HomingRefRaw` restent ré-exposés depuis
  `Calib` quand `Enable=FALSE` (déjà corrigé, `AF-09 §4`).

## Réponse

```
Décision retenue : [ A | B | C ]
Par : ____________________   Date : ____________
Justification / précision :


```
