**1. Trois situations qui piègent les plans**

- **Rail mouillé/boueux (mu=0,06) :** après la coupure, le chariot continue sur 0,5 à 1 m. Je corrige au joystick pendant que ça glisse. Un contact de came de 100 ms dans ce moment arme le latch → arrêt machine pour rien, alors que je ne suis pas en butée.
- **Benne qui balance :** j'amortis par petits à-coups. Un à-coup pile dans la zone 5 Hz et le variateur repart en rampe ; la benne repart en oscillation, je dois la re-stabiliser avant de poser. Cycle allongé.
- **Reprise d'homme-mort :** je relâche pour repositionner, `CommandWord` tombe, décélération 618 ms, came perdue. Le latch ne distingue pas « came perdue en approche » de « came perdue en reprise homme-mort ». Il m'arrête hors contexte butée.

**2. Ce qui m'agace / me pousse à contourner**

**Plan A1 (Latch + Reset)**
- Où est le Reset ? S'il est au pupitre IHM et pas au joystick, je lâche la benne, je perds 20-30 s et je bloque le cycle. Sur une drague, on ne quitte pas le siège.
- Le « sens opposé obligatoire » me force à reculer alors que la benne est au-dessus de la trémie. C'est précisément ce que je veux éviter.
- Latch sur rebond capteur = arrêt pour un parasite. Je finirai par le shunter.

**Plan B2 (5 Hz sur 5 m)**
- 5 m à 5 Hz, c'est doubler la phase d'approche. Sur 200 cycles, 30-45 min de production/jour.
- À 5 Hz en limite de couple, le chariot « n'avance plus », la benne racle. Tentant de repasser en MANU et de pousser le joystick pour franchir les 5 m.

**3. Trois critères d'acceptation opérateur**

1. Reset accessible au joystick, <2 s, sans quitter le siège ; latch insensible aux contacts <300 ms.
2. Surcoût du 5 Hz mesuré sur 20 cycles réels : ≤3 s/cycle, sinon cadence non tenue.
3. Latch explicite : voyant + cause affichée, distinction nette arrêt normal / arrêt butée, et reprise possible sans déverrouillage lourd quand la came revient dans la fenêtre des 115 ms.