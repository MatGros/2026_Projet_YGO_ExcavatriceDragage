# Registre d'actions — T206 StartupFail / verrouillage AU

| Action | Décision / preuve attendue |
|---|---|
| Qualification | C4 : la condition intervient dans l'autorisation de réarmement de la chaîne AU. |
| Stratégie | Patch local du FB et de son harnais, sans interface publique ni câblage PRG modifié. |
| Origine | `StartupFail` démarre le verrouillage au scan de l'échec ; l'horloge ne dépend ni du retour de chaîne ni de Reset. |
| Reset | Reset acquitte `StartupFail` mais ne doit jamais écourter le délai déjà entamé. |
| Armable | `Armable=FALSE` tant que `StartupFail=TRUE` ou que le verrouillage de démarrage est actif, en plus des préconditions existantes. |
| Séquence | Pendant ce verrouillage, un front `ArmRequest` ne quitte pas IDLE et aucune impulsion ne sort. |
| Architecture | Ne pas confondre l'origine `StartupFail` avec le lockout d'échec contacteur, actuellement annulable par Reset. |
| Non-régression | Les règles existantes Enable, PowerCutOff, IHM, redondance et lockout contacteur restent inchangées. |
