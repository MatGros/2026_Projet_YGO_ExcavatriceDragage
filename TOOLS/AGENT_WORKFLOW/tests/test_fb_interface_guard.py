import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import G315_check_fb_interface
from G315_check_fb_interface import analyze_fb_files, STATUS_MEMBERS, EXCEPTIONS_JUSTIFICATION


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


if __name__ == "__main__":
    unittest.main()

