# 🧪 Proposition — Câblage `ArmingPermit` (v0.1, NON VALIDÉE)

> ⚠️ Ne constitue **pas** une autorisation de coder. Étude de conception seule, plusieurs points
> restent à trancher par un humain avant tout lot C4. Déplacé depuis
> `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md` §7 (2026-08-25, audit critique demandant de garder
> l'AF centrée sur les exigences machine, pas sur l'exploration de conception).

## Contexte

`ArmingPermit` (`FB_Joystick`) est câblé en dur `TRUE` dans `PRG_02_Acquisition.st:303`
(« câblage temporaire »), aucun producteur réel. Trou de sécurité documenté, non tranché — voir
`AF_Partie-08_Fonction_Joystick_v2.2.md` §10 Q1 et `QUESTIONS_OUVERTES_PRG02_v0.1.md` Q1.

## Ce qui existait avant l'abstraction (`CODE_20260807_v0.5.25`)

Les 3 signaux qui pilotaient le désarmement avant l'abstraction `ArmingPermit` existent toujours
dans l'archi actuelle : `Auth.Mode` (`PRG_03_Modes_Cycle`), `instBucket.Status.Busy` avec un
`F_TRIG BenneBusyFallEdge` **déjà écrit** (`PRG_04_Treuils_Benne.st:494`), et le pattern
« préserver l'armement pendant `ExtractionSequence` » déjà dupliqué 2× dans `PRG_04` pour l'arrêt
moteur — jamais raccordé à `ArmingPermit`.

## Piste retenue

Calculer `ArmingPermit` dans `PRG_04_Treuils_Benne` (où `Mode` et `BenneBusyFallEdge` sont déjà à
jour), publier sur le bus `Data`, `PRG_02_Acquisition` le consomme avec **1 scan de retard
explicite** (`PRG_04` s'exécute après `PRG_02` dans la `MainTask`).

## Points non tranchés avant de coder

- Le retard (10-20ms) sur un signal de désarmement homme-mort est-il acceptable ? Il existe un
  filet de sécurité potentiel (`PRG_04`/`PRG_05` réarbitrent chaque consigne contre `Auth.Mode` du
  scan courant) — **à prouver par audit**, pas supposé.
- Modification de contrat DUT (`Data`, AF03) à documenter formellement.
- Contrat de tâche C4 requis avant implémentation.

## Documents liés

| Doc | Lien |
|---|---|
| AF08 | `DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md` §10 Q1 |
| Questions ouvertes | `QUESTIONS_OUVERTES_PRG02_v0.1.md` |
