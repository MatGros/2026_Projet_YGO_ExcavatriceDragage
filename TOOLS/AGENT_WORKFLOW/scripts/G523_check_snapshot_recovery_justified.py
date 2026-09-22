#!/usr/bin/env python3
"""G523 - Restauration depuis un snapshot : ne JAMAIS agir sans avoir lu le catalogue (G523).

Classe de bug couverte : un orchestrateur a conclu a tort qu'un lot de code avait ete
EFFACE ACCIDENTELLEMENT, en se fondant sur DEUX snapshots du gate G390 (marqueurs presents a
10:14, absents a 10:44) SANS lire le catalogue. Or DOC/WFLOW/TASKS.yaml portait, dans le
`contexte` de la tache, la mention explicite : "ENTIEREMENT ANNULEE ET REVERTEE ... 125 lignes
de code non commitees supprimees (git checkout)". Il a donc commence a RE-INSERER du code
volontairement supprime avant de decouvrir la mention.

Classe d'erreur interdite : AGIR (restaurer / ecraser) sur la base de snapshots de fichiers,
sans avoir confronte le catalogue (DOC/WFLOW/TASKS.yaml) et le registre d'orchestration
(DOC/WFLOW/TASKS_ORCHESTRATOR.yaml).

Ce gate ECHOUE si :
  1. un `--task <ID>` porte un marqueur de retrait documente dans son catalogue (contexte /
     avancement / description) ou dans les entrees du registre d'orchestration qui le
     mentionnent (id/sujet) : un retrait est un acte VOLONTAIRE, il ne doit pas etre defait
     par quelqu'un qui n'a lu que des snapshots ;
  2. en mode `--scan`, un fichier CODE/**/*.st MODIFIE dans l'arbre de travail est concerne
     par une entree du catalogue qui porte un marqueur de retrait (contradiction : on ecrit
     dans un fichier dont le retrait est documente).

Marqueurs de retrait documente (insensibles a la casse ET aux accents) : `revert`, `reverte`,
`annul`, `abandonn`, `on oublie`, `supprim`, `git checkout`, `plus le bon sujet`.

⚠️ Affinage `supprim` (faux positif 2026-09-22) : une occurrence `supprim` introduite par une
negation (« aucune suppression », « aucune assertion supprimée », « ne pas supprimer ») est une
mention NEUTRE, PAS un retrait documente — le code n'est pas retire. Seul un retrait reel
(« 125 lignes supprimees (git checkout) », REX T367) demeure bloquant.

Trois modes :
  python G523_check_snapshot_recovery_justified.py [racine]            (usage)
  python G523_check_snapshot_recovery_justified.py [racine] --task <ID> [--file <chemin>]
  python G523_check_snapshot_recovery_justified.py [racine] --scan    (gate, rien n'est ecrit)
  python G523_check_snapshot_recovery_justified.py [racine] --selftest

`--file <chemin CODE/...>` (option du mode --task) ne change JAMAIS le verdict : il precise le
niveau de confiance de l'arret. Si un retrait est documente :
  - et que le texte de retrait (contexte/avancement/description du catalogue, verdict/decision
    du registre) mentionne LE chemin ou LE nom de fichier passe -> message renforce
    « le retrait documente VISE ce fichier » ;
  - sinon -> « retrait documente sur la tache, fichier non nomme dans le texte ».
La ligne citee par [G523] FAIL est la ligne du champ DANS LE BLOC de la tache, jamais la
1re occurrence globale du fichier (D1 : ex. T367 -> contexte:171, avancement:177).

Echappatoire : `--acknowledge-documented-revert <justification>` — passe seulement si la
justification est NON VIDE (hors espaces blancs), teste par `ack_est_valide()` (D3).
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
import unicodedata
from contextlib import nullcontext
from pathlib import Path

# Console Windows / pipe : la sortie peut etre cp1252, qui ne sait pas encoder les emojis du
# catalogue (statut ⬜/⏳...) ni les accents. Meme garde que run_all_gates.py : UTF-8 avec
# substitution, pour ne JAMAIS crasher sur un caractere affichable dans un YAML.
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

try:
    import yaml  # PyYAML (deja utilise par G200, G470, sync_tasks, etc.)
except Exception:  # pragma: no cover - dependance partagée avec le reste du depot
    print("[G523] FAIL - PyYAML introuvable : ce gate depend du meme outillage que G200 (import yaml).")
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[3]

CATALOGUE = "DOC/WFLOW/TASKS.yaml"
REGISTRE = "DOC/WFLOW/TASKS_ORCHESTRATOR.yaml"
CODE_PREFIX = "CODE/"

# Marqueurs de retrait documente. Formes normees (sans accent, minuscules). Les radicaux
# (`revert`, `annul`, `abandonn`, `supprim`) couvrent aussi `revertee` / `annulee` /
# `abandonne`. Champs analyses : contexte / avancement / description du catalogue, et
# verdict / decision du registre.
SOUS_CHAINES = (
    "plus le bon sujet",
    "on oublie",
    "git checkout",
    "revert",
    "annul",
    "abandonn",
    "supprim",
)
# Famille `revers` : couvre `revers`, `reverse`, `reversee`, `reversée` (retrait/revoke
# documente, REX T367 ligne « annulation et reverse consignes ») SANS attraper le mot
# legitime `reversibilité` (très frequent dans les descriptions d'options de correctif) ni
# le sens directionnel « relay reverse ». Le motif exige `e` juste apres `revers` puis un
# `\b` : `reversibilite` (caractere `i` apres `revers`) et `reversible` sont donc exclus.
REVERS_FAMILLE = re.compile(r"revers(?:e{1,2})?\b")
MARQUEUR_REVERS = "revers(e/reversee) [retrait/revoke documente]"
RADICAUX_ISO = ("reverte", "annulee", "abandonne")  # deja couverts par les prefixes, documentes

CHAMPS_CATALOGUE = ("contexte", "avancement", "description")
CHAMPS_REGISTRE = ("verdict", "decision")


def sans_accent(texte: str) -> str:
    """Normalise un texte : NFKD puis suppression des accents (casse normale conservee)."""
    nfkd = unicodedata.normalize("NFKD", texte)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


# Négations qui annulent la portée d'un marqueur "supprim" : « aucune suppression »,
# « aucune assertion supprimée », « ne pas supprimer » sont des mentions NEUTRES
# (le code n'est PAS retiré), pas un retrait documenté. Un vrai retrait (REX T367 :
# « 125 lignes ... supprimées (git checkout) ») n'est jamais introduit par une négation.
NEGATIONS_SUPPRIM = ("aucun", "aucune", "rien", "ne pas", "n est pas", "jamais", "pas ")
# Fenêtre de contexte (caractères) avant une occurrence "supprim" pour chercher la négation.
FENETRE_NEGATION = 22
# Fenêtre (caractères) APRES une occurrence du nom de fichier, pour chercher un marqueur de
# retrait documenté à proximité (correction faux positif 2026-09-22).
FENETRE_MARQUEUR = 200


def _supprim_est_neutre(norme: str, m: re.Match | None = None, pos: int | None = None) -> bool:
    """Vrai si l'occurrence `supprim` est introduite par une negation.

    Peut recevoir soit un match `m` (position relative a `norme`), soit une position ABSOLUE
    `pos` dans `norme`. Ex. « aucune suppression » / « aucune assertion supprimee » =>
    neutre (PASS). Ex. « 125 lignes supprimees (git checkout) » => retrait reel (FAIL).
    """
    if m is not None:
        pos = m.start()
    if pos is None:
        return False
    debut = max(0, pos - FENETRE_NEGATION)
    contexte = norme[debut:pos]
    return any(n in contexte for n in NEGATIONS_SUPPRIM)


def marqueurs_trouves(texte: str) -> list[str]:
    """Marqueurs de retrait presents dans `texte` (insensible casse/accent).

    Sous-chaines : simple recherche de sous-chaine. La sous-chaine `supprim` est affinee :
    une occurrence introduite par une negation (« aucune suppression », « aucune assertion
    supprimee ») est une mention NEUTRE et ne constitue PAS un retrait documente (faux
    positif G523, REX 2026-09-22 : le gate attrapait « AUCUNE suppression »). Famille
    `revers` : motif regex (voir ci-dessus) applique sur le texte normalise."""
    norme = sans_accent(texte).lower()
    trouves: list[str] = []
    for m in SOUS_CHAINES:
        if m == "supprim":
            # Occurrences de la sous-chaine, en excluant celles introduites par une negation.
            for occ in re.finditer(re.escape("supprim"), norme):
                if not _supprim_est_neutre(norme, occ):
                    trouves.append(m)
                    break
        elif m in norme:
            trouves.append(m)
    if REVERS_FAMILLE.search(norme):
        trouves.append(MARQUEUR_REVERS)
    return trouves


def charger_yaml(root: Path, rel: str) -> tuple[list[dict], str] | None:
    """Charge TASKS.yaml / TASKS_ORCHESTRATOR.yaml. Retourne (donnees_liste, texte_brut).

    Accepte une liste racine (registre) OU un dictionnaire `{tasks: [...]}` (catalogue).
    Retourne None si le fichier est absent/illisible ou si aucune liste exploitable."""
    chemin = root / rel
    if not chemin.is_file():
        return None
    try:
        brut = chemin.read_text(encoding="utf-8")
    except OSError:
        return None
    try:
        donnees = yaml.safe_load(brut)
    except Exception as exc:
        print(f"[G523] FAIL - YAML illisible dans {rel} : {exc}")
        return None
    if isinstance(donnees, dict):
        for cle in ("tasks", "entrees", "items"):
            if isinstance(donnees.get(cle), list):
                donnees = donnees[cle]
                break
    if not isinstance(donnees, list):
        print(f"[G523] FAIL - {rel} n'expose pas une liste YAML de taches (racine passee en liste).")
        return None
    return donnees, brut


def _lignes_marqueur(texte_brut: str, task_id: str, marqueur: str) -> int | None:
    """Numero (1-base) de la 1re ligne du bloc de la tache qui porte CE marqueur."""
    for debut, fin in chercher_entrees(texte_brut, task_id):
        for i in range(debut, fin):
            if marqueur in marqueurs_trouves(texte_brut.splitlines()[i]):
                return i + 1
    return None


def _ligne_champ_bloc(texte_brut: str | None, task_id: str, champ: str) -> int | None:
    """Numero (1-base) de la ligne `<champ>:` DANS LE BLOC de la tache.

    D1 — ne cherche PAS sur tout le fichier (ce qui donnait le contexte de T374 pour T367) :
    on se restreint aux bornes du bloc delimitees par `chercher_entrees`."""
    if texte_brut is None:
        return None
    for debut, fin in chercher_entrees(texte_brut, task_id):
        for i in range(debut, fin):
            if re.match(rf"^\s*{re.escape(champ)}\s*:", texte_brut.splitlines()[i]):
                return i + 1
    return None


def ack_est_valide(justification: str | None) -> bool:
    """D3 — porte unique d'echappatoire `--acknowledge-documented-revert`.

    Un retrait documente est VOLONTAIRE : la seule facon de le franchir est une justification
    humaine NON VIDE (hors espaces blancs). "" et "   " sont refuses ; "raison valide" accepte."""
    return bool(justification) and bool(justification.strip())


def chercher_entrees(texte_brut: str | None, task_id: str) -> list[tuple[int, int]]:
    """Bornes (debut, fin) des blocs `- id: <task_id>` (id nu OU entre guillemets)."""
    if texte_brut is None:
        return []
    lignes = texte_brut.splitlines()
    motif = rf"^\s*-\s*id:\s*[\"']?{re.escape(task_id)}[\"']?\s*$"
    debuts = [i for i, l in enumerate(lignes) if re.match(motif, l)]
    zones: list[tuple[int, int]] = []
    for d in debuts:
        fin = len(lignes)
        for j in range(d + 1, len(lignes)):
            if re.match(r"^\s*-\s*id:", lignes[j]):
                fin = j
                break
        zones.append((d, fin))
    return zones


def trouver_marqueur(texte_brut: str, task_id: str) -> tuple[str | None, int | None, str | None]:
    """Premier marqueur trouve dans le bloc de la tache. Retourne (marqueur, ligne, extrait)."""
    zones = chercher_entrees(texte_brut, task_id)
    if not zones:
        return None, None, None
    lignes = texte_brut.splitlines()
    for debut, fin in zones:
        for i in range(debut, fin):
            ligne = lignes[i]
            for m in marqueurs_trouves(ligne):
                return m, i + 1, ligne.strip()
    return None, None, None


# ── Analyse mode `--task` (controle prealable a toute restauration) ─────────────

def analyser_tache(
    task_id: str,
    tasks: list[dict] | None,
    tasks_brut: str | None,
    registre: list[dict] | None,
    registre_brut: str | None,
) -> tuple[list[str], list[dict], dict | None, list[dict]]:
    """Retourne (marqueurs, details, entree_tache, entrees_orchestrateur). Jamais d'exception."""
    entrees = [t for t in (tasks or []) if str(t.get("id", "")).strip() == task_id]
    entree = entrees[0] if entrees else None

    orchs = []
    for e in (registre or []):
        eid = str(e.get("id", ""))
        sujet = str(e.get("sujet", ""))
        if task_id in eid or task_id in sujet:
            orchs.append(e)

    details: list[dict] = []
    # Marqueurs dans le catalogue (contexte/avancement/description). D1 : la ligne citee est la
    # ligne `<champ>:` DANS LE BLOC de la tache (ex. contexte=171, avancement=177 pour T367),
    # jamais la 1re occurrence globale du fichier.
    for champ in CHAMPS_CATALOGUE:
        valeur = str(entree.get(champ, "")) if entree else ""
        if not valeur:
            continue
        for m in marqueurs_trouves(valeur):
            ligne = _ligne_champ_bloc(tasks_brut, task_id, champ)
            source = f"{CATALOGUE}:{ligne}" if ligne else f"{CATALOGUE}:?"
            details.append({"source": source, "champ": champ, "marqueur": m, "extrait": valeur})
    # Marqueurs dans le registre d'orchestration (verdict/decision). Même logique scoped au bloc.
    for e in orchs:
        eid = str(e.get("id", ""))
        for champ in CHAMPS_REGISTRE:
            valeur = str(e.get(champ, ""))
            if not valeur:
                continue
            for m in marqueurs_trouves(valeur):
                ligne = _ligne_champ_bloc(registre_brut, eid, champ)
                source = f"{REGISTRE}:{ligne}" if ligne else f"{REGISTRE}:?"
                details.append({"source": source, "champ": champ, "marqueur": m, "extrait": valeur})
    # Secours : marqueur trouve dans le texte brut du bloc (ligne exacte, pour le message),
    # quand le champ catalogue n'est pas porte par l'entree structuree (ex. pas de contexte).
    if tasks_brut is not None and entree and not details:
        m, ligne, extrait = trouver_marqueur(tasks_brut, task_id)
        if m:
            details.append({"source": f"{CATALOGUE}:{ligne}", "champ": "bloc", "marqueur": m, "extrait": extrait})

    marqueurs = [d["marqueur"] for d in details]
    return marqueurs, details, entree, orchs


