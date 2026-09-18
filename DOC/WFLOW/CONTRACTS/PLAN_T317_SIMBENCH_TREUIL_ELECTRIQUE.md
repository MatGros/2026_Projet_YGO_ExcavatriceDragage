# T317 — Modèle électrotechnique treuils M1/M2 (moteur rotor bobiné + groupe électrogène)

Statut : P0 (identification), aucun code écrit. Mise à jour : 2026-09-18.

## Origine

Demande utilisateur : SimBench doit pouvoir estimer, en fonction des commandes réelles (gradin
de résistance rotorique actif, ordre de marche), le couple disponible, les courants stator/rotor
approximatifs et l'effet sur la tension du groupe électrogène (observé 400V→360V sous appel de
charge), pour tester si un enchaînement trop rapide de gradins produit une surintensité dangereuse.

Deux recherches déjà menées (research agent + challenge expert électrotechnique, 2026-09-18) : la
synthèse initiale est jugée **trop optimiste pour un usage sécurité** — elle lisse deux phénomènes
qui vont dans le même sens (sous-estimation des pics de courant / creux de tension), ce qui est le
pire cas pour valider une logique anti-surintensité. Corrections minimales identifiées avant tout
code (voir § Corrections obligatoires).

## Observations et limites de connaissance

| Donnée | Origine | Usage |
|---|---|---|
| Moteur rotor bobiné, ~200A stator | Estimation utilisateur | Point de calage I1 nominal |
| Chute tension groupe électrogène 400V→360V sous appel important | Observation utilisateur | Calage X"d ; un seul point ne suffit pas à séparer X"d de Tavr |
| Nombre de gradins rotoriques réel du coffret | INCONNU | Bloque le nombre d'états gradin_m du modèle |
| Référence moteur exacte, tension rotor, plaque signalétique | INCONNU | Bloque le calage E2, X2, R2_rotor |
| Puissance groupe électrogène (kVA) | INCONNU | Bloque X"d/X'd en valeur absolue (pu → SI) |
| Référentiel R2/X2 (stator vs rotor) utilisé par tout calcul futur | À FIXER en P1 | Erreur silencieuse si non tracé (facteur a² sur gmax) |

## Corrections obligatoires avant tout ST (issues du challenge expert 2026-09-18)

1. **Terme transitoire de commutation de gradin** : un modèle purement quasi-statique (Kloss + filtre
   1er ordre ~20-50ms) ne peut PAS représenter le pic de courant à la commutation brutale d'impédance
   rotorique (constante L2/R2_total, flux rémanent). Sans ce terme, la simulation peut dire "gradin
   trop rapide = OK" alors que le matériel réel ne l'est pas — faux sentiment de sécurité. Soit on
   l'ajoute, soit on documente noir sur blanc dans AC/limites que le modèle **ne peut pas** qualifier
   un délai minimal inter-gradin.
2. **Référentiel R2/X2 tracé explicitement** (stator ou rotor) dans les équations et le code — jamais
   implicite.
3. **R1 stator non négligée en mode génératrice** (treuil en descente / benne qui entraîne le moteur) :
   le modèle doit couvrir ce quadrant si l'objectif inclut la logique de freinage électrique/descente,
   pas seulement le démarrage.
4. **Modèle groupe électrogène** : le premier ordre (X"d→X'd, Tavr) ne produit aucune oscillation en
   cas d'appels rapprochés (plusieurs treuils/gradins en quelques centaines de ms) — sous-estime
   structurellement une sous-tension prolongée. Documenter comme limite non contournable au pas
   10-100ms, ou passer à un second ordre minimal si le budget le permet.
5. **Couplage couple ∝ U²** appliqué à C(g) complet, jamais à Cmax isolé — préciser dans le contrat
   d'interface du composant pour éviter une implémentation erronée.
6. **Toute valeur numérique du §2 de la synthèse recherche (X"d, ratios Cdém/Cnom, nb gradins)**
   reste étiquetée "hypothèse non validée terrain" tant que la plaque signalétique moteur et la fiche
   groupe électrogène ne sont pas fournies.

## Verdict recherche

Modèle exploitable pour la logique **macro** (séquencement de gradins en régime établi, cohérence
fonctionnelle gmax/glissement) — **pas** en l'état pour valider des critères de sécurité temporels
(délai minimal inter-gradin, détection surintensité réelle, comportement multi-treuils simultanés).
C'est précisément l'usage visé par la demande initiale : le scope P1 doit donc soit intégrer la
correction 1, soit réduire explicitement l'objectif à la logique macro et documenter la limite.

## Registre des questions à résoudre en P0

1. Plaque signalétique moteur M1/M2 : référence, tension rotor à l'arrêt E2, courant nominal exact,
   nombre de pôles, vitesse nominale.
2. Coffret résistances rotoriques : nombre réel de gradins, valeurs de résistance par gradin, mode
   de commutation (contacteurs, timing actuel côté CODESYS déjà implémenté dans T316).
3. Fiche groupe électrogène : puissance nominale (kVA), réactances X"d/X'd si disponibles constructeur.
4. Objectif réel à qualifier : uniquement logique macro (séquencement gradins), ou aussi sécurité
   temporelle (délai mini inter-gradin) ? Détermine si la correction 1 (terme transitoire) est
   obligatoire ou si le scope peut être réduit avec limite documentée.
5. Le modèle doit-il couvrir le quadrant génératrice (descente/freinage) dès ce lot, ou seulement le
   levage (P327/T316 couvrent déjà rampe fréquence + frein temporisé côté commande) ?

Chaque réponse est classée MESURÉE / DOCUMENTÉE / ESTIMÉE / SYNTHÉTIQUE / INCONNUE, comme pour T300.
Une INCONNUE n'empêche pas le plan mais interdit la qualification terrain de la branche concernée.

## Prochaine étape

R0 : validation humaine (Mathieu) des réponses au registre ci-dessus, en particulier Q4 (portée
sécurité vs macro) qui conditionne si la correction 1 est un blocant de scope ou une limite
documentée acceptée. Sans cette réponse, aucun code ST ne doit être écrit (guardrail AGENTS.md :
spec incomplète = pas de code).
