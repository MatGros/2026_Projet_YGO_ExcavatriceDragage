import pytest
import re

def validate_no_spaced_assignment(source_text: str):
    """
    Vérifie qu'aucune séquence invalidée `: =` avec espaces entre : et = n'existe dans le code ST.
    En IEC 61131-3, l'opérateur d'affectation est l'élément atomique `:=` sans espace.
    """
    # Recherche de : suivi d'espaces/tabulations puis de = (hors commentaires)
    # Exclut les commentaires (* ... *) et // ...
    clean_lines = []
    for line in source_text.splitlines():
        line_clean = line.split("//")[0]
        clean_lines.append(line_clean)
    
    clean_code = "\n".join(clean_lines)
    
    # Détection de : <espaces> =
    match = re.search(r":\s+=", clean_code)
    if match:
        raise SyntaxError("Erreur de syntaxe CODESYS : espace interdit entre ':' et '=' dans l'opérateur ':='")

def test_detect_spaced_assignment_operator_raises_error():
    invalid_st = """
    instSimTranslation(
        Enable      := TRUE,
        TargetNum   : = M3_TargetNum,
        RelayFwd    := M3_RelayFwd
    );
    """
    with pytest.raises(SyntaxError, match="espace interdit entre ':' et '='"):
        validate_no_spaced_assignment(invalid_st)

def test_valid_assignment_operator_passes():
    valid_st = """
    instSimTranslation(
        Enable      := TRUE,
        TargetNum   := M3_TargetNum,
        RelayFwd    := M3_RelayFwd
    );
    """
    validate_no_spaced_assignment(valid_st)
