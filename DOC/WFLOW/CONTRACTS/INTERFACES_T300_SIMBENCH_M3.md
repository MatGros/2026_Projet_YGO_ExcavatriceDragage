# T300 — Contrats d'interfaces SimBench M3

Statut : modèle V1 synthétique réduit implémenté. Les constantes marquées `SYNTHETIQUE` servent aux essais exploratoires et ne valent pas calibration terrain. Les interfaces force/puissance, masse/transmission, défauts frein injectés et StatusWord constructeur décrits plus bas restent `BLOCKED_DATA` : elles ne sont pas simulées par cette V1 fréquence + frein temporisé + pendule réduit.

## Boucle et propriété des données

```text
PRG_06.Data.TranslationFinalApplied (scan N)
 → PRG_02 / FB_SimBench (scan N+1)
 → FB_Sim_TranslationDrive
 → FB_Sim_TranslationBrake + FB_Sim_SuspendedLoad
 → 5 × FB_Sim_PositionSensor
 → HwSim.Translation → HwIn.Translation
 → PRG_05 et blocs métier inchangés
```

Le retard nominal d'un scan est inclus dans tous les chronogrammes. `PRG_06` est producteur unique des ordres appliqués. `FB_Sim_Translation` est l'unique intégrateur de position/vitesse chariot ; `FB_Sim_SuspendedLoad` est producteur de l'angle, vitesse angulaire et réaction réduite. L'estimateur applicatif reste un observateur indépendant.

## Bus inter-PRG cible

Ajouter au bus final existant un sous-ensemble explicite :

| Champ | Type/unité | Producteur | Consommateur simulation |
|---|---|---|---|
| `TranslationDriveControlWord` | `WORD` | sortie finale de l'interlock PRG_06 | Drive |
| `TranslationDriveFrequencyCmd_Hz` | `REAL`, Hz | sortie finale avant conversion PDO | Drive |
| `TranslationBrakeReleaseCmd` | `BOOL` | sortie finale PRG_06 | Brake |
| `TranslationPowerAvailable` | `BOOL` | état puissance effectivement applicable | Drive/Brake |

Le nom définitif du DUT suit `ST_OutputsInterPrg` existant. Le scope T300 doit autoriser ce DUT et PRG_06. Les variables physiques globales restent affectées par PRG_06 pour le matériel, sans devenir l'interface du modèle.

## Interfaces fonctionnelles proposées

### `FB_Sim_TranslationDrive`

Entrées : `Enable`, contrôle/sens final, `FrequencyCmd_Hz`, `PowerAvailable`, `BrakeMechanicallyOpen`, `LoadReactionForce_N`, `CycleTimeS`, configuration. Sorties : `ElectricalFrequencyOut_Hz`, `MotorSpeed_Rpm`, `DriveForce_N`, `StatusWord`, `Ready`, diagnostics saturation. Le drive ne possède aucun état du frein ni position mécanique.

### `FB_Sim_TranslationBrake`

Entrées : `Enable`, `ReleaseCmd`, `PowerAvailable`, `CartSpeedMps`, `CycleTimeS`, configuration et défauts injectés. Sorties distinctes : `CoilEnergized`, `MechanicallyOpen`, `AuxContactOpen`, `BrakeForce_N`. Une perte de puissance conduit vers l'état sûr défini après identification technologique. Le contact ne confirme jamais avant l'état mécanique.

### `FB_Sim_SuspendedLoad`

Entrées : `DriveForce_N`, `BrakeForce_N`, `CycleTimeS`, configuration, commande de réinitialisation explicite. États/sorties : position/vitesse chariot, angle/vitesse angulaire, réaction de charge, énergie et bornage. Modèle réduit à quatre états, petit angle, intégration semi-implicite ou RK2 avec sous-pas fixes `<=10 ms`. Les butées physiques absorbent/dissipent selon configuration ; elles restent distinctes des seuils capteurs.

### `FB_Sim_PositionSensor`

Entrées : `CartPositionM`, seuil/fenêtre, polarité, hystérésis, délais ON/OFF, `CycleTimeS`, scénario d'intermittence et graine. Sorties : `RawDetected`, `ElectricalOutput`, `TransitionCount`, `EpisodeActive`. Les recroisements mécaniques et l'intermittence électrique sont deux modes séparés. Un épisode tire ses paramètres une fois et ne se réarme pas sur ses propres fronts.

### `FB_Sim_Translation`

Compose Drive, Brake, mécanique et cinq capteurs. Il publie la vérité mécanique uniquement en diagnostic SimBench, puis les retours matériels via `ST_HwTranslation`. Désactivation : politique cible `HOLD` par défaut ; un `ResetScenario` conscient replace à une position configurée. L'override des capteurs remplace uniquement les DI publiées et laisse la mécanique évoluer ; à sa sortie, les DI reprennent l'état courant sans reseed caché.

## Configuration et inconnues bloquantes

Chaque FB composite reçoit un `ST_fb<Nom>_Cfg` selon NC-110. Les configurations contiennent unités, bornes et provenance. La trace terrain fixe provisoirement : rampes 18–20 Hz/s, GV 40 Hz, PV 10 Hz, réponse fréquence du premier ordre de constante 0,15 s, ouverture frein 0–100 ms et fermeture 80–100 ms après vitesse nulle. Restent `INCONNU` : type/mode moteur AC600, table complète du `StatusWord`, technologie exacte du frein, masse chariot, transmission et géométrie/polarité des capteurs hors PV active bas. Ces inconnues restent configurables et `SYNTHETIQUE` ; elles n'empêchent pas les tests logiciels mais interdisent une conclusion de sécurité ou de fidélité terrain.

## Portee effectivement appliquee en V1

| Element | V1 effectivement codee | Non pretendu / bloque |
|---|---|---|
| Drive | rampe cible, reponse premier ordre, derating synthetique sous charge, retour frequence | couple, puissance, courant, table AC600 / `StatusWord` constructeur |
| Frein | commande bobine, ouverture mecanique et contact temporises | force de freinage, technologie bobine/redresseur, pannes colle/ouvert |
| Charge | pendule petit angle, amortissement, reaction vitesse et butee rigide | masse 10 t calibree, transmission, dissipation choc mesuree |
| Capteur | seuil cumulatif, hysteresis, retard, episode intermittent borne/rejouable | geometrie et technologie terrain qualifiees |
| Integration | sorties finales -> SimBench -> `HwSim` -> `HwIn`; G502 et TC representatifs image/decodeur | ordonnanceur CODESYS, memoires PRG_05 et securite aval : trace runtime obligatoire |

## Stimuli opérateur

Les boutons simulés appartiennent à l'image `HwSim.Operator` ou à un bus de stimuli de banc consommé à la frontière d'acquisition. `PRG_05` ne lit pas `GVL_Simulation.SimBtn*`. Priorité à figer : commande réelle sélectionnée par `HwIn.Operator`, homme-mort réel, puis arbitrage métier existant. Simulation OFF remet les stimuli au repos sans écrire les mémoires métier.