# ── Analyse mode `--scan` (gate sans argument) ─────────────────────────────────

def fichiers_modifies(root: Path) -> list[str] | None:
    """Liste des fichiers CODE/ modifies dans l'arbre de travail (git status --porcelain).
    Retourne None si git est indisponible. Ne modifie JAMAIS rien."""
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain", "--", CODE_PREFIX],
            cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
    except Exception:
        return None
    if proc.returncode != 0:
        return None
    resultat: list[str] = []
    for ligne in proc.stdout.splitlines():
        if len(ligne) < 4:
            continue
        chemin = ligne[3:].strip()
        if " -> " in chemin:  # rename : `R  old -> new`
            chemin = chemin.split(" -> ")[-1].strip()
        if chemin.endswith(".st"):
            resultat.append(chemin)
    return resultat


def analyser_scan(
    modifies: list[str],
    tasks: list[dict] | None,
    tasks_brut: str | None,
) -> list[dict]:
    """Contradictions : fichier modifie ET retrait documente le concernant. Rien n'est ecrit.

    Proximite fichier <-> marqueur (correction orchestrateur 2026-09-22, faux positif) : un
    marqueur ne constitue une contradiction QUE s'il est proche (FENETRE_MARQUEUR caracteres)
    d'une occurrence du fichier modifie dans le texte de la tache. Sans ce lien de proximite,
    le marqueur apparait dans une phrase sans rapport (ex. « supprime les recaptures » / « rien
    n a ete supprime » dans l'avancement de T346/T347 qui listent aussi d'autres fichiers).
    """
    contradictions: list[dict] = []
    for entree in (tasks or []):
        eid = str(entree.get("id", ""))
        texte = " ".join(
            str(entree.get(c, "")) for c in CHAMPS_CATALOGUE if entree.get(c)
        )
        if not texte:
            continue
        norme = sans_accent(texte).lower()
        presentes = sorted({m for m in modifies if m in texte})
        if not presentes:
            continue
        for fichier in presentes:
            nom_brut = fichier.split("/")[-1]
            if not _marqueur_proche_fichier(norme, fichier, nom_brut):
                continue
            # Correction orchestrateur D1-scan (meme defaut que D1 dans le chemin --task) : citer la
            # ligne du BLOC de la tache concernee, jamais la 1re occurrence `contexte:` du fichier.
            # On cite le champ qui PORTE reellement le marqueur (le marqueur peut venir de
            # `avancement` ou `description`, pas seulement de `contexte`).
            ligne = None
            for champ in CHAMPS_CATALOGUE:
                valeur_champ = str(entree.get(champ, ""))
                if valeur_champ and marqueurs_trouves(valeur_champ):
                    ligne = _ligne_champ_bloc(tasks_brut, eid, champ)
                    break
            contradictions.append({"fichier": fichier, "tache": eid, "ligne": ligne,
                                  "marqueur": "supprim", "extrait": texte[:140]})
            break  # une seule contradiction par entree/fichier suffit
    return contradictions


