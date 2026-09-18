"""Test d'integrite headless du GUI -- non interactif, mocke les dialogues bloquants."""
import sys
from unittest import mock

import sim_treuil_gui as g

# Empeche tout messagebox modal de bloquer le test (on capture juste ce qui aurait ete affiche)
g.messagebox.showerror = lambda title, msg: print(f"[messagebox.showerror] {title}: {msg}")
g.messagebox.showwarning = lambda title, msg: print(f"[messagebox.showwarning] {title}: {msg}")


def try_mode(app, mode, **kwargs):
    print(f"--- test mode={mode} kwargs={kwargs} ---", flush=True)
    app._clear_output()
    app.mode.set(mode)
    app._on_mode_change()
    if "load" in kwargs:
        app.load_var.set(kwargs["load"])
    if "gradin_times" in kwargs:
        app.gradin_times_var.set(kwargs["gradin_times"])
    if "t_end" in kwargs:
        app.t_end_var.set(kwargs["t_end"])
    if "incident_path" in kwargs:
        app.incident_path_var.set(kwargs["incident_path"])
    try:
        app._run()
        txt = app.output.get("1.0", "end")
        print("OK -- longueur sortie:", len(txt), flush=True)
        if "Traceback" in txt:
            print("!!! Traceback dans la sortie:", txt[:500], flush=True)
        # Verification du schema synoptique
        keys = list(app._schema_results.keys())
        print("schema keys:", keys, flush=True)
        if keys:
            for idx in [0, len(app._schema_results[keys[0]].hist["t"]) // 2, -1]:
                app.schema_time_idx.set(idx if idx >= 0 else len(app._schema_results[keys[0]].hist["t"]) - 1)
                app._update_schematic()
                vals = {k: app.schema_canvas.itemcget(b["value_id"], "text") for k, b in app._schema_blocks.items()}
                print(f"  idx={idx} valeurs schema:", vals, flush=True)
    except Exception as e:
        print("EXCEPTION NON CAPTUREE:", repr(e), flush=True)
    print(flush=True)


def main():
    app = g.SimGUI()
    app.update()

    try_mode(app, "un_treuil", load=0.9, gradin_times="0,0.4,0.8,1.2", t_end=5)
    try_mode(app, "compare", load=0.5, gradin_times="0,0.4,0.8,1.2", t_end=5)
    try_mode(app, "deux_treuils", t_end=6)
    try_mode(app, "incident", incident_path="incident_exemple.json")
    try_mode(app, "un_treuil", load=0.0, gradin_times="0,0.4,0.8,1.2", t_end=3)
    try_mode(app, "un_treuil", load=1.0, gradin_times="0,0.1,0.2,0.3", t_end=3)
    try_mode(app, "un_treuil", load=0.9, gradin_times="0", t_end=3)
    try_mode(app, "incident", incident_path="fichier_qui_nexiste_pas.json")
    try_mode(app, "un_treuil", load=0.9, gradin_times="pas,des,nombres", t_end=3)
    try_mode(app, "un_treuil", load=0.9, gradin_times="0,0.4,0.8,1.2", t_end=0)
    try_mode(app, "un_treuil", load=-0.5, gradin_times="0,0.4,0.8,1.2", t_end=3)

    app.destroy()
    print("=== FIN BATTERIE DE TESTS ===", flush=True)


if __name__ == "__main__":
    main()
