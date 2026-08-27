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
    dut_exists,
    STATUS_MEMBERS,
    EXCEPTIONS_JUSTIFICATION,
)


class TestFbInterfaceGuard(unittest.TestCase):
    def test_fb_interface_classification(self):
        standard_fbs, light_fbs, documented_exceptions, unauthorized = analyze_fb_files(REPO_ROOT)

        total = len(standard_fbs) + len(light_fbs) + len(documented_exceptions) + len(unauthorized)
        self.assertEqual(total, 58, f"Attendu 58 FB au total, obtenu {total}")
        self.assertEqual(len(standard_fbs), 18, f"Attendu 18 FB standard, obtenu {len(standard_fbs)}")
        self.assertEqual(len(light_fbs), 34, f"Attendu 34 FB light, obtenu {len(light_fbs)}")
        self.assertEqual(len(documented_exceptions), 6, f"Attendu 6 exceptions, obtenu {len(documented_exceptions)}")
        self.assertEqual(len(unauthorized), 0, f"Aucun FB non autorisé attendu, obtenu {len(unauthorized)}")

    def test_documented_exceptions_presence(self):
        standard_fbs, light_fbs, documented_exceptions, unauthorized = analyze_fb_files(REPO_ROOT)
        exception_names = {p.stem for p, _ in documented_exceptions}

        # T164-3 : FB_Diag_CanOpen / FB_Diag_Ethercat portent desormais `Status : ST_Status`
        # -> classes standard (forme legacy-status), plus des exceptions. FB_Joystick est passe
        # en forme cible `Fault : ST_Fault` -> plus une exception non plus.
        expected_exceptions = {
            "FB_Safety_EmergencyManagement",
            "FB_Safety_EmergencyManagementLogic",
            "FB_Safety_EmergencyManagementOutput",
            "FB_Cycle",
            "FB_WinchOutputInterlock",
            "FB_SimBench",
        }
        self.assertEqual(exception_names, expected_exceptions)

    def test_dut_st_fault_existe(self):
        self.assertTrue(dut_exists(REPO_ROOT), "Le DUT cible ST_Fault doit exister dans CODE/A_COMMUN/")

    def test_repartition_des_formes_standard(self):
        standard, _, _, _ = analyze_fb_files(REPO_ROOT)
        cible, legacy_status, legacy_flat = split_standard_by_form(standard)
        self.assertEqual(
            len(legacy_flat), 0,
            "Cloture T137 : plus aucune forme a plat parmi les FB standard",
        )
        self.assertEqual(
            len(cible), 2,
            "Forme cible (Fault : ST_Fault) : FB_Joystick pilote + le socle FB_FaultCore",
        )
        self.assertEqual(
            len(legacy_status), 16,
            "16 FB en forme legacy-status (Status : ST_Status), a migrer en T164-5",
        )
        self.assertEqual(len(cible) + len(legacy_status) + len(legacy_flat), len(standard))


