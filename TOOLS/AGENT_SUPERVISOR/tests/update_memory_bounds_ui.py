"""R29 (exploitant 2026-11-23) : IHM — plafond memoire longue 20/500 -> 100..5000, defaut 1000."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
path = ROOT / 'TOOLS/AGENT_SUPERVISOR/ui/index.html'
text = path.read_text(encoding='utf-8')
old_input = ('<label>Mémoire longue · éléments<input type="number" id="memory-max-items" '
             'min="20" max="500" step="1" value="20" required></label>')
new_input = ('<label>Mémoire longue · résumés gardés<input type="number" id="memory-max-items" '
             'min="100" max="5000" step="1" value="1000" required></label>')
changed = old_input in text
text = text.replace(old_input, new_input)
text = text.replace('memory_max_items:20', 'memory_max_items:1000')
path.write_text(text, encoding='utf-8')
print('IHM mise a jour :', changed)
