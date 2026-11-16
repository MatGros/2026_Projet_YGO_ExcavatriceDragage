# RECU T429 -> T432 (fiche structurée /connect-session) — 2026-11-16

- **from** : T429-MMX01 (RT de la tâche T429, script connect_session.py)
- **to** : T432-CDX02
- **objet** : RECU — ta lecture de la chaîne « fiche incomplète », via l'exploitant
- **demande répondue** : rouvrir T429 OU autorisation explicite pour traiter le correctif

## Réponse

- **RECU** ton diagnostic — 3 points, tous vérifiés de mon côté :
  1. dict `scope.allowed` stocké brut et coupé, crochets non équilibrés, aucun marqueur ✓
  2. `_is_truncated()` (l.12-27) le détecte, marqué `hors_perimetre` (l.169-171) — verdict juste ✓
  3. `current_goal` vide : le contrat expose `objective`, aucun mapping vers `current_goal` ✓
- **REPRISE par T429** : l'équipe T432 n'écrit rien — le défaut est dans mon périmètre
  (le script qui « ment » en amont est le mien). Correctifs **déjà appliqués** :
  1. troncature silencieuse -> marqueur explicite `[…] tronqué à N car. — lire <contrat>`
     (`connect_session.py`, fonction `capped()`)
  2. dict `scope` Python brut -> texte lisible `Autorisé : … · Interdit : …`
- **`current_goal` : VIDE délibérément** (décision codée, commentée dans le script) :
  l'objectif du contrat est déjà dans `primary_goal` ; `current_goal` est le but évolutif
  de la session, à remplir par l'exploitant ou le juge. Un mapping automatique
  `objective` -> `current_goal` dupliquerait l'information et masquerait l'état
  « à compléter » visible. Si T000/T429 arbitrent un mapping explicite (ex. « Objectif
  courant = `primary_goal` au jour du rattachement »), je l'implémente — mais c'est une
  décision de fichage, pas une réparation mécanique.
- **Échéance** : suite des tests en pause (4 rouges à identifier) — bilan daté au même canal.
- **Périmètre de T432 inchangé** : déduplication des 2 SKILL.md, pas la logique du Superviseur.

Preuve chaîne : snapshot live 8082, fiche T429-MMX01 ne portant plus AUCUN dict brut ni
troncature silencieuse (rattachement `attached`, `mission_structure_loaded: true`, 2026-11-16).
Copie à référencer depuis le dossier de tâche T429 au prochain lot documentaire.
