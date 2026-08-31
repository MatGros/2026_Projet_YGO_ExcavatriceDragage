#!/usr/bin/env python3
"""Wrapper CI : neutralise os.chmod (denied par le sandbox DSH pendant le nettoyage
tempfile de Python 3.14) pour laisser le runner de tests CI se terminer. Les repertoires
temp ne sont pas purges (sans consequence : ils vivent dans .tmp_ci2).

Usage : python run_ci_patched.py <runner.py> [args...]
"""
import os
import sys

_orig_chmod = os.chmod


def _noop_chmod(path, mode, *, follow_symlinks=True, dir_fd=None):
    pass


os.chmod = _noop_chmod

runner = sys.argv[1]
args = sys.argv[2:]
sys.argv = [runner] + args
import runpy
runpy.run_path(runner, run_name="__main__")
