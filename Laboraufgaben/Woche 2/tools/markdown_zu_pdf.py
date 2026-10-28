"""Eine Markdown-Datei mit Tabellen als A4-PDF ausgeben.

Aufruf aus Woche 2 (setzt mistune und einen lokalen Chromium-Browser voraus):
    py tools/markdown_zu_pdf.py ../Programmuebersicht.md

Die Markdown-Datei ist die einzige Inhaltsquelle. Der Browser öffnet nur
lokales HTML; Tabellen, Quellcode und relative Dateilinks bleiben erhalten.
"""
from __future__ import annotations

import argparse
import html
from pathlib import Path
import re
import subprocess
import tempfile
import unicodedata

import mistune


class Renderer(mistune.HTMLRenderer):
    def heading(self, text: str, level: int, **attrs) -> str:
        plain = re.sub(r"<[^>]*>", "", html.unescape(text))
        slug = unicodedata.normalize("NFKD", plain).encode("ascii", "ignore").decode().lower()
        slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")
        return f'<h{level} id="{slug}">{text}</h{level}>\n'


CSS = """
@page {
  size: A4; margin: 17mm 17mm 17mm;
  @bottom-left { content: 'Programmübersicht · Laboraufgaben'; font: 8pt 'Segoe UI', Arial, sans-serif; color: #617480; }
  @bottom-right { content: counter(page) ' / ' counter(pages); font: 8pt 'Segoe UI', Arial, sans-serif; color: #617480; }
}
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font: 9.7pt/1.36 'Segoe UI', Arial, sans-serif; color: #243542; margin: 0; }
h1,h2,h3 { color: #123d58; font-weight: 650; line-height: 1.20; }
h1 { font-size: 24pt; margin: 0 0 6mm; letter-spacing: -.4pt; }
h2 { font-size: 16pt; margin: 0 0 5mm; padding-bottom: 2.5mm; border-bottom: 1px solid #b8cedd;
     break-before: page; break-after: avoid; }
h2:first-of-type { break-before: auto; margin-top: 7mm; }
h3 { font-size: 11.5pt; margin: 4mm 0 2mm; break-after: avoid; }
p { margin: 0 0 2.8mm; orphans: 3; widows: 3; }
a { color: #12658e; text-decoration: none; }
strong { color: #19394e; }
ul,ol { padding-left: 5.5mm; margin: 1.5mm 0 3.2mm; }
li { margin: 0 0 2.0mm; orphans: 2; widows: 2; }
li p { margin-bottom: 1mm; }
pre { background: #eff4f8; border-left: 3px solid #4083ac; padding: 3mm;
      white-space: pre-wrap; overflow-wrap: anywhere; break-inside: avoid;
      font: 8.0pt/1.42 Consolas, 'Courier New', monospace; margin: 2.5mm 0 4mm; }
code { font: .92em Consolas, 'Courier New', monospace; overflow-wrap: anywhere; }
p code,li code,td code { background: #eff4f8; border-radius: 2px; padding: 0 1px; }
table { border-collapse: collapse; width: 100%; margin: 2.5mm 0 4mm;
        font-size: 8.3pt; line-height: 1.28; }
thead { display: table-header-group; }
tr { break-inside: avoid; }
th,td { text-align: left; vertical-align: top; border: 1px solid #cedbe4;
        padding: 1.7mm 2.4mm; overflow-wrap: anywhere; }
th { background: #dfebf3; color: #153e5a; font-weight: 650; }
tbody tr:nth-child(even) { background: #f4f7f9; }
blockquote { margin: 3mm 0; border-left: 3px solid #73a4bf; padding-left: 4mm; }
"""


def browser_path() -> Path:
    for path in (
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ):
        if Path(path).is_file():
            return Path(path)
    raise RuntimeError("Kein lokaler Chrome-/Edge-Browser gefunden.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("markdown", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--base-dir", type=Path, help="Bezugsordner relativer Dateilinks")
    parser.add_argument("--keep-html", type=Path)
    args = parser.parse_args()
    source = args.markdown.resolve()
    target = (args.output or source.with_suffix(".pdf")).resolve()
    base = (args.base_dir or source.parent).resolve()
    converter = mistune.create_markdown(renderer=Renderer(escape=True), plugins=["table"])
    body = converter(source.read_text(encoding="utf-8-sig"))
    content = ('<!doctype html><html lang="de"><head><meta charset="utf-8">'
               f'<base href="{html.escape(base.as_uri())}/">'
               '<title>Programmübersicht · Modellbildung und Simulation</title>'
               f'<style>{CSS}</style></head><body>{body}</body></html>')
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".sbahn-dokumentation-", dir=target.parent) as temp:
        temp_dir = Path(temp)
        # Die automatische rekursive Bereinigung bleibt im Ausgabeordner.
        assert temp_dir.resolve().parent == target.parent
        html_file = temp_dir / "Programmuebersicht.html"
        html_file.write_text(content, encoding="utf-8")
        if args.keep_html:
            args.keep_html.write_text(content, encoding="utf-8")
        command = [str(browser_path()), "--headless=new", "--disable-gpu",
                   "--no-first-run", "--no-default-browser-check", "--disable-extensions",
                   "--disable-background-networking", "--disable-sync",
                   f"--user-data-dir={temp_dir / 'browser-profile'}", "--no-pdf-header-footer",
                   f"--print-to-pdf={target}", html_file.as_uri()]
        completed = subprocess.run(command, capture_output=True, timeout=60,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if completed.returncode or not target.is_file():
            raise RuntimeError(completed.stderr.decode("utf-8", errors="replace")[-3500:])
    print(f"PDF erstellt: {target}")


if __name__ == "__main__":
    main()
