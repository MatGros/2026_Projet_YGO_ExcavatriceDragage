"""
Gates L8-L12 pour G200_check_linkage.py

L8  : VAR_OUTPUT physique jamais assignée
L9  : VAR_OUTPUT absent du mapping I/O (io_mapping.yaml)
L10 : Variable assignée par 2+ sources (multiwriter)
L11 : Polarité (comment) manquante sur VAR_OUTPUT physique
L12 : Pulse sans timing ou timing trop court (<100ms)
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import re
import yaml


# ═══════════════════════════════════════════════════════════════════════════
# L8 — VAR_OUTPUT physique jamais assignée
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class L8Finding:
    level: str  # HIGH, MEDIUM, INFO, OK, IGNORE
    var_name: str
    var_type: str
    line: int
    message: str
    details: str = ""


class L8Checker:
    """Détecte VAR_OUTPUT physique jamais assignée."""
    
    PHYSICAL_OUTPUT_PATTERNS = [
        # Noms standards (nouvelles conventions)
        r"_RQ$", r"_DQ$", r"_Q$", r"_DO$",
        # Noms du code actuel (M1RelayFwd, M1BrakeCmd, etc.)
        r"^M[123]Relay", r"^M[123]SpeedContactor", r"^M[123]BrakeCmd",
        r"^TranslationBrakeCmd", r"^PowerKeepAlive", r"^EmergencyArming",
        r"^KoboldMeasureEnable"
    ]
    IGNORE_PATTERNS = [
        r"^Diag", r"_Txt$", r"_Count$", r"_Status", r"_Temp", r"_Feedback"
    ]
    
    def __init__(self, pou: "Pou"):
        self.pou = pou
    
    def is_physical_output(self, var_name: str) -> bool:
        if not any(re.search(p, var_name) for p in self.PHYSICAL_OUTPUT_PATTERNS):
            return False
        if any(re.search(p, var_name) for p in self.IGNORE_PATTERNS):
            return False
        return True
    
    def find_assignments(self, var_name: str) -> List[int]:
        """Retourne les lignes où var_name est assignée."""
        locations = []
        for match in re.finditer(rf"{re.escape(var_name)}\s*:=", self.pou.body):
            line = 1 + self.pou.body[:match.start()].count("\n")
            locations.append(line)
        return locations
    
    def check(self) -> List[L8Finding]:
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            if not self.is_physical_output(var_name):
                findings.append(L8Finding(
                    level="IGNORE", var_name=var_name, var_type=typ, line=line,
                    message="Not physical pattern"
                ))
                continue
            
            assignments = self.find_assignments(var_name)
            
            if not assignments:
                findings.append(L8Finding(
                    level="HIGH", var_name=var_name, var_type=typ, line=line,
                    message=f"Never assigned in {self.pou.name}",
                    details="Physical output declared but never implemented"
                ))
            elif len(assignments) > 1:
                findings.append(L8Finding(
                    level="MEDIUM", var_name=var_name, var_type=typ, line=line,
                    message=f"Multiple assignments ({len(assignments)} times)",
                    details=f"Lines {assignments} — verify no accidental override"
                ))
            else:
                findings.append(L8Finding(
                    level="OK", var_name=var_name, var_type=typ, line=line,
                    message="Assigned once", details=f"Line {assignments[0]}"
                ))
        
        return findings


# ═══════════════════════════════════════════════════════════════════════════
# L9 — VAR_OUTPUT mappé au matériel (io_mapping.yaml)
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class L9Finding:
    level: str  # HIGH, MEDIUM, OK, IGNORE
    var_name: str
    message: str
    address: str = ""
    details: str = ""


class L9Checker:
    """Vérifie mapping I/O physique."""
    
    def __init__(self, pou: "Pou", io_map: Dict[str, Dict]):
        self.pou = pou
        self.io_map = io_map
    
    def check(self) -> List[L9Finding]:
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            # Filtre : que les sorties physiques
            if not any(re.search(p, var_name) for p in L8Checker.PHYSICAL_OUTPUT_PATTERNS):
                findings.append(L9Finding(
                    level="IGNORE", var_name=var_name, message="Not physical output"
                ))
                continue
            
            full_name = f"{self.pou.name}.{var_name}"
            
            if full_name in self.io_map:
                mapping = self.io_map[full_name]
                addr = mapping.get("address", "?")
                findings.append(L9Finding(
                    level="OK", var_name=var_name, message="Mapped",
                    address=addr, details=f"Address: {addr}"
                ))
            else:
                findings.append(L9Finding(
                    level="HIGH", var_name=var_name,
                    message="Not found in I/O mapping", address="MISSING"
                ))
        
        return findings


# ═══════════════════════════════════════════════════════════════════════════
# L10 — Producteur unique (pas multiwriter)
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class L10Finding:
    level: str  # MEDIUM, OK
    var_name: str
    message: str
    sources: List[Tuple[str, int]] = None  # (POU, line)
    details: str = ""


class L10Checker:
    """Détecte variables assignées par 2+ sources."""
    
    def __init__(self, pous: Dict[str, "Pou"]):
        self.pous = pous
        self.assignments: Dict[str, List[Tuple[str, int]]] = {}
    
    def analyze_all(self):
        """Collecte toutes les assignations."""
        for pou in self.pous.values():
            for match in re.finditer(r"(\w+)\s*:=", pou.body):
                var_name = match.group(1)
                full_name = f"{pou.name}.{var_name}"
                line = 1 + pou.body[:match.start()].count("\n")
                
                if full_name not in self.assignments:
                    self.assignments[full_name] = []
                self.assignments[full_name].append((pou.name, line))
    
    def check(self) -> List[L10Finding]:
        self.analyze_all()
        findings = []
        
        for full_name, sources in self.assignments.items():
            if len(sources) > 1:
                # Multiple assignations trouvees
                unique_pous = len(set(s[0] for s in sources))
                findings.append(L10Finding(
                    level="MEDIUM", var_name=full_name,
                    message=f"Multiple assignments ({len(sources)} times)",
                    sources=sources,
                    details=f"From {unique_pous} POU(s): {set(s[0] for s in sources)}"
                ))
        
        return findings


# ═══════════════════════════════════════════════════════════════════════════
# L11 — Polarité documentée
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class L11Finding:
    level: str  # MEDIUM, OK
    var_name: str
    message: str
    keywords: List[str] = None
    details: str = ""


class L11Checker:
    """Vérifie documentation polarité."""
    
    POLARITY_KEYWORDS = [
        "TRUE", "FALSE", "avant", "arrière", "forward", "reverse",
        "relâche", "serre", "maintien", "coupure", "open", "close",
        "actif", "inactif", "enabled", "disabled", "engagé", "libre"
    ]
    
    def __init__(self, pou: "Pou", raw_text: str = ""):
        self.pou = pou
        self.raw_text = raw_text or pou.path.read_text(encoding="utf-8", errors="replace")
    
    def check(self) -> List[L11Finding]:
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        raw_text = self.raw_text
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            # Chercher la ligne de déclaration
            pattern = rf"{re.escape(var_name)}\s*:\s*{typ}\s*;?\s*(\(\*[^*]*\*\))?"
            match = re.search(pattern, raw_text)
            
            if not match:
                findings.append(L11Finding(
                    level="MEDIUM", var_name=var_name,
                    message="No comment (polarity undocumented)"
                ))
                continue
            
            comment_part = match.group(1) or ""
            comment_lower = comment_part.lower()
            
            found_keywords = [
                k for k in self.POLARITY_KEYWORDS if k.lower() in comment_lower
            ]
            
            if not found_keywords:
                findings.append(L11Finding(
                    level="MEDIUM", var_name=var_name,
                    message="Comment present but no polarity keywords"
                ))
            else:
                findings.append(L11Finding(
                    level="OK", var_name=var_name,
                    message="Polarity documented",
                    keywords=found_keywords
                ))
        
        return findings


# ═══════════════════════════════════════════════════════════════════════════
# L12 — Timing réaliste (pulse patterns)
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class L12Finding:
    level: str  # HIGH, MEDIUM, OK, IGNORE
    var_name: str
    message: str
    duration_ms: int = 0
    details: str = ""


class L12Checker:
    """Heuristique: détecte sorties pulse et vérifie timing."""
    
    PULSE_KEYWORDS = ["Pulse", "ARM", "arm", "Arming", "Reset", "Trigger"]
    MIN_PULSE_TIME = 100  # ms
    
    def __init__(self, pou: "Pou"):
        self.pou = pou
    
    def check(self) -> List[L12Finding]:
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        raw_text = self.pou.path.read_text(encoding="utf-8", errors="replace")
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            # Est-ce un pulse pattern?
            is_pulse = any(k.lower() in var_name.lower() for k in self.PULSE_KEYWORDS)
            
            if not is_pulse:
                findings.append(L12Finding(
                    level="IGNORE", var_name=var_name, message="Not a pulse pattern"
                ))
                continue
            
            # Chercher durée documentée
            pattern = rf"{re.escape(var_name)}\s*:\s*{typ}\s*;?\s*(\(\*[^*]*\*\))?"
            match = re.search(pattern, raw_text)
            
            comment = (match.group(1) or "").lower() if match else ""
            
            # Regex durée: T#200ms, 1s, etc.
            duration_pattern = r"([Dd]uration|time|delay).*?([Tt]#)?(\d+)(ms|s|min)"
            duration_match = re.search(duration_pattern, comment)
            
            if not duration_match:
                findings.append(L12Finding(
                    level="MEDIUM", var_name=var_name,
                    message="Pulse without documented duration",
                    details="Add comment like (* Duration: T#1s *)"
                ))
                continue
            
            # Parser durée
            duration_val = int(duration_match.group(3))
            duration_unit = duration_match.group(4)
            
            if duration_unit == "s":
                duration_ms = duration_val * 1000
            elif duration_unit == "min":
                duration_ms = duration_val * 60000
            else:
                duration_ms = duration_val
            
            if duration_ms < self.MIN_PULSE_TIME:
                findings.append(L12Finding(
                    level="HIGH", var_name=var_name,
                    message=f"Pulse too short: {duration_ms}ms (min: {self.MIN_PULSE_TIME}ms)",
                    duration_ms=duration_ms
                ))
            else:
                findings.append(L12Finding(
                    level="OK", var_name=var_name,
                    message=f"Valid pulse timing",
                    duration_ms=duration_ms, details=f"{duration_ms}ms"
                ))
        
        return findings


# ═══════════════════════════════════════════════════════════════════════════
# Utilitaires
# ═══════════════════════════════════════════════════════════════════════════

def load_io_mapping(root: Path) -> Dict[str, Dict]:
    """Charge Device_IO_*.csv (export CODESYS natif, source unique).
    
    Format CODESYS (semicolon-separated):
    Mapped variable;Parameter name;Unit;Description;IEC address;Device name
    Ex: M1RelayFwd;Bit0;;+1 Sens;%QX0.0;Local_Digital_IO
    """
    from glob import glob
    
    # Trouver Device_IO_*.csv le plus récent
    csv_pattern = root / "TOOLS/AGENT_WORKFLOW/config/Device_IO_*.csv"
    csv_files = sorted(glob(str(csv_pattern)))
    
    if not csv_files:
        return {}  # Aucun CSV
    
    csv_file = Path(csv_files[-1])  # Le plus récent
    
    try:
        mapping = {}
        with open(csv_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Parser format CODESYS (skip commentaires header)
        for line in lines:
            line = line.strip()
            if not line or line.startswith('//'):
                continue
            
            parts = line.split(';')
            if len(parts) < 5:
                continue
            
            var_name = parts[0].strip()
            iec_address = parts[4].strip()
            
            if var_name and iec_address and iec_address.startswith('%'):
                # Détecter INPUT vs OUTPUT via le prefixe %I vs %Q
                pou_name = "PRG_OUTPUTS_LD" if iec_address.startswith('%Q') else "PRG_01_Inputs_LD"
                full_name = f"{pou_name}.{var_name}"
                
                mapping[full_name] = {
                    "address": iec_address,
                    "type": "BOOL",
                    "domain": "",
                }
        
        return mapping
    
    except Exception as e:
        print(f"[WARNING] Cannot load Device_IO_*.csv: {e}")
        return {}
