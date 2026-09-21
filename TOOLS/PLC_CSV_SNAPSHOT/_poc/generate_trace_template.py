"""
POC — Générateur de fichier .trace CODESYS 3.5 à partir d'un fichier de référence.

⚠️ PHASE 1 / POC — NON VALIDÉ PAR IMPORT CODESYS RÉEL. Voir rapport T372
   (DOC/WFLOW/CONTRACTS/BRIEF_T372_GENERATEUR_TEMPLATE_TRACE.md) pour le détail des preuves
   et des limites. Ne pas industrialiser tel quel sans un test d'import IDE.

Principe (verdict de l'investigation) : ce n'est PAS un générateur XML from-scratch. C'est un
"template modifié" automatisé : on part d'un fichier .trace réel (référence), on clone son bloc
<Single Type="{b6a18d24-...}"> (une entrée de variable tracée) autant de fois que nécessaire, on
substitue uniquement VariableName et guid (identifiant d'entrée, aléatoire par variable dans les
fichiers réels), et on conserve TOUT le reste à l'identique (guidPOU / AppGuid / DownloadGuid /
ExitGuid / TaskName / BufferEntries / TriggerXxx / Appearance / ...). Ces champs sont identiques
dans les 37 fichiers .trace réels analysés (même session PLC) : leur mode de calcul réel
(rattachement à un GUID de build/téléchargement CODESYS) n'est PAS prouvé depuis les fichiers
seuls — les copier depuis un fichier réel récent est donc plus sûr qu'inventer une valeur.

Limites connues (non prouvées, à vérifier avant tout usage réel) :
- Aucun des 37 fichiers .trace réels analysés n'a de trigger configuré (TriggerVariable="",
  TriggerEdge=None dans 100% des cas). L'encodage d'un trigger actif (Rising/Falling/Level,
  pré/post-trigger réel) n'est donc PAS prouvé par la donnée réelle. Ce script laisse ces champs
  strictement à l'identique du template (jamais deviné) — le paramètre --trigger-variable existe
  mais n'écrit QUE le nom de variable (champ string simple, même schéma que VariableName), il
  n'active PAS de front/condition dont l'encodage réel est inconnu.
- La validité de l'AppGuid/DownloadGuid/ExitGuid copiés dépend de la session PLC de la référence :
  s'ils sont liés au build/téléchargement au moment de l'enregistrement, un fichier généré à
  partir d'une référence ancienne pourrait ne plus correspondre à l'application en ligne actuelle.
  Non testé.
- La sortie ne contient QUE <TraceConfiguration> (pas de <TraceData>) : les fichiers réels ont
  toujours les deux sections. Un import CODESYS sans <TraceData> n'a pas été testé.

Usage :
    python generate_trace_template.py \
        --reference "TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_MesureTempsHoming_20260902_15.trace" \
        --variables variables_homing.txt \
        --record-name Suivi_HomingMachine \
        --output out.trace

`variables_homing.txt` : un chemin de variable complet par ligne.
"""

from __future__ import annotations

import argparse
import re
import uuid
from pathlib import Path

VAR_BLOCK_MARKER = '<Single Type="{b6a18d24-a045-4a81-a2ac-7044c6f553c0}" Method="IArchivable">'
INNERLIST_OPEN = '<List Name="InnerList" Type="System.Collections.ArrayList">'
INNERLIST_CLOSE = "</List>"


def read_utf16(path: Path) -> str:
    # Les .trace réels observés sont UTF-16 LE avec BOM, CRLF.
    return path.read_text(encoding="utf-16")