class TestStFbStatusRecognition(unittest.TestCase):
    """Non-regression du defaut corrige le 2026-08-19.

    Avant correction, le guard ne detectait que les membres A PLAT. Un FB migre
    vers un membre struct de statut perdait ces membres, tombait a 0/5, etait classe
    « light » et le script sortait en SUCCES sans rien signaler.
    T164-3 : la forme cible reconnue est desormais `Fault : ST_Fault`.
    """

    FB_MIGRE = """FUNCTION_BLOCK FB_ExempleMigre
VAR_INPUT
    Enable : BOOL;
    Reset  : BOOL;
END_VAR
VAR_OUTPUT
    Ready  : BOOL;
    Fault  : ST_Fault;
END_VAR
END_FUNCTION_BLOCK
"""

    FB_LEGACY_STATUS = """FUNCTION_BLOCK FB_ExempleLegacy
VAR_INPUT
    Enable : BOOL;
    Reset  : BOOL;
END_VAR
VAR_OUTPUT
    Ready  : BOOL;
    Status : ST_Status;
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
        self.assertEqual(len(standard), 1, "Un FB portant Fault : ST_Fault doit etre STANDARD")
        self.assertEqual(len(light), 0, "Il ne doit surtout pas retomber en profil light")
        self.assertEqual(len(exceptions), 0)
        self.assertEqual(len(unauthorized), 0)

    def test_fb_legacy_status_est_standard(self):
        standard, light, exceptions, unauthorized = self._analyze(
            {"FB_ExempleLegacy.st": self.FB_LEGACY_STATUS}
        )
        self.assertEqual(len(standard), 1, "Un FB portant Status : ST_Status reste STANDARD (legacy tolere T164-5)")
        self.assertEqual(len(light), 0)

    def test_fb_sans_status_reste_light(self):
        standard, light, _, _ = self._analyze({"FB_ExempleLight.st": self.FB_LIGHT})
        self.assertEqual(len(light), 1, "Un calculateur pur reste en profil light")
        self.assertEqual(len(standard), 0)

    def test_split_3_formes(self):
        _, (cible, legacy_status, legacy_flat) = self._analyze(
            {"FB_ExempleMigre.st": self.FB_MIGRE, "FB_ExempleLegacy.st": self.FB_LEGACY_STATUS},
            avec_split=True,
        )
        self.assertEqual(len(cible), 1, "FB_ExempleMigre compte en forme cible (Fault : ST_Fault)")
        self.assertEqual(len(legacy_status), 1, "FB_ExempleLegacy compte en forme legacy-status")
        self.assertEqual(len(legacy_flat), 0)

    def test_repartition_repo(self):
        standard, _, _, _ = analyze_fb_files(REPO_ROOT)
        cible, legacy_status, legacy_flat = split_standard_by_form(standard)
        self.assertEqual(len(legacy_flat), 0, "Cloture T137 : plus aucune forme a plat")
        self.assertEqual(len(cible), 2, "Forme cible : FB_Joystick + FB_FaultCore")
        self.assertEqual(len(legacy_status), 16, "16 FB legacy-status a migrer en T164-5")


class TestStateAwareGuard(unittest.TestCase):
    """Non-regression du classifieur type-aware (REX 2026-08-20).

    Avant correction, un FB avec `State` public typé hors E_State (E_Diag_State,
    ST_Safety_Emergency_State…) ou un `State` local `[LOC]` était compté 5/5 et classé
    « standard » à tort — alors qu'il NE PEUT PAS adopter ST_FbStatus (State:E_State)
    sans perte sémantique. Le classifieur doit refuser ces formes.
    """

    def _analyze(self, fichiers: dict[str, str]):
        with tempfile.TemporaryDirectory() as tmp:
            code_dir = Path(tmp) / "CODE"
            code_dir.mkdir()
            for nom, contenu in fichiers.items():
                (code_dir / nom).write_text(contenu, encoding="utf-8")
            return analyze_fb_files(Path(tmp))

    def test_state_domaine_n_est_pas_standard(self):
        fb = """FUNCTION_BLOCK FB_ExempleDiag
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_OUTPUT
    Error    : BOOL;
    ErrorId  : WORD;
    State    : E_Diag_State;
    Ready    : BOOL;
END_VAR
END_FUNCTION_BLOCK
"""
        standard, light, exceptions, unauthorized = self._analyze({"FB_ExempleDiag.st": fb})
        self.assertEqual(len(standard), 0, "Un FB a State domaine (E_Diag_State) ne peut pas etre standard")
        self.assertEqual(len(light), 0, "Il ne doit pas etre light non plus (il a un etat machine)")
        # Non documente → doit ressortir en hors-contrat, jamais en standard.
        self.assertEqual(len(unauthorized), 1, "Un FB a State domaine non documente est un hors-contrat")

    def test_state_local_n_est_pas_compte(self):
        # FB_Cycle : `State : E_CycleStep` est une variable LOCALE, pas une sortie.
        FB = """FUNCTION_BLOCK FB_ExempleLocal
VAR
    State    : E_CycleStep;   // . [LOC]
    SavedState: E_CycleStep;
END_VAR
VAR_OUTPUT
    Busy    : BOOL;
    Done    : BOOL;
    Error   : BOOL;
    ErrorId : WORD;
    CycleStep : E_CycleStep;
END_VAR
END_FUNCTION_BLOCK
"""
        standard, light, _, unauthorized = self._analyze({"FB_ExempleLocal.st": FB})
        self.assertEqual(len(standard), 0, "Un State local [LOC] ne compte pas comme membre de statut public")
        # Busy/Done/Error/ErrorId (4/5) sans State public → entre-deux → hors-contrat (non documenté).
        self.assertEqual(len(unauthorized), 1, "Sans State public E_State, un FB 4/5 est un entre-deux non autorise")

    def test_state_scalaire_bool_est_light(self):
        # FB_Output : `State : BOOL` = sortie logique physique, PAS un etat machine.
        FB = """FUNCTION_BLOCK FB_ExempleOutput
VAR_OUTPUT
    State : BOOL;
END_VAR
END_FUNCTION_BLOCK
"""
        standard, light, exceptions, _ = self._analyze({"FB_ExempleOutput.st": FB})
        self.assertEqual(len(standard), 0)
        self.assertEqual(len(light), 1, "Un State:Bool est une sortie physique -> profil light")


if __name__ == "__main__":
    unittest.main()

