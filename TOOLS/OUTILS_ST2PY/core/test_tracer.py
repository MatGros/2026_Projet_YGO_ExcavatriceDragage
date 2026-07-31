#!/usr/bin/env python3
"""
Test Execution Tracer & Chronicle Report Generator.
Logs step-by-step state transitions during test execution and generates
both CSV logs and a human-readable HTML timeline report.
"""

import json
from pathlib import Path
from typing import Any, Dict, List


class ExecutionTracer:
    def __init__(self, test_name: str) -> None:
        self.test_name = test_name
        self.chronicle: List[Dict[str, Any]] = []
        self.current_t_ms: float = 0.0

    def log_step(self, fb: Any, dt_ms: float, event: str = "") -> None:
        """Log a snapshot of FB inputs, outputs, and internal state after step(dt_ms)."""
        self.current_t_ms += dt_ms
        snapshot = {
            "t_ms": round(self.current_t_ms, 1),
            "dt_ms": dt_ms,
            "event": event,
            "inputs": {
                "Enable": getattr(fb, "Enable", False),
                "Reset": getattr(fb, "Reset", False),
                "ArmRequest": getattr(fb, "ArmRequest", False),
                "EmergencyChainClosed": getattr(fb, "EmergencyChainClosed", False),
                "PowerContactorEngaged": getattr(fb, "PowerContactorEngaged", False),
                "PowerCutOffRequest": getattr(fb, "PowerCutOffRequest", False),
                "BtnEmergencyCutOff": getattr(fb, "BtnEmergencyCutOff", False),
            },
            "outputs": {
                "Ready": getattr(fb, "Ready", False),
                "Busy": getattr(fb, "Busy", False),
                "Done": getattr(fb, "Done", False),
                "Error": getattr(fb, "Error", False),
                "ErrorId": getattr(fb, "ErrorId", 0),
                "MaintainA_RQ": getattr(fb, "MaintainA_RQ", False),
                "MaintainB_RQ": getattr(fb, "MaintainB_RQ", False),
                "ArmPulse_RQ": getattr(fb, "ArmPulse_RQ", False),
                "ArmingSeqStep": getattr(fb, "ArmingSeqStep", 0),
                "RedundancyTestFailed": getattr(fb, "RedundancyTestFailed", False),
                "EmergencyArmingFailed": getattr(fb, "EmergencyArmingFailed", False),
                "EmergencyArmingLockoutActive": getattr(fb, "EmergencyArmingLockoutActive", False),
            },
        }
        self.chronicle.append(snapshot)

    def export_html_report(self, out_path: Path) -> Path:
        """Generate a clean HTML timeline report of the test execution."""
        rows_html = []
        step_labels = {
            0: "IDLE (attente armement)",
            1: "TestA (coupe canal A)",
            2: "RestoreA (rétablit A)",
            3: "TestB (coupe canal B)",
            4: "RestoreB (rétablit B)",
            5: "Pulse (armement 1s)",
            6: "Confirm (attente contacteur)",
        }

        for row in self.chronicle:
            t = row["t_ms"]
            ev = row["event"]
            inp = row["inputs"]
            out = row["outputs"]
            step = out["ArmingSeqStep"]
            step_lbl = step_labels.get(step, f"Step {step}")

            bg_class = "normal"
            if out["Error"]:
                bg_class = "error"
            elif step == 5:
                bg_class = "pulse"
            elif step > 0:
                bg_class = "active"

            rows_html.append(f"""
            <tr class="{bg_class}">
                <td><b>{t} ms</b></td>
                <td><span class="badge">{step_lbl}</span></td>
                <td>{ev}</td>
                <td>ArmReq={inp['ArmRequest']}, Chain={inp['EmergencyChainClosed']}, Contactor={inp['PowerContactorEngaged']}, CutOff={inp['PowerCutOffRequest']}</td>
                <td>MaintainA={out['MaintainA_RQ']}, MaintainB={out['MaintainB_RQ']}, ArmPulse={out['ArmPulse_RQ']}</td>
                <td>ErrorId=0x{out['ErrorId']:04X}, RedundancyFail={out['RedundancyTestFailed']}, Lockout={out['EmergencyArmingLockoutActive']}</td>
            </tr>
            """)

        html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Chronique d'Exécution — {self.test_name}</title>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #F5F7FA; color: #263238; }}
        h1 {{ color: #1565C0; margin-bottom: 5px; }}
        .subtitle {{ color: #546E7A; margin-bottom: 20px; }}
        table {{ border-collapse: collapse; width: 100%; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }}
        th, td {{ padding: 10px 14px; text-align: left; border-bottom: 1px solid #ECEFF1; font-size: 13px; }}
        th {{ background: #263238; color: white; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }}
        tr.normal {{ background: #FFFFFF; }}
        tr.active {{ background: #E3F2FD; }}
        tr.pulse {{ background: #FFF3E0; font-weight: bold; }}
        tr.error {{ background: #FFEBEE; color: #C62828; }}
        .badge {{ background: #1976D2; color: white; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px; }}
    </style>
</head>
<body>
    <h1>📊 Journal d'Exécution & Chronogramme de Test</h1>
    <div class="subtitle">Test : <b>{self.test_name}</b> | Nombre de scans : {len(self.chronicle)}</div>
    <table>
        <thead>
            <tr>
                <th>Temps (t)</th>
                <th>Étape FSM (Step)</th>
                <th>Événement / Stimulus</th>
                <th>Entrées (DI / Cmd)</th>
                <th>Sorties Physiques (Q)</th>
                <th>Diagnostics & Erreurs</th>
            </tr>
        </thead>
        <tbody>
            {"".join(rows_html)}
        </tbody>
    </table>
</body>
</html>
"""
        out_path.write_text(html_content, encoding="utf-8")
        return out_path
