# AF Partie 14 - Troubleshooting v1.2

Orientee Fonctions Machine / Utilisation Operateur.

1. LevageSynchroniseM1M2
2. LevageUnitaireM1
3. LevageUnitaireM2
4. BenneOuvertureFermeture
5. TranslationPontM3

---

## Integration programme

> Architecture cible faisant foi : `DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md` §2 et §4.

| | POU | Statut |
|---|---|---|
| Code actuel | `PRG_TROUBLESHOOTING_CFC` (ST) | page d'observation distincte de `PRG_SUPERVISION_CFC` |
| Cible | `PRG_07_Supervision_CFC` (rang 07) | **absorbe le troubleshooting** : observation et diagnostic au meme endroit |

Il n'existe **pas** de POU `PRG_11_Troubleshooting` dans l'architecture cible : ce nom
appartient au decoupage transverse abandonne. Observer un fonctionnement et le publier a l'IHM
est une seule responsabilite, portee par une page unique executee en dernier.

### Invariant opposable

Le troubleshooting **n'ecrit jamais** une commande, une configuration ou un interlock.
`PRG_07_Supervision_CFC` est en **lecture seule stricte**. Cette regle est inchangee par la
migration : elle est deja l'invariant du POU actuel.

Le contenu fonctionnel des 5 fonctions machine ci-dessus, ses seuils et ses observateurs
(`FB_Acquisition_Preflight`, `FB_Winch_Symmetry`) ne sont pas modifies par le changement de POU.
Fiches : `AF_Partie-06` (Preflight) et `AF_Partie-10` (Symmetry).

📌 Lot de migration : **M6** de `DOC/WFLOW/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md` (C2, patch).

---

## 🔄 1bis. Flux d'observation & Supervision

<div style="display:flex; flex-direction:column; align-items:stretch; width:100%; margin:12px 0;">
  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #38bdf8; padding:6px 10px; border-radius:4px; font-size:12px;">
    📡 &nbsp;<b>PRG_02_Acquisition (HwIn) & Capteurs</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Lecture seule des états d'entrée réels/simulés</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">Observation passive (aucune écriture)</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #fbbf24; padding:6px 10px; border-radius:4px; font-size:12px;">
    🩺 &nbsp;<b>PRG_07_Supervision_CFC</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Observateurs passifs (FB_Acquisition_Preflight & FB_Winch_Symmetry)</span>
  </div>

  <div style="display:flex; flex-direction:column; align-items:center; margin:3px 0;">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 0V12M8 12L4 8M8 12L12 8" stroke="#fbbf24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <span style="color:#94a3b8; font-size:10px; font-style:italic; margin-top:1px;">États de dépannage & mesures</span>
  </div>

  <div style="background:#1e293b; color:#f8fafc; border-left:4px solid #4ade80; padding:6px 10px; border-radius:4px; font-size:12px;">
    🖥️ &nbsp;<b>Vue IHM Dépannage & Watch CODESYS</b> &nbsp;—&nbsp; <span style="color:#cbd5e1;">Affichage opérateur / technicien terrain</span>
  </div>
</div>

---

## 2. 🩺 Table de visu — dépannage de l'acquisition DI

> La source d'observation cible est `PRG_02_Acquisition`. Les références historiques à
> `PRG_01_Inputs_LD` et `FB_Input` ne doivent plus être ajoutées ; elles sont conservées
> uniquement dans les audits de migration jusqu'à la suppression effective du code.

> **Proposition de support IHM / Watch CODESYS.** Cette table est en lecture seule : elle observe
> l'acquisition et ses conséquences, mais n'écrit ni commande, ni Reset, ni bypass.
> Les valeurs doivent être comparées dans l'ordre **module → agrégat → procédé → entrée**.

### 2.1 Ordre de diagnostic

1. Vérifier l'état des trois modules (`GetDeviceState()` traduit en `*Ok`).
2. Vérifier l'agrégat `InputModuleFault` / `Network.InputModules.Fault`.
3. Identifier les `SafeStop` actifs sur M1, M2 et M3.
4. Contrôler ensuite les valeurs `HwIn` des entrées concernées et leur polarité.
5. Corriger la cause matérielle ou de simulation, puis acquitter par un appui conscient.
6. Vérifier qu'aucun mouvement ne redémarre automatiquement.

### 2.2 Table opérateur/automaticien

