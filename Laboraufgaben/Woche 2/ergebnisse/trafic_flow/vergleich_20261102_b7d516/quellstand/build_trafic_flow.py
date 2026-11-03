"""Add native Live Editor controls and a parameter table to the MATLAB-created MLX.

First: matlab -batch "matlab.internal.liveeditor.openAndSave(...source.m,...mlx)"
Then:  py tools/build_trafic_flow.py
The container and document schema come from the locally installed MATLAB.
"""
from pathlib import Path
import json
import re
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MLX = ROOT / "trafic_flow.mlx"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
MC = "http://schemas.openxmlformats.org/markup-compatibility/2006"
ET.register_namespace("w", W)
ET.register_namespace("mc", MC)

CONTROLS = {
    "verkehrsstromuntersuchung": ("Verkehrsstromuntersuchung", None),
    "untersuchungsachse": ("X-Achse der Untersuchung", ["Maximalgeschwindigkeit", "Störungswahrscheinlichkeit p", "Antizipationsfaktor beta", "Haltezeitzuschlag"]),
    "anzahlZuege": ("Anzahl der Züge (Einzellauf)", (1, 200, 1)),
    "einschwingzeitMinuten": ("Einschwingzeit [min]", (0, 1440, 1)),
    "messdauerMinuten": ("Messdauer [min]", (1, 1440, 1)),
    "wahrscheinlichkeitP": ("Wahrscheinlichkeit p", (0, 1, 0.01)),
    "zeitspanneSekunden": ("Zeitspanne Stationszusatzhalt [s]", (0, 3600, 1)),
    "langsamesAbbremsen": ("Langsames Abbremsen", None),
    "beta": ("Antizipationsfaktor beta [1/s]", (0.001, 10, 0.05)),
    "zusaetzlicheWartezeit": ("Zusätzliche Wartezeit", None),
    "wartezeitzuschlagSekunden": ("Fester GTFS-Zuschlag [s]", (0, 3600, 1)),
    "geschwindigkeitMinimumKmh": ("Geschwindigkeit Minimum [km/h]", (3.6, 80, 3.6)),
    "geschwindigkeitMaximumKmh": ("Geschwindigkeit Maximum [km/h]", (3.6, 80, 3.6)),
    "geschwindigkeitSchrittKmh": ("Geschwindigkeit Schritt [km/h]", (0.1, 80, 3.6)),
    "zugzahlMinimum": ("Zugzahl Minimum", (1, 200, 1)),
    "zugzahlMaximum": ("Zugzahl Maximum", (1, 200, 1)),
    "zugzahlSchritt": ("Zugzahl Schritt", (1, 200, 1)),
    "pMinimum": ("p Minimum", (0, 1, 0.01)),
    "pMaximum": ("p Maximum", (0, 1, 0.01)),
    "pSchritt": ("p Schritt", (0.001, 1, 0.01)),
    "betaMinimum": ("beta Minimum [1/s]", (0.001, 10, 0.05)),
    "betaMaximum": ("beta Maximum [1/s]", (0.001, 10, 0.05)),
    "betaSchritt": ("beta Schritt [1/s]", (0.001, 10, 0.05)),
    "haltezuschlagMinimumSekunden": ("Haltezuschlag Minimum [s]", (0, 3600, 1)),
    "haltezuschlagMaximumSekunden": ("Haltezuschlag Maximum [s]", (0, 3600, 1)),
    "haltezuschlagSchrittSekunden": ("Haltezuschlag Schritt [s]", (1, 3600, 1)),
}
ROWS = [
    ("Parameter", "Fest / variabel", "Bedeutung / Wert"),
    ("Strecke / Darstellung", "fest", "Reale Ringbahn S41 / geografischer Verlauf"),
    ("Fahrmodell / Raster", "fest", "Beschleunigen und Bremsen; ±1 m/s²; 1 m / 1 s"),
    ("Blocksteuerung / Zielabstand", "fest", "OSM-Signalabschnitte; 500 m ohne Wirkung bei OSM"),
    ("Haltezeitmodell", "fest", "GTFS-Stationshalte, stationsabhängig"),
    ("Bildpause / Bildabstand", "fest", "0,05 s / 10 Simulationsschritte; nur Wiedergabe"),
    ("Maximalgeschwindigkeit", "fest außer Geschwindigkeitsstudie", "80 km/h eingegeben → 79,2 km/h effektiv"),
    ("Betriebsart / Zugzahl", "variabel", "Checkbox Untersuchung; Zugzahl im Einzellauf"),
    ("Einschwingzeit / Messdauer", "variabel", "Minuten; Durchsatz nur nach Einschwingen"),
    ("p / Zeitspanne", "variabel", "p ∈ [0,1] für beide Störungen; Zufallszusatz 0…Zeitspanne s"),
    ("Langsames Abbremsen / beta", "variabel", "Checkbox; beta [1/s] für Anpassung an langsameren Vorgänger"),
    ("Zusätzliche Wartezeit", "variabel", "Checkbox + fester Zuschlag [s] auf jeden GTFS-Halt"),
    ("Untersuchungsachse", "variabel", "Geschwindigkeit, Störungswahrscheinlichkeit p, beta oder Haltezeitzuschlag"),
    ("Haltezuschlag-Untersuchung", "variabel", "Fester Zuschlag auf jeden GTFS-Halt; p und beta bleiben konstant"),
    ("Untersuchungsbereiche", "variabel", "Je Achse und Zugzahl: Minimum / Maximum / Schritt"),
    ("beta-Untersuchung", "automatisch", "Langsames Abbremsen aktiv; p bleibt konstant"),
    ("Zufallsstartwert", "fest", "42; reproduzierbare Läufe"),
]


