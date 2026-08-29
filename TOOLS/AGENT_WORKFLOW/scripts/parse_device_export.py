#!/usr/bin/env python3
"""
Parse Device.export XML → table [VAR → ADDRESS, TYPE, MODULE]

CODESYS exports configuration en XML propriétaire. Ce parser extrait:
- Variable names (PRG_06_Outputs.M1_Fwd_RQ)
- Adresses I/O (%QX0.1, %QY1.2, etc.)
- Types (BOOL, INT, REAL)
- Modules

Sortie: dictionnaire {full_name: {address, type, module}}

Usage:
  from parse_device_export import parse_device_export
  io_map = parse_device_export("Device.export")
  # {'PRG_06_Outputs.M1_Fwd_RQ': {'address': '%QX0.1', 'type': 'BOOL', 'module': 'VH601'}}
"""

import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, Any, Optional, Tuple

class DeviceExportParser:
    """Parse CODESYS Device.export XML → I/O mapping table."""
    
    def __init__(self, export_path: Path):
        """
        Initialise le parser avec un fichier Device.export.
        
        Args:
            export_path: Chemin vers Device.export
        """
        self.path = Path(export_path)
        self.io_map: Dict[str, Dict[str, Any]] = {}
        self.raw_text: str = ""
    
    def parse(self) -> Dict[str, Dict[str, Any]]:
        """
        Parse le fichier et retourne la table I/O mappée.
        
        Returns:
            {
              "PRG_06_Outputs.M1_Fwd_RQ": {
                "address": "%QX0.1",
                "type": "BOOL",
                "module": "VH601-0808TP"
              },
              ...
            }
        """
        if not self.path.exists():
            print(f"[WARNING] Device.export not found: {self.path}")
            return {}
        
        try:
            self.raw_text = self.path.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            print(f"[ERROR] Cannot read Device.export: {e}")
            return {}
        
        # Stratégie: regex sur le texte brut (plus flexible que parsing XML strict)
        # Device.export est bien formé mais structure complexe, regex suffit
        
        self._extract_io_from_text()
        
        return self.io_map
    
    def _extract_io_from_text(self):
        """Extrait variables et adresses par regex."""
        
        # Pattern 1 : Identifier + Value (simple case)
        # <Single Name="Identifier" Type="string">M1_Fwd_RQ</Single>
        # <Single Name="Value" Type="string">%QX0.1</Single>
        
        pattern_simple = re.compile(
            r'<Single Name="Identifier"[^>]*>([^<]+)</Single>.*?'
            r'<Single Name="Value"[^>]*>([^<]+)</Single>',
            re.DOTALL
        )
        
        for match in pattern_simple.finditer(self.raw_text):
            identifier = match.group(1).strip().strip("'\"")
            value = match.group(2).strip().strip("'\"")
            
            # Filtre : juste les I/O intéressants (contien PRG_ et adresse %Q/%M)
            if "PRG_" in identifier and value.startswith("%"):
                # Extraire type si dispo (dans le contexte proche)
                var_type = self._extract_type_near(match.start())
                
                self.io_map[identifier] = {
                    "address": value,
                    "type": var_type or "UNKNOWN",
                    "module": self._infer_module(identifier)
                }
    
    def _extract_type_near(self, position: int) -> Optional[str]:
        """Extrait le type BOOL/INT/REAL près de la position."""
        
        # Chercher dans ±500 chars
        start = max(0, position - 500)
        end = min(len(self.raw_text), position + 500)
        context = self.raw_text[start:end].lower()
        
        type_pattern = r'<Single Name="Type"[^>]*>(BOOL|INT|REAL|DINT|WORD|DWORD|BYTE|LREAL)'
        match = re.search(type_pattern, context, re.IGNORECASE)
        
        if match:
            return match.group(1).upper()
        
        return None
    
    def _infer_module(self, var_name: str) -> str:
        """Détermine le module (VH601, EtherCAT, etc.) d'après le contexte."""
        
        # Heuristique simple : chercher dans le texte autour du PLC device name
        if "VH601" in self.raw_text:
            return "VH601-0808TP"
        if "EtherCAT" in self.raw_text:
            return "EtherCAT"
        if "CANopen" in self.raw_text:
            return "CANopen"
        
        return "Unknown"
    
    def pretty_print(self, limit: int = 20):
        """Affiche les I/O mappées de manière lisible."""
        print(f"\n{'Mapping I/O':=^60}")
        print(f"{'VAR':30} {'ADDRESS':12} {'TYPE':8}")
        print("=" * 60)
        
        for var_name in sorted(self.io_map.keys())[:limit]:
            info = self.io_map[var_name]
            addr = info.get("address", "?")
            typ = info.get("type", "?")
            print(f"{var_name:30} {addr:12} {typ:8}")
        
        if len(self.io_map) > limit:
            print(f"... et {len(self.io_map) - limit} autres")
        print("=" * 60)


def parse_device_export(export_path: Path) -> Dict[str, Dict[str, Any]]:
    """
    Fonction utilitaire : parse et retourne l'I/O map.
    
    Usage:
      io_map = parse_device_export("path/to/Device.export")
    """
    parser = DeviceExportParser(export_path)
    return parser.parse()


if __name__ == "__main__":
    # Test rapide
    export_path = Path(__file__).resolve().parents[3] / "PRJ_CODESYS/PROJ_Full_ImportExport/Device.export"
    
    if export_path.exists():
        parser = DeviceExportParser(export_path)
        io_map = parser.parse()
        parser.pretty_print(limit=20)
        print(f"\nTotal I/O trouvées: {len(io_map)}")
    else:
        print(f"[ERROR] Device.export not found at {export_path}")