| Observable à afficher | Valeur nominale | Si défaut | Cause probable | Action sûre | Interdit |
|---|---|---|---|---|---|
| `PRG_02_Acquisition.LocalDigitalIoOk` | `TRUE` | `FALSE` | `Local_Digital_IO` absent, non opérationnel ou non présent sur le banc | Vérifier alimentation, bus et présence du module | Forcer à `TRUE` |
| `PRG_02_Acquisition.Vh0800EndOk` | `TRUE` | `FALSE` | `VH_0800END` absent ou non opérationnel | Vérifier module, bus et configuration CODESYS | Forcer à `TRUE` |
| `PRG_02_Acquisition.Vh0808EtpOk` | `TRUE` | `FALSE` | `VH_0808ETP` absent ou non opérationnel | Vérifier module, bus et configuration CODESYS | Forcer à `TRUE` |
| `PRG_02_Acquisition.InputModuleFault` | `FALSE` | `TRUE` | Au moins une carte DI en défaut ; défaut global actuel | Relever les trois états individuels, corriger la cause, Reset conscient | Forcer à `FALSE` |
| `GVL_IHM.Network.InputModules.Fault` | `FALSE` | `TRUE` | Recopie IHM de l'agrégat acquisition | Comparer à `InputModuleFault` | Utiliser l'IHM comme preuve unique |
| `PRG_04_Treuils_Benne.SafeStopM1_Raw` | `FALSE` au repos sain | `TRUE` | Défaut module, synchro ou glissement selon code actuel | Identifier la cause avant Reset | Forcer à `FALSE` |
| `PRG_04_Treuils_Benne.SafeStopM2_Raw` | `FALSE` au repos sain | `TRUE` | Défaut module ou synchro selon code actuel | Identifier la cause avant Reset | Forcer à `FALSE` |
| `PRG_05_Translation.M3_SafeStop_Active` | `FALSE` au repos sain | `TRUE` | `InputModuleFault` selon implémentation actuelle | Vérifier les cartes DI et la rampe SafeStop | Forcer à `FALSE` |
| `PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI` | Selon position réelle/simulée | Valeur incohérente | Capteur, polarité ou modèle de simulation | Comparer `HwReal` / `HwSim` / `HwIn` | Conclure à la santé de la carte |
| `PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI` | Selon position réelle/simulée | Valeur incohérente | Capteur, polarité ou modèle de simulation | Comparer `HwReal` / `HwSim` / `HwIn` | Conclure à la santé de la carte |
| `PRG_04_Treuils_Benne.ForbidAscentM1_Raw` | Selon limite haute validée | À confirmer | Liaison limite haute à vérifier | Bloquer l'essai de montée limite tant que non validé | Déclarer le test conforme sans preuve |
| `PRG_04_Treuils_Benne.ForbidAscentM2_Raw` | Selon limite haute validée | À confirmer | Liaison limite haute à vérifier | Bloquer l'essai de montée limite tant que non validé | Déclarer le test conforme sans preuve |
| `GVL_IHM.Modes.Cmd.BtnFaultReset` | Appui bref / front | Maintenu ou sans effet | Cause encore présente ou traitement Reset à vérifier | Relâcher, corriger la cause, générer un nouvel appui | Utiliser un niveau maintenu comme bypass |

### 2.3 Règle d'interprétation

Un bit TOR qui change prouve que le programme reçoit une valeur logique ; il ne prouve pas que
la carte est saine. La santé carte est donnée par `*Ok`. Inversement, un module `*Ok = TRUE` ne
prouve pas que chaque capteur est correctement câblé ou mécaniquement fonctionnel.

Sur un banc sans modules physiques, `GetDeviceState()` peut rester différent de `RUNNING` et
maintenir `InputModuleFault = TRUE`. Ce cas doit être affiché comme **indisponibilité matérielle
de la simulation**, pas comme panne d'un canal et pas comme défaut à contourner sans décision
safety formelle.

> ⚠️ Cette table ne valide pas les fonctions de limite haute, de frein, d'AU ou de SafeStop. Elle
> indique les observations à relever ; chaque fonction nécessite encore sa recette dédiée.

## 2.4 Diagnostic réarmement AU — vue unique

La checklist `GVL_Troubleshooting.Safety` suit l'ordre AF01 §5.3 : modules, demande AU, boucle fermée, contacteur relâché, puis état armable. Elle expose aussi `ArmingStep`, `ArmingBusy`, `LockoutActive`, `ArmingErrorId`, `PowerCutOffActive` et les maintiens A/B.

`AllConditionsMet` décrit uniquement l'état final chaîne fermée + contacteur engagé ; ce n'est pas une précondition d'armement. Après acquittement éventuel, l'opérateur doit générer un **front `BtnEmergencyArming`**. Aucun réarmement automatique n'est autorisé.
