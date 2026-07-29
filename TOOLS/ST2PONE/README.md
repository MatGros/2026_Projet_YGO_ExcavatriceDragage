# ST2Pone

ST2Pone is a thin, review-friendly entrypoint that preserves the existing ST2PY workflow while exposing it under a dedicated tool name.

## Usage

```bash
python TOOLS/ST2PONE/st2pone.py --bundle CODE/CODE_Bundle.xml --pou FB_Translation --out TOOLS/OUTILS_ST2PY/out --force --allow-safety
```

It reuses the existing generator in [TOOLS/OUTILS_ST2PY/fb_gen.py](../OUTILS_ST2PY/fb_gen.py) so the original XML bundle pipeline and the new entrypoint remain compatible.
