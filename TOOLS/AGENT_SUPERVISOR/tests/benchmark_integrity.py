"""Measure full-prefix integrity verification using generated JSONL only.

Files are retained in the explicitly supplied scratch directory.
"""
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts.session_watcher import JsonlAppendWatcher


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scratch', type=Path)
    args = parser.parse_args()
    args.scratch.mkdir(parents=True, exist_ok=False)
    row = b'{"type":"assistant","message":{"content":"' + b'x' * 950 + b'"}}\n'
    measurements = []
    for megabytes in (1, 10, 50):
        source = args.scratch / f'synthetic_{megabytes}mb.jsonl'
        with source.open('xb') as stream:
            for _ in range(megabytes * 1024 * 1024 // len(row)):
                stream.write(row)
        started = time.perf_counter()
        watcher = JsonlAppendWatcher(source)
        attach = time.perf_counter() - started
        with source.open('ab') as stream:
            stream.write(b'{"type":"user"}\n')
        times = []
        for _ in range(3):
            started = time.perf_counter()
            result = watcher.poll()
            times.append(time.perf_counter() - started)
            if result.state != 'active':
                raise RuntimeError(result.state)
        measurements.append(dict(bytes=source.stat().st_size, attach_ms=round(attach*1000,2), poll_ms=[round(value*1000,2) for value in times]))
    print(json.dumps({'generated': True, 'measurements': measurements}, indent=2))


if __name__ == '__main__':
    main()
