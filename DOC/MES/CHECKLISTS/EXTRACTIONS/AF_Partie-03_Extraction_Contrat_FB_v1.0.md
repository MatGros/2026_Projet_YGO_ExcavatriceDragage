# Extraction de specifications - AF Partie 03 Contrat FB (v1.0)

> Source analysee : `DOC/AF_Partie-03_Contrats_Composants_v2.1.md`.
> Statut : fiche de conservation pour la future Partie 03. Elle ne remplace pas l'AF03.

## A conserver sans regression

| Domaine | Exigence |
|---|---|
| 🧩 Responsabilite | Un FB metier = une responsabilite. Composition, pas heritage ; internes prives. |
| 📚 Reutilisation | Reutiliser les bibliotheques CODESYS disponibles avant de creer une brique specifique. |
| 🛑 Arrets | Precedence `Enable` > `SafeStop` > `StartStop` pour les FB de mouvement uniquement. |
| 🔑 Reset | Front interne obligatoire ; effacement seulement si cause disparue ; aucun redemarrage automatique apres defaut. |
| 🚦 Etat | `State` decrit la phase, `ErrorId` les causes cumulees et `StateAtError` fige la phase du premier defaut jusqu'a acquittement. |
| 🧾 Defauts | `Error := (ErrorId <> 0)` ; chaque bit est documente, pose par un seul endroit et lisible IHM. |
| 🔒 Securite electrique | AU materiel, puissance distincte de l'automate et rearmement restent proprietaires de l'AF01 v2.0. |
| 👁️ IHM | L'IHM consomme un contrat public ; elle ne traverse jamais les variables internes d'un FB. |
| 🔗 Couplage | Un appelant ne lit/ecrit pas les internes d'une autre instance ; les flux passent par interface publique typee. |

## Profils de futurs composants

| Profil | Contrat attendu |
|---|---|
| FB metier autonome | Cycle de vie explicite, diagnostic, reset, etat public et contrat de domaine. |
| FB de mouvement | Profil metier + `StartStop`, `SafeStop`, consigne et retour de mouvement appropries. |
| FB safety de domaine | Entrees qualifiees, conditions de surveillance, sorties safety explicites et diagnostic des causes. Il ne devient pas proprietaire de la mesure qu'il surveille. |
| Brique technique | Interface minimale dediee a sa fonction ; pas d'obligation artificielle de `Mode`, `State` ou `StartStop`. |
| Barriere finale sortie | Recoit une demande de sortie typee, applique les interlocks finaux et produit seule les commandes physiques autorisees. |
| Programme/page CFC | Orchestrateur de cablage : instances, contrats et ordre visuel. Il ne reimplemente pas les responsabilites des FB. |

## Contrats DUT : regles de conception a valider

- Un DUT est un contrat de frontiere, pas un type universel de « bus ».
- Son proprietaire, ses ecrivains, lecteurs, unite, polarite, duree de vie et comportement en invalidite sont explicites.
- Un contrat de commande porte une intention unique deja arbitree ou une demande brute clairement sourcee ; il ne melange pas les deux.
- Un contrat safety porte les sorties safety et leurs diagnostics de domaine ; il ne remplace pas le contrat de commande ni le contrat d'etat.
- Un contrat d'etat publie les faits et diagnostics du producteur ; il ne transporte pas les commandes de ses lecteurs.
- Les structures IHM `Cmd/State/Cfg/Bypass` restent a la frontiere IHM et ne deviennent pas les bus internes des domaines.
- `VAR_IN_OUT` reste reserve au partage intentionnel et documente d'un objet ; il ne sert pas de raccourci de cablage CFC.

## Points a redefinir dans AF03 v2

| Sujet | Decision necessaire |
|---|---|
| Interface universelle | Determiner le socle commun reel d'un FB metier sans imposer une interface artificielle aux briques, au CFC ou aux diagnostics. |
| Interface par profil | Formaliser les profils ci-dessus et les champs obligatoires/interdits de chacun. |
| Cycle de vie | Distinguer `Enable`, validite d'une donnee, disponibilite device et permission de mode : ces notions ne sont pas interchangeables. |
| Erreurs | Definir quels contrats exposent `ErrorId`, comment leurs diagnostics sont agreges et ou se fait la traduction IHM. |
| DUT | Definir un gabarit de documentation de contrat : proprietaire, producteurs, lecteurs, champs, unites/polarites, frequence, invalidite, reset et tests. |
| CFC | Definir les elements autorises dans une page CFC, la convention de disposition, la lecture des flux et la preuve de l'ordre d'appel. |
| Safety | Referencer AF01 pour la chaine puissance ; ne conserver dans AF03 que les regles generiques de precedence, reset et interfaces safety de domaine. |

## Alertes a ne pas perdre

1. `SafeStop` et `StartStop` ne sont pas des entrees universelles : ils sont reserves aux FB de mouvement.
2. Un `OR` de commandes masque souvent un arbitrage et une priorite safety. L'arbitre doit etre proprietaire, nomme et visible dans le CFC.
3. Un bus global de commandes recree une GVL fourre-tout, meme s'il est type. Le typage seul ne garantit ni producteur unique ni ordre de scan.
4. La protection ne doit pas dependre de l'ordre graphique apparent : le rattachement CODESYS et l'ordre reel doivent etre prouvables.
5. Les valeurs issues IHM, capteur ou bus sont bornees avant emploi ; les conversions sont explicites et les temps sont nommes.
