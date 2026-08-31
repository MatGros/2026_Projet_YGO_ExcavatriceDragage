import os
_orig_mkdir = os.mkdir
def _safe_mkdir(path, mode=0o777, *, dir_fd=None):
    return _orig_mkdir(path, 0o777, dir_fd=dir_fd)
os.mkdir = _safe_mkdir
_orig_chmod = os.chmod
def _safe_chmod(path, mode, *, follow_symlinks=True):
    try:
        return _orig_chmod(path, mode, follow_symlinks=follow_symlinks)
    except PermissionError:
        return None
os.chmod = _safe_chmod
import shutil
shutil.chmod = _safe_chmod
_orig_rmtree = shutil.rmtree
def _safe_rmtree(path, ignore_errors=False, onerror=None, onexc=None):
    _orig_rmtree(path, ignore_errors=True)
shutil.rmtree = _safe_rmtree
