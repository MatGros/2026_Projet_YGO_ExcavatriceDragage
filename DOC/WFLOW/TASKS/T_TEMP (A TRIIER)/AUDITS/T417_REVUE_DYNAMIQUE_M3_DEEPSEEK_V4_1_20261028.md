## Verdict : **PASS** (sous une réserve de preuve nommée)

**1. Patch correct et suffisant — inversion numérique bien supprimée**
Ancien code : `v=+0.004`, `μ=0.1`, `dt=0.1` → `a=-0.1` puis `v = 0.004 - 0.01 = -0.006` ❌. Nouveau code : `FreeVelocity=0.004`, `FrictionStep=0.01`, `MAX(0, 0.004-0.01)=0` ✔. Dissipation bornée à zéro dans les deux sens (`MAX`/`MIN`), aucune énergie injectée : le signe ne peut plus s'inverser par le seul frottement. Mécanique inchangée ailleurs (mêmes branches `BrakeMechanicallyOpen`, `BrakePhysicalActive`, butées).

**2. Contrat tenu sur les 4 exigences vérifiables**
- Manuel/auto identiques : branche libre pilotée par `ObsCartFree`, indépendante de `TravelDirection` → symétrie OK, et **M3-DYN-030/040** l'exercent réellement dans les deux sens à 100 ms et 10 ms, avec second pas (anti-redémarrage).
- Décembre pilotée variateur après mot 0 : **M3-DYN-010/020** hors branche libre, non touchés.
- Adhérence repos/seuil/départ : **M3-DYN-050** = 0.05→0, 0.1→0, 0.2→>0 : cohérent avec le modèle Coulomb implanté.
- Inversion réelle : **M3-DYN-060** pente −0.2 sur `v=+0.004` → `-0.006` <0 : inversion physique autorisée. Frein/bobine (**070**) et balancement secondaire (**080**) non modifiés.

**3. Preuve manquante, non inventée**
Aucun `RollingFriction_Mps2` n'est affecté dans SETUP : **030/040/050 supposent implicitement la valeur par défaut 0.1** (non fournie). Si ce défaut ≠ 0.1, 030 et 050 perdent leur sens. Par ailleurs le « 9/9 PASS ST + C++ » et la liaison G200 sont *déclarés*, non fournis ici — à restituer par l'orchestrateur. Aucune calibration terrain exigée.