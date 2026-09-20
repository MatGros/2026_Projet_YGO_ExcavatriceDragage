(* Mode de remise a zero AUTOMATIQUE du compteur JOURNALIER de prelevements.
   Reglage IHM persistant : le comportement se choisit par parametrage, sans modifier le code.
   ⚠️ Le compteur TOTALISATEUR (_CycleSampleCountTotal) n'est JAMAIS concerne par ce
   reglage : aucun mode ne l'ecrit, aucun chemin de RAZ n'existe pour lui.
   🔒 Repli sur valeur non reconnue (memoire persistante restauree hors plage, saisie IHM
   invalide) : aucun des deux modes n'est alors reconnu, donc AUCUNE RAZ automatique ->
   comportement NEVER, le plus conservateur. Le compteur journalier ne peut pas etre efface
   par accident. *)
TYPE E_CycleSampleCountResetMode :
(
    NEVER              := 0, // Defaut : RAZ manuelle IHM uniquement (comportement historique, aucun changement)
    ON_FIRST_START     := 1, // RAZ au premier demarrage de cycle apres mise sous tension de l'automate
    ON_SAFETY_REARM    := 2  // RAZ au rearmement de la chaine AU (contacteur puissance reengage)
);
END_TYPE
