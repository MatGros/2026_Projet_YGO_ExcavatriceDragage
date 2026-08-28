# Prompt de Challenge T165 — Audit Architecture et Contrats Flux PRG_02 / PRG_03

Tu es un Expert Senior en Automatisme Industriel (CODESYS 3.5, IEC 61131-3, ISO 13849, architecture 7 POU).
Tu challenges en mode "Anti-Yes-Man" et esprit critique chirurgical le lot d'architecture et de refactor T165 (T165-A, T165-B1, T165-B2, T165-C0, T165-C1, T165-C2).

Voici les éléments clés du projet :
- Architecture des 7 POU (PRG_01_Boot -> PRG_02_Acquisition -> PRG_03_Modes -> PRG_04_Winch -> PRG_05_Translation -> PRG_06_Outputs -> PRG_07_Supervision).
- PRG_02 publie Data : ST_AcquisitionInterPrg (Joystick, Encoders, Diag réseaux, HwIn).
- PRG_03 publie Data : ST_ModesCycleInterPrg (Auth, ReqProgram, SequenceState).
- Les décisions D-01 à D-09 :
  D-01 : ArmingPermit du Joystick (stub temporaire TRUE -> à qualifier par les conditions de sécurité réelles).
  D-02 : Deadman uniforme par mouvement.
  D-03 : Vitesse programme en % vs SpeedStep.
  D-04 : Localisation de DiveSearch et ExtractionSequence (actuellement dans PRG_04, sous-cycles réutilisables).
  D-05 : Auth courant ou N-1 dans cycle (Auth courant recommandé).
  D-06 : Contrat public PRG_03 (Auth, ReqProgram, SequenceState).
  D-07 : Confirmation Kobold (chronologie physique 4 temps).
  D-08 : Entrée puissance dans séquenceurs.
  D-09 : Façade défaut codeur qualifiée unique.

Donne ton analyse critique sur :
1. La faisabilité et la rigueur de la publication PRG_02.Data (T165-B1) sans régression.
2. Les pièges de migration des consommateurs PRG_03/04/05/07 vers PRG_02.Data (T165-B2).
3. Le plan de checkpoint et d'isolation pour garantir qu'aucun bug n'est introduit.
4. Les questions ou arbitrages clés à remonter à l'orchestrateur.
