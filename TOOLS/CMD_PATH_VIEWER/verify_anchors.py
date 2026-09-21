#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T353 — Verification d'ancrage par BLOB (mode statique de l'outil CMD_PATH_VIEWER).

Role : confronter le blob SHA consigne par les documents source au blob reellement mesure sur le
disque, et figer ce constat (horodate) dans data/freshness.json — c'est ce fichier qui alimente les
badges de fraicheur de l'outil ouvert en `file://` (mode statique, ou aucun recalcul n'est possible).

Regle de hash — IDENTIQUE au JS du navigateur (TOOLS/CMD_PATH_VIEWER/git-blob-sha1.js) :
    core.autocrlf = true  =>  git convertit CRLF->LF AVANT de calculer le blob, et l'en-tete porte
    la taille APRES conversion :  SHA1("blob " + taille_normalisee + "\\0" + contenu_normalise)
Sans cette normalisation, les fichiers CODE/*.st du depot sortent en faux ROUGE (cf. PREUVE §P4).

Preuves produites :
  - mode nominal           : etat de chacun des fichiers cites (VERT / ROUGE / ABSENT / NON_ANCRABLE)
  - `--preuve-p4`          : table « SHA-1 du JS execute sous Node » vs « git hash-object » (>= 5 fichiers)
  - `--fichier <chemin>`   : etat d'un fichier precis (utilise pour le test volontaire du garde-fou P3)

N'ecrit QUE sous TOOLS/CMD_PATH_VIEWER/data/. Ne touche ni CODE/, ni les documents source.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ICI = Path(__file__).resolve().parent
RACINE = ICI.parents[1]
DATA = ICI / "data"
MODULE_JS = ICI / "git-blob-sha1.js"

# Fichiers de controle de la preuve P4 (au moins 5, dont les 3 cas CRLF du 7e constat et un cas LF)
CONTROLES_P4 = [
    "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
    "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st",
    "CODE/M_MAIN/PRG_02_Acquisition.st",
    "TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv",
    "CODE/M_MAIN/PRG_06_Outputs.st",
    "CODE/G_CYCLE/FB_CycleSemiAuto.st",
    "DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md",
    "DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md",
]

PROGRAMME_NODE = r"""
'use strict';
const fs = require('fs');
const path = require('path');
const m = require(process.env.CPV_MODULE);
const controles = JSON.parse(process.env.CPV_CONTROLES);
const racine = process.env.CPV_RACINE;
const out = controles.map(function (rel) {
  const p = path.join(racine, rel);
  if (!fs.existsSync(p)) return { chemin: rel, erreur: 'ABSENT' };
  const octets = new Uint8Array(fs.readFileSync(p));
  const r = m.gitBlobSha1(octets);
  return { chemin: rel, sha1_js: r.sha1_git, sha1_js_brut: r.sha1_brut,
           taille_brute: r.taille_brute, taille_normalisee: r.taille_normalisee,
           crlf_converti: r.crlf_converti, normalisation: r.normalisation, formule: r.formule };
});
const autotest = m.autoTest();
process.stdout.write(JSON.stringify({ auto_test_js: autotest, fichiers: out }));
"""


# ═══════════════════════════════════════════════════════════════════════════════════════════
def sha1_git_depuis_octets(octets: bytes) -> dict:
    """Implementation Python de la MEME regle que le JS (controle croise des deux modes)."""
    norm = octets.replace(b"\r\n", b"\n")
    return {
        "sha1_git": hashlib.sha1(b"blob %d\0" % len(norm) + norm).hexdigest(),
        "sha1_brut": hashlib.sha1(b"blob %d\0" % len(octets) + octets).hexdigest(),
        "taille_brute": len(octets),
        "taille_normalisee": len(norm),
        "crlf_converti": octets.count(b"\r\n"),
        "lignes": octets.count(b"\n"),
    }


def git_hash_object(chemin_rel: str, racine: Path | None = None) -> str | None:
    """Reference absolue : `git hash-object <chemin>` (filtre du depot applique)."""
    r = subprocess.run(["git", "hash-object", chemin_rel], cwd=str(racine or RACINE),
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def git_head() -> str:
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(RACINE),
                          capture_output=True, text=True).stdout.strip()


def mesurer(chemin_rel: str) -> dict:
    p = RACINE / chemin_rel
    if not p.exists():
        return {"etat": "ABSENT", "message": "fichier introuvable sur le disque"}
    octets = p.read_bytes()
    imp = sha1_git_depuis_octets(octets)
    ref = git_hash_object(chemin_rel)
    imp["sha1_git_reference"] = ref
    imp["implementation_conforme"] = (ref == imp["sha1_git"])
    return imp


def test_garde_fou() -> int:
    """
    Test VOLONTAIRE du garde-fou blob (AC5) — trois etats mesures et horodates.

    Le perimetre d'ECRITURE du contrat T353 est borne a TOOLS/CMD_PATH_VIEWER/ ; il interdit toute
    ecriture sur CODE/ et sur les 3 documents source. Le test est donc conduit en DEUX volets, ce
    qui couvre la preuve exigee sans violer le perimetre :

      VOLET A (en MEMOIRE, sur 2 fichiers REELLEMENT cites par les documents, lus en LECTURE SEULE) :
        etat VERT sur les octets reels -> etat ROUGE sur les memes octets + une ligne de test ->
        retour au VERT en relisant le fichier reel. Corrobore par `git hash-object` avant / apres.
        Le depot n'est JAMAIS modifie : c'est la preuve la plus forte possible de non-residu.

      VOLET B (sur DISQUE, sur un fichier reel du perimetre autorise : git-blob-sha1.js) :
        modification reelle sur le disque, mesure ROUGE avec blob attendu vs blob mesure (outil ET
        `git hash-object`), restauration a l'octet pres, retour au VERT. Prouve le chemin
        lecture-disque + comparaison de bout en bout.
    """
    graphe = charger_graphe()
    attendus = {e["chemin"]: e.get("blob_consigne") for e in graphe["ancrage"]["blobs"]}
    horodatage = _dt.datetime.now().astimezone().replace(microsecond=0).isoformat()
    journal = {"horodatage": horodatage, "head": git_head(),
               "perimetre_ecriture": "TOOLS/CMD_PATH_VIEWER/ uniquement (contrat T353)",
               "fichiers_cites_modifies_dans_le_depot": False, "volets": {}}

    print("=" * 112)
    print("P3 — TEST VOLONTAIRE DU GARDE-FOU BLOB (3 états : avant / pendant / après)")
    print("=" * 112)
    print(f"  horodatage : {horodatage} · HEAD {git_head()[:12]}")
    print(f"  périmètre d'écriture du lot : {ICI.relative_to(RACINE)}/ — CODE/ et les 3 sources sont en LECTURE SEULE")
    print()

    # ── VOLET A : fichiers RÉELLEMENT cités, en mémoire (le dépôt n'est jamais écrit) ────────
    print("  VOLET A — fichiers RÉELLEMENT cités par les documents, test EN MÉMOIRE (lecture seule)")
    print(f"  {'fichier':52} {'état':8} {'blob mesuré (outil)':42} {'blob consigné':42} verdict  git hash-object")
    lignes_a = []
    for rel in ["TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv",
                "CODE/M_MAIN/PRG_04_Treuils_Benne.st"]:
        p = RACINE / rel
        octets = p.read_bytes()
        consigne = attendus.get(rel)
        git_avant = git_hash_object(rel)
        avant = sha1_git_depuis_octets(octets)
        pendant = sha1_git_depuis_octets(octets + b"# T353 - ligne de test volontaire du garde-fou blob\n")
        apres = sha1_git_depuis_octets(p.read_bytes())
        git_apres = git_hash_object(rel)

        def v(m):
            return "VERT" if m["sha1_git"] == consigne else "ROUGE"

        for libelle, m, gitv in (("AVANT", avant, git_avant), ("PENDANT", pendant, git_avant),
                                 ("APRÈS", apres, git_apres)):
            print(f"  {rel[:51]:52} {libelle:8} {m['sha1_git']:42} {str(consigne):42} {v(m):8} {gitv}")
        print(f"  {'':52} brut PENDANT {pendant['sha1_brut'][:12]} · CRLF convertis PENDANT {pendant['crlf_converti']}"
              f" · octets relus identiques : {'OUI' if p.read_bytes() == octets else 'NON'}")
        print()
        lignes_a.append({"fichier": rel, "blob_consigne": consigne,
                         "avant": avant["sha1_git"], "pendant": pendant["sha1_git"], "apres": apres["sha1_git"],
                         "brut_pendant": pendant["sha1_brut"], "crlf_pendant": pendant["crlf_converti"],
                         "etat_avant": v(avant), "etat_pendant": v(pendant), "etat_apres": v(apres),
                         "git_hash_object_avant": git_avant, "git_hash_object_apres": git_apres,
                         "fichier_reel_intact": p.read_bytes() == octets})
    journal["volets"]["A_memoire_fichiers_reels"] = lignes_a

    # ── VOLET B : test SUR DISQUE, dans le périmètre autorisé ────────────────────────────────
    cible_rel = "TOOLS/CMD_PATH_VIEWER/git-blob-sha1.js"
    cible = RACINE / cible_rel
    octets_origine = cible.read_bytes()
    consigne_b = git_hash_object(cible_rel)
    (DATA / "selftest.json").write_text(json.dumps({
        "objet": "auto-test du garde-fou blob sur disque (volet B de la preuve P3)",
        "fichier": cible_rel, "blob_consigne": consigne_b, "mesure_le": horodatage,
        "note": ("fichier du périmètre autorisé du lot, utilisé comme cible de test SUR DISQUE : "
                 "aucun fichier cité par les documents n'est modifiable sans sortir du périmètre."),
    }, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")

    print("  VOLET B — test SUR DISQUE, cible dans le périmètre autorisé du lot")
    print(f"  cible : {cible_rel} · blob consigné = {consigne_b}")
    etats_b = []
    for libelle, octets in (("AVANT", octets_origine),
                            ("PENDANT", octets_origine + b"/* T353 - ligne de test volontaire du garde-fou blob */\n"),
                            ("APRÈS", octets_origine)):
        cible.write_bytes(octets)
        outil = sha1_git_depuis_octets(cible.read_bytes())
        gitv = git_hash_object(cible_rel)
        etat = "VERT" if outil["sha1_git"] == consigne_b else "ROUGE"
        etats_b.append({"etat": libelle, "blob_outil": outil["sha1_git"], "blob_git": gitv, "verdict": etat})
        print(f"    {libelle:7} outil {outil['sha1_git']} · git {gitv} → {etat}"
              + ("  (attendu %s / mesuré %s)" % (consigne_b, outil["sha1_git"]) if etat == "ROUGE" else ""))
    restaure = cible.read_bytes() == octets_origine
    conforme_final = sha1_git_depuis_octets(cible.read_bytes())["sha1_git"] == consigne_b
    print(f"    restauration à l'octet près : {'OUI' if restaure else 'NON'} · blob final = blob initial : "
          f"{'OUI' if conforme_final else 'NON'}")
    journal["volets"]["B_sur_disque"] = {"cible": cible_rel, "blob_consigne": consigne_b,
                                         "etats": etats_b, "restauration_complete": restaure,
                                         "blob_final_egal_initial": conforme_final}

    ok = (all(x["etat_avant"] == "VERT" and x["etat_pendant"] == "ROUGE" and x["etat_apres"] == "VERT"
              and x["fichier_reel_intact"] and x["git_hash_object_avant"] == x["git_hash_object_apres"]
              for x in lignes_a)
          and etats_b[0]["verdict"] == "VERT" and etats_b[1]["verdict"] == "ROUGE"
          and etats_b[2]["verdict"] == "VERT" and restaure and conforme_final)
    journal["verdict"] = "PASS" if ok else "FAIL"
    (DATA / "preuve_garde_fou_T353.json").write_text(json.dumps(journal, ensure_ascii=False, indent=1),
                                                    encoding="utf-8", newline="\n")
    print()
    print(f"  verdict global : {'PASS — VERT → ROUGE → VERT dans les deux volets' if ok else 'FAIL'}")
    print(f"  journal : {DATA/'preuve_garde_fou_T353.json'}")
    print("  ⚠ CONSTAT À REMONTER : la variante « modifier SUR DISQUE un fichier cité par les "
          "documents » est HORS du périmètre d'écriture du lot (CODE/ interdit, sources interdites). "
          "Elle exige soit une extension explicite du périmètre, soit une action humaine sur un arbre gelé.")
    return 0 if ok else 1


