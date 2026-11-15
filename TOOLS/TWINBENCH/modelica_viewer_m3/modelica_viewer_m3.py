from __future__ import annotations

import csv
import os
import re
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


APP_TITLE = "Modelica Viewer — M3 Translation"
DEFAULT_RELATIVE_MODEL = Path("TOOLS/TWINBENCH/modelica_atelier/Dredge.mo")
DEFAULT_CLASS = "Dredge.Examples.M3ContractCycle"


def find_omc() -> str | None:
    candidates = []
    env = os.environ.get("OPENMODELICAHOME")
    if env:
        candidates.append(Path(env) / "bin" / "omc.exe")
        candidates.append(Path(env) / "omc.exe")

    path_omc = shutil.which("omc")
    if path_omc:
        candidates.append(Path(path_omc))

    pf = os.environ.get("ProgramFiles", r"C:\Program Files")
    pfx86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
    for root in (pf, pfx86):
        root_path = Path(root)
        if root_path.exists():
            candidates.extend(sorted(root_path.glob("OpenModelica*/bin/omc.exe"), reverse=True))

    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


def modelica_string(value: str) -> str:
    return '"' + value.replace("\\", "/").replace('"', '\\"') + '"'


def discover_classes(source: str) -> list[tuple[str, str, int]]:
    """Return (qualified-ish display name, kind, source offset)."""
    pattern = re.compile(
        r"\b(package|model|block|record|connector|function)\s+([A-Za-z_]\w*)"
    )
    results = []
    stack: list[str] = []
    for match in pattern.finditer(source):
        kind, name = match.group(1), match.group(2)
        # This is intentionally lightweight. The full parser remains OpenModelica.
        display = ".".join(stack + [name]) if stack else name
        results.append((display, kind, match.start()))
        if kind == "package":
            stack.append(name)
        elif kind in {"model", "block", "record", "connector", "function"}:
            pass
    return results


def extract_class(source: str, class_name: str) -> str:
    short = class_name.split(".")[-1]
    pattern = re.compile(
        rf"\b(?:model|block|record|package|connector|function)\s+{re.escape(short)}\b"
    )
    match = pattern.search(source)
    if not match:
        return ""
    start = match.start()
    # Balanced-ish scan based on end <kind>; OpenModelica remains authoritative.
    end_pattern = re.compile(rf"\bend\s+{re.escape(short)}\s*;", re.MULTILINE)
    end = end_pattern.search(source, match.end())
    return source[start:end.end()] if end else source[start:]


def parse_ports(source: str) -> list[dict]:
    ports = []
    # Captures input/output declarations with primitive/record types.
    rx = re.compile(
        r"\b(input|output)\s+([A-Za-z_][\w.]*)\s+([A-Za-z_]\w*)"
        r'(?:\s*\([^;]*\))?\s*(?:"[^"]*")?\s*;',
        re.MULTILINE,
    )
    for m in rx.finditer(source):
        ports.append({"direction": m.group(1), "type": m.group(2), "name": m.group(3)})
    return ports


def parse_instances(source: str) -> list[dict]:
    instances = []
    # Handles common component declarations, not every Modelica grammar construct.
    rx = re.compile(
        r"^\s*(?!input\b|output\b|parameter\b|constant\b|final\b)"
        r"([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s+([A-Za-z_]\w*)"
        r"\s*(?:\([^;]*\))?\s*;",
        re.MULTILINE,
    )
    for m in rx.finditer(source):
        typ, name = m.group(1), m.group(2)
        if typ in {"Real", "Boolean", "Integer", "String"}:
            continue
        instances.append({"type": typ, "name": name})
    return instances


def parse_connects(source: str) -> list[tuple[str, str]]:
    return re.findall(r"\bconnect\s*\(\s*([^,]+)\s*,\s*([^\)]+)\)", source)


def read_csv(path: Path) -> tuple[list[str], dict[str, list[float]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))
    if len(rows) < 2:
        return [], {}
    headers = rows[0]
    data = {h: [] for h in headers}
    for row in rows[1:]:
        if not row:
            continue
        for i, header in enumerate(headers):
            if i >= len(row):
                continue
            try:
                data[header].append(float(row[i]))
            except ValueError:
                data[header].append(float("nan"))
    return headers, data


