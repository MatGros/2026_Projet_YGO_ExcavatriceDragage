# GO tracé — Implémentation « capteur TOP » par T417-C (AGY02)

- from : exploitant (oral 2026-11-18 ~10:45, « ok Go ») — relais et cadrage : T377-CC03
- to : T417-C (AGY02) — via TORC-CC10
- tâche : T377 / T417-C · objet : implémentation SPEC v0.2
- spé de référence : `DOC/WFLOW/MISE_EN_SERVICE/20261118_RELEVES/SPEC_2_ABSENCES_CONTACT_TOP_20261118_v0.2.md`
  (A1 latch anti-martelage · A2 escalade 2 s · A3/A3bis messages + carrousel complet ·
  AnyFaultActive · A4 tests feature + non-régression PAR ITEM)
- précondition d'ordre : T377-B (perte codeur au boot) passe d'abord si déjà lancée ;
  sinon ce lot peut démarrer — aucun chevauchement de fichier.
- périmètre CODE : `PRG_06_Outputs.st` (VAR RETAIN latch), `PRG_04_Treuils_Benne.st`
  (permits + miroir), `FB_Safety_Winch.st` (TON escalade + entrée latch + OR
  CausesPowerCutOff — SANS nouvelle cause, table pleine), `FB_Hmi_BannerFormatter.st`
  (messages TOP + [W] carrousel), `PRG_07_Supervision.st` (AnyFaultActive + publication),
  miroirs/checklists associés. INTERDITS inchangés : Device.export, TASKS.yaml, gate-fou.
- **Posture exigée (motifs exploitant) : SANS COMPLAISANCE + DEVOIR D'ALERTE** —
  1. toute divergence spec/réalité du code ou impossibilité technique = signalée
     IMMÉDIATEMENT (jamais contournée, jamais reportée en fin de lot) ;
  2. aucune auto-validation : « j'ai fini » passe d'office en revue (T417-C contrôle +
     alerte) ; le verdict de fin revient à l'exploitant/T377-CC03 sur preuves ;
  3. chaque item livré avec ses DEUX tests (feature + non-régression, section A4) ;
  4. zéro commit sans accord humain ; diff fichier:fichier avec argumentaire à chaque
     restitution (règle exploitant du 18/11) ;
  5. si un contrôle révèle du travail non stabilisé (le moindre écart notable vérifié),
     corrections + re-validation OBLIGATOIRES.
- preuve attendue : git diff fichier:fichier + argumentaires · bandeaux bundle/diff
  bundle · G200 --report (bloc collé) · run_all_gates.py --palier C · tests simu A4
  (features + non-régressions, sorties brutes) · message IHM vérifié G408.
- échéance : AUCUNE date imposée — amendé par l'exploitant le 18/11 (« pas de date,
  on gère les échanges » ; transmis par l'exploitant lui-même au chat de T417-C).
  Le suivi des échanges est assumé par l'exploitant ; un « RECU » reste attendu
  formellement (sans date promise). GO verbal non copié n'autorise rien — cette
  copie date le GO.
