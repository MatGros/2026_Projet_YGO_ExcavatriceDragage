# 🧾 Registre de Suivi Mise en Service (v1.0)

> 🎯 **Rôle** : historique factuel des séances banc/terrain : ce qui a été fait, mesuré, constaté et décidé.
> 📌 **Source des actions à réaliser** : `DOC/PLAN_TASK_v1.0.md` §3 reste le registre maître des reliquats (`Txx`).
> 🚫 Ce registre ne remplace ni les checklists, ni la recette, ni une analyse de risque.

---

## 1. Règles d'utilisation

| Élément | Où le tracer |
|---|---|
| Test prévu et verdict Pass/Fail | Checklist métier ou `PLAN_TASK` §4 Recette |
| Mesure, anomalie, réglage, observation terrain | Ce registre |
| Code, câblage, paramètre ou décision à faire plus tard | Nouvelle ligne `Txx` dans `PLAN_TASK` §3, puis référence ici |
| Évolution code/DOC significative | `VERSION_HISTORY.md` |

**Une entrée = une séance ou un fait vérifiable.** Ne jamais effacer une entrée : ajouter une correction datée si nécessaire.

### Statuts

| Statut | Sens |
|---|---|
| 🟢 Validé | Mesure conforme, preuve disponible |
| 🟡 À surveiller | Fonctionne, seuil/comportement à confirmer |
| 🟠 Action ouverte | À réaliser, référencée par un `Txx` |
| 🔴 Bloquant | Interdit le mouvement ou la suite concernée |
| ⚪ Non testé | Pas encore exécuté |

---

## 2. Entrées de séance

### MES-003 — Palier vitesse treuils limité à 0

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Essais treuils |
| Version CODE/DOC | Version utilisée pendant la séance à confirmer |
| Périmètre | Winch M1/M2 |
| Statut | 🟠 Réglage temporaire d'essai |
| Réglage | Plafond de palier vitesse limité à `0` pour les essais treuils. |
| But | Réduire la vitesse/énergie pendant les premiers essais. |
| Vigilance | `0` n'est pas validé comme valeur d'exploitation. Vérifier le comportement réel du décodeur de paliers et les contacteurs effectivement commandés. |
| Action différée | `T64` : tracer le résultat, puis définir ou restaurer la valeur d'exploitation avant fonctionnement normal. |
| Preuves attendues | Version CODESYS, valeur IHM/PERSISTENT, paliers M1/M2 observés, états contacteurs, verdict opérateur. |

---

### MES-002 — Bypass ciblés et homing à 0 m

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Développement et préparation mise en service |
| Version CODE/DOC | Commit `96ef589` |
| Périmètre | Winch M1/M2, Translation M3, diagnostic réseau et codeurs |
| Statut | 🟡 À valider sur banc/terrain |
| Réalisé | Ajout de bypass globaux et ciblés par surveillance : Winch, Translation M3, synchronisme, benne et réseau. Persistance regroupée dans `GVL_BypassRetain`. |
| Homing | Cible d'homing unitaire M1 et M2 réglable, initialisée à `0,0 m`. Le homing à zéro ignore le capteur haut pour prendre la position courante comme référence. |
| Vigilance | Les bypass facilitent la mise en service mais masquent des protections. Vérifier leur état avant tout mouvement et les désactiver dès que le matériel concerné est validé. |
| À valider | Comportement de chaque bypass, persistance après redémarrage, homing M1/M2 à `0,0 m`, cohérence de la position et réarmement sûr. |
| Références | `96ef589`, `CODE/MAIN/GVL_BypassRetain.st`, `FB_Encoder_Homing.st`, `AF_Partie-13_Fonction_Simulation_v1.3.md` |

---

### MES-001 — Registre initial

| Champ | Valeur |
|---|---|
| Date | 2026-07-23 |
| Lieu / environnement | Documentation projet, avant prochaine séance banc ou terrain |
| Version CODE/DOC | À renseigner avant essai (`VERSION_HISTORY.md`) |
| Périmètre | Création du registre de suivi MES/REX |
| Statut | ⚪ Non testé |
| Constat | Les checklists Joystick et Translation existent. Les reliquats sont centralisés dans `PLAN_TASK`, mais aucune fiche courte ne consigne encore les résultats réels de chaque séance. |
| Décision | Utiliser ce registre dès le prochain essai. Créer ou mettre à jour un `Txx` pour tout point qui impose une action ultérieure. |
| Références | `PLAN_TASK` §3, `PLAN_TASK` §4 |

---

## 3. Modèle à dupliquer

```md
### MES-XXX — Titre court

| Champ | Valeur |
|---|---|
| Date / heure | YYYY-MM-DD HH:MM |
| Lieu / environnement | Simulation CODESYS / banc / terrain |
| Intervenants | Initiales et rôle |
| Version CODE/DOC | Tag/version export CODESYS + version checklist |
| Périmètre | Fonction, axe ou chaîne testée |
| Statut | 🟢 / 🟡 / 🟠 / 🔴 / ⚪ |
| Conditions sûres | Mode, zone dégagée, charge, simulation, autorisations |
| Essai réalisé | Action concrète et ordre d'exécution |
| Mesures / preuves | Valeurs, captures, photos, log, signature |
| Constat | Résultat observé, sans interprétation ambiguë |
| Décision | Accepté / réglage / analyse / arrêt essai |
| Action différée | `Txx` existant ou nouveau `Txx` créé dans PLAN_TASK §3 |
| Références | Checklist, AF Partie, code, schéma électrique |
```

---

## 4. Clôture d'une action

Quand une action `Txx` est réalisée :

1. Ajouter une entrée MES avec la preuve de validation.
2. Mettre le statut `✅` et la référence MES dans `PLAN_TASK` §3.
3. Ajouter un jalon dans `VERSION_HISTORY.md` si code ou documentation significative ont évolué.

⚠️ Une action sécurité reste ouverte tant que la preuve terrain et le réarmement sûr ne sont pas validés.
