"""Replay T429 lot 2 integration guards; never uses the production port or storage."""
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[3]
    commands = [
        [sys.executable, '-m', 'pytest', 'TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py',
         '-q', '-k', 'lot2', '-p', 'no:cacheprovider'],
        ['node', '--test', *[str(p.relative_to(root)) for p in
                            sorted((root / 'TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/test').glob('*.test.js'))]],
    ]
    failed = False
    for command in commands:
        subprocess.run(['git', 'status', '--short'], cwd=root, check=True)
        result = subprocess.run(command, cwd=root, check=False)
        subprocess.run(['git', 'status', '--short'], cwd=root, check=True)
        failed |= result.returncode != 0
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
