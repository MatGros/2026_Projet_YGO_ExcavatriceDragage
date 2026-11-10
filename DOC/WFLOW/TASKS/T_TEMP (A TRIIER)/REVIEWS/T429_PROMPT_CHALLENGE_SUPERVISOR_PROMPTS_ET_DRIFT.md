# Challenge & Refonte des Prompts du Veilleur (Drift, Gouvernance, Alarmes Réelles)

Tu interviens en tant qu'Architecte Senior en Systèmes Multi-Agents et Sécurité Machine.

## Constat & Diagnostic de l'Exploitant (2026-11-09)
Actuellement, l'Agent Supervisor (Veilleur) présente un déséquilibre structurel :
1. **Hyper-focalisation locale sur la preuve textuelle** : 90% des constats portent sur des détails de citation ou d'affirmations sans preuve brute dans l'extrait ("l'agent dit que le test passe mais n'a pas affiché la sortie").
2. **Angle mort sur le pilotage, l'ordonnancement et le drift** :
   - L'agent supervisé est un orchestrateur/ingénieur censé planifier, découper en jalons et piloter sa tâche avec rigueur.
   - Le superviseur ne vérifie pas activement si l'agent a un plan, s'il suit ses jalons, s'il dérive de l'objectif initial (drift d'objectifs, dispersion, perte de fil).
   - Le superviseur ne vérifie pas si l'agent respecte son **devoir d'alerte** : avertit-il l'utilisateur des risques réels, des incohérences ou des blocages rencontrés ?
3. **Absence quasi-totale d'Alarmes (`Alarm`)** :
   - L'exploitant constate : *"J'ai beaucoup d'avertissements (warnings), mais je n'ai JAMAIS vu d'alarmes. Dans quel cas réel a-t-on des alarmes ?"*
   - Dans le code actuel (`supervisor_service.py:281`) :
     `alarm uniquement pour category=unauthorized_action avec action explicitement deja accomplie et ancrage exact dans une interdiction`
   - Ce verrouillage rend les Alarmes quasi-inaccessibles en pratique, banalisant les vraies alertes critiques dans une masse de Warnings tatillons.

## Questionnements à Challenger
1. **Prompt du Juge (`OMNI_JUDGE_SYSTEM`)** :
   Comment réécrire les consignes du juge pour équilibrer la détection :
   - Détection du **Drift de mission / Abandon d'objectif** (l'agent part sur un sujet annexe sans accord).
   - Détection du **Défaut de planification** (l'agent fonce tête baissée sans plan, boucle sans progression, ou ignore ses propres jalons).
   - Détection du **Manquement au devoir d'alerte** (l'agent minimise un risque, contourne une règle de sécurité sans prévenir, tait une erreur).
2. **Matrice de Sévérité Réelle : Alarm vs Warning** :
   Quels sont les cas réels, concrets et physiques devant lever une `🔴 Alarm` immédiate (ex: violation guardrail, action destructive, masquage de défaut, drift non consenti) vs un `⚠️ Warning` (défaut méthodologique, preuve à consolider, imprécision) ?
3. **Système de Récolte des Données (Data Ingestion)** :
   Actuellement le juge reçoit les derniers messages textuels. Comment structurer la récolte pour que le juge perçoive l'état de la tâche :
   - Fiche mission et contrat (`objectifs`, `jalons`).
   - Journal des étapes franchies.
   - Les directives clés de l'utilisateur (recadrages).

Rends une analyse d'ingénierie sans complaisance, structurée en 4 parties :
1. Diagnostic des faiblesses du prompt actuel
2. Nouvelle matrice concrète Alarm vs Warning (avec exemples industriels réels)
3. Proposition de refonte du prompt `OMNI_JUDGE_SYSTEM`
4. Recommandations sur la récolte des données (framing/planning)
