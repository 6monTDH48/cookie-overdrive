#!/usr/bin/env python3
"""Inline src/index.html + css + js into one self-contained dist/cookie-overdrive.html."""
import re, pathlib, sys

ROOT = pathlib.Path(__file__).parent
SRC = ROOT / "src"
OUT = ROOT / "dist" / "cookie-overdrive.html"

html = (SRC / "index.html").read_text(encoding="utf-8")

def inline_css(m):
    path = SRC / m.group(1)
    return "<style>\n" + path.read_text(encoding="utf-8") + "\n</style>"

def inline_js(m):
    path = SRC / m.group(1)
    if not path.exists():
        print(f"  ! missing {m.group(1)} (skipped)", file=sys.stderr)
        return f"<!-- missing {m.group(1)} -->"
    code = path.read_text(encoding="utf-8")
    if re.search(r"</script", code, re.I):
        code = re.sub(r"</(script)", r"<\\/\1", code, flags=re.I)
    return f"<script>\n/* ── {m.group(1)} ── */\n{code}\n</script>"

html = re.sub(r'^.*<!-- dev only[^>]*-->\n', '', html, flags=re.M)
html = re.sub(r'<link rel="stylesheet" href="(css/[^"]+)">', inline_css, html)
html = re.sub(r'<script src="(js/[^"]+)"></script>', inline_js, html)

OUT.parent.mkdir(exist_ok=True)
OUT.write_text(html, encoding="utf-8")
print(f"built {OUT.relative_to(ROOT)}  {len(html.encode('utf-8'))/1024:.0f} KB")