# ═══════════════════════════════════════════════════════════════════════════════════════════
def charger_graphe() -> dict:
    f = DATA / "graph.json"
    if not f.exists():
        raise SystemExit("ERREUR : data/graph.json absent — lancez d'abord parse_cartographies.py")
    return json.loads(f.read_text(encoding="utf-8"))


def etat_de(chemin: str, blob_consigne: str | None, mesure: dict) -> tuple[str, str]:
    if blob_consigne is None:
        return "NON_ANCRABLE", "aucun blob consigne par les documents : cet etat n'est JAMAIS vert"
    if mesure.get("etat") == "ABSENT":
        return "ABSENT", "fichier cite mais absent du disque"
    if mesure["sha1_git"] == blob_consigne:
        return "VERT", "blob mesure == blob consigne"
    return "ROUGE", "blob mesure != blob consigne — les numeros de ligne cités sont a re-verifier"


def construire_fraicheur(graphe: dict) -> dict:
    maintenant = _dt.datetime.now().astimezone().replace(microsecond=0).isoformat()
    head = git_head()
    entrees = []
    for e in graphe["ancrage"]["blobs"]:
        chemin = e["chemin"]
        mesure = mesurer(chemin)
        etat, motif = etat_de(chemin, e.get("blob_consigne"), mesure)
        entrees.append({
            "chemin": chemin,
            "blob_consigne": e.get("blob_consigne"),
            "blob_mesure": mesure.get("sha1_git"),
            "blob_mesure_brut": mesure.get("sha1_brut"),
            "blob_git_hash_object": mesure.get("sha1_git_reference"),
            "implementation_conforme": mesure.get("implementation_conforme"),
            "lignes": mesure.get("lignes"),
            "taille_brute": mesure.get("taille_brute"),
            "taille_normalisee": mesure.get("taille_normalisee"),
            "crlf_converti": mesure.get("crlf_converti"),
            "etat": etat,
            "motif": motif,
            "sources_ancrage": e.get("sources", []),
            "ancrage_derive": e.get("ancrage_derive", False),
            "etiquettes": e.get("etiquettes", []),
            "utilise_par": e.get("utilise_par", []),
        })
    totaux = {
        "fichiers": len(entrees),
        "verts": sum(1 for x in entrees if x["etat"] == "VERT"),
        "rouges": sum(1 for x in entrees if x["etat"] == "ROUGE"),
        "absents": sum(1 for x in entrees if x["etat"] == "ABSENT"),
        "non_ancrables": sum(1 for x in entrees if x["etat"] == "NON_ANCRABLE"),
        "ancrage_derive": sum(1 for x in entrees if x["ancrage_derive"]),
    }
    return {
        "meta": {
            "outil": "T353 — CMD_PATH_VIEWER (verify_anchors.py)",
            "mode": "STATIQUE (constat figé et horodaté)",
            "genere_le": maintenant,
            "head_mesure": head,
            "reference_command": "git hash-object <chemin>  (PAS --stdin : git n'applique pas le filtre CRLF sur stdin)",
            "formule": "SHA1(\"blob \" + taille_apres_normalisation_CRLF + \"\\0\" + contenu_normalisé_CRLF)",
            "regle_hash": "core.autocrlf=true : CRLF->LF avant calcul, en-tete = taille APRES normalisation",
            "avertissement": ("En mode statique (file://) ces badges sont FIGES : aucun recalcul n'est "
                              "possible dans le navigateur. Le mode live recalcule chaque blob."),
        },
        "totaux": totaux,
        "fichiers": sorted(entrees, key=lambda x: (x["etat"] != "ROUGE", x["chemin"])),
    }


