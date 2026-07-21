#!/usr/bin/env python3
"""Launch standardized project workspace.

Supports:
- Windows Terminal (native splits/tabs) - Windows
- tmux (via tmuxinator or direct) - Linux/WSL/macOS
- Cross-platform fallback

Usage:
    python TOOLS/launch_workspace.py [--backend wt|tmux|auto]

Backends:
    wt      - Windows Terminal (native)
    tmux    - tmux (requires tmux installed)
    auto    - Detect best available (default)
"""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


def find_project_root() -> Path:
    """Find project root by looking for marker directories."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / "CODE").is_dir() and (parent / "DOC").is_dir() and (parent / "TOOLS").is_dir():
            return parent
    return cwd


def run_windows_terminal(root: Path) -> int:
    """Launch workspace in Windows Terminal with splits."""
    wt = shutil.which("wt.exe") or shutil.which("wt")
    if not wt:
        print("Windows Terminal (wt.exe) not found in PATH", file=sys.stderr)
        return 1

    cmds = [
        ("Pi", ["pi"]),
        ("Claude Ollama", ["ollama", "launch", "claude", "--model", "gemma4:e4b"]),
        ("OpenCode", ["opencode", "--agent", "orchestrateur"]),
        ("OpenCode Ollama", ["ollama", "launch", "opencode", "--model", "gemma4:e4b"]),
        ("Gates", [sys.executable, "TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py", "--skip-codesys", "--watch"]),
        ("Herdr", ["herdr", "start-agent", "claude"]),
        ("Graphs", [sys.executable, "TOOLS/visualize_workflow.py"]),
    ]

    args = [wt]
    for i, (title, cmd) in enumerate(cmds):
        if i == 0:
            args += ["new-tab", "-p", "Windows PowerShell", "--title", title, "--startingDirectory", str(root)]
        elif i == 1:
            args += ["split-pane", "-V", "-p", "Windows PowerShell", "--title", title, "--startingDirectory", str(root)]
        else:
            args += ["split-pane", "-H", "-p", "Windows PowerShell", "--title", title, "--startingDirectory", str(root)]
        args += [";"] + cmd

    print(f"Launching in Windows Terminal...")
    return subprocess.run(args, cwd=root).returncode


def run_tmux_direct(root: Path) -> int:
    """Launch workspace directly in tmux (no tmuxinator needed)."""
    if not shutil.which("tmux"):
        print("tmux not found in PATH", file=sys.stderr)
        return 1

    session = "mgs"
    # Kill existing session if any
    subprocess.run(["tmux", "kill-session", "-t", session], capture_output=True)

    cmds = [
        "pi",
        "ollama launch claude --model gemma4:e4b",
        "opencode --agent orchestrateur",
        "ollama launch opencode --model gemma4:e4b",
        f"python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys --watch",
        "herdr start-agent claude",
        f"python TOOLS/visualize_workflow.py",
    ]

    # Build tmux command
    tmux_cmd = ["tmux", "new-session", "-d", "-s", session]
    tmux_cmd += [";", "send-keys", cmds[0], "C-m"]

    for i, cmd in enumerate(cmds[1:], 1):
        if i == 1:
            tmux_cmd += [";", "split-window", "-h"]
        else:
            tmux_cmd += [";", "split-window", "-v"]
        tmux_cmd += [";", "send-keys", cmd, "C-m"]

    tmux_cmd += [";", "select-layout", "main-vertical", ";", "attach"]

    print(f"Launching in tmux session '{session}'...")
    return subprocess.run(tmux_cmd, cwd=root).returncode


def run_tmuxinator(root: Path) -> int:
    """Launch workspace via tmuxinator."""
    if not shutil.which("tmuxinator"):
        print("tmuxinator not found", file=sys.stderr)
        return 1

    config = root / ".tmuxinator" / "mgs.yml"
    if not config.exists():
        print(f"tmuxinator config not found: {config}", file=sys.stderr)
        return 1

    print("Launching via tmuxinator...")
    return subprocess.run(["tmuxinator", "mgs"], cwd=root).returncode


def run_windows_terminal_profile(root: Path) -> int:
    """Launch using Windows Terminal named profile (requires profile in settings.json)."""
    wt = shutil.which("wt.exe") or shutil.which("wt")
    if not wt:
        return 1

    # Uses a profile named "MGS Workspace" defined in Windows Terminal settings.json
    print("Launching via Windows Terminal profile 'MGS Workspace'...")
    return subprocess.run([wt, "-p", "MGS Workspace"], cwd=root).returncode


def detect_best_backend() -> str:
    """Auto-detect best available backend."""
    system = platform.system().lower()

    if system == "windows":
        if shutil.which("wt.exe") or shutil.which("wt"):
            return "wt"
        if shutil.which("tmux"):
            return "tmux"
    else:
        if shutil.which("tmuxinator") and Path(".tmuxinator/mgs.yml").exists():
            return "tmuxinator"
        if shutil.which("tmux"):
            return "tmux"

    return "none"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=["wt", "tmux", "tmuxinator", "auto"],
                        default="auto", help="Backend to use for workspace launch")
    args = parser.parse_args()

    root = find_project_root()
    os.chdir(root)

    backend = args.backend
    if backend == "auto":
        backend = detect_best_backend()

    print(f"Project root: {root}")
    print(f"Backend: {backend}")

    if backend == "wt":
        return run_windows_terminal(root)
    elif backend == "tmux":
        return run_tmux_direct(root)
    elif backend == "tmuxinator":
        return run_tmuxinator(root)
    elif backend == "wt-profile":
        return run_windows_terminal_profile(root)
    else:
        print("No suitable backend found. Install Windows Terminal or tmux.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())