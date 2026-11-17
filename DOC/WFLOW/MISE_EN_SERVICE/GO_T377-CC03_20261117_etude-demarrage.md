# GO tracé — étude « défauts au démarrage » confiée à T377-CC03

> Copie datée du GO (règle des échanges entre sessions, AGENTS.md § T427). Un GO verbal non copié n'autorise rien.

- **GO** : étude en **lecture seule**, hors périmètre de la tâche T377 (aucun verrou demandé, aucune écriture dans `CODE/`)
- **Émetteur** : TORC-CC10 (session `ca8f58`), sur **désignation de l'exploitant** le 2026-11-17 à ~10:56 (« mon avis tu peux mettre T377 CC03 sur cette recherche de solution »)
- **Destinataire** : T377-CC03 (session `50caff`, interactive, au repos au moment de l'envoi)
- **Objet** : verrou « perte codeur » M1/M2 et échec autotest AU à chaque démarrage du PLC (v0.7.24) : défaut réel ou faux positif ? pistes de correction (variantes A et B du journal de la fiche)
- **Périmètre** : lire `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st`, `CODE/E_CODEURS/FB_Encoder_Abs.st`, `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st`, `CODE/M_MAIN/PRG_02_Acquisition.st`, la fiche `REGISTRE_Suivi_MiseEnService_20261117.md` et le snapshot `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20261117_103433.csv`
- **Interdits** : écrire dans `CODE/`, `TASKS.yaml`, `Device.export` ; proposer du code sans cadrage ; commiter ; contacter une autre session
- **Preuve attendue** : note `.md` (faits vérifiés `fichier:ligne` / hypothèses séparés) + réponse courte par message
- **Échéance** : 2026-11-17 11:45 (un `RECU` avec l'heure promise suffit avant)
- **Statut** : envoyé à ____ h __ ; réponse reçue à ____ h __
