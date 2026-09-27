"""Interactive offline M3 workbench using the native TwinBench plant."""
from __future__ import annotations

import csv
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, ttk

from m3_native import M3Config, M3Inputs, M3NativePlant


class M3NativeViewer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("TwinBench — M3 autonome")
        self.geometry("1280x800")
        self.minsize(1000, 650)
        self.cfg = M3Config()
        self.plant = M3NativePlant(self.cfg)
        self.running = False
        self.t = 0.0
        self.dt = 0.05
        self.history: list[dict] = []

        self.command = tk.IntVar(value=0)
        self.frequency = tk.DoubleVar(value=0.0)
        self.brake = tk.BooleanVar(value=False)
        self.thermal = tk.BooleanVar(value=True)
        self.device = tk.BooleanVar(value=True)
        self.speed = tk.DoubleVar(value=1.0)
        self.status = tk.StringVar(value="Prêt — moteur autonome, sans omc.exe")
        self._build()
        self._refresh(self.plant.outputs(self._inputs()))
        self.after(50, self._tick)

    def _build(self):
        top = ttk.Frame(self, padding=8); top.pack(fill="x")
        ttk.Button(top, text="▶ Démarrer", command=self._toggle).pack(side="left")
        ttk.Button(top, text="Pas +50 ms", command=self._single_step).pack(side="left", padx=5)
        ttk.Button(top, text="↻ Reset P1", command=self._reset).pack(side="left")
        ttk.Button(top, text="Export CSV", command=self._export).pack(side="left", padx=5)
        ttk.Label(top, textvariable=self.status).pack(side="right")

        body = ttk.Panedwindow(self, orient="horizontal"); body.pack(fill="both", expand=True, padx=8, pady=8)
        controls = ttk.Frame(body, padding=8); view = ttk.Frame(body, padding=8)
        body.add(controls, weight=1); body.add(view, weight=3)

        ttk.Label(controls, text="Interface PLC → AC600", font=("Segoe UI", 12, "bold")).pack(anchor="w")
        ttk.Label(controls, text="CommandWord").pack(anchor="w", pady=(12, 2))
        for text, value in (("0 — Stop",0),("1 — Trémie",1),("2 — Maintenance",2)):
            ttk.Radiobutton(controls, text=text, variable=self.command, value=value).pack(anchor="w")
        ttk.Label(controls, text="SetpointFrequency [Hz]").pack(anchor="w", pady=(12,2))
        ttk.Scale(controls, from_=0, to=50, variable=self.frequency, orient="horizontal").pack(fill="x")
        self.freq_label = ttk.Label(controls); self.freq_label.pack(anchor="w")
        ttk.Checkbutton(controls, text="BrakeRelease_RQ", variable=self.brake).pack(anchor="w", pady=(12,0))
        ttk.Checkbutton(controls, text="M3_ThermalOK", variable=self.thermal).pack(anchor="w")
        ttk.Checkbutton(controls, text="AC600 Device RUNNING", variable=self.device).pack(anchor="w")
        ttk.Label(controls, text="Vitesse temps réel").pack(anchor="w", pady=(12,2))
        ttk.Combobox(controls, textvariable=self.speed, values=(0.5,1.0,2.0,4.0), state="readonly", width=8).pack(anchor="w")

        ttk.Separator(controls).pack(fill="x", pady=15)
        ttk.Label(controls, text="Retours équipement → PLC", font=("Segoe UI", 12, "bold")).pack(anchor="w")
        self.telemetry = ttk.Label(controls, font=("Consolas", 10), justify="left")
        self.telemetry.pack(anchor="w", pady=8)

        self.canvas = tk.Canvas(view, bg="#0b1120", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", lambda _e: self._draw())
        self.last_out = self.plant.outputs(self._inputs())

    def _inputs(self):
        return M3Inputs(self.command.get(), int(round(self.frequency.get()*100)), self.brake.get(), self.thermal.get(), self.device.get())

    def _toggle(self): self.running = not self.running
    def _single_step(self): self._advance(self.dt)

    def _reset(self):
        self.running=False; self.t=0.0; self.history.clear(); self.command.set(0); self.frequency.set(0); self.brake.set(False)
        self._refresh(self.plant.reset(self.cfg.x_p1_m))

    def _tick(self):
        if self.running: self._advance(self.dt * self.speed.get())
        self.freq_label.configure(text=f"{self.frequency.get():.2f} Hz  →  {int(self.frequency.get()*100)} (x100)")
        self.after(50, self._tick)

    def _advance(self, dt):
        self.t += dt
        out = self.plant.step(dt, self._inputs())
        self.history.append({"time_s":self.t,"position_m":out.position_m,"velocity_m_s":out.velocity_m_s,"actual_frequency_x100":out.actual_frequency_x100,"status_word":out.status_word,"sensors_word":out.sensors_word,"brake_open":int(out.brake_is_open)})
        self._refresh(out)

    def _refresh(self, out):
        self.last_out=out
        self.telemetry.configure(text=(f"t                 {self.t:8.2f} s\nStatusWord        16#{out.status_word:04X}\nActualFrequency   {out.actual_frequency_x100:5d}  ({out.actual_frequency_x100/100:5.2f} Hz)\nBrakeIsOpen       {int(out.brake_is_open)}\nSensorsWord       {out.sensors_word:05b}\nIncoherent        {int(out.sensor_incoherent)}\nPosition physique {out.position_m:8.3f} m\nVitesse physique  {out.velocity_m_s:8.3f} m/s"))
        self.status.set("FAULT équipement" if out.status_word & self.plant.ST_FAULT else "Simulation autonome — CODE/ boundary")
        self._draw()

    def _draw(self):
        c=self.canvas; c.delete("all"); w=max(c.winfo_width(),700); h=max(c.winfo_height(),450)
        y=h*0.52; x0=70; x1=w-70
        c.create_text(30,28,anchor="w",text="M3 — chaîne physique et capteurs TOR cumulés",fill="white",font=("Segoe UI",16,"bold"))
        c.create_line(x0,y,x1,y,fill="#64748b",width=6)
        positions=[("Trémie",self.cfg.x_tremie_m,self.last_out.pos_tremie),("PV",self.cfg.x_pv_m,self.last_out.pos_pv),("P2",self.cfg.x_p2_m,self.last_out.pos_p2),("P1",self.cfg.x_p1_m,self.last_out.pos_p1),("Maint",self.cfg.x_maintenance_m,self.last_out.pos_maintenance)]
        span=max(self.cfg.x_maintenance_m-self.cfg.x_tremie_m,1e-6)
        for name,pos,on in positions:
            x=x0+(pos-self.cfg.x_tremie_m)/span*(x1-x0)
            c.create_line(x,y-35,x,y+35,fill="#38bdf8" if on else "#334155",width=3)
            c.create_text(x,y+55,text=f"{name}\n{pos:g} m",fill="#7dd3fc" if on else "#94a3b8",justify="center")
        x=x0+(self.last_out.position_m-self.cfg.x_tremie_m)/span*(x1-x0)
        c.create_rectangle(x-24,y-26,x+24,y+26,fill="#22c55e" if self.last_out.brake_is_open else "#f59e0b",outline="white",width=2)
        c.create_text(x,y,text="M3",fill="white",font=("Segoe UI",11,"bold"))
        c.create_text(x0,100,anchor="w",text=f"PLC → CmdWord={self.command.get()} | Set={self.frequency.get():.2f} Hz | BrakeRQ={int(self.brake.get())}",fill="#f8fafc",font=("Consolas",11))
        c.create_text(x0,130,anchor="w",text=f"AC600 → Status=16#{self.last_out.status_word:04X} | Actual={self.last_out.actual_frequency_x100/100:.2f} Hz | BrakeDI={int(self.last_out.brake_is_open)}",fill="#a7f3d0",font=("Consolas",11))

    def _export(self):
        if not self.history: return
        path=filedialog.asksaveasfilename(defaultextension=".csv",filetypes=[("CSV","*.csv")])
        if not path: return
        with Path(path).open("w",newline="",encoding="utf-8") as f:
            wr=csv.DictWriter(f,fieldnames=self.history[0].keys()); wr.writeheader(); wr.writerows(self.history)


if __name__ == "__main__":
    M3NativeViewer().mainloop()
