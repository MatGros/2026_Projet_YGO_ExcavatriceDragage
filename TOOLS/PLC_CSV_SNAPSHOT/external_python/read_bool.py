"""POC — lit une variable BOOL en live sur un serveur OPC UA CODESYS (sim ou automate reel).

Prerequis cote CODESYS IDE (manuel, voir README.md) : OPC UA Server active + variable
cochee dans Symbol Configuration. Utiliser list_nodes.py pour trouver le NodeId exact.
"""
import argparse
import asyncio
import time

from asyncua import Client


async def read_once(client: Client, node_id: str):
    node = client.get_node(node_id)
    data_value = await node.read_data_value()
    return data_value.Value.Value, data_value.SourceTimestamp


async def main(endpoint: str, node_id: str, watch: bool, interval: float):
    async with Client(url=endpoint) as client:
        print(f"Connecte a {endpoint}")
        if not watch:
            value, ts = await read_once(client, node_id)
            print(f"{node_id} = {value}  (SourceTimestamp={ts})")
            return

        try:
            while True:
                value, ts = await read_once(client, node_id)
                print(f"{time.strftime('%H:%M:%S')}  {node_id} = {value}  (SourceTimestamp={ts})")
                await asyncio.sleep(interval)
        except KeyboardInterrupt:
            print("Arret demande (Ctrl+C).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint", help="ex: opc.tcp://localhost:4840")
    parser.add_argument("node_id", help='ex: "ns=4;s=|var|Application.GVL_Test.MaVariable"')
    parser.add_argument("--watch", action="store_true", help="relit en boucle au lieu d'une seule fois")
    parser.add_argument("--interval", type=float, default=1.0, help="periode de relecture en s (defaut 1.0)")
    args = parser.parse_args()

    asyncio.run(main(args.endpoint, args.node_id, args.watch, args.interval))