def sub(parent, tag, **attrs):
    return ET.SubElement(parent, f"{{{W}}}{tag}", {f"{{{W}}}{k}": str(v) for k, v in attrs.items()})


def table():
    element = ET.Element(f"{{{W}}}tbl")
    props = sub(element, "tblPr")
    sub(props, "tblW", w=9600, type="dxa")
    borders = sub(props, "tblBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        sub(borders, side, val="single", sz=4, color="B0B0B0")
    grid = sub(element, "tblGrid")
    for width in (2500, 1600, 5500):
        sub(grid, "gridCol", w=width)
    for index, row in enumerate(ROWS):
        tr = sub(element, "tr")
        for value in row:
            cell = sub(tr, "tc")
            p = sub(cell, "p")
            pr = sub(p, "pPr")
            sub(pr, "pStyle", val="text")
            run = sub(p, "r")
            if index == 0:
                sub(sub(run, "rPr"), "b")
            sub(run, "t").text = value
    return element


with zipfile.ZipFile(MLX) as archive:
    entries = {item.filename: (item, archive.read(item)) for item in archive.infolist()}
document = ET.fromstring(entries["matlab/document.xml"][1])
found = set()
for paragraph in list(document.iter(f"{{{W}}}p")):
    code = "".join(node.text or "" for node in paragraph.iter(f"{{{W}}}t"))
    style = paragraph.find(f"{{{W}}}pPr/{{{W}}}pStyle")
    if style is None or style.get(f"{{{W}}}val") != "code":
        continue
    for name, (label, limits) in CONTROLS.items():
        match = re.search(rf'(?m)^{name} = (?P<value>true|false|[0-9.]+|"[^"\n]*");', code)
        if not match:
            continue
        literal = match["value"]
        value = json.loads(literal)
        data = {"text": label, "value": value, "executionModel": "Nothing", "defaultValue": value}
        context = {"data": data}
        if isinstance(limits, list):
            context["type"] = "comboBox"
            data["value"] = literal
            data["defaultValue"] = literal
            data["items"] = [{"label": json.dumps(item, ensure_ascii=False),
                              "value": json.dumps(item, ensure_ascii=False)} for item in limits]
            data["itemLabels"] = limits
            data["linkedVariable"] = ""
        elif limits is None:
            context["type"] = "checkBox"
            data["defaultValueLinkedVariable"] = ""
        else:
            data.update(minimum=limits[0], maximum=limits[1], step=limits[2], executionOn="ValueChanged",
                        minLinkedVariable="", maxLinkedVariable="", stepLinkedVariable="",
                        defaultValueLinkedVariable="")
        alternate = ET.SubElement(paragraph, f"{{{MC}}}AlternateContent")
        release = "R2018a" if isinstance(limits, list) else "R2019a" if limits is None else "R2022b"
        choice = ET.SubElement(alternate, f"{{{MC}}}Choice", {"Requires": release})
        custom = sub(choice, "customXml", element="livecontrol")
        properties = sub(custom, "customXmlPr")
        line = code.count("\n", 0, match.start("value"))
        column = match.start("value") - (code.rfind("\n", 0, match.start("value")) + 1)
        attributes = {"context": json.dumps(context, ensure_ascii=False, separators=(",", ":")),
                      "text": literal, "startOffsetLine": line, "startColumn": column,
                      "endOffsetLine": line, "endColumn": column + len(literal)}
        if isinstance(limits, tuple):
            attributes["className"] = "SpinnerControlNode"
        for key, val in attributes.items():
            sub(properties, "attr", name=key, val=val)
        ET.SubElement(alternate, f"{{{MC}}}Fallback")
        found.add(name)
assert found == set(CONTROLS), set(CONTROLS) - found
replaced = False
for parent in document.iter():
    for index, child in enumerate(list(parent)):
        if child.tag == f"{{{W}}}p" and "".join(child.itertext()).strip() == "PARAMETERTABELLE":
            parent.remove(child)
            parent.insert(index, table())
            replaced = True
assert replaced, "Parameter table marker missing"
xml = ET.tostring(document, encoding="utf-8", xml_declaration=True)
with zipfile.ZipFile(MLX, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for name, (info, content) in entries.items():
        archive.writestr(info, xml if name == "matlab/document.xml" else content)
print(f"{MLX.name}: {len(found)} native controls, {len(ROWS)-1} parameter rows")
