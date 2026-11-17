# MISE_EN_SERVICE — conventions du dossier

> Une journée de mise en service (MES) laisse **trois types de documents**. Les garder séparés et nommés comme ci-dessous, pour que tout agent ou toute personne s'y retrouve.

## 1. Fiche de suivi (document de terrain)
- Nom : `REGISTRE_Suivi_MiseEnService_<AAAAMMJJ>.md`
- Usage : suivie **pendant** la journée, étape par étape. Contient les étapes, les bits à relever, les mesures, le **Journal** horodaté et les **Constats ouverts**.
- Règles : une valeur mesurée = valeur brute + source ; ce qui n'est pas prouvé s'écrit **hypothèse** ; un événement ou un message CODESYS se consigne **dès qu'il arrive**, avec l'heure réelle (commande `date`).
- Sa **première section** renvoie vers la revue et les relevés de la journée.
- Exemple : `REGISTRE_Suivi_MiseEnService_20261117.md`.

## 2. Revue de l'agent (autocritique, après coup)
- Nom : `REVUE_<ACTEUR>_MES_<AAAAMMJJ>.md` (ex. `REVUE_TORC-CC10_MES_20261117.md`).
- Usage : lue **après** la journée. Ce qui est fait et vérifié, les erreurs de l'agent à ne pas répéter, ce qui reste à améliorer.
- Règles : **ne pas dupliquer** les points ouverts de la fiche (la fiche fait foi, la revue y renvoie) ; ne pas s'auto-valider : la clôture revient à l'exploitant.

## 3. Relevés et preuves
- Dossier : `<AAAAMMJJ>_PERSISTANTES/` (CSV `Persistantes_<AAAAMMJJ>_<HHMMSS>.csv`).
- Produits par `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/snapshot_persistent.py` (lecture seule, dans la console CODESYS, projet déjà en ligne). Comparaison de deux relevés : `compare_persistent_csv.py` (Python normal, hors CODESYS).
- À copier **hors du dépôt** avant tout chargement du nouveau programme : ils ne sont commités que sur accord de l'exploitant.

## Avant de commencer une MES
1. Relever la version **réellement** présente sur l'automate (bouton « Details » à la connexion), jamais une version supposée.
2. Faire le relevé des persistantes **avant** tout téléchargement.
3. Aucune écriture sur l'automate sans décision explicite de l'exploitant.
4. Si le garde d'écriture refuse un fichier : donner le contenu à l'exploitant, ne pas chercher un autre dossier.
