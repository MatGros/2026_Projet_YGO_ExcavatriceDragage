"""R29 (correction de terminologie exploitant 2026-11-23) : renommage unique des termes.

"coordination" = POSTE (coordination d'une TACHE, workflow). L'orchestrateur est un autre
poste (T000-*/TORC-*) : il ne faut plus melanger. Ce script renomme identifiants et textes
visibles ; il conserve des alias historiques pour ne rien casser.
Usage unique : python TOOLS/AGENT_SUPERVISOR/tests/rename_orchestrator_terms.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def rename_service():
    path = ROOT / 'TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py'
    text = path.read_text(encoding='utf-8')
    pairs = [
        ('COORDINATION_DEFAULT_CADRAGE', 'ORCHESTRATOR_DEFAULT_SOCLE'),
        ('COORDINATION_JUDGE_NOTICE', 'ORCHESTRATOR_JUDGE_NOTICE'),
        ('is_coordination_session', 'is_orchestrator_session'),
        ('_detect_coordination_conflicts', '_detect_orchestrator_conflicts'),
        ("SESSION DE COORDINATION (role orchestrateur/coordinateur, alias T000-*/TORC-*)",
         "SESSION D'ORCHESTRATION (orchestrateur, alias T000-*/TORC-*)"),
        ('Conflit de coordination', "Conflit d'orchestrateurs"),
        ('deux sessions de coordination (T000-*) sont', 'deux orchestrateurs actifs (T000-*/TORC-*) sont'),
        ('Session de coordination sans cadrage', "Session d'orchestration sans cadrage"),
        ('Socle coordination applique', 'Socle orchestrateur applique'),
        ('socle coordination par defaut', 'socle orchestrateur par defaut'),
        ('Coordination du projet : piloter', 'Orchestration du projet : piloter'),
        ('"Coordination (socle par defaut)"', '"Orchestration (socle par defaut)"'),
    ]
    for old, new in pairs:
        text = text.replace(old, new)
    compat = (
        "def is_coordination_session(session):\n"
        "    \"\"\"Alias historique — ATTENTION TERMES (exploitant 2026-11-23) : \"coordination\"\n"
        "    est un POSTE (coordination d'une tache, workflow) ; ce predicat detecte un\n"
        "    ORCHESTRATEUR (T000-*/TORC-*). Nom canonique : is_orchestrator_session.\"\"\"\n"
        "    return is_orchestrator_session(session)\n\n\n"
    )
    if 'def is_coordination_session(' not in text:
        index = text.find('MEMORY_SEARCH_NOTICE = (')
        text = text[:index] + compat + text[index:]
    path.write_text(text, encoding='utf-8')


def rename_client():
    path = ROOT / 'TOOLS/AGENT_SUPERVISOR/scripts/connect_session.py'
    text = path.read_text(encoding='utf-8')
    for old, new in [
        ('Coordination du projet par', 'Orchestration du projet par'),
        ('Coordination (sans contrat par conception', 'Orchestration (sans contrat par conception'),
        ('"Coordination : DOC/WFLOW/TASKS', '"Orchestration : DOC/WFLOW/TASKS'),
        ('Template coordination', 'Template orchestrateur'),
        ('Fiche coordination generique', 'Fiche orchestrateur generique'),
        ('(T000/TORC : sans contrat par conception)',
         "(orchestrateur hors catalogue : sans contrat par conception)"),
    ]:
        text = text.replace(old, new)
    path.write_text(text, encoding='utf-8')


def rename_tests():
    for rel in ('TOOLS/AGENT_SUPERVISOR/tests/test_torc_inactivity.py',
                'TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py',
                'TOOLS/AGENT_SUPERVISOR/tests/test_connect_session.py'):
        path = ROOT / rel
        if not path.exists():
            continue
        text = path.read_text(encoding='utf-8')
        for old, new in [
            ('Coordination du projet', 'Orchestration du projet'),
            ('Coordination (sans contrat', 'Orchestration (sans contrat'),
            ('Fiche coordination generique', 'Fiche orchestrateur generique'),
            ('startswith(\'Coordination\')', "startswith('Orchestration')"),
            ('is_coordination_session', 'is_orchestrator_session'),
            ('test_fiche_torc_template_coordination', 'test_fiche_torc_template_orchestrateur'),
        ]:
            text = text.replace(old, new)
        path.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    rename_service()
    rename_client()
    rename_tests()
    print('renommages orchestrateur appliques')
