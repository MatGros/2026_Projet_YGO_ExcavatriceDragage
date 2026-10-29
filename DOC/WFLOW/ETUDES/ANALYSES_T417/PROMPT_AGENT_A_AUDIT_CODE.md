# MISSION D'ANALYSE AGENT A — AUDIT DU MODÈLE ACTUEL DE TRANSLATION SIMBENCH (T417)

## Contexte Projet
Projet d'automate CODESYS 3.5 pour excavatrice de dragage en carrière noyée.
L'axe Translation M3 déplace le chariot entre la Trémie (0.00 m) et la Maintenance (30.00 m).
La motorisation réelle est un moteur HELMKE 7.5 kW triphasé (963 tr/min) piloté par un variateur AC600 avec frein mécanique à manque de courant et 5 capteurs inductifs fixes.

## Objectif de l'Agent A
Réaliser un **audit critique et exhaustif** du code de simulation actuel de la translation M3 :
- `CODE/L_SIMULATION/FB_Sim_Translation.st`
- `CODE/L_SIMULATION/FB_Sim_TranslationDrive.st`
- `CODE/L_SIMULATION/FB_Sim_TranslationBrake.st`
- `CODE/L_SIMULATION/FB_Sim_PositionSensor.st`
- `CODE/L_SIMULATION/FB_SimBench.st` (section §3 M3)

## Questions Précises à Traiter
1. **Écarts physiques majeurs** : Quelles sont les simplifications actuelles qui rendent le comportement trop idéal ou irréaliste (ex. arrêt instantané, pas d'inertie réelle, couplage frein/variateur rigide, recopie artificielle de signaux) ?
2. **Gestion du frein M3** : Comment `FB_Sim_TranslationBrake` gère-t-il la bobine, le retour contact auxiliaire et la retombée du frein ? Est-ce cohérent avec un frein à manque de courant réel ?
3. **Gestion des 5 capteurs** : Comment `FB_Sim_PositionSensor` génère-t-il les signaux Trémie, PV, P2, P1, Maintenance ? Sont-ils franchissables naturellement ou bloqués en butée ?
4. **Interface SimBench -> Automate** : Analyser les signaux envoyés par SimBench vers `PRG_02_Acquisition` (`ActualFrequencyHz`, `StatusWord`, `BrakeIsOpen_DI`, capteurs DI). Le Bit0 de `StatusWord` est-il manipulé correctement ?
5. **Recommandations concrètes** : Quels ajustements ciblés apporter dans `FB_Sim_Translation` pour obtenir une cinématique réaliste sans sur-complexification mathématique ?

Format de réponse attendu : Structuré, factuel, citant les lignes de code et variables exactes, avec des conclusions claires.
