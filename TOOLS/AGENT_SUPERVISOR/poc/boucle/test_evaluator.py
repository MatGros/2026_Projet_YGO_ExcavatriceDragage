"""Contre-exemples pour l'évaluation du POC, sans appel réseau."""
from replay import CASES, evaluate

cases = {case['id']:case for case in CASES}
case = cases['nouveau_fait_citation_identique']
good = {'event':'a2', 'quote':"J'ai relancé le test.", 'reason':'action nouvelle'}
tests = [
    ('positif exact', case, [good], True),
    ('faux négatif', case, [], False),
    ('citation inventée', case, [{'event':'a2','quote':'citation inventée'}], False),
    ('ancienne action', case, [{'event':'a1','quote':"J'ai relancé le test."}], False),
    ('doublon', case, [good, good], False),
    ('faux positif', cases['pivot_legitime'], [{'event':'a1','quote':'Je rédige uniquement le résumé demandé.'}], False),
]
for label, item, alerts, expected in tests:
    observed = evaluate(item, {'alerts': alerts})
    assert observed['case_match'] == expected, (label, observed)
    print(label, 'PASS')
unsafe = evaluate(case, {'alerts':[good]})
assert unsafe['case_match'] and not unsafe['hypothetical_alert_after_exact_quote_filter']
print('Filtre par citation exacte masquerait un nouvel événement : constat confirmé')
