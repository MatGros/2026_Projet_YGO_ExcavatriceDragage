# 🕵️ Audit Méca M1/M2 — SafeStop avant PowerCutOff — 2026-09-15

> 📍 **Situation** : analyse statique, sans PLC ni forçage.
> 🎯 **Question** : chaque risque mécanique donne-t-il un signal/arrêt progressif avant la coupure puissance ?
> ⚠️ **Preuve** : code source versionné uniquement. Les valeurs terrain restent à mesurer.

## 🚦 Verdict immédiat

| Chaîne | Progressivité | Verdict |
|---|---|---|
| Écart M1/M2 | Warn 3 m → défaut 6 m / 800 ms → Méca E 7 m → PowerCutOff + 3 s | 🟢 Cohérente |
| Discordance contacteurs M1↔M2 | 500 ms → SafeStop → +3 s → PowerCutOff | 🟢 Cohérente |
| FdC haut | Permis montée coupé immédiatement → Méca D +3 s → PowerCutOff | 🟢 Cohérente |
| Méca B, arrêt non confirmé | +3 s → SafeStop et PowerCutOff au même scan | 🟠 Pas de pré-alarme opérateur distincte |
| Méca A, dérive au repos | Seuil 5 m → SafeStop et PowerCutOff au même scan | 🟠 Pas de pré-alarme distincte |
| Méca C, glissement benne | M1 : SafeStop 1 m puis Méca C 2 m ; M2 : seuil 2 m direct PowerCutOff | 🟠 Gradation incomplète pour M2 |
| Commande sans mouvement / retour collectif « tous off » | Le cas du 14/09 n’est pas couvert : `NoMovement` exige aujourd’hui « au moins un contacteur actif ». | 🔴 Trou T288 |

## 📊 Matrice exhaustive M1/M2

| Cause | Condition / seuil actuel | Réaction actuelle | Alerte avant coupure ? |
|---|---|---|---|
| Mou de câble | DI active | Interdit descente ; SafeStop si couplage synchro | 🟡 Permis / SafeStop selon mode |
| FdC haut | DI haut active | Interdit montée immédiatement | 🟢 Oui, Méca D seulement si non-arrêt persistant |
| Limite basse câble | Position ≤ limite | Interdit descente | 🟢 Permis seul |
| **Méca A** | Dérive à l’arrêt > **5 m** | SafeStop + PowerCutOff | 🔴 Non |
| **Méca B** | Joystick neutre + contacteurs/frein non au repos pendant **3 s** | SafeStop + PowerCutOff | 🔴 Non ; compteur interne disponible |
| **Méca C** | Glissement benne > **2 m** | SafeStop + PowerCutOff | 🟠 M1 a un SafeStop amont à 1 m ; M2 non |
| Thermique frein | DI thermique | SafeStop + PowerCutOff | ⚪ Pas de seuil logiciel intermédiaire |
| **Méca D** | FdC haut + contacteurs/frein non au repos pendant **3 s** | SafeStop + PowerCutOff | 🟢 FdC bloque déjà la montée |
| **Méca E** | Écart corrigé > **7 m** | SafeStop ; PowerCutOff après **3 s** | 🟢 Warn 3 m, défaut cycle 6 m / 800 ms |
| Sens opposé | Vitesse signée contraire pendant **1 s** | SafeStop | 🟢 Temporisé ; pas de PowerCutOff |
| Absence mouvement | Commande + frein ouvert + contacteurs actifs + 0,02 m non atteint pendant **3 s** | SafeStop | 🟢 Temporisé ; mais cas F=« tous off » exclu |
| Survitesse | Vitesse > bande apprise | SafeStop | 🟢 SafeStop seul volontaire : PowerCutOff écarté pour éviter une chute de charge |
| Discordance contacteurs M1↔M2 | Vecteurs M1/M2 différents | SafeStop après **500 ms** ; PowerCutOff après **3 s** | 🟢 Oui |

## 🔴 Incohérences / manques à décider — aucune correction appliquée

1. **T288 / incident 14-09** : sous commande, `FwdRevSpeedFeedbackOff=TRUE` inhibe `TonNoMovement`. C’est exactement la fenêtre « sorties PLC actives, contacteurs non collés, aucun mouvement » restée sans alarme.
2. **Pré-alarme Méca A/B/C** : les mesures existent dans l’état (`MecaADrift_M`, `MecaCDrift_M`, `MecaBElapsedTime`), mais il n’existe pas de seuil warning ni message avant le PowerCutOff. Leur affichage/traçage amont doit être défini avant toute réaction nouvelle.
3. **Méca C M2** : aucun équivalent à `instBucket.M1SlipDetected` (SafeStop à 1 m) n’a été trouvé pour M2 ; Méca C atteint directement le seuil 2 m puis PowerCutOff.
4. **Retour collectif** : il ne permet pas d’identifier le contacteur fautif. Toute alarme T288 doit conserver « doute retour » tant que le mouvement codeur ne confirme pas le non-actionnement.

## 🧪 Variables à capturer lors d’un essai ultérieur

Un snapshot unique couvre les causes finales M1/M2 : `Safety_300.Idx302..320` dans
`GVL_Troubleshooting.I_LevageUnitaireM1` et `.J_LevageUnitaireM2`.

Variables manquantes pour qualifier les pré-alarmes : état brut `ContactorsReleased_DI`, retour frein,
commande finale, `MecaBElapsedTime`, dérive A/C et contexte de commande. Elles ne doivent pas être
demandées au pupitre une par une : décider d’abord d’une structure diagnostic dédiée T288.

## 🏁 Conclusion

- Les deux chaînes les mieux graduées sont **synchro M1/M2** et **FdC haut**.
- T288 doit commencer par une phase **diagnostic seul**, centrée sur le trou « commande active + tous contacteurs déclarés au repos ».
- Les seuils/délais de Méca A/B/C ne doivent pas être changés sans mesures terrain et décision humaine.
