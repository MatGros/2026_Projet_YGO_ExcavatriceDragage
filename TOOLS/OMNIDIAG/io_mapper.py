"""
===============================================================================
🖲️ OMNIDIAG — Parseur de Cartographie Matérielle E/S Automate (Device_IO)
===============================================================================
🎯 Rôle : Analyse automatiquement le fichier Device_IO_*.csv le plus récent
   et extrait la configuration physique des cartes du rack (adresses %IX/%QX,
   bits, variables, descriptions).
===============================================================================
"""

from pathlib import Path
from typing import Dict, Any, List, Optional
import re


def find_latest_device_io_csv(base_dir: Path) -> Optional[Path]:
    """Trouve le fichier Device_IO_*.csv le plus récent dans le projet."""
    config_dir = base_dir / "TOOLS" / "AGENT_WORKFLOW" / "config"
    if not config_dir.exists():
        return None
    
    candidates = list(config_dir.glob("Device_IO_*.csv"))
    if not candidates:
        candidate_std = config_dir / "Device_IO.csv"
        return candidate_std if candidate_std.exists() else None
    
    # Trier par nom de fichier (contient la date AAAAMMJJ)
    candidates.sort(key=lambda p: p.name, reverse=True)
    return candidates[0]


def parse_rack_io(base_dir: Path) -> Dict[str, Any]:
    """Extrait la structure du rack E/S automate depuis le dernier Device_IO."""
    csv_file = find_latest_device_io_csv(base_dir)
    if not csv_file or not csv_file.exists():
        return {"source_file": "Introuvable", "modules": []}

    # Modules cibles du rack physique dans l'ordre d'implantation de gauche à droite
    rack_order = [
        {"dev_id": "Local_Digital_IO", "slot": "Slot 1 (CPU)", "name": "Carte 1 : Local_Digital_IO", "desc": "Base CPU E/S Intégrées (%IX0 / %QX0)", "badge": "bg-cyan-500/10 text-cyan-400 border-cyan-500/20"},
        {"dev_id": "VH_0808ETP",       "slot": "Slot 2",       "name": "Carte 2 : VH_0808ETP",       "desc": "Transistors & Cames M3 (%IX224 / %QX26)", "badge": "bg-indigo-500/10 text-indigo-400 border-indigo-500/20"},
        {"dev_id": "VH_0800END",       "slot": "Slot 3",       "name": "Carte 3 : VH_0800END",       "desc": "Sécurité & Retours Freins (%IX225)",     "badge": "bg-purple-500/10 text-purple-400 border-purple-500/20"},
        {"dev_id": "VH_0008ER",        "slot": "Slot 4",       "name": "Carte 4 : VH_0008ER",        "desc": "Relais Bobines Freins (%QX27)",          "badge": "bg-rose-500/10 text-rose-400 border-rose-500/20"},
        {"dev_id": "VH_0008ER_1",      "slot": "Slot 5",       "name": "Carte 5 : VH_0008ER_1",      "desc": "Relais Sécurité & AU (%QX28)",           "badge": "bg-amber-500/10 text-amber-400 border-amber-500/20"},
    ]

    modules_dict = {m["dev_id"]: {**m, "inputs": [], "outputs": []} for m in rack_order}

    with open(csv_file, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) >= 6:
                var_name = parts[0]
                param = parts[1]
                desc = parts[3]
                addr = parts[4]
                dev = parts[5]

                if dev in modules_dict:
                    # Ignorer les lignes de headers d'octets comme %IB224 ou %QB26
                    if addr.startswith("%IB") or addr.startswith("%QB"):
                        continue

                    # Détermination IN vs OUT
                    is_in = addr.startswith("%IX")
                    is_out = addr.startswith("%QX")

                    # Extraction du numéro de bit
                    bit_match = re.search(r"Bit(\d+)", param)
                    bit_num = int(bit_match.group(1)) if bit_match else 0

                    channel_info = {
                        "bit": bit_num,
                        "param": param,
                        "var": var_name,
                        "desc": desc,
                        "addr": addr,
                        "type": "DI" if is_in else ("RQ" if "ER" in dev else "DQ"),
                        "active": False
                    }

                    if is_in:
                        modules_dict[dev]["inputs"].append(channel_info)
                    elif is_out:
                        modules_dict[dev]["outputs"].append(channel_info)

    channels_by_var = {}
    channels_by_addr = {}

    # Tri par bit et calcul du résumé de plage
    for dev_id, mod in modules_dict.items():
        mod["inputs"].sort(key=lambda c: c["bit"])
        mod["outputs"].sort(key=lambda c: c["bit"])
        
        in_addrs = [c["addr"] for c in mod["inputs"] if c["addr"]]
        out_addrs = [c["addr"] for c in mod["outputs"] if c["addr"]]
        
        summary_parts = []
        if in_addrs:
            summary_parts.append(f"{in_addrs[0]}-{in_addrs[-1]}" if len(in_addrs) > 1 else in_addrs[0])
        if out_addrs:
            summary_parts.append(f"{out_addrs[0]}-{out_addrs[-1]}" if len(out_addrs) > 1 else out_addrs[0])
        mod["range_summary"] = " / ".join(summary_parts) if summary_parts else "-"

        for ch in mod["inputs"] + mod["outputs"]:
            info = {
                "dev_id": dev_id,
                "slot": mod["slot"],
                "module_name": mod["name"],
                "bit": ch["bit"],
                "addr": ch["addr"],
                "var": ch["var"],
                "desc": ch["desc"],
                "type": ch["type"]
            }
            if ch["var"]:
                channels_by_var[ch["var"].lower()] = info
            if ch["addr"]:
                channels_by_addr[ch["addr"].lower()] = info

    return {
        "source_file": csv_file.name,
        "modules": list(modules_dict.values()),
        "by_var": channels_by_var,
        "by_addr": channels_by_addr
    }


if __name__ == "__main__":
    import json
    data = parse_rack_io(Path("."))
    print(f"Fichier analysé : {data['source_file']}")
    for m in data["modules"]:
        print(f"Module {m['slot']} - {m['dev_id']} : {len(m['inputs'])} IN, {len(m['outputs'])} OUT")
