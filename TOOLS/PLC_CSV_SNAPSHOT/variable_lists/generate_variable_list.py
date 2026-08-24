"""Genere la liste a plat des chemins de variables sous un noeud de la Symbol Configuration
(par defaut GVL_Troubleshooting), a partir d'un export Symbolconfiguration.xsd.

Script Python standard (pas IronPython) : a lancer hors CODESYS pour preparer la liste que
snapshot_troubleshooting.py utilisera ensuite dans la console de scripting CODESYS.

Regenerer cette liste si la structure de GVL_Troubleshooting change dans le projet
(nouveau champ ST_Chain*, nouvelle chaine de diagnostic, etc.) : reexporter la Symbol
Configuration depuis l'IDE et relancer ce script.
"""
import argparse
import xml.etree.ElementTree as ET

NS = "{http://www.3s-software.com/schemas/Symbolconfiguration.xsd}"


def parse_types(root):
    types = {}
    for node in root.find(f"{NS}TypeList"):
        name = node.get("name")
        if node.tag == f"{NS}TypeUserDef" and node.get("typeclass") == "Userdef":
            elements = [
                (el.get("iecname"), el.get("type"))
                for el in node.findall(f"{NS}UserDefElement")
            ]
            types[name] = elements
    return types


def walk(type_name, prefix, types, out):
    if type_name in types:
        for field_name, field_type in types[type_name]:
            walk(field_type, f"{prefix}.{field_name}", types, out)
    else:
        out.append(prefix)


def find_node(nodelist_root, path_parts):
    node = nodelist_root
    for part in path_parts:
        node = node.find(f"{NS}Node[@name='{part}']")
        if node is None:
            return None
    return node


def main(xml_path, root_node_path, output_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    types = parse_types(root)

    nodelist = root.find(f"{NS}NodeList")
    path_parts = root_node_path.split(".")
    target = find_node(nodelist, path_parts)
    if target is None:
        raise SystemExit(f"Noeud '{root_node_path}' introuvable dans {xml_path}")

    # read_value() est relatif a l'application (pas de prefixe "Application.", valide sur le POC) :
    # le chemin genere reprend donc le dernier segment du noeud racine (ex: "GVL_Troubleshooting"), pas le chemin complet.
    gvl_name = path_parts[-1]
    out = []
    for child in target.findall(f"{NS}Node"):
        walk(child.get("type"), f"{gvl_name}.{child.get('name')}", types, out)

    with open(output_path, "w", encoding="ascii") as f:
        for path in out:
            f.write(path + "\n")

    print(f"{len(out)} variables ecrites dans {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xml_path", help="export Symbol Configuration (ex: v0.6.04_CycleSemiAuto.Device.Application.xml)")
    parser.add_argument("--root", default="Application.GVL_Troubleshooting", help="noeud racine (defaut: Application.GVL_Troubleshooting)")
    parser.add_argument("--output", default="troubleshooting_variables.txt", help="fichier de sortie")
    args = parser.parse_args()

    main(args.xml_path, args.root, args.output)
