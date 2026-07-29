import pathlib
import sys

__test__ = False

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from tests.generation.test_fb_gen_changed import *
