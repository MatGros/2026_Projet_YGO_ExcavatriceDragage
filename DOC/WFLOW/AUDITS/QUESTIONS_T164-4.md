# Questions et confirmations finales — T164-4

Ce registre évite d'interrompre l'exécution. Il ne contient que les points qui
nécessitent une confirmation humaine lors de la remise finale ou du test CODESYS.

| ID | Point | Décision appliquée / impact | Moment de confirmation |
|---|---|---|---|
| Q1 | `PresetConfirmMode` est commun aux deux codeurs. | `GVL_IHM.Commun.EncoderCfg` est l'unique propriétaire ; les cibles de homing restent M1/M2. Si le site exige des modes de confirmation différents, il faudra une tâche dédiée avant modification. | Revue IHM et essai fonctionnel M1/M2. |
| Q2 | `PresetStatusBit` réel est inconnu. | Le câblage reste `FALSE` et le mode par défaut est `READBACK_ONLY` ; aucun signal absent ne peut confirmer un preset. | Mise en service EtherCAT/site. |
| Q3 | Compilation/import CODESYS 3.5. | Les sources et bundle seront contrôlés mécaniquement ; l'utilisateur vérifie ensuite l'import, la compilation et le comportement physique. | Après clôture 4D. |
| Q4 | Relecture preset avant commit atomique. | La confirmation utilise une mesure candidate locale `(RawPos - PendingHomingRefRaw)` ; `CablePosM` publique ne peut pas être utilisée avant le commit sans mélanger ancien et nouveau repère. | Essai preset nominal et échec 50 mm sur banc/site. |
| Q5 | Latence de vérification preset. | `PresetLatencyCycles` était absent du code ; aucune valeur arbitraire n'est ajoutée. La transaction conserve `T#500MS`, temporisation historique de maintien de commande, avant relecture. | Vérifier sur codeur EtherCAT réel que 500 ms couvre la propagation PDO. |
| Q6 | Sémantique physique du PDO preset. | Le code historique publie `PresetValue = RawPos`. Une relecture de `RawPos` peut alors réussir sans démontrer que le codeur a appliqué l'ordre. Il faut la fiche PDO/SDO : objet écrit, interprétation de la valeur (absolue ou offset) et valeur/bit réellement relu après preset. Sans cette preuve, le READBACK_ONLY fermé n'est pas implémentable de manière sûre. | Fournir le mapping EtherCAT constructeur ou constater un cycle preset réel sur banc. |
