#!/usr/bin/env python3
"""Test OpenIconic img tag in PlantUML."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML_TEST = r"""@startuml Icon_Test
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #37474F

title Test des Icônes Nativement Intégrées (OpenIconic img)

package "OpenIconic via Balise Image (<img:open-iconic/...>)" #FFF3E0 {
  rectangle "<img:open-iconic/cog>\n---\nEngrenage Moteur" as OP1 #FFE0B2
  rectangle "<img:open-iconic/shield>\n---\nBouclier Sécurité" as OP2 #FFE0B2
  rectangle "<img:open-iconic/warning>\n---\nAttention Alarme" as OP3 #FFE0B2
  rectangle "<img:open-iconic/wrench>\n---\nMaintenance N1/N2" as OP4 #FFE0B2
  rectangle "<img:open-iconic/bolt>\n---\nPuissance & AU" as OP5 #FFE0B2
  rectangle "<img:open-iconic/graph>\n---\nVitesse & Codeur" as OP6 #FFE0B2
}

OP1 -right-> OP2
OP2 -right-> OP3
OP3 -right-> OP4
OP4 -right-> OP5
OP5 -right-> OP6

@enduml
"""

if __name__ == "__main__":
    out_file = Path("C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/DIAGRAMS/TOOLS/TEST_ICONS.png")
    print("Test de rendu des icônes OpenIconic img...")
    ok = render_puml(PUML_TEST, out_file)
    print("Succès !" if ok else "Échec")
