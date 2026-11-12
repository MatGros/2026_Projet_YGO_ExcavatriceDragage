"""Banc A/B déterministe : une contrainte posée au tour 1 reste-t-elle injectable au tour N ?

Aucun appel modèle. Mesure uniquement la PRÉSENCE de l'information dans l'entrée envoyée au juge,
pas la façon dont un modèle l'utilise. Données entièrement synthétiques.
"""
import sys

CONSTRAINT = "Ne jamais toucher aux migrations de base de données"
N_TURNS = 60
WINDOW_MSGS = 12
WINDOW_CHARS = 12000


def build_session(n):
    msgs = [{"id": "e1", "role": "user", "text": f"Consigne : {CONSTRAINT}."}]
    for i in range(2, n + 1):
        msgs.append({"id": f"e{i}", "role": "assistant" if i % 2 else "user",
                     "text": f"Étape {i} : travail courant sur le module {i % 7}."})
    return msgs


def condition_window(msgs):
    """Fenêtre glissante actuelle : les plus anciens sortent sans trace."""
    kept = list(msgs)
    while len(kept) > WINDOW_MSGS or sum(len(m["text"]) for m in kept) > WINDOW_CHARS:
        kept.pop(0)
    return kept


def condition_journal(msgs):
    """Journal en ajout seul : chaque décision utilisateur est ancrée, la fenêtre reste bornée."""
    journal = [{"id": m["id"], "text": m["text"]} for m in msgs if m["role"] == "user" and "Consigne" in m["text"]]
    return journal + condition_window(msgs)


def present(payload):
    return any(CONSTRAINT in m["text"] for m in payload)


def main():
    results = {}
    for name, fn in (("fenetre_seule", condition_window), ("journal_plus_fenetre", condition_journal)):
        ok = 0
        for n in range(1, N_TURNS + 1):
            if present(fn(build_session(n))):
                ok += 1
        results[name] = ok
    print(f"tours évalués : {N_TURNS}")
    for name, ok in results.items():
        print(f"{name}: contrainte présente dans l'entrée juge à {ok}/{N_TURNS} tours")
    # Contrôle négatif : la contrainte doit disparaître de la fenêtre seule dès que le fil dépasse la limite.
    assert results["fenetre_seule"] < N_TURNS, "contrôle négatif échoué : la fenêtre seule devrait perdre la contrainte"
    assert results["journal_plus_fenetre"] == N_TURNS, "le journal devrait conserver la contrainte à chaque tour"
    print("contrôles : OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
