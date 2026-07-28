import xml.etree.ElementTree as ET

NS = {'pc': 'http://www.plcopen.org/xml/tc6_0200'}

def canonicalize_pou_bytes(bundle_path: str, pou_name: str) -> bytes:
    """Retourne la représentation canonique (bytes) d'un élément <pou name=...> dans le bundle.
    Normalise les espaces pour obtenir un canonique stable utilisable pour le hashing.
    """
    tree = ET.parse(bundle_path)
    root = tree.getroot()
    pou_elem = None
    for pou in root.findall('.//pc:pou', NS):
        if pou.get('name') == pou_name:
            pou_elem = pou
            break
    if pou_elem is None:
        raise FileNotFoundError(f"POU {pou_name} not found in bundle")
    canonical_bytes = ET.tostring(pou_elem, encoding='utf-8', method='xml')
    canonical = b" ".join(canonical_bytes.split())
    return canonical