def ecrire(fr: dict) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "freshness.json").write_text(json.dumps(fr, ensure_ascii=False, indent=1), encoding="utf-8",
                                          newline="\n")
    (DATA / "freshness.js").write_text(
        "/* GÉNÉRÉ par verify_anchors.py — ne pas éditer à la main. Constat FIGÉ, horodaté. */\n"
        "window.CMD_PATH_VIEWER_FRESHNESS = " + json.dumps(fr, ensure_ascii=False) + ";\n",
        encoding="utf-8", newline="\n")


def preuve_p4() -> int:
    """Table P4 : SHA-1 du JS (execute sous Node, le MEME fichier que le navigateur) vs git hash-object."""
    env = dict(os.environ)
    env.update({
        "CPV_MODULE": str(MODULE_JS).replace("\\", "/"),
        "CPV_CONTROLES": json.dumps(CONTROLES_P4),
        "CPV_RACINE": str(RACINE),
    })
    r = subprocess.run(["node", "-"], input=PROGRAMME_NODE, env=env, capture_output=True,
                       text=True, encoding="utf-8", errors="replace", cwd=str(RACINE))
    if r.returncode != 0:
        print("ERREUR node :"); print(r.stdout); print(r.stderr)
        return 1
    donnees = json.loads(r.stdout)
    print("=" * 118)
    print("P4 — JS (même fichier que le navigateur, exécuté sous Node) vs `git hash-object`")
    print("=" * 118)
    print(f"{'fichier':58} {'SHA-1 JS (git-normalisé)':42} {'git hash-object':42} égal")
    conformes = 0
    for f in donnees["fichiers"]:
        ref = git_hash_object(f["chemin"]) or "—"
        egal = (f.get("sha1_js") == ref)
        conformes += 1 if egal else 0
        print(f"{f['chemin'][:57]:58} {str(f.get('sha1_js')):42} {ref:42} {'OUI' if egal else 'NON'}")
    print()
    print(f"  conformes : {conformes}/{len(donnees['fichiers'])}")
    for f in donnees["fichiers"][:3]:
        print(f"  {f['chemin']} · brut {f['taille_brute']} o → normalisé {f['taille_normalisee']} o"
              f" ({f['crlf_converti']} CRLF convertis) · {f['normalisation']}")
    print(f"  auto-test JS (vecteurs vérifiés contre git) : {'PASS' if donnees['auto_test_js']['pass'] else 'FAIL'}")
    for v in donnees["auto_test_js"]["vecteurs"]:
        print(f"    {'OK ' if v['pass'] else 'KO '} {v['nom'][:52]:54} {v['obtenu']}  ({v['ref']})")
    return 0 if conformes == len(donnees["fichiers"]) else 1


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    args = sys.argv[1:]
    if "--test-garde-fou" in args:
        return test_garde_fou()
    if "--preuve-p4" in args:
        return preuve_p4()
    if "--fichier" in args:
        chemin = args[args.index("--fichier") + 1]
        m = mesurer(chemin)
        print(json.dumps({"chemin": chemin, **m}, ensure_ascii=False, indent=1))
        return 0
    graphe = charger_graphe()
    fr = construire_fraicheur(graphe)
    ecrire(fr)
    t = fr["totaux"]
    print("=" * 96)
    print("GARDE-FOU BLOB — constat figé (mode statique)")
    print("=" * 96)
    print(f"  généré le {fr['meta']['genere_le']} · HEAD {fr['meta']['head_mesure'][:12]}")
    print(f"  fichiers {t['fichiers']} · VERT {t['verts']} · ROUGE {t['rouges']} · ABSENT {t['absents']}"
          f" · NON_ANCRABLE {t['non_ancrables']} · ancrage DÉRIVÉ {t['ancrage_derive']}")
    for x in fr["fichiers"]:
        if x["etat"] != "VERT":
            print(f"  [{x['etat']}] {x['chemin']} — {x['motif']}")
    ko = [x for x in fr["fichiers"] if x["implementation_conforme"] is False]
    print(f"  implémentation Python conforme à `git hash-object` : "
          f"{'OUI (' + str(t['fichiers']) + '/' + str(t['fichiers']) + ')' if not ko else 'NON ' + str(ko)}")
    print(f"  Écrit : {DATA/'freshness.json'} et {DATA/'freshness.js'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
