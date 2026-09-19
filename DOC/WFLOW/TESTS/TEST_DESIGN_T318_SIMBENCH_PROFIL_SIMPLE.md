# T318 - SimBench profil simple : design de test

| Cas | Stimulus | Attendu |
|---|---|---|
| Nominal Kobold | Kobold fond TRUE, injection cable FALSE | `M2_TensionedCable_DI=TRUE`, aucun SlackCable simule |
| Injection cable | `SimM2TensionedCableFaultInject=TRUE` | `M2_TensionedCable_DI=FALSE` |
| Treuil simple | `SimWinchDynamicsActive=FALSE` | Tau/delais transmis a 0.0 |
| Treuil dynamique | Gate TRUE + reglages non nuls | Tau/delais transmis depuis GVL |
| Diagnostic electrique OFF | Gate FALSE | couple 0.0, stall FALSE, aucun signal safety ecrit |

Hors lot : retour M3 strictement pre-T300 (branche legacy necessaire), joystick (stimuli deja neutres par defaut), cycle semi-auto et textes operateur.
