#!/usr/bin/env python3
"""
Test Execution Tracer & Chronicle Report Generator.
Logs step-by-step state transitions during test execution and generates
both CSV logs and a human-readable HTML timeline report with status (PASS/FAIL).
"""

import datetime as _dt
import json
from pathlib import Path
from typing import Any, Dict, List, Optional


def resolve_single_report_path(out_path: Path, passed: bool = True) -> Path:
    """Résout le chemin de sortie unique par cas de test, en remplaçant tout rapport antérieur.

    Exemple : `.../TC-P01-003_Chronicle_Report.html` ou `.../TC-P01-003`
              -> supprime tout `TC-P01-003_*.html` résiduel
              -> génère un fichier unique `TC-P01-003_PASS.html` (ou `_FAIL.html`)
    """
    parent = out_path.parent
    stem = out_path.stem.replace("_Chronicle_Report", "").split("_PASS")[0].split("_FAIL")[0]
    status_str = "PASS" if passed else "FAIL"

    # Nettoyage des anciens rapports pour ce même cas de test (évite l'accumulation)
    for old_file in parent.glob(f"{stem}_*.html"):
        try:
            old_file.unlink()
        except OSError:
            pass

    return parent / f"{stem}_{status_str}.html"


class ExecutionTracer:
    def __init__(self, test_name: str, auto_export_dir: Optional[Path] = None, base_filename: Optional[str] = None) -> None:
        self.test_name = test_name
        self.auto_export_dir = auto_export_dir
        self.base_filename = base_filename
        self.chronicle: List[Dict[str, Any]] = []
        self.current_t_ms: float = 0.0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        passed = (exc_type is None)
        if not passed and exc_val is not None:
            # Enregistrer l'échec d'assertion du test Python
            self.chronicle.append({
                "t_ms": round(self.current_t_ms, 1),
                "dt_ms": 0.0,
                "event": f"🛑 ÉCHEC ASSERTION TEST ({exc_type.__name__}): {exc_val}",
                "inputs": {
                    "Enable": False, "Reset": False, "ArmRequest": False,
                    "EmergencyChainClosed": False, "PowerContactorEngaged": False,
                    "PowerCutOffRequest": False, "BtnEmergencyCutOff": False,
                },
                "outputs": {
                    "Ready": False, "Busy": False, "Done": False, "Error": True,
                    "ErrorId": 0xFFFF, "MaintainA_RQ": False, "MaintainB_RQ": False,
                    "ArmPulse_RQ": False, "ArmingSeqStep": -1, "RedundancyTestFailed": True,
                    "EmergencyArmingFailed": False, "EmergencyArmingLockoutActive": False,
                },
                "is_test_failure": True,
            })
        if self.auto_export_dir:
            base_name = self.base_filename or self.test_name.split()[0]
            self.export_html_report(self.auto_export_dir / base_name, passed=passed)
        return False  # Ne masque pas l'exception pour que pytest comptabilise le FAIL

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
            "is_test_failure": False,
        }
        self.chronicle.append(snapshot)

    def export_html_report(self, out_path: Path, passed: bool = True) -> Path:
        """Génère le rapport HTML unique par cas de test (remplace l'ancien run)."""
        final_path = resolve_single_report_path(out_path, passed=passed)
        final_path.parent.mkdir(parents=True, exist_ok=True)

        exec_time_str = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        status_badge = (
            '<span class="status-pass">🟢 TEST SUCCÈS (PASS)</span>'
            if passed else
            '<span class="status-fail">🔴 TEST ÉCHEC (FAIL)</span>'
        )

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
            is_failure = row.get("is_test_failure", False)
            step = out.get("ArmingSeqStep", 0)
            step_lbl = step_labels.get(step, f"Step {step}")

            # Distinguer clairement : ÉCHEC DU TEST (rouge vif) vs DÉFAUT AUTOMATE (orange ambré)
            if is_failure or "ÉCHEC ASSERTION" in ev:
                bg_class = "test-failure"
            elif out.get("Error"):
                bg_class = "plc-fault"
            elif step == 5:
                bg_class = "pulse"
            elif step > 0:
                bg_class = "active"
            else:
                bg_class = "normal"

            arm_req = inp.get('ArmRequest', '-')
            chain_closed = inp.get('EmergencyChainClosed', '-')
            contactor = inp.get('PowerContactorEngaged', '-')
            cutoff = inp.get('PowerCutOffRequest', '-')
            maint_a = out.get('MaintainA_RQ', '-')
            maint_b = out.get('MaintainB_RQ', '-')
            arm_pulse = out.get('ArmPulse_RQ', '-')
            err_id = out.get('ErrorId', 0)
            redundancy_fail = out.get('RedundancyTestFailed', '-')
            lockout = out.get('EmergencyArmingLockoutActive', '-')

            rows_html.append(f"""
            <tr class="{bg_class}">
                <td><b>{t} ms</b></td>
                <td><span class="badge">{step_lbl}</span></td>
                <td>{ev}</td>
                <td>ArmReq={arm_req}, Chain={chain_closed}, Contactor={contactor}, CutOff={cutoff}</td>
                <td>MaintainA={maint_a}, MaintainB={maint_b}, ArmPulse={arm_pulse}</td>
                <td>ErrorId=0x{err_id:04X}, RedundancyFail={redundancy_fail}, Lockout={lockout}</td>
            </tr>
            """)

        html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Chronique d'Exécution — {self.test_name} [{ "PASS" if passed else "FAIL" }]</title>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #F5F7FA; color: #263238; }}
        .header-container {{ display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #CFD8DC; padding-bottom: 10px; margin-bottom: 15px; }}
        h1 {{ color: #1565C0; margin: 0; font-size: 22px; }}
        .status-pass {{ background: #E8F5E9; color: #2E7D32; border: 1px solid #A5D6A7; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 14px; }}
        .status-fail {{ background: #FFEBEE; color: #C62828; border: 1px solid #EF9A9A; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 14px; }}
        .subtitle {{ color: #546E7A; font-size: 13px; margin-bottom: 15px; }}
        .legend {{ display: flex; gap: 15px; font-size: 12px; margin-bottom: 15px; padding: 8px 12px; background: #ECEFF1; border-radius: 6px; }}
        .legend-item {{ display: flex; align-items: center; gap: 5px; }}
        .box-normal {{ width: 12px; height: 12px; background: #FFFFFF; border: 1px solid #CCC; }}
        .box-active {{ width: 12px; height: 12px; background: #E3F2FD; border: 1px solid #90CAF9; }}
        .box-pulse {{ width: 12px; height: 12px; background: #FFF3E0; border: 1px solid #FFB74D; }}
        .box-fault {{ width: 12px; height: 12px; background: #FFF8E1; border: 1px solid #FFE082; }}
        .box-failure {{ width: 12px; height: 12px; background: #FFEBEE; border: 1px solid #EF9A9A; }}
        table {{ border-collapse: collapse; width: 100%; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }}
        th, td {{ padding: 10px 14px; text-align: left; border-bottom: 1px solid #ECEFF1; font-size: 13px; }}
        th {{ background: #263238; color: white; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }}
        tr.normal {{ background: #FFFFFF; }}
        tr.active {{ background: #E3F2FD; }}
        tr.pulse {{ background: #FFF3E0; font-weight: bold; }}
        tr.plc-fault {{ background: #FFF8E1; color: #E65100; border-left: 4px solid #FF9800; }}
        tr.test-failure {{ background: #FFEBEE; color: #C62828; font-weight: bold; border-left: 4px solid #D32F2F; }}
        .badge {{ background: #1976D2; color: white; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px; }}
    </style>
</head>
<body>
    <div class="header-container">
        <h1>📊 Journal d'Exécution & Chronogramme de Test</h1>
        <div>{status_badge}</div>
    </div>
    <div class="subtitle">
        Test : <b>{self.test_name}</b> | Horodatage du run : <b>{exec_time_str}</b> | Scans : <b>{len(self.chronicle)}</b>
    </div>
    <div class="legend">
        <div class="legend-item"><div class="box-normal"></div> Scan Nominal</div>
        <div class="legend-item"><div class="box-active"></div> Séquence FSM en cours</div>
        <div class="legend-item"><div class="box-pulse"></div> Impulsion Réarmement</div>
        <div class="legend-item"><div class="box-fault"></div> ⚠️ Défaut Automate (attendu par le test)</div>
        <div class="legend-item"><div class="box-failure"></div> 🛑 Échec Assertion Test</div>
    </div>
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
        final_path.write_text(html_content, encoding="utf-8")
        return final_path
