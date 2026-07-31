import pathlib
import sys

TOOLS_ROOT = pathlib.Path(__file__).resolve().parents[1]
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

import st2pone


def test_main_forwards_arguments(monkeypatch):
    observed = []

    def fake_main():
        observed.append(sys.argv)

    monkeypatch.setattr(st2pone.fb_gen, 'main', fake_main)
    st2pone.main(['--bundle', 'bundle.xml', '--pou', 'FB_Test', '--out', 'outdir', '--force'])

    assert observed[0][1:3] == ['--bundle', 'bundle.xml']
    assert observed[0][3:5] == ['--pou', 'FB_Test']
    assert observed[0][5:7] == ['--out', 'outdir']
    assert '--force' in observed[0]
