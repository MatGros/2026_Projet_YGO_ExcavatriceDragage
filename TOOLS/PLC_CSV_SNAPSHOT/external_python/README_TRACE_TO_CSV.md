# Convertisseur de traces CODESYS

`trace_to_csv.py` lit hors ligne un export CODESYS `.trace` (XML UTF-16 ou UTF-8), sans connexion
au PLC et sans modifier la trace source.

## Utilisation sans ligne de commande

Double-cliquer sur [`convert_trace.bat`](convert_trace.bat) : la boîte de dialogue s'ouvre
directement dans `RESULTS/trace`, puis sélectionner la trace dans l'arborescence Windows. Le bouton
**Oui** produit le CSV large, **Non** le CSV long. Le résultat
est écrit à côté de la trace et un écrasement nécessite une confirmation. Un fichier `.trace` peut
aussi être glissé-déposé sur le `.bat`.

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py "capture.trace"
```

Le CSV long par défaut contient `Timestamp_ms;Variable;Value`. Pour Excel, utiliser le format large
(une variable par colonne et un horodatage par ligne) :

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py "capture.trace" --format wide -o "capture_wide.csv"
```

Les métadonnées peuvent être exportées en JSON avec `--metadata capture.json`. Une sortie existante
n'est jamais écrasée implicitement ; ajouter `--force` pour l'autoriser.
