import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import tempfile

import G315_check_fb_interface
from G315_check_fb_interface import (
    analyze_fb_files,
    split_standard_by_form,
    STATUS_MEMBERS,
    EXCEPTIONS_JUSTIFICATION,
)


class TestFbInterfaceGuard(unittest.TestCase):
    def test_fb_interface_classification(self):
        standard_fbs, light_fbs, documented_exceptions, unauthorized = analyze_fb_files(REPO_ROOT)

        total = len(standard_fbs) + len(light_fbs) + len(documented_exceptions) + len(unauthorized)
        self.assertEqual(total, 53, f"Attendu 53 FB au total, obtenu {total}")
        self.assertEqual(len(standard_fbs), 21, f"Attendu 21 FB standard, obtenu {len(standard_fbs)}")
        self.assertEqual(len(light_fbs), 27, f"Attendu 27 FB light, obtenu {len(light_fbs)}")
        self.assertEqual(len(documented_exceptions), 5, f"Attendu 5 exceptions, obtenu {len(documented_exceptions)}")
        self.assertEqual(len(unauthorized), 0, f"Aucun FB non autorisé attendu, obtenu {len(unauthorized)}")

    def test_documented_exceptions_presence(self):
        standard_fbs, light_fbs, documented_exceptions, unauthorized = analyze_fb_files(REPO_ROOT)
        exception_names = {p.stem for p, _ in documented_exceptions}

        expected_exceptions = {
            "FB_Output",
            "FB_Safety_EmergencyManagementLogic",
            "FB_Safety_EmergencyManagementOutput",
            "FB_Joystick",
            "FB_SimBench",
        }
        self.assertEqual(exception_names, expected_exceptions)


class TestStFbStatusRecognition(unittest.TestCase):
    """Non-regression du defaut corrige le 2026-08-19.

    Avant correction, le guard ne detectait que les membres A PLAT. Un FB migre
    vers `Status : ST_FbStatus` perdait ces membres, tombait a 0/5, etait classe
    « light » et le script sortait en SUCCES sans rien signaler : le garde-fou se
    degradait en silence des le premier FB migre par T137.
    """

    FB_MIGRE = """FUNCTION_BLOCK FB_ExempleMigre
VAR_INPUT
    Enable : BOOL;
    Reset  : BOOL;
END_VAR
VAR_OUTPUT
    Ready  : BOOL;
    Status : ST_FbStatus;
END_VAR
END_FUNCTION_BLOCK
"""

    FB_LIGHT = """FUNCTION_BLOCK FB_ExempleLight
VAR_INPUT
    Enable : BOOL;
    RawIn  : INT;
END_VAR
VAR_OUTPUT
    Ready  : BOOL;
    OutPct : REAL;
END_VAR
END_FUNCTION_BLOCK
"""

    def _analyze(self, fichiers: dict[str, str], avec_split: bool = False):
        """Analyse des FB factices. `split_standard_by_form` relit les fichiers sur
        disque : le split doit donc etre calcule DANS le context manager, avant que
        le dossier temporaire ne disparaisse."""
        with tempfile.TemporaryDirectory() as tmp:
            code_dir = Path(tmp) / "CODE"
            code_dir.mkdir()
            for nom, contenu in fichiers.items():
                (code_dir / nom).write_text(contenu, encoding="utf-8")
            resultat = analyze_fb_files(Path(tmp))
            if avec_split:
                return resultat, split_standard_by_form(resultat[0])
            return resultat

    def test_fb_migre_est_standard_pas_light(self):
        standard, light, exceptions, unauthorized = self._analyze(
            {"FB_ExempleMigre.st": self.FB_MIGRE}
        )
        self.assertEqual(len(standard), 1, "Un FB portant Status : ST_FbStatus doit etre STANDARD")
        self.assertEqual(len(light), 0, "Il ne doit surtout pas retomber en profil light")
        self.assertEqual(len(exceptions), 0)
        self.assertEqual(len(unauthorized), 0)

    def test_fb_sans_status_reste_light(self):
        standard, light, _, _ = self._analyze({"FB_ExempleLight.st": self.FB_LIGHT})
        self.assertEqual(len(light), 1, "Un calculateur pur reste en profil light")
        self.assertEqual(len(standard), 0)

    def test_indicateur_avancement_t137(self):
        _, (cible, heritee) = self._analyze(
            {"FB_ExempleMigre.st": self.FB_MIGRE}, avec_split=True
        )
        self.assertEqual(len(cible), 1, "Le FB migre compte dans la forme cible")
        self.assertEqual(len(heritee), 0)

    def test_les_21_standard_sont_tous_en_forme_heritee_avant_t137(self):
        standard, _, _, _ = analyze_fb_files(REPO_ROOT)
        cible, heritee = split_standard_by_form(standard)
        self.assertEqual(
            len(heritee), 21,
            "T137 non demarree : les 21 FB standard sont encore en forme a plat",
        )
        self.assertEqual(len(cible), 0, "Aucun FB migre tant que T137 n'a pas demarre")


if __name__ == "__main__":
    unittest.main()

