# Plan d'Action — Excavatrice de Dragage

> Cocher les cases au fur et à mesure. Les étapes complètes en bleu, les en cours en orange, pas encore commencé en blanc.

---

## 📋 PHASE 1 : ARCHITECTURE & COMMUNS

- [ ] Finaliser structure données (`ST_AxisCmd`, `ST_WinchIO`, `ST_TransIO`, `ST_EncoderData`)
- [ ] Implémenter `FB_FilterPT1` (filtre premier ordre)
- [ ] Implémenter `FB_Brake` (logique frein levage)
- [ ] Mettre en place énumérations (`E_Mode`, `E_CycleStep`, `E_State`)

---

## 🕹️ PHASE 2 : ACQUISITION & TRAITEMENT

### Joystick
- [ ] Implémenter `FB_JoystickCAN` (filtrage signal Hall)
- [ ] Implémenter `PRG_JOY1` (acquisition CanTask)
- [ ] Calibrer zone morte et rampes d'accélération

### Codeurs
- [ ] Implémenter `FB_EncoderRead` (lecture EtherCAT)
- [ ] Implémenter `FB_EncoderScale` (conversion pts → mètres)
- [ ] Implémenter `FB_EncoderHoming` (référencement plan d'eau)
- [ ] Tester précision de position (±0.01 m)

### Capteurs TOR
- [ ] Configurer entrées fond touché, fdc haut/bas, positions travail/vidange/maintenance

---

## ⚙️ PHASE 3 : OBJETS MÉTIER

### Treuils (×2)
- [ ] Implémenter `FB_SpeedStep` (décodeur paliers vitesse)
- [ ] Implémenter `FB_Winch` (gestionnaire treuil)
  - [ ] Logique direction (Fwd/Rev/Neutre)
  - [ ] Séquence frein (relâche avant moteur, colle à l'arrêt)
  - [ ] Limites position (haut/bas)
  - [ ] Arrêt progressif (rampe RAMP_REAL)

### Translation
- [ ] Implémenter `FB_Translation` (régulation variateur)
  - [ ] Consigne vitesse %
  - [ ] Communication mot de commande/état variateur
  - [ ] Arrêt précis avec rampe

### Godet
- [ ] Implémenter `FB_Bucket` (calculateur désynchro)
  - [ ] Formule cinématique ouverture/fermeture
  - [ ] Vérification limites écartement treuils

---

## 🔒 PHASE 4 : COORDINATION & SÉCURITÉ

- [ ] Implémenter `FB_Safety_<Metier>` (un bloc par domaine — treuils, translation, godet…)
  - [ ] Cohérence capteurs
  - [ ] Détection valeurs absurdes
  - [ ] Levée `SafeStop` (propre au métier) en cas défaut

- [ ] Configurer la surveillance périodicité des tâches (fonction système CODESYS, seuil 200 ms — pas de `FB_Watchdog` applicatif)

- [ ] Implémenter `FB_Modes` (arbitrage sources commande)
  - [ ] Mode Manuel (joystick direct)
  - [ ] Mode Maint N1 & N2
  - [ ] Mode Semi-auto (cycle)
  - [ ] Vérification limite légale de dragage (interdiction normale, gérée ici — pas dans `FB_Safety_*`)

- [ ] Implémenter `FB_Cycle` (séquenceur semi-auto)
  - [ ] État Descente
  - [ ] État Synchro treuils
  - [ ] État Extraction
  - [ ] État Égouttage
  - [ ] État Déplacement
  - [ ] État Vidage
  - [ ] Transitions & conditions

---

## 🧪 PHASE 5 : TESTS EN ATELIER (FAT)

### Unitaires
- [ ] Test `FB_Winch` (direction, vitesse, frein)
- [ ] Test `FB_Translation` (rampe, arrêt précis)
- [ ] Test `FB_Bucket` (calcul désynchro)
- [ ] Test `FB_EncoderHoming` (calibration)

### Intégration
- [ ] Test `FB_Safety_<Metier>` (arrêts sûrs, `SafeStop` par métier)
- [ ] Test `FB_Modes` (basculement modes)
- [ ] Test `FB_Cycle` complet (toutes les étapes)

### Scénarios
- [ ] Cycle nominal (complet)
- [ ] Défaut capteur → SafeStop
- [ ] AU enfoncé → arrêt sûr
- [ ] Limite légale → arrêt
- [ ] Récupération défaut après réarmement

---

## 🚀 PHASE 6 : MISE EN SERVICE (SAT)

- [ ] Paramétrage machine (offsets, vitesses limites)
- [ ] Formation opérateurs (modes, cycle, défauts)
- [ ] Essais sur site (conditions réelles)
- [ ] Validation respect normes/sécurité
- [ ] Livraison documentation & manuels

---

## 📊 Synthèse Progression

| Phase | Étapes | ✅ | ⏳ |
|-------|--------|----|----|
| 1. Architecture | 4 | 0 | 0 |
| 2. Acquisition | 10 | 0 | 0 |
| 3. Objets métier | 12 | 0 | 0 |
| 4. Coordination | 13 | 0 | 0 |
| 5. Tests FAT | 9 | 0 | 0 |
| 6. SAT | 4 | 0 | 0 |
| **TOTAL** | **52** | **0** | **0** |

---

**Dernière mise à jour** : 2026-07-01
