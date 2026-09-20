# DSH05_T255D_FDC_BAS — reproduction exploratoire (hors CI officiel)

> 🏷️ Agent **DSH05** (session T255-D). Dossier renommé le 2026-09-20 : l'ancien tag `DSH01` était en
> **collision** (4 sessions distinctes — cf. `TASK_LOCKS.json`, `updated_at 2026-09-20T15:55`).

But : **reproduire par exécution** le symptôme T255-D — voyant `AnyFault` allumé, bandeau muet — à
l'arrivée d'un treuil (M1 puis M2) sur la **butte logicielle basse câble**, **trancher la sémantique de la
vue publiée** par le socle de défaut, et **mesurer** les hypothèses de mécanisme du brief de délégation.

Ces scénarios ne sont **pas** des tests de non-régression CI et ne sont **pas** enregistrés dans le registre
principal. Le runner est lancé avec un **registre éphémère hors dépôt** (voir `tests/run.py`) : aucun
fichier officiel n'est modifié. Ils sont **jetables** (skill `troubleshooting` §4ter).

```text
DSH05_T255D_FDC_BAS/
├── README.md
├── tests/
│   ├── run.py                             # registre éphémère, 4 cas (--case)
│   ├── run.bat
│   ├── test_t255d_fdc_bas_producer.st     # PRODUCTEUR  : FB_Safety_Winch
│   ├── test_t255d_fdc_bas_exploratory.st  # CONSOMMATEUR : harnais PRG_07
│   └── test_t255d_fdc_bas_hypotheses.st   # MÉCANISME (A) : masquage par EncM1Valid
└── reports/                               # sorties locales, régénérables
```

## Résultats mesurés sur le code du 2026-09-20 (aucun correctif)

| Cas (`--case`) | Test | Résultat |
|---|---|---|
| `producer` | `T255D-PROD-1` limite basse câble **seule** ⇒ `Fault.Error` (vue LIVE) | **PASS** |
| `producer` | `T255D-PROD-2` ⇒ `ErrorId = 16#0040` et **`Latched = FALSE`** | **PASS** |
| `consumer` | `T255D-REPRO-M1-A1`/`-M2-A1` la cause active est exposée par un canal du bandeau | **FAIL (symptôme)** |
| `consumer` | `T255D-REPRO-M1-A2`/`-M2-A2` le texte d'action nomme la cause | **FAIL (symptôme)** |
| `banner-hyp` | `T255D-HYP-A1` défaut **latché bloquant** (MecaB) actif, matériel sain ⇒ visible | **PASS** |
| `banner-hyp` | `T255D-HYP-A2` même cause + codeur M1 perdu ⇒ **masquée par le parent ECAT** | **PASS** |
| `banner-ref` | fichier de test **officiel** du bandeau (non modifié), registre réparé localement | **15/19 — 4 rouges pré-existants** |

⇒ **La limite basse câble seule allume la vue LIVE sans aucun défaut latché** (producteur) ; le bandeau
**n'expose cette cause par aucun canal** (consommateur) ; le mécanisme (A) de masquage par flag de validité
**existe et est mesuré**, mais il affiche une alarme **parente** — il n'explique donc pas un bandeau vide.

## Réparation locale du registre (pour `banner-*` seulement, jamais officielle)

L'entrée officielle `FB_Hmi_BannerFormatter` est inutilisable : **13 sources absentes**
(`CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/`, retiré du dépôt) **et une source manquante non
déclarée** (`E_CycleDepthStopMode.st`, requise par `ST_CycleCfg.st` qui est listée). `run.py` retire les
sources inexistantes et ajoute l'enum manquante **dans le registre éphémère uniquement**, et affiche ce
qu'il a retiré ou ajouté. Décision D4 du contrat T255-D.

## Lancement

Un cas à la fois (le pool multi-processus du runner est refusé sous sandbox : `PermissionError [WinError 5]`
sur création de pipe nommé — ce n'est pas un défaut des tests).

```text
tests\run.bat --case producer
tests\run.bat --case consumer
tests\run.bat --case banner-hyp
tests\run.bat --case banner-ref
python tests/run.py --case consumer --debug
```

Rapport écrit dans `reports/` ; un échec de compilation ou d'assertion est conservé pour diagnostic.