class ModelicaViewer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1450x900")
        self.minsize(1050, 700)

        self.omc = find_omc()
        self.model_path: Path | None = None
        self.current_class = tk.StringVar(value=DEFAULT_CLASS)
        self.status = tk.StringVar(value="Prêt" if self.omc else "omc.exe introuvable")
        self.start_time = tk.DoubleVar(value=0.0)
        self.stop_time = tk.DoubleVar(value=12.0)
        self.intervals = tk.IntVar(value=1200)
        self.selected_var = tk.StringVar()
        self.variables: dict[str, list[float]] = {}
        self.time_values: list[float] = []
        self.classes: list[tuple[str, str, int]] = []
        self._build_ui()

        repo_root = Path(__file__).resolve().parents[3]
        default_model = repo_root / DEFAULT_RELATIVE_MODEL
        if default_model.exists():
            self.load_file(default_model)
            self.current_class.set(DEFAULT_CLASS)

    def _build_ui(self):
        top = ttk.Frame(self, padding=8)
        top.pack(fill="x")

        ttk.Button(top, text="Ouvrir .mo", command=self.open_file).pack(side="left")
        ttk.Button(top, text="Ouvrir Dredge M3", command=self.open_default).pack(side="left", padx=5)
        ttk.Button(top, text="Recharger", command=self.reload_file).pack(side="left")
        ttk.Button(top, text="Enregistrer", command=self.save_file).pack(side="left", padx=5)
        ttk.Button(top, text="Vérifier", command=self.check_model).pack(side="left")
        ttk.Button(top, text="Simuler", command=self.simulate).pack(side="left", padx=8)

        ttk.Label(top, text="Classe :").pack(side="left", padx=(20, 4))
        self.class_combo = ttk.Combobox(top, textvariable=self.current_class, width=38)
        self.class_combo.pack(side="left")
        self.class_combo.bind("<<ComboboxSelected>>", lambda _e: self.refresh_graph())

        ttk.Label(top, text="t0").pack(side="left", padx=(18, 3))
        ttk.Entry(top, textvariable=self.start_time, width=7).pack(side="left")
        ttk.Label(top, text="t1").pack(side="left", padx=(8, 3))
        ttk.Entry(top, textvariable=self.stop_time, width=7).pack(side="left")
        ttk.Label(top, text="N").pack(side="left", padx=(8, 3))
        ttk.Entry(top, textvariable=self.intervals, width=7).pack(side="left")

        ttk.Label(top, textvariable=self.status).pack(side="right")

        main = ttk.Panedwindow(self, orient="horizontal")
        main.pack(fill="both", expand=True, padx=8, pady=(0, 8))

        left = ttk.Frame(main)
        right = ttk.Frame(main)
        main.add(left, weight=1)
        main.add(right, weight=3)

        ttk.Label(left, text="Classes / composants").pack(anchor="w")
        self.tree = ttk.Treeview(left, columns=("kind",), show="tree headings")
        self.tree.heading("#0", text="Nom")
        self.tree.heading("kind", text="Type")
        self.tree.column("#0", width=260)
        self.tree.column("kind", width=90)
        self.tree.pack(fill="both", expand=True)
        self.tree.bind("<<TreeviewSelect>>", self.on_tree_select)

        ttk.Label(left, text="Variables résultat").pack(anchor="w", pady=(8, 0))
        self.var_list = tk.Listbox(left, height=12)
        self.var_list.pack(fill="x")
        self.var_list.bind("<<ListboxSelect>>", self.on_variable_select)

        nb = ttk.Notebook(right)
        nb.pack(fill="both", expand=True)

        diagram_tab = ttk.Frame(nb)
        editor_tab = ttk.Frame(nb)
        plot_tab = ttk.Frame(nb)
        log_tab = ttk.Frame(nb)
        nb.add(diagram_tab, text="Blocs")
        nb.add(editor_tab, text="Éditeur .mo")
        nb.add(plot_tab, text="Simulation")
        nb.add(log_tab, text="Journal")

        self.canvas = tk.Canvas(diagram_tab, background="#f7f8fa", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _e: self.refresh_graph())

        self.editor = tk.Text(editor_tab, undo=True, wrap="none", font=("Consolas", 10))
        self.editor.pack(side="left", fill="both", expand=True)
        sy = ttk.Scrollbar(editor_tab, orient="vertical", command=self.editor.yview)
        sy.pack(side="right", fill="y")
        self.editor.configure(yscrollcommand=sy.set)

        self.plot = tk.Canvas(plot_tab, background="white", highlightthickness=0)
        self.plot.pack(fill="both", expand=True)
        self.plot.bind("<Configure>", lambda _e: self.draw_plot())

        self.log = tk.Text(log_tab, wrap="word", font=("Consolas", 9))
        self.log.pack(fill="both", expand=True)

    def set_status(self, text: str):
        self.after(0, lambda: self.status.set(text))

    def append_log(self, text: str):
        self.after(0, lambda: (self.log.insert("end", text + "\n"), self.log.see("end")))

    def open_file(self):
        path = filedialog.askopenfilename(filetypes=[("Modelica", "*.mo"), ("Tous", "*.*")])
        if path:
            self.load_file(Path(path))

    def open_default(self):
        repo_root = Path(__file__).resolve().parents[3]
        path = repo_root / DEFAULT_RELATIVE_MODEL
        if path.exists():
            self.load_file(path)
            self.current_class.set(DEFAULT_CLASS)
            self.refresh_graph()
        else:
            messagebox.showerror("M3", f"Fichier introuvable : {path}")

    def load_file(self, path: Path):
        try:
            source = path.read_text(encoding="utf-8")
        except Exception as exc:
            messagebox.showerror("Ouverture", str(exc))
            return
        self.model_path = path
        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", source)
        self.classes = discover_classes(source)
        names = [x[0] for x in self.classes]
        if names:
            self.class_combo["values"] = names
            if self.current_class.get() not in names:
                self.current_class.set(names[-1])
        self.populate_tree(source)
        self.refresh_graph()
        self.set_status(f"Chargé : {path.name}")

    def reload_file(self):
        if self.model_path:
            self.load_file(self.model_path)

    def save_file(self):
        if not self.model_path:
            self.save_as()
            return
        try:
            self.model_path.write_text(self.editor.get("1.0", "end-1c"), encoding="utf-8")
            self.set_status("Enregistré")
        except Exception as exc:
            messagebox.showerror("Enregistrement", str(exc))

    def save_as(self):
        path = filedialog.asksaveasfilename(defaultextension=".mo", filetypes=[("Modelica", "*.mo")])
        if path:
            self.model_path = Path(path)
            self.save_file()

    def source(self) -> str:
        return self.editor.get("1.0", "end-1c")

    def populate_tree(self, source: str):
        for item in self.tree.get_children():
            self.tree.delete(item)
        for name, kind, _ in self.classes:
            self.tree.insert("", "end", iid=f"class:{name}", text=name, values=(kind,))
        for inst in parse_instances(extract_class(source, self.current_class.get())):
            self.tree.insert("", "end", text=f"  {inst['name']}", values=(inst["type"],))

    def on_tree_select(self, _event):
        selection = self.tree.selection()
        if not selection:
            return
        item = selection[0]
        if item.startswith("class:"):
            self.current_class.set(item[6:])
            self.refresh_graph()

    def refresh_graph(self):
        self.canvas.delete("all")
        source = self.source()
        selected = extract_class(source, self.current_class.get())
        if not selected:
            selected = source
        ports = parse_ports(selected)
        instances = parse_instances(selected)
        connects = parse_connects(selected)

        w = max(700, self.canvas.winfo_width())
        h = max(450, self.canvas.winfo_height())

        self.canvas.create_text(25, 25, anchor="w",
                                text=self.current_class.get(),
                                font=("Segoe UI", 16, "bold"), fill="#17202a")

        # Main structural block.
        x0, y0, x1, y1 = 90, 100, w - 90, min(h - 120, 360)
        self.canvas.create_rectangle(x0, y0, x1, y1, fill="#e9eef3", outline="#64748b", width=2)
        self.canvas.create_text((x0+x1)/2, y0+28, text="Modèle / plante", font=("Segoe UI", 13, "bold"))

        input_ports = [p for p in ports if p["direction"] == "input"]
        output_ports = [p for p in ports if p["direction"] == "output"]

        for i, p in enumerate(input_ports):
            y = y0 + 70 + i * 30
            self.canvas.create_oval(x0-10, y-6, x0+2, y+6, fill="#3b82f6", outline="")
            self.canvas.create_text(x0+15, y, anchor="w", text=f"{p['name']} : {p['type']}", fill="#1e3a8a")
            self.canvas.create_line(x0-130, y, x0-10, y, arrow="last", fill="#3b82f6", width=2)

        for i, p in enumerate(output_ports):
            y = y0 + 70 + i * 30
            self.canvas.create_oval(x1-2, y-6, x1+10, y+6, fill="#16a34a", outline="")
            self.canvas.create_text(x1-15, y, anchor="e", text=f"{p['name']} : {p['type']}", fill="#166534")
            self.canvas.create_line(x1+10, y, x1+130, y, arrow="last", fill="#16a34a", width=2)

        if instances:
            self.canvas.create_text(25, h-90, anchor="w",
                                    text="Instances détectées", font=("Segoe UI", 10, "bold"))
            x = 25
            for inst in instances[:8]:
                label = f"{inst['name']}\n{inst['type']}"
                self.canvas.create_rectangle(x, h-65, x+150, h-25, fill="white", outline="#94a3b8")
                self.canvas.create_text(x+75, h-45, text=label, justify="center", font=("Segoe UI", 8))
                x += 165

        if connects:
            self.canvas.create_text(w-25, h-90, anchor="e",
                                    text=f"{len(connects)} connexion(s) connect() détectée(s)",
                                    font=("Segoe UI", 9), fill="#475569")
        else:
            self.canvas.create_text(w-25, h-90, anchor="e",
                                    text="Vue structurelle — équations explicites / composants sans connect()",
                                    font=("Segoe UI", 9), fill="#64748b")

        self.populate_tree(source)

    def make_mos(self, workdir: Path) -> Path:
        if not self.model_path:
            raise RuntimeError("Aucun fichier .mo chargé")
        source_path = self.model_path.resolve()
        script = workdir / "run.mos"
        prefix = workdir / "m3_result"
        model_file = modelica_string(str(source_path))
        script_text = f"""
loadModel(Modelica);
loadFile({model_file});
print("=== CHECK ===");
checkModel({self.current_class.get()});
print(getErrorString());
print("=== SIMULATE ===");
simulate({self.current_class.get()},
  startTime={float(self.start_time.get())},
  stopTime={float(self.stop_time.get())},
  numberOfIntervals={int(self.intervals.get())},
  tolerance=1e-6,
  method="dassl",
  fileNamePrefix={modelica_string(str(prefix))},
  outputFormat="csv");
print(getErrorString());
"""
        script.write_text(script_text, encoding="utf-8")
        return script

    def check_model(self):
        if not self.omc:
            messagebox.showerror("OpenModelica", "omc.exe introuvable.")
            return
        if not self.model_path:
            return
        self.save_file()
        self.set_status("Vérification...")
        self.append_log("\n=== CHECK MODEL ===")
        threading.Thread(target=self._run_check, daemon=True).start()

    def _run_check(self):
        with tempfile.TemporaryDirectory(prefix="modelica_viewer_") as td:
            work = Path(td)
            script = work / "check.mos"
            script.write_text(
                f'loadModel(Modelica);\nloadFile({modelica_string(str(self.model_path.resolve()))});\n'
                f'checkModel({self.current_class.get()});\nprint(getErrorString());\n',
                encoding="utf-8",
            )
            try:
                proc = subprocess.run([self.omc, str(script)], cwd=work,
                                      capture_output=True, text=True, timeout=180)
                out = proc.stdout + "\n" + proc.stderr
                self.append_log(out)
                ok = proc.returncode == 0 and "Error" not in out
                self.set_status("CHECK PASS" if ok else "CHECK / compilation à examiner")
            except Exception as exc:
                self.append_log(str(exc))
                self.set_status("Erreur CHECK")

    def simulate(self):
        if not self.omc:
            messagebox.showerror("OpenModelica", "omc.exe introuvable.")
            return
        if not self.model_path:
            return
        try:
            if float(self.stop_time.get()) <= float(self.start_time.get()):
                raise ValueError("t1 doit être supérieur à t0")
            if int(self.intervals.get()) < 10:
                raise ValueError("N doit être >= 10")
        except Exception as exc:
            messagebox.showerror("Simulation", str(exc))
            return

        self.save_file()
        self.set_status("Simulation OpenModelica...")
        self.append_log("\n=== SIMULATION ===")
        threading.Thread(target=self._run_simulation, daemon=True).start()

    def _run_simulation(self):
        with tempfile.TemporaryDirectory(prefix="modelica_viewer_") as td:
            work = Path(td)
            script = self.make_mos(work)
            try:
                proc = subprocess.run([self.omc, str(script)], cwd=work,
                                      capture_output=True, text=True, timeout=300)
                out = proc.stdout + "\n" + proc.stderr
                self.append_log(out)
                csv_candidates = list(work.glob("*_res.csv"))
                if not csv_candidates:
                    # OpenModelica may honour an absolute prefix differently.
                    csv_candidates = list(work.rglob("*.csv"))
                if proc.returncode != 0 or not csv_candidates:
                    self.set_status("Simulation échouée")
                    return
                headers, data = read_csv(csv_candidates[0])
                self.after(0, lambda: self.load_results(headers, data))
                self.set_status(f"Simulation OK — {len(data.get('time', []))} points")
            except subprocess.TimeoutExpired:
                self.append_log("Timeout > 300 s")
                self.set_status("Simulation interrompue")
            except Exception as exc:
                self.append_log(str(exc))
                self.set_status("Erreur simulation")

    def load_results(self, headers, data):
        self.variables = {k: v for k, v in data.items() if k != "time"}
        self.time_values = data.get("time", [])
        self.var_list.delete(0, "end")
        for name in sorted(self.variables):
            self.var_list.insert("end", name)
        if self.variables:
            self.var_list.selection_set(0)
            self.selected_var.set(self.var_list.get(0))
        self.draw_plot()

    def on_variable_select(self, _event):
        selection = self.var_list.curselection()
        if selection:
            self.selected_var.set(self.var_list.get(selection[0]))
            self.draw_plot()

    def draw_plot(self):
        self.plot.delete("all")
        values = self.variables.get(self.selected_var.get(), [])
        times = self.time_values
        w = max(500, self.plot.winfo_width())
        h = max(400, self.plot.winfo_height())
        if not values or not times:
            self.plot.create_text(w/2, h/2, text="Simuler pour afficher un résultat",
                                  fill="#64748b")
            return

        pairs = [(t, v) for t, v in zip(times, values) if v == v]
        if not pairs:
            return
        tmin, tmax = pairs[0][0], pairs[-1][0]
        ymin = min(v for _, v in pairs)
        ymax = max(v for _, v in pairs)
        if abs(ymax-ymin) < 1e-12:
            ymax += 1
            ymin -= 1

        left, top, right, bottom = 65, 35, w-25, h-65
        self.plot.create_line(left, bottom, right, bottom, fill="#64748b")
        self.plot.create_line(left, top, left, bottom, fill="#64748b")

        last = None
        for t, v in pairs:
            x = left + (t-tmin) / max(1e-12, tmax-tmin) * (right-left)
            y = bottom - (v-ymin) / max(1e-12, ymax-ymin) * (bottom-top)
            if last:
                self.plot.create_line(last[0], last[1], x, y, fill="#2563eb", width=2)
            last = (x, y)

        self.plot.create_text(left, top-15, anchor="w",
                              text=self.selected_var.get(), font=("Segoe UI", 10, "bold"))
        self.plot.create_text(right, bottom+25, anchor="e", text=f"t = {tmax:g} s")
        self.plot.create_text(left, top, anchor="e", text=f"{ymax:.5g}")
        self.plot.create_text(left, bottom, anchor="e", text=f"{ymin:.5g}")
        self.plot.create_text((left+right)/2, h-20,
                              text=f"min {ymin:.5g}   max {ymax:.5g}   final {pairs[-1][1]:.5g}",
                              fill="#334155")


if __name__ == "__main__":
    app = ModelicaViewer()
    app.mainloop()