def _marqueur_proche_fichier(norme: str, fichier: str, nom_brut: str) -> bool:
    """Vrai si un marqueur de retrait non nie est A PROXIMITE d'une occurrence du fichier.

    Fait la recherche sur chaque occurrence du nom de fichier (chemin complet puis basename) :
    on regarde la fenetre [FENETRE_MARQUEUR] caracteres AVANT ET APRES chaque occurrence (la
    mention du fichier peut venir avant ou apres l'action documentee, ex. REX T367 :
    « 125 lignes supprimees (git checkout) » precede le nom du fichier). Un marqueur nie (ex.
    « rien n a ete supprime ») ou situe sans rapport (ex. « supprime les recaptures » d'un autre
    sujet) n'est PAS retenu — c'est la correction du faux positif 2026-09-22.
    """
    for cible in (fichier.lower(), nom_brut.lower()):
        for occ in re.finditer(re.escape(cible), norme):
            debut = max(0, occ.start() - FENETRE_MARQUEUR)
            fin = min(len(norme), occ.end() + FENETRE_MARQUEUR)
            contexte = norme[debut:fin]
            if REVERS_FAMILLE.search(contexte):
                return True
            for m in SOUS_CHAINES:
                if m == "supprim" and m in contexte:
                    # Position ABSOLUE de l'occ. supprim (pas la tranche) : la negation peut
                    # tomber juste avant les bornes de la fenetre, elle serait coupee si on
                    # cherchait seulement sur la tranche (faux positif 2026-09-22).
                    for occ_m in re.finditer(re.escape(m), contexte):
                        abs_pos = debut + occ_m.start()
                        if not _supprim_est_neutre(norme, None, abs_pos):
                            return True
                elif m != "supprim" and m in contexte:
                    return True
    return False


