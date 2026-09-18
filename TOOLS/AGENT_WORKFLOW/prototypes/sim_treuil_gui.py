#!/usr/bin/env python3
"""
Interface graphique (Tkinter, stdlib -- aucune dependance a installer pour l'UI elle-meme)
pour piloter le prototype sim_treuil_electrique.py sans ligne de commande.

Lancement :
    python TOOLS/AGENT_WORKFLOW/prototypes/sim_treuil_gui.py

Optionnel pour le graphe integre : pip install matplotlib
"""

from __future__ import annotations

import json
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

from sim_treuil_electrique import (
    GensetParams, MotorParams, WinchInstance,
    scenario_un_treuil, scenario_deux_treuils, load_incident,
    simulate_multi,
)

try:
    import matplotlib
    matplotlib.use("TkAgg")
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
    HAS_MPL = True
except ImportError:
    HAS_MPL = False


class SimGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("SimBench Treuil Electrique -- prototype T317 (hors CODESYS)")
        self.geometry("1100x750")

        self._build_controls()
        self._build_output()

    # ------------------------------------------------------------------
    def _build_controls(self):
        top = ttk.Frame(self, padding=8)
        top.pack(side="top", fill="x")

        ttk.Label(top, text="Mode :", font=("", 10, "bold")).grid(row=0, column=0, sticky="w")
        self.mode = tk.StringVar(value="un_treuil")
        modes = [
            ("Un treuil", "un_treuil"),
            ("Un treuil -- comparer charge/a vide", "compare"),
            ("Deux treuils simultanes", "deux_treuils"),
            ("Rejeu d'incident (JSON)", "incident"),
        ]
        for i, (label, value) in enumerate(modes):
            ttk.Radiobutton(top, text=label, variable=self.mode, value=value,
                             command=self._on_mode_change).grid(row=0, column=1 + i, sticky="w", padx=4)

        # --- Parametres mode "un treuil" / "compare" ---
        self.frame_un = ttk.LabelFrame(self, text="Parametres -- un treuil", padding=8)
        self.frame_un.pack(side="top", fill="x", padx=8, pady=4)

        ttk.Label(self.frame_un, text="Charge (0-1) :").grid(row=0, column=0, sticky="w")
        self.load_var = tk.DoubleVar(value=0.9)
        ttk.Entry(self.frame_un, textvariable=self.load_var, width=8).grid(row=0, column=1, sticky="w")

        ttk.Label(self.frame_un, text="Instants bascule gradins (s, separes par virgule) :").grid(row=0, column=2, sticky="w", padx=(16, 0))
        self.gradin_times_var = tk.StringVar(value="0,0.4,0.8,1.2")
        ttk.Entry(self.frame_un, textvariable=self.gradin_times_var, width=24).grid(row=0, column=3, sticky="w")

        ttk.Label(self.frame_un, text="Duree simulee (s) :").grid(row=1, column=0, sticky="w", pady=(4, 0))
        self.t_end_var = tk.DoubleVar(value=6.0)
        ttk.Entry(self.frame_un, textvariable=self.t_end_var, width=8).grid(row=1, column=1, sticky="w", pady=(4, 0))

        ttk.Label(self.frame_un, text="Sens :").grid(row=1, column=2, sticky="w", padx=(16, 0), pady=(4, 0))
        self.direction_var = tk.StringVar(value="montee")
        ttk.Radiobutton(self.frame_un, text="Montee", variable=self.direction_var, value="montee").grid(row=1, column=3, sticky="w", pady=(4, 0))
        ttk.Radiobutton(self.frame_un, text="Descente (mode generatrice possible)", variable=self.direction_var, value="descente").grid(row=1, column=4, sticky="w", pady=(4, 0))

        # --- Parametres mode "incident" ---
        self.frame_incident = ttk.LabelFrame(self, text="Parametres -- rejeu d'incident", padding=8)
        ttk.Label(self.frame_incident, text="Fichier JSON :").grid(row=0, column=0, sticky="w")
        self.incident_path_var = tk.StringVar(value="")
        ttk.Entry(self.frame_incident, textvariable=self.incident_path_var, width=60).grid(row=0, column=1, sticky="w")
        ttk.Button(self.frame_incident, text="Parcourir...", command=self._browse_incident).grid(row=0, column=2, padx=4)

        # --- Parametres avances (moteur/genset) ---
        self.frame_adv = ttk.LabelFrame(self, text="Caracteristiques techniques (modifiables -- valeurs SYNTHETIQUES)", padding=8)
        self.frame_adv.pack(side="top", fill="x", padx=8, pady=4)

        adv_fields = [
            ("Cmax moteur (N.m)", "cmax", 3800.0),
            ("In stator (A)", "in_stator", 200.0),
            ("Inertie J (kg.m2)", "j_total", 45.0),
            ("U nominal GE (V)", "u_nom", 400.0),
            ("I nominal GE (A)", "i_nom_ge", 350.0),
            ("Seuil choc reducteur (x nominal)", "sf_choc", 2.5),
        ]
        self.adv_vars = {}
        self.adv_entries = []
        for i, (label, key, default) in enumerate(adv_fields):
            ttk.Label(self.frame_adv, text=label + " :").grid(row=i // 3, column=(i % 3) * 2, sticky="w", padx=(0, 4), pady=2)
            var = tk.DoubleVar(value=default)
            entry = ttk.Entry(self.frame_adv, textvariable=var, width=10)
            entry.grid(row=i // 3, column=(i % 3) * 2 + 1, sticky="w", padx=(0, 16))
            self.adv_vars[key] = var
            self.adv_entries.append(entry)

        self.adv_note = ttk.Label(self.frame_adv, text="", foreground="#b05000")
        self.adv_note.grid(row=2, column=0, columnspan=6, sticky="w", pady=(4, 0))

        # --- Boutons d'action ---
        actions = ttk.Frame(self, padding=8)
        actions.pack(side="top", fill="x")
        ttk.Button(actions, text="Simuler", command=self._run).pack(side="left", padx=4)
        ttk.Button(actions, text="Effacer", command=self._clear_output).pack(side="left", padx=4)
        self.plot_status = ttk.Label(actions, text="matplotlib: OK" if HAS_MPL else "matplotlib absent (pip install matplotlib pour le graphe)")
        self.plot_status.pack(side="left", padx=16)

        self._on_mode_change()

    def _on_mode_change(self):
        is_incident = self.mode.get() == "incident"
        if is_incident:
            self.frame_un.pack_forget()
            self.frame_incident.pack(side="top", fill="x", padx=8, pady=4, before=self.frame_adv)
        else:
            self.frame_incident.pack_forget()
            self.frame_un.pack(side="top", fill="x", padx=8, pady=4)

        # En mode incident, les caracteristiques avancees sont ignorees : le fichier JSON
        # fait foi (sinon on ecrase silencieusement les parametres d'un incident rejoue --
        # bug bloquant identifie en revue 2026-09-18). On grise le bloc pour que ce soit visible.
        for entry in self.adv_entries:
            entry.config(state="disabled" if is_incident else "normal")
        self.adv_note.config(
            text="Ignore en mode incident : le fichier JSON fait foi pour Cmax/In/J/U_nom/I_nom_GE."
            if is_incident else ""
        )

    def _browse_incident(self):
        path = filedialog.askopenfilename(
            initialdir="TOOLS/AGENT_WORKFLOW/prototypes",
            filetypes=[("JSON", "*.json")],
        )
        if path:
            self.incident_path_var.set(path)

    # ------------------------------------------------------------------
    def _build_output(self):
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(side="top", fill="both", expand=True, padx=8, pady=4)

        tab_results = ttk.Frame(self.notebook)
        tab_schema = ttk.Frame(self.notebook)
        self.notebook.add(tab_results, text="📋 Resultats + graphe")
        self.notebook.add(tab_schema, text="🔌 Schema synoptique")

        left = ttk.Frame(tab_results)
        left.pack(side="left", fill="both", expand=True)
        self.output = tk.Text(left, wrap="none", font=("Consolas", 9))
        self.output.pack(side="top", fill="both", expand=True)
        scroll = ttk.Scrollbar(left, command=self.output.yview)
        scroll.pack(side="right", fill="y")
        self.output.config(yscrollcommand=scroll.set)

        self.plot_frame = ttk.Frame(tab_results, width=420)
        self.plot_frame.pack(side="right", fill="both")

        self._build_schematic(tab_schema)

    def _clear_output(self):
        self.output.delete("1.0", tk.END)
        for w in self.plot_frame.winfo_children():
            w.destroy()
        self._reset_schematic()

    # ------------------------------------------------------------------
    # Schema synoptique : blocs physiques relies par les flux de grandeurs
    # (tension, couple, courant, vitesse), valeurs mises a jour via un curseur
    # temporel qui rejoue la sequence simulee pas a pas.
    # ------------------------------------------------------------------
    def _build_schematic(self, parent):
        top = ttk.Frame(parent, padding=6)
        top.pack(side="top", fill="x")

        ttk.Label(top, text="Treuil affiche :").pack(side="left")
        self.schema_selector_var = tk.StringVar(value="")
        self.schema_selector = ttk.Combobox(top, textvariable=self.schema_selector_var, state="readonly", width=40)
        self.schema_selector.pack(side="left", padx=6)
        self.schema_selector.bind("<<ComboboxSelected>>", lambda e: self._update_schematic())

        self.schema_time_label = ttk.Label(top, text="t = -- s   (lance une simulation)")
        self.schema_time_label.pack(side="left", padx=16)

        self.schema_time_idx = tk.IntVar(value=0)
        self.schema_slider = ttk.Scale(
            parent, from_=0, to=0, orient="horizontal",
            variable=self.schema_time_idx, command=lambda v: self._update_schematic(),
        )
        self.schema_slider.pack(side="top", fill="x", padx=6, pady=(0, 6))

        self.schema_canvas = tk.Canvas(parent, bg="white", height=560)
        self.schema_canvas.pack(side="top", fill="both", expand=True, padx=6, pady=6)

        self._schema_blocks = {}   # key -> {"value_id": canvas_id, "rect_id": canvas_id}
        self._schema_results = {}  # "titre / treuil" -> WinchInstance
        self._draw_schematic_layout()

    def _draw_block(self, x, y, w, h, title, subtitle, fill="#eef3fa"):
        rect = self.schema_canvas.create_rectangle(x, y, x + w, y + h, fill=fill, outline="#4a6fa5", width=2)
        self.schema_canvas.create_text(x + w / 2, y + 16, text=title, font=("", 9, "bold"), width=w - 10)
        self.schema_canvas.create_text(x + w / 2, y + h - 20, text=subtitle, font=("", 7), fill="#555", width=w - 10)
        value_id = self.schema_canvas.create_text(x + w / 2, y + h / 2 + 4, text="--", font=("Consolas", 11, "bold"), fill="#1a5c1a")
        return {"rect_id": rect, "value_id": value_id, "x": x, "y": y, "w": w, "h": h}

    def _arrow(self, x1, y1, x2, y2, label=""):
        self.schema_canvas.create_line(x1, y1, x2, y2, arrow=tk.LAST, width=2, fill="#4a6fa5")
        if label:
            self.schema_canvas.create_text((x1 + x2) / 2, (y1 + y2) / 2 - 10, text=label, font=("", 8), fill="#4a6fa5")

    def _draw_schematic_layout(self):
        c = self.schema_canvas
        bw, bh = 160, 90

        # Ligne principale : GE -> Moteur -> Mecanique -> Charge
        x_ge, x_mot, x_mec, x_charge = 30, 260, 490, 720
        y_main = 60

        self._schema_blocks["ge"] = self._draw_block(x_ge, y_main, bw, bh, "⚡ Groupe electrogene", "U reseau", "#fdeecb")
        self._schema_blocks["moteur"] = self._draw_block(x_mot, y_main, bw, bh, "🧲 Moteur (bobinage)", "Couple electromagnetique", "#e6f0ff")
        self._schema_blocks["mecanique"] = self._draw_block(x_mec, y_main, bw, bh, "⚙️ Mecanique + reducteur", "Vitesse / glissement", "#e8f7e8")
        self._schema_blocks["charge"] = self._draw_block(x_charge, y_main, bw, bh, "🪝 Charge (treuil)", "Couple resistant", "#f7e8e8")

        self._arrow(x_ge + bw, y_main + bh / 2, x_mot, y_main + bh / 2, "U (V)")
        self._arrow(x_mot + bw, y_main + bh / 2, x_mec, y_main + bh / 2, "C moteur (N.m)")
        self._arrow(x_mec + bw, y_main + bh / 2, x_charge, y_main + bh / 2, "N (rpm)")
        self._arrow(x_charge + 10, y_main + bh + 5, x_mec + 10, y_main + bh + 5, "")
        c.create_text((x_mec + x_charge) / 2 + bw / 2, y_main + bh + 18, text="<- C resistant (retro-action)", font=("", 7), fill="#a05050")

        # Blocs derives (branches secondaires) sous le moteur et la mecanique
        y_sec = 210
        self._schema_blocks["courant"] = self._draw_block(x_mot, y_sec, bw, bh, "🔥 Courant stator I1", "Composition I0 / Iactif", "#fff2e0")
        self._arrow(x_mot + bw / 2, y_main + bh, x_mot + bw / 2, y_sec, "")

        y_sec2 = 340
        self._schema_blocks["thermique"] = self._draw_block(x_mot - 40, y_sec2, bw, bh, "🌡️ Protection thermique", "Image I2t (relais)", "#ffe0e0")
        self._schema_blocks["isolant"] = self._draw_block(x_mot + 180, y_sec2, bw, bh, "🧪 Isolant bobinage", "Vieillissement Montsinger", "#ffe0e0")
        self._arrow(x_mot + bw / 2 - 20, y_sec + bh, x_mot + bw / 2 - 20 - 20, y_sec2, "I1")
        self._arrow(x_mot + bw / 2 + 20, y_sec + bh, x_mot + bw / 2 + 60, y_sec2, "I1")

        self._schema_blocks["choc"] = self._draw_block(x_mec, y_sec2, bw, bh, "💥 Choc reducteur", "Seuil SF x nominal", "#ffe0e0")
        self._arrow(x_mec + bw / 2, y_main + bh, x_mec + bw / 2, y_sec2, "C moteur")

        c.create_text(30, 470, anchor="w", font=("", 8, "italic"), fill="#555",
                       text="Fleches = flux de grandeurs entre blocs physiques. Deplace le curseur au-dessus pour rejouer la sequence pas a pas.")

    def _reset_schematic(self):
        self._schema_results = {}
        self.schema_selector["values"] = []
        self.schema_selector_var.set("")
        self.schema_slider.config(to=0)
        self.schema_time_idx.set(0)
        self.schema_time_label.config(text="t = -- s   (lance une simulation)")
        for block in self._schema_blocks.values():
            self.schema_canvas.itemconfig(block["value_id"], text="--")

    def _populate_schematic(self, results):
        self._schema_results = {}
        for title, res in results:
            for name, w in res.winches.items():
                label = f"{title} / {name}" if len(res.winches) > 1 or len(results) > 1 else title
                self._schema_results[label] = w

        keys = list(self._schema_results.keys())
        self.schema_selector["values"] = keys
        if keys:
            self.schema_selector_var.set(keys[0])
            w = self._schema_results[keys[0]]
            n_points = len(w.hist["t"])
            self.schema_slider.config(to=max(n_points - 1, 0))
            self.schema_time_idx.set(max(n_points - 1, 0))  # positionne sur l'etat final par defaut
        self._update_schematic()

    def _update_schematic(self):
        label = self.schema_selector_var.get()
        w = self._schema_results.get(label)
        if w is None or not w.hist["t"]:
            return
        idx = int(self.schema_time_idx.get())
        idx = max(0, min(idx, len(w.hist["t"]) - 1))

        t = w.hist["t"][idx]
        self.schema_time_label.config(text=f"t = {t:.2f} s   (gradin {w.hist['gradin'][idx]})")

        def set_val(key, text):
            self.schema_canvas.itemconfig(self._schema_blocks[key]["value_id"], text=text)

        # Tension reseau : reconstituee depuis U_reseau_hist du meme index (partage entre treuils)
        res_owner = None
        for title, res in getattr(self, "_last_raw_results", []):
            if w in res.winches.values():
                res_owner = res
                break
        u_val = res_owner.U_reseau_hist[idx] if res_owner else float("nan")

        regime = "GENERATRICE" if w.hist['C'][idx] < 0 else "moteur"  # cf. print_summary, meme convention
        set_val("ge", f"{u_val:.0f} V")
        set_val("moteur", f"{w.hist['C'][idx]:.0f} N.m\n({regime})")
        set_val("mecanique", f"{w.hist['N_rpm'][idx]:.0f} rpm\ng={w.hist['g'][idx]:.2f}")
        set_val("charge", f"{w.hist['Cr'][idx]:.0f} N.m")
        pic_note = " <PIC>" if w.hist["I1_brut"][idx] > w.hist["I1"][idx] * 1.05 else ""
        set_val("courant", f"{w.hist['I1_brut'][idx]:.0f} A{pic_note}\n(lisse: {w.hist['I1'][idx]:.0f} A)")
        set_val("thermique", f"{w.image.theta*100:.0f}%" if idx == len(w.hist['t']) - 1 else f"{w.hist['theta'][idx]*100:.0f}%")
        set_val("isolant", f"{w.hist['theta_bobinage'][idx]:.0f} C")
        choc_txt = "SEVERE" if (w.shock.choc_detecte and w.shock.choc_time is not None and w.shock.choc_time <= t and w.shock.choc_severe) \
            else ("choc" if (w.shock.choc_detecte and w.shock.choc_time is not None and w.shock.choc_time <= t) else "--")
        set_val("choc", choc_txt)

    def _apply_advanced(self, motor: MotorParams, genset: GensetParams):
        motor.Cmax = self.adv_vars["cmax"].get()
        motor.In_stator = self.adv_vars["in_stator"].get()
        motor.J_total = self.adv_vars["j_total"].get()
        genset.U_nom = self.adv_vars["u_nom"].get()
        genset.I_nom_groupe = self.adv_vars["i_nom_ge"].get()

    def _validate_common(self) -> str | None:
        """Retourne un message d'erreur convivial, ou None si tout est valide."""
        mode = self.mode.get()
        if mode == "incident":
            return None
        try:
            gradin_times = [float(x) for x in self.gradin_times_var.get().split(",")]
        except ValueError:
            return "Instants de bascule gradins invalides -- utilise des nombres separes par des virgules (ex: 0,0.4,0.8,1.2)."
        if not gradin_times:
            return "Renseigne au moins un instant de bascule gradin."
        t_end = self.t_end_var.get()
        if t_end <= 0:
            return "La duree simulee doit etre strictement positive."
        if max(gradin_times) >= t_end:
            return (f"Le dernier gradin bascule a t={max(gradin_times)}s mais la duree simulee "
                    f"n'est que de {t_end}s -- augmente la duree simulee pour voir le regime etabli.")
        load = self.load_var.get()
        if not (0.0 <= load <= 1.0):
            return f"Charge {load} hors plage physique [0,1] -- 0=a vide, 1=pleine charge nominale."
        return None

    # ------------------------------------------------------------------
    def _run(self):
        self._clear_output()
        err = self._validate_common()
        if err:
            messagebox.showwarning("Parametres invalides", err)
            return
        try:
            mode = self.mode.get()
            results = []  # liste de (titre, MultiSimResult)

            if mode == "incident":
                path = self.incident_path_var.get()
                if not path:
                    messagebox.showwarning("Fichier manquant", "Choisis un fichier JSON d'incident.")
                    return
                genset, winches, t_end = load_incident(path)
                # Mode incident : le fichier JSON fait foi, on n'ecrase PAS ses parametres
                # avec les champs avances du GUI (bug bloquant corrige le 2026-09-18).
                res = simulate_multi(genset, winches, t_end)
                results.append((f"Rejeu incident : {path}", res))

            elif mode == "deux_treuils":
                genset, winches, t_end = scenario_deux_treuils(self.t_end_var.get())
                for w in winches:
                    self._apply_advanced(w.motor, genset)
                    w.gearbox.SF_choc_admissible = self.adv_vars["sf_choc"].get()
                res = simulate_multi(genset, winches, t_end)
                results.append(("Deux treuils simultanes", res))

            else:
                load = self.load_var.get()
                gradin_times = [float(x) for x in self.gradin_times_var.get().split(",")]
                t_end = self.t_end_var.get()
                direction = 1 if self.direction_var.get() == "montee" else -1
                sens_label = "montee" if direction == 1 else "descente"

                genset, winches, _ = scenario_un_treuil(load, gradin_times, t_end, direction)
                for w in winches:
                    self._apply_advanced(w.motor, genset)
                    w.gearbox.SF_choc_admissible = self.adv_vars["sf_choc"].get()
                res = simulate_multi(genset, winches, t_end)
                results.append((f"Charge {load*100:.0f}% ({sens_label})", res))

                if mode == "compare":
                    genset2, winches2, _ = scenario_un_treuil(0.0, gradin_times, t_end, direction)
                    for w in winches2:
                        self._apply_advanced(w.motor, genset2)
                        w.gearbox.SF_choc_admissible = self.adv_vars["sf_choc"].get()
                    res2 = simulate_multi(genset2, winches2, t_end)
                    results.append((f"A vide ({sens_label})", res2))

            self._last_raw_results = results
            self._print_all(results)
            if HAS_MPL:
                self._plot_all(results)
            self._populate_schematic(results)

        except Exception as exc:  # affichage d'erreur convivial plutot qu'un traceback brut
            messagebox.showerror("Erreur de simulation", str(exc))

    # ------------------------------------------------------------------
    def _print_all(self, results):
        from io import StringIO
        import contextlib
        import sim_treuil_electrique as sim_mod

        for title, res in results:
            buf = StringIO()
            with contextlib.redirect_stdout(buf):
                print(f"\n### {title} ###")
                sim_mod.print_summary(res)
            self.output.insert(tk.END, buf.getvalue())
        self.output.insert(tk.END, "\n\nRAPPEL : parametres SYNTHETIQUES, non calibres terrain.\n")

    def _plot_all(self, results):
        # Tous les scenarios de `results` sont superposes sur le meme graphe (ex: mode
        # "compare" = charge + a vide) -- avant correction, seul results[0] etait trace
        # sans que l'utilisateur soit informe que l'autre cas manquait (bug corrige 2026-09-18).
        for w in self.plot_frame.winfo_children():
            w.destroy()

        fig = Figure(figsize=(4.5, 6.5), dpi=100)
        colors = ["black", "tab:orange", "tab:green", "tab:red"]

        ax0 = fig.add_subplot(3, 1, 1)
        ax1 = fig.add_subplot(3, 1, 2, sharex=ax0)
        ax2 = fig.add_subplot(3, 1, 3, sharex=ax0)

        for idx, (title, res) in enumerate(results):
            color = colors[idx % len(colors)]
            ax0.plot(res.t_hist, res.U_reseau_hist, color=color, label=title)
            for name, w in res.winches.items():
                suffixe = f" {name}" if len(res.winches) > 1 else ""
                ax1.plot(w.hist["t"], w.hist["I1_brut"], color=color, alpha=0.4, linewidth=1,
                          label=f"{title}{suffixe} (brut, pics commutation)")
                ax1.plot(w.hist["t"], w.hist["I1"], color=color, linestyle="-" if idx == 0 else "--",
                          label=f"{title}{suffixe} (lisse)")
                ax2.plot(w.hist["t"], w.hist["N_rpm"], color=color, linestyle="-" if idx == 0 else "--",
                          label=f"{title}{suffixe}")

        ax0.axhline(400, color="gray", linestyle=":", alpha=0.5)
        ax0.set_ylabel("U reseau (V)")
        ax0.legend(fontsize=7)
        ax0.grid(True, alpha=0.3)

        ax1.set_ylabel("I1 (A)")
        ax1.legend(fontsize=6)
        ax1.grid(True, alpha=0.3)

        ax2.set_ylabel("Vitesse (rpm)")
        ax2.set_xlabel("Temps (s)")
        ax2.legend(fontsize=6)
        ax2.grid(True, alpha=0.3)

        fig.suptitle(" vs ".join(t for t, _ in results), fontsize=9)
        fig.tight_layout()

        canvas = FigureCanvasTkAgg(fig, master=self.plot_frame)
        canvas.draw()
        canvas.get_tk_widget().pack(side="top", fill="both", expand=True)


if __name__ == "__main__":
    SimGUI().mainloop()