def extract_first_variable_block(text: str) -> str:
    """Isole le premier bloc <Single Type="{b6a18d24...}">...</Single> complet du InnerList."""
    inner_start = text.find(INNERLIST_OPEN)
    if inner_start == -1:
        raise ValueError("InnerList introuvable dans le fichier de référence — format inattendu.")
    inner_close = text.find(INNERLIST_CLOSE, inner_start)
    inner_body = text[inner_start + len(INNERLIST_OPEN):inner_close]

    starts = [m.start() for m in re.finditer(re.escape(VAR_BLOCK_MARKER), inner_body)]
    if not starts:
        raise ValueError("Aucun bloc variable (marqueur b6a18d24) trouvé — format inattendu.")
    first_start = starts[0]
    # fin du 1er bloc = début du 2e bloc, ou fin de InnerList s'il n'y a qu'une variable
    first_end = starts[1] if len(starts) > 1 else len(inner_body)
    block = inner_body[first_start:first_end]
    # on retire un éventuel indentation finale / retour ligne traînant pour ré-assemblage propre
    return block.rstrip("\r\n ")


def render_variable_block(template_block: str, variable_name: str) -> str:
    """Substitue VariableName et régénère un guid d'entrée (champ per-row, valeur libre observée)."""
    block = re.sub(
        r'(<Single Name="VariableName" Type="string">)[^<]*(</Single>)',
        lambda m: f"{m.group(1)}{variable_name}{m.group(2)}",
        template_block,
        count=1,
    )
    new_guid = str(uuid.uuid4())
    block = re.sub(
        r'(<Single Name="guid" Type="System.Guid">)[^<]*(</Single>)',
        lambda m: f"{m.group(1)}{new_guid}{m.group(2)}",
        block,
        count=1,
    )
    return block


def build_config(reference_text: str, variables: list[str], record_name: str | None,
                  trigger_variable: str | None) -> str:
    inner_start = reference_text.find(INNERLIST_OPEN)
    inner_close = reference_text.find(INNERLIST_CLOSE, inner_start)

    template_block = extract_first_variable_block(reference_text)
    rendered_blocks = "\n        ".join(
        render_variable_block(template_block, v) for v in variables
    )

    new_text = (
        reference_text[: inner_start + len(INNERLIST_OPEN)]
        + "\n        "
        + rendered_blocks
        + "\n      "
        + reference_text[inner_close:]
    )

    if record_name is not None:
        new_text = re.sub(
            r'(<Single Name="RecordName" Type="string">)[^<]*(</Single>)',
            lambda m: f"{m.group(1)}{record_name}{m.group(2)}",
            new_text,
            count=1,
        )

    if trigger_variable is not None:
        new_text = re.sub(
            r'(<Single Name="TriggerVariable" Type="string">)[^<]*(</Single>)',
            lambda m: f"{m.group(1)}{trigger_variable}{m.group(2)}",
            new_text,
            count=1,
        )

    return new_text


def extract_trace_configuration(full_text: str) -> str:
    start = full_text.find("<TraceConfiguration>")
    end = full_text.find("</TraceConfiguration>") + len("</TraceConfiguration>")
    if start == -1 or end == -1:
        raise ValueError("<TraceConfiguration> introuvable dans le fichier de référence.")
    return full_text[start:end]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path,
                         help="Fichier .trace réel servant de gabarit structurel")
    parser.add_argument("--variables", required=True, type=Path,
                         help="Fichier texte, un chemin de variable complet par ligne")
    parser.add_argument("--record-name", default=None,
                         help="Nom de l'enregistrement (RecordName) — défaut : celui du template")
    parser.add_argument("--trigger-variable", default=None,
                         help="Nom de variable trigger (champ simple, PAS de front/condition — non prouvé)")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    reference_text = read_utf16(args.reference)
    ref_config = extract_trace_configuration(reference_text)

    variables = [
        line.strip() for line in args.variables.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not variables:
        raise SystemExit("Aucune variable dans --variables.")

    new_config = build_config(ref_config, variables, args.record_name, args.trigger_variable)

    output_text = "<Trace>\r\n  " + new_config + "\r\n</Trace>"
    # ré-encodage identique à l'original : UTF-16 LE + BOM, CRLF (new_config est déjà en CRLF,
    # hérité du fichier de référence — ne pas re-remplacer \n globalement, ça double les \r).
    args.output.write_text(output_text, encoding="utf-16")
    print(f"[OK] {len(variables)} variable(s) -> {args.output}")
    print("[ATTENTION] Non teste par import CODESYS reel - voir limites en tete de script.")


if __name__ == "__main__":
    main()