# ── Selftest ──────────────────────────────────────────────────────────────────

def _extraire(det: dict) -> str:
    return f"{det['source']} - marqueur '{det['marqueur']}' (champ {det['champ']})"


def selftest() -> int:
    """Cas synthetiques dans le temp systeme. SANS dependre du contenu reel du depot."""
    echecs: list[str] = []
    n_asserts = 0

    def verifier(ok: bool, libelle: str) -> None:
        nonlocal n_asserts
        n_asserts += 1
        if not ok:
            echecs.append(libelle)

    # ── Donnees synthetiques : construction DETERMINISTE, sans regex ──────────────
    # Historique (correction orchestrateur, 2026-09-22) : la version precedente parsait un
    # mini-YAML par regex avec `(?:.*\n)*?` + DOTALL. Avec DEUX taches, ce motif avalait la
    # seconde : le jeu de donnees rendu etait FAUX ( {'id': 'T499', 'contexte': '... de T500'} )
    # et le test devenait complaisant, incapable de distinguer la ligne du bloc de celle d'une
    # tache precedente. On construit donc le document ligne a ligne : plus d'ambiguite possible.
    def document(taches: list[tuple[str, str, str]]) -> tuple[list[dict], str]:
        """(entrees, texte_brut) pour N taches (id, statut, contexte).

        Numeros de ligne garantis : pour la i-eme tache (i a partir de 0),
        `- id:` = 2 + 3*i et `contexte:` = 4 + 3*i (1-base, la 1re ligne etant `tasks:`)."""
        lignes = ["tasks:"]
        entrees: list[dict] = []
        for tid, statut, contexte in taches:
            lignes.append(f"- id: {tid}")
            lignes.append(f"  statut: {statut}")
            lignes.append(f"  contexte: '{contexte}'")
            entrees.append({"id": tid, "contexte": contexte})
        return entrees, "\n".join(lignes) + "\n"

    NEUTRE = ("T100", "⏳", "Tache ordinaire, aucun retrait.")
    RETRAIT = ("T200", "⬜", "ENTIEREMENT ANNULEE ET REVERTEE 125 lignes (git checkout).")
    REVERTE = ("T201", "⬜", "Lot reversee sans accent.")
    ACCENT = ("T300", "⬜", "REVERTÉE ENTIÈREMENT.")

    # Chemin de catalogue ABSENT, sous le temp systeme hors depot (tempfile.gettempdir()),
    # jamais materialise : la sandbox bloque toute creation/suppression hors workspace, et
    # le cas (h) n'a besoin que d'un chemin qui n'existe pas -> charger_yaml renvoie None.
    tmp_root = Path(tempfile.gettempdir()) / "g523_selftest_absent.yaml"
    with nullcontext(tmp_root) as tmp:
        # (tmp_root sert a (h) : chemin ABSENT -> charger_yaml doit renvoyer None sans traceback)

        # (a) « revertee » sans accent -> FAIL.
        tasks_a, brut_a = document([REVERTE])
        marqueurs, det, entree, _ = analyser_tache("T201", tasks_a, brut_a, [], None)
        verifier(bool(marqueurs), "(a) 'revertee' sans accent non detecte")
        if not marqueurs:
            echecs.append("(a) FAIL attendu (retrait non accentue) non obtenu")

        # (b) « REVERTÉE » majuscules + accents -> FAIL.
        tasks_b, brut_b = document([ACCENT])
        marqueurs, det, entree, _ = analyser_tache("T300", tasks_b, brut_b, [], None)
        verifier(bool(marqueurs), "(b) 'REVERTÉE' accentue/casse non detecte")
        if not marqueurs:
            echecs.append("(b) FAIL attendu (retrait accentue) non obtenu")

        # (c) catalogue neutre -> PASS.
        tasks_c, brut_c = document([NEUTRE])
        marqueurs, det, entree, _ = analyser_tache("T100", tasks_c, brut_c, [], None)
        verifier(not marqueurs, "(c) catalogue neutre detecte un retrait (faux positif)")
        verifier(entree is not None, "(c) entree neutre absente (analyse interrompue)")

        # (d) acknowledgement : D3 — la porte est `ack_est_valide`, on teste LA FONCTION :
        #     "" et "   " refuses, "raison valide" accepte. (Plus de tautologie sur str.strip().)
        tasks_d, brut_d = document([RETRAIT])
        marqueurs_f, det_f, _, _ = analyser_tache("T200", tasks_d, brut_d, [], None)
        verifier(bool(marqueurs_f), "(d) contexte de retrait non detecte pour ack")
        verifier(not ack_est_valide(""), "(d) acknowledgement vide refuse")
        verifier(not ack_est_valide("   "), "(d) acknowledgement blanc refuse")
        verifier(ack_est_valide("raison valide"), "(d) acknowledgement non vide accepte")

        # (d2) faux positif `supprim` (REX 2026-09-22) : une mention NEGATIVE ne porte aucun
        # retrait documente. « AUCUNE suppression » et « aucune assertion supprimee » doivent
        # PASSER ; « 125 lignes supprimees (git checkout) » doit rester FAIL.
        tasks_d2, brut_d2 = document([
            ("T401", "⏳", "AUCUNE suppression, aucun deplacement : tache de reconciliation."),
            ("T402", "⬜", "Aucune assertion supprimee ni affaiblie."),
            ("T403", "⬜", "Lot reverte : 125 lignes supprimees (git checkout)."),
        ])
        m401, _, _, _ = analyser_tache("T401", tasks_d2, brut_d2, [], None)
        verifier(not m401,
                 "(d2) 'AUCUNE suppression' detecte comme un retrait (faux positif)")
        m402, _, _, _ = analyser_tache("T402", tasks_d2, brut_d2, [], None)
        verifier(not m402,
                 "(d2) 'aucune assertion supprimee' detecte comme un retrait (faux positif)")
        m403, _, _, _ = analyser_tache("T403", tasks_d2, brut_d2, [], None)
        verifier(bool(any(m == "supprim" for m in m403)),
                 "(d2) '125 lignes supprimees (git checkout)' n'est plus detecte (regression)")

        # (e) --scan avec contradiction -> FAIL, ET la ligne citee est celle du BLOC de la tache
        # concernee. Le cas comporte VOLONTAIREMENT une tache neutre AVANT la tache en retrait :
        # sans l'ancrage au bloc, le gate citerait la ligne `contexte:` de la tache neutre — le
        # test serait donc non discriminant (correction orchestrateur D1-scan). Numeros garantis
        # par `document` : T499 -> ligne 4, T500 -> ligne 7.
        tasks_e, brut_e = document([
            ("T499", "⏳", "Tache neutre sans retrait."),
            ("T500", "⬜", "Revoque (git checkout) CODE/M_MAIN/PRG_07_Supervision.st."),
        ])
        contra = analyser_scan(["CODE/M_MAIN/PRG_07_Supervision.st"], tasks_e, brut_e)
        verifier(bool(contra), "(e) --scan n'a pas vu la contradiction")
        if contra:
            verifier(contra[0]["fichier"].endswith("PRG_07_Supervision.st"),
                     "(e) fichier de contradiction incorrect")
            verifier(contra[0]["tache"] == "T500", "(e) tache de contradiction incorrecte")
            verifier(contra[0]["ligne"] == 7,
                     f"(e) ligne citee incorrecte : {contra[0]['ligne']} (attendu 7 = contexte de T500, "
                     "pas 4 = contexte de la tache neutre T499)")

        # (f) --scan sans contradiction -> PASS.
        tasks_f, brut_f = document([NEUTRE])
        contra = analyser_scan(["CODE/M_MAIN/PRG_02_Acquisition.st"], tasks_f, brut_f)
        verifier(not contra, "(f) --scan a vu une contradiction inexistante")

        # (g) ID inexistant -> FAIL explicite (entree absente, pas d'exception).
        marqueurs, det, entree, _ = analyser_tache("T9999", tasks_c, brut_c, [], None)
        verifier(entree is None and not marqueurs,
                 "(g) ID inexistant non gere (entree attendue absente)")

        # (h) catalogue absent -> FAIL explicite (chargeur renvoie None, pas de traceback).
        verifier(charger_yaml(tmp_root, "absent.yaml") is None,
                 "(h) catalogue absent non gere")

    if echecs:
        print("[G523] SELFTEST FAIL :")
        for e in echecs:
            print(f"  - {e}")
        return 1
    print(f"[G523] SELFTEST PASS - {n_asserts} assertions, 0 faux positif")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot")
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--task", metavar="ID", help="controle prealable a une restauration")
    g.add_argument("--scan", action="store_true", help="mode gate : scan CODE/ modifie")
    g.add_argument("--selftest", action="store_true", help="auto-test sur cas synthetiques")
    parser.add_argument("--file", metavar="PATH", help="fichier CODE/ concerne par la restauration")
    parser.add_argument("--acknowledge-documented-revert", metavar="JUSTIF",
                        help="assumer un retrait documente (justification non vide obligatoire)")
    args = parser.parse_args()

    root = args.root.resolve()

    if args.selftest:
        return selftest()

    if args.scan:
        modifies = fichiers_modifies(root)
        if modifies is None:
            print("[G523] FAIL - 'git status --porcelain -- CODE/' indisponible : impossible de lister les fichiers modifiees.")
            return 1
        if not modifies:
            print("[G523] PASS - aucun fichier CODE/ modifie dans l'arbre de travail (retrait documente impossible a contredire).")
            return 0
        charge = charger_yaml(root, CATALOGUE)
        if charge is None:
            print(f"[G523] FAIL - catalogue {CATALOGUE} introuvable/illisible : le scan ne peut pas confronter le catalogue.")
            return 1
        tasks, brut = charge
        contrad = analyser_scan(modifies, tasks, brut)
        if contrad:
            print("[G523] FAIL - contradiction : des fichiers modifies dans l'arbre portent un retrait documente :")
            for c in contrad:
                print(f"  - fichier {c['fichier']} | tache {c['tache']} | catalogue:{c['ligne']} | marqueur '{c['marqueur']}'")
            print("ARRET - un retrait documente est VOLONTAIRE. Ne pas re-inserer du code volontairement retire. Relire le catalogue.")
            return 1
        print(f"[G523] PASS - {len(modifies)} fichier(s) CODE/ modifie(s), aucun retrait documente le concernant dans le catalogue.")
        return 0

    # mode --task
    task_id = args.task
    charge = charger_yaml(root, CATALOGUE)
    if charge is None:
        print(f"[G523] FAIL - catalogue {CATALOGUE} introuvable/illisible : impossible de confronter le catalogue avant restauration.")
        return 1
    tasks, brut = charge
    registre = charger_yaml(root, REGISTRE)

    marqueurs, det, entree, orchs = analyser_tache(
        task_id, tasks, brut,
        registre[0] if registre else None,
        registre[1] if registre else None,
    )

    # Affiche l'entree du catalogue.
    if entree is None:
        print(f"[G523] FAIL - tache {task_id} introuvable dans {CATALOGUE} : impossible de confronter le catalogue. Ne rien restaurer sans preuve.")
        return 1
    print(f"=== Catalogue {CATALOGUE} — tache {task_id} ===")
    for champ in ("statut", "agent", "criticite", "contrat", "contexte", "avancement", "description"):
        if champ in entree:
            valeur = str(entree[champ])
            print(f"  {champ:<12}: {valeur[:400]}{'…' if len(valeur) > 400 else ''}")
    if args.file:
        print(f"  fichier (restauration): {args.file}")

    # Affiche les entrees du registre d'orchestration qui mentionnent l'ID.
    if orchs:
        print(f"=== Registre {REGISTRE} — entrees mentionnant {task_id} ===")
        for e in orchs[:8]:
            print(f"  - {e.get('id')} | {str(e.get('sujet'))[:120]}")
            print(f"    statut : {e.get('statut','')}")
            verdict = str(e.get("verdict", "")).replace("\n", " ")
            decision = str(e.get("decision", "")).replace("\n", " ")
            if verdict:
                print(f"    verdict : {verdict[:300]}")
            if decision:
                print(f"    decision : {decision[:300]}")

    if marqueurs:
        # D2 : si --file est fourni, dire si le retrait documente VISE ce fichier (niveau de
        # confiance de l'arret), sans changer le verdict. Le texte de retrait = les extraits des
        # champs catalogue + registre porteurs de marqueurs.
        if args.file:
            file_norm = str(args.file).replace("\\", "/")
            vise = any(file_norm in d["extrait"] or Path(file_norm).name in d["extrait"] for d in det)
            if vise:
                print(f"  [--file] -> le retrait documente VISE ce fichier : {args.file}")
            else:
                print(f"  [--file] -> retrait documente sur la tache, fichier non nomme dans le texte : {args.file}")
        # Retrait documente : ARRET sauf acknowledgement non vide (D3 : porte unique ack_est_valide).
        if ack_est_valide(args.acknowledge_documented_revert):
            print(f"[G523] PASS (AVERTISSEMENT) - retrait documente ASSUME : {args.acknowledge_documented_revert.strip()}")
            for d in det[:3]:
                print(f"  averti : {_extraire(d)}")
            return 0
        premier = det[0]
        print(f"[G523] FAIL - retrait documente ({premier['source']}) : ne pas restaurer.")
        print(f"ARRET - retrait documente ({premier['source']}) : ne pas restaurer. Relire le contexte de la tache avant toute ecriture.")
        for d in det[:5]:
            print(f"  - {_extraire(d)}")
            extrait = d["extrait"].strip()
            print(f"    extrait : {extrait[:220]}")
        return 1

    print(f"[G523] PASS - aucun retrait documente pour {task_id}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
