"""POC — parcourt l'espace d'adressage OPC UA d'un serveur CODESYS et affiche les nodes
dont le BrowseName correspond a un filtre, pour trouver le NodeId exact d'une variable
sans deviner le format d'adressage CODESYS (ns=<N>;s=|var|<App>.<Chemin>).

Prerequis cote CODESYS IDE (manuel, voir README.md) : OPC UA Server active + variable
cochee dans Symbol Configuration.
"""
import argparse
import asyncio

from asyncua import Client
from asyncua.ua import NodeClass


async def walk(node, filter_text, max_depth, depth=0, path=""):
    try:
        name = (await node.read_browse_name()).Name
    except Exception:
        return
    current_path = f"{path}/{name}" if path else name

    try:
        node_class = await node.read_node_class()
    except Exception:
        node_class = None

    if filter_text.lower() in name.lower() and node_class == NodeClass.Variable:
        print(f"{current_path}  ->  {node.nodeid.to_string()}")

    if depth >= max_depth:
        return
    try:
        children = await node.get_children()
    except Exception:
        return
    for child in children:
        await walk(child, filter_text, max_depth, depth + 1, current_path)


async def main(endpoint: str, filter_text: str, max_depth: int):
    async with Client(url=endpoint) as client:
        objects = client.nodes.objects
        print(f"Connecte a {endpoint} — recherche '{filter_text}' (profondeur max {max_depth})")
        await walk(objects, filter_text, max_depth)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint", help="ex: opc.tcp://localhost:4840")
    parser.add_argument("--filter", default="", help="sous-chaine a chercher dans le nom (defaut: tout afficher)")
    parser.add_argument("--max-depth", type=int, default=15, help="profondeur max de parcours (defaut 15)")
    args = parser.parse_args()

    asyncio.run(main(args.endpoint, args.filter, args.max_depth))
