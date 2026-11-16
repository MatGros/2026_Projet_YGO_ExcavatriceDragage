"""Garde anti-incident (R29, 2026-11-16) : les tests ne touchent JAMAIS les
serveurs reels ni l'etat de l'exploitant.

Incident du 2026-11-16 : un run de la suite a coincide avec la mort des serveurs
reels (8082). Le mecanisme exact n'etait pas prouve au moment du garde ; ce conftest
verrouille les chemins plausibles quels que soient les tests :

1. bind du port 8081 ou 8082 depuis un test -> echec immediat avec message explicite ;
2. demarrage d'un service sans state_path, ou sur l'etat reel
   %LOCALAPPDATA%/ExcavatriceDragage/agent-supervision.json -> echec immediat.

L'essai legitime reste : port 0 (ephemere) ou >= 8090 + etat dans tmp_path ou
.tmpsandbox. Hors pytest, le service reel de l'exploitant n'est pas affecte.
"""
from __future__ import annotations

import http.server
import os
from pathlib import Path

import pytest

REAL_STATE = (Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.local/share')))
              / 'ExcavatriceDragage' / 'agent-supervision.json').resolve()
FORBIDDEN_PORTS = (8081, 8082)


def _refuse(why: str) -> str:
    return (f"INTERDIT EN TEST : {why} — port d'essai 0 ou >= 8090, etat dans tmp_path "
            f"ou .tmpsandbox (incident 2026-11-16).")


@pytest.fixture(autouse=True)
def forbid_real_service(monkeypatch):
    # 1. Aucun bind de test sur les ports reels, pour tout serveur (TM comme superviseur).
    original_bind = http.server.ThreadingHTTPServer.__init__

    def guarded_bind(self, server_address, *args, **kwargs):
        port = server_address[1] if isinstance(server_address, tuple) else None
        if port in FORBIDDEN_PORTS:
            pytest.fail(_refuse(f'un test ecoute sur le port reel {port}'))
        return original_bind(self, server_address, *args, **kwargs)

    monkeypatch.setattr(http.server.ThreadingHTTPServer, '__init__', guarded_bind)

    # 2. Aucun service de test sans etat isole (l'etat réel implicite est refusé).
    try:
        from TOOLS.AGENT_SUPERVISOR.scripts import supervisor_server
    except ImportError:
        supervisor_server = None
    if supervisor_server is not None:
        original_create = supervisor_server.create_server

        def guarded_create(port=8082, state_path=None, *args, **kwargs):
            if port in FORBIDDEN_PORTS:
                pytest.fail(_refuse(f'create_server(port={port})'))
            if state_path is None:
                pytest.fail(_refuse("create_server sans state_path explicite"))
            try:
                same = Path(state_path).resolve() == REAL_STATE
            except (OSError, ValueError):
                same = False
            if same:
                pytest.fail(_refuse(f"create_server sur l'etat reel : {state_path}"))
            return original_create(port, state_path, *args, **kwargs)

        monkeypatch.setattr(supervisor_server, 'create_server', guarded_create)

    yield
