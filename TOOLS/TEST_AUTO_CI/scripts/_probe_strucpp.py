import subprocess, pathlib, tempfile, re, sys
strucpp = sys.argv[1]
tmp = sys.argv[2]
test = sys.argv[3]
converted = [str(pathlib.Path(tmp) / n) for n in [
    "E_State.st","ST_Fault.st","ST_FaultCause.st","ST_Lifecycle.st","FB_FaultCore.st",
    "E_Mode.st","E_CycleStep.st","E_OperatorAxis.st","E_ProgramSequence.st",
    "ST_fbCycle_WinchCmdDemand.st","ST_fbCycle_TranslationCmdDemand.st",
    "ST_fbCycle_BucketCmdDemand.st","FB_Cycle.st"]]
out = str(pathlib.Path(tmp) / "FB_Cycle.cpp")
tmp_root = pathlib.Path(tempfile.gettempdir())
before = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
cmd = [strucpp] + converted + ["-o", out, "-O", "0", "--cxx-flags", "-O0 -pipe", "--test", test]
p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
print("STRUCPP_RC=", p.returncode)
after = {p for p in tmp_root.glob("strucpp-test-*") if p.is_dir()}
new = after - before
print("nouveaux dossiers:", [str(x) for x in new])
if new:
    d = max(new, key=lambda x: x.stat().st_mtime)
    print("DIR=", d)
    for f in d.iterdir():
        print("  ", f.name)
    tm = d / "test_main.cpp"
    if tm.exists():
        txt = tm.read_text(encoding="utf-8", errors="replace")
        tests = re.findall(r"TEST '([^']*)'", txt)
        print("  tests dans test_main.cpp:", tests[:6])
