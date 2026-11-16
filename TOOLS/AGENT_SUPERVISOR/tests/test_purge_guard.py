"""Garde R29 (fix + guard, incident prove 2026-11-16) : kill_port_listeners ne doit
JAMAIS tuer hors de la colonne LOCALE du port demande.

Preuves de l'incident (journal du service) : un serveur de test demarre sur port=0
executait kill_port_listeners(0) ; le filtre sous-chaine ':0 ' matchait la colonne
DISTANTE 0.0.0.0:0 de chaque ligne LISTENING et tuait tous les listeners reels :
8081 (TM), 8082 (superviseur), VS Code, et meme une tentative sur pid 4 (System.exe).
"""
from __future__ import annotations

import os
from unittest.mock import patch

from TOOLS.AGENT_SUPERVISOR.scripts import supervisor_server

# Lignes netstat factices : les vraies formes du journal du 2026-11-16 + cas d'ecole.
NETSTAT_FAKE = "\n".join([
    "  Proto  Adresse locale         Adresse distante       Etat           PID",
    "  TCP    127.0.0.1:8082         0.0.0.0:0              LISTENING       27672",   # vrai superviseur
    "  TCP    127.0.0.1:8081         0.0.0.0:0              LISTENING       8744",    # vrai TM
    "  TCP    0.0.0.0:5354           0.0.0.0:0              LISTENING       4",       # System, remote :0
    "  TCP    192.168.1.20:5040      0.0.0.0:0              LISTENING       10245",   # aut listener systeme
    "  TCP    [::]:8082              [::]:0                 LISTENING       27672",   # doublon ipv6
    "",
])


def _killed_pids(port):
    """Execute kill_port_listeners avec netstat factice, rend la liste des pids tues."""
    import signal
    killed = []

    def fake_netstat(*_args, **_kwargs):
        class Completed:
            stdout = NETSTAT_FAKE
        return Completed()

    def fake_kill(pid, sig):
        killed.append(pid)

    with patch.object(supervisor_server.subprocess, 'run', fake_netstat), \
         patch.object(signal, 'SIGTERM', 15, create=False):
        with patch.object(os, 'kill', fake_kill), \
             patch.object(supervisor_server.os, 'getpid', lambda: 999999):
            supervisor_server.kill_port_listeners(port)
    return killed


def test_purge_port_0_ne_tue_rien():
    """Incident prove : port=0 doit etre ignore, jamais de kill en cascade."""
    assert _killed_pids(0) == [], "kill_port_listeners(0) doit etre une operation nulle"
    assert _killed_pids(None) == [], "kill_port_listeners(None) doit etre une operation nulle"


def test_purge_ne_tue_que_le_port_demande():
    """Seules les lignes dont l'ADRESSE LOCALE porte le port sont ciblees."""
    pids = _killed_pids(8082)
    assert 27672 in pids, "le listener local 127.0.0.1:8082 doit etre tue"
    assert [p for p in pids if p != 27672] == [], "aucun autre pid ne doit etre vise"


def test_purge_port_absent_ne_tue_rien():
    """Port non ecoute -> aucun kill (et pas de faux positif via colonne distante)."""
    assert _killed_pids(4242) == []
