"""Layout des artefacts generes : RESULTS/<DOMAINE>/<kind>/ (REX 2026-08).

Avant : tout a plat dans `out/`, sans lien visible avec la machine reelle.
Maintenant : un dossier par domaine metier, miroir de `CODE/` et de l'analyse
fonctionnelle (`AF_Partie-*`), pour qu'un humain retrouve les resultats d'une
fonction machine sans connaitre le nom du module Python genere.

    RESULTS/
      AU/          modules/ reports/ chronicles/     (TC-P01-*)
      TRANSLATION/ modules/ reports/ chronicles/     (TC-P11-*)
      COMMUN/      modules/ reports/ chronicles/     (briques partagees, sans TC dedie)
      _ARCHIVE/                                      (artefacts neutralises)

`chronicles/` regroupe TOUT ce qui se lit comme un resultat de test : rapports
HTML du traceur, exports CSV/JSON de banc, et diagrammes UML/FSM generes.
"""

from __future__ import annotations

import pathlib

ST2PY_DIR = pathlib.Path(__file__).resolve().parents[1]
RESULTS_DIR = ST2PY_DIR / 'RESULTS'

KINDS = ('modules', 'reports', 'chronicles')

#: POU -> domaine metier. Le prefixe le plus long gagne (FB_Translation_PositionDecoder
#: avant FB_Translation). Un POU inconnu tombe dans COMMUN : c'est volontaire, une
#: brique non classee est par defaut partagee, pas rattachee a tort a un domaine.
DOMAIN_BY_POU = {
    'FB_Safety_EmergencyManagement': 'AU',
    'FB_Sim_AU_ChainFeedback': 'AU',
    'FB_Translation': 'TRANSLATION',
    'FB_Safety_Translation': 'TRANSLATION',
    'FB_Translation_PositionDecoder': 'TRANSLATION',
    'FB_Brake': 'COMMUN',
    'FB_Ramp': 'COMMUN',
    'FB_CycleTime': 'COMMUN',
    'FB_Input': 'COMMUN',
    'FB_Test_Safety': '_ARCHIVE',
}

DEFAULT_DOMAIN = 'COMMUN'


def domain_for(pou_name: str) -> str:
    """Domaine metier d'un POU (prefixe le plus long, COMMUN par defaut)."""
    best_key = None
    for key in DOMAIN_BY_POU:
        if pou_name.startswith(key) and (best_key is None or len(key) > len(best_key)):
            best_key = key
    return DOMAIN_BY_POU[best_key] if best_key else DEFAULT_DOMAIN


def results_dir(pou_name: str, kind: str = 'modules', create: bool = True) -> pathlib.Path:
    """Dossier de resultat d'un POU pour un `kind` donne (modules/reports/chronicles)."""
    if kind not in KINDS:
        raise ValueError(f'kind inconnu: {kind!r} (attendu: {KINDS})')
    path = RESULTS_DIR / domain_for(pou_name) / kind
    if create:
        path.mkdir(parents=True, exist_ok=True)
    return path


def domain_dir(domain: str, kind: str = 'chronicles', create: bool = True) -> pathlib.Path:
    """Dossier d'un domaine explicite (quand on n'a pas de nom de POU, ex. TC-P01-*)."""
    path = RESULTS_DIR / domain / kind
    if create:
        path.mkdir(parents=True, exist_ok=True)
    return path


def iter_module_files():
    """Tous les modules Python generes, hors _ARCHIVE, tries par domaine puis nom."""
    if not RESULTS_DIR.is_dir():
        return []
    found = []
    for domain in sorted(p.name for p in RESULTS_DIR.iterdir() if p.is_dir()):
        if domain.startswith('_'):
            continue
        modules = RESULTS_DIR / domain / 'modules'
        if modules.is_dir():
            found.extend((domain, p) for p in sorted(modules.glob('*.py')))
    return found
