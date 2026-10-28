"""Diagramme und dreiseitiger Bericht aus direkt exportierten MATLAB-Zahlen.

Aufruf: py tools/erstelle_bericht.py
Alle Kurvenkoordinaten und markierten Betriebspunkte stammen aus
ergebnisse/diagrammdaten.mat (run_sbahn2 -> results.plotData).
Python berechnet keine Simulationskennzahlen und wählt kein Optimum aus.
"""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.collections import LineCollection
import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ergebnisse"
FIG = OUT / "diagramme"
BLUE, ORANGE, GRAY, GREEN, PURPLE = "#146b9c", "#c57618", "#778b96", "#238054", "#7946a2"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9,
                     "axes.spines.top": False, "axes.grid": True,
                     "grid.alpha": .22, "pdf.fonttype": 42})


def rows(name):
    with (OUT / name).open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def vector(data, key):
    return np.atleast_1d(np.asarray(data[key], dtype=float)).ravel()


def fmt(value, digits=1):
    return f"{float(value):.{digits}f}".replace(".", ",")


def index(data, key):
    return int(data[key])-1  # MATLAB verwendet einsbasierte Indizes.


def parameter_plot(ax, data, label, role, qmax, waitmax):
    x = vector(data, "x")
    q = vector(data, "throughput")
    free = vector(data, "freeThroughput")
    wait = vector(data, "blockedSecondsPerTrainHour")
    line, = ax.plot(x, q, "o-", color=BLUE, lw=1.8, label="gemessener Durchsatz")
    reference, = ax.plot(x, free, "--", color=GRAY, lw=1.3, label="freier Referenzbetrieb")
    ax.set(xlabel=label, ylabel="Durchsatz [Züge/h]", ylim=(0, qmax), xlim=(x[0], x[-1]))
    ax.set_xticks(x)
    twin = ax.twinx()
    waiting, = twin.plot(x, wait, "s-", color=ORANGE, lw=1.5, ms=4, label="blockierter Stillstand")
    twin.set_ylabel("Stillstand [s/(Zug·h)]", color="#a7600e")
    twin.set_ylim(0, waitmax)
    twin.grid(False)
    base = index(data, "baseIndex")
    if role == "trains":
        ax.scatter(x[base], q[base], marker="*", s=125, c=GREEN, edgecolors="white",
                   zorder=5, clip_on=False, label=f"Ausgangsfall N={int(data['baseTrainCount'])}")
        ax.annotate(f"N={int(data['baseTrainCount'])}", (x[base], q[base]), xytext=(7, 7),
                    textcoords="offset points", fontsize=8, color=GREEN)
        common = index(data, "comparisonIndex")
        common_label = f"Vergleich: N={int(x[common])}"
    else:
        common = base
        common_label = "Vergleich: GTFS + 0 s"
    ax.scatter(x[common], q[common], marker="D", s=58, facecolors="none",
               edgecolors=PURPLE, lw=1.6, zorder=5, clip_on=False, label=common_label)
    twin.scatter(x[common], wait[common], marker="D", s=58, facecolors="none",
                 edgecolors=PURPLE, lw=1.6, zorder=5, clip_on=False)
    handles, labels = ax.get_legend_handles_labels()
    handles2, labels2 = twin.get_legend_handles_labels()
    ax.legend(handles[:2]+handles2+handles[2:], labels[:2]+labels2+labels[2:],
              loc="upper left", fontsize=6.9, framealpha=.94)
    # Tatsächlich gezeichnete Linien müssen die MATLAB-Vektoren unverändert enthalten.
    for artist, y in [(line, q), (reference, free), (waiting, wait)]:
        np.testing.assert_array_equal(artist.get_xdata(), x)
        np.testing.assert_array_equal(artist.get_ydata(), y)


def speed_plot(ax, data):
    x = vector(data, "xKmh")
    seconds = vector(data, "modelSeconds")
    reference = vector(data, "referenceSeconds")
    errors = vector(data, "absoluteErrorSeconds")
    chosen, initial = index(data, "bestIndex"), index(data, "initialIndex")
    measured, = ax.plot(x, seconds, "o-", color=BLUE, lw=1.8, label="simulierte Fahrzeit")
    planned, = ax.plot(x, reference, "--", color=GRAY, lw=1.3, label="GTFS-Referenz")
    ax.scatter(x[chosen], seconds[chosen], marker="*", s=150, c=GREEN,
               edgecolors="white", zorder=5, label="kleinster Fehler")
    ax.scatter(x[initial], seconds[initial], marker="o", s=75, facecolors="none",
               edgecolors=BLUE, lw=1.7, clip_on=False, zorder=5, label="vorherige Grenze")
    ax.annotate(f"Optimum: {fmt(x[chosen])} km/h\nFehler: {fmt(errors[chosen],0)} s",
                (x[chosen], seconds[chosen]), xytext=(12, 14), textcoords="offset points",
                fontsize=8, color=GREEN, arrowprops={"arrowstyle": "-", "color": GREEN})
    ax.set(xlabel="Effektive Geschwindigkeitsgrenze [km/h]",
           ylabel="Abfahrt bis Rückkehrankunft [s]", xlim=(x[0], x[-1]))
    ax.set_ylim(min(seconds.min(), reference.min())-180, max(seconds.max(), reference.max())+160)
    ax.set_xticks(x, [fmt(v) for v in x], fontsize=7.2)
    twin = ax.twinx()
    errorline, = twin.plot(x, errors, "s-", color=ORANGE, lw=1.5, ms=4, label="absoluter Fahrzeitfehler")
    twin.set_ylabel("Absoluter Fehler [s]", color="#a7600e")
    twin.set_ylim(0, max(1, errors.max()*1.18))
    twin.grid(False)
    handles, labels = ax.get_legend_handles_labels()
    handles2, labels2 = twin.get_legend_handles_labels()
    ax.legend(handles+handles2, labels+labels2, loc="lower left", fontsize=6.8, framealpha=.94)
    for artist, y in [(measured, seconds), (planned, reference), (errorline, errors)]:
        np.testing.assert_array_equal(artist.get_xdata(), x)
        np.testing.assert_array_equal(artist.get_ydata(), y)


def spacetime(ax, data):
    x = np.asarray(data["positionKm"], dtype=float)
    time = vector(data, "timeMinutes")
    stations = vector(data, "stationKm")
    blocked = np.asarray(data["blocked"], dtype=bool)
    for station in stations:
        ax.axvline(station, color="#9ba9b4", lw=.6, ls=":", zorder=0)
    paths = []
    for train in range(x.shape[1]):
        xx = x[:, train].copy()
        xx[np.r_[False, np.diff(xx) < 0]] = np.nan  # Ringsprünge grafisch unterbrechen.
        paths.append(np.column_stack((xx, time)))
    ax.add_collection(LineCollection(paths, colors=BLUE, linewidths=.65, alpha=.75))
    row, col = np.where(blocked)
    ax.scatter(x[row, col], time[row], s=1.2, c=ORANGE, zorder=3,
               label="verkehrsbedingt blockiert")
    ax.plot([], [], color=BLUE, label="Zugspitzen")
    ax.plot([], [], ":", color="#9ba9b4", label="Stationen (Nummern oben)")
    ax.set(xlim=(0, float(data["ringLengthKm"])), ylim=(float(data["durationMinutes"]), 0),
           xlabel="Position entlang der S41 [km]",
           ylabel=f"Zeit ab Minute {fmt(data['startMinute'],0)} [min]")
    ax.legend(loc="lower left", fontsize=7, framealpha=.95)
    top = ax.secondary_xaxis("top")
    top.set_xticks(stations, [str(i+1) for i in range(len(stations))], fontsize=6.8)


def paragraph(fig, y, text, *, size=8.6, width=112):
    lines = textwrap.wrap(text, width=width, break_long_words=False, break_on_hyphens=False)
    fig.text(.075, y, "\n".join(lines), va="top", fontsize=size, linespacing=1.32, color="#202a34")
    return y-len(lines)*size*1.32/(11.69*72)-.012


def page(number, subtitle):
    f = plt.figure(figsize=(8.27, 11.69), facecolor="white")
    f.text(.075, .958, "S-Bahn-Ring simulieren und validieren", fontsize=16,
           weight="bold", color="#123650", va="top")
    f.text(.075, .928, subtitle, fontsize=9.4, color="#4a5966", va="top")
    f.text(.075, .027, "Modellbildung und Simulation · Woche 2 · Datenstand 14.10.2026", fontsize=8, color="#596570")
    f.text(.925, .027, f"{number} / 3", fontsize=8, color="#596570", ha="right")
    return f


def table_on(fig, bounds, cells, labels, widths, size=8):
    ax = fig.add_axes(bounds); ax.axis("off")
    t = ax.table(cellText=cells, colLabels=labels, colWidths=widths,
                 cellLoc="left", colLoc="left", bbox=[0, 0, 1, 1])
    t.auto_set_font_size(False); t.set_fontsize(size)
    for (r, c), cell in t.get_celld().items():
        cell.set_edgecolor("#d6e0e7"); cell.set_linewidth(.5)
        cell.set_facecolor("#e7eff4" if r == 0 else ("#f5f8fa" if r % 2 else "white"))
        if r == 0: cell.set_text_props(weight="bold", color="#123650")


def finish_page(pdf, fig, number):
    fig.savefig(FIG / f"bericht_seite_{number}.png", dpi=130)
    pdf.savefig(fig); plt.close(fig)


def main():
    FIG.mkdir(exist_ok=True)
    data = loadmat(OUT / "diagrammdaten.mat", simplify_cells=True)["plotData"]
    assert int(data["schemaVersion"]) == 2, "Diagrammdaten neu in MATLAB berechnen."
    p = data["meta"]; tr = data["trains"]; dw = data["dwell"]; speed = data["speed"]
    checks, tests, audit, manifest = (rows(name) for name in
        ["sanity_checks.csv", "matlab_tests.csv", "diagrammwerte_pruefung.csv", "laufverzeichnis.csv"])
    assert len(audit) == len(checks) == len(manifest) == int(p["evaluatedRunCount"])
    assert {r["run"] for r in audit} == {r["run"] for r in manifest}
    assert all(r["passed"].lower() in {"1", "true"} for r in audit)
    assert all(v.lower() in {"1", "true"} for r in checks for k,v in r.items() if k != "run")
    assert tests and all(r["Passed"].lower() in {"1", "true"} for r in tests)
    common, zero = index(tr, "comparisonIndex"), index(dw, "baseIndex")
    np.testing.assert_equal(tr["throughput"][common], dw["throughput"][zero])
    np.testing.assert_equal(tr["blockedSecondsPerTrainHour"][common], dw["blockedSecondsPerTrainHour"][zero])
    assert len(vector(dw,"x")) == 6 and np.array_equal(vector(dw,"x"), np.arange(0,31,6))
    assert vector(tr,"x")[0] == p["baseTrainCount"]
    qmax = max(vector(tr,"throughput").max(),vector(tr,"freeThroughput").max(),
               vector(dw,"throughput").max(),vector(dw,"freeThroughput").max())*1.12
    waitmax = max(1,vector(tr,"blockedSecondsPerTrainHour").max(),
                  vector(dw,"blockedSecondsPerTrainHour").max())*1.15
    for name, series, label, role in [
        ("zugzahl",tr,"Zugzahl N · GTFS-Halte, 500-m-Blöcke","trains"),
        ("haltezeit",dw,"Zuschlag auf jeden GTFS-Stationshalt [s] · N=36","dwell")]:
        f,ax = plt.subplots(figsize=(7.6,3.8),layout="constrained")
        parameter_plot(ax,series,label,role,qmax,waitmax)
        f.savefig(FIG/f"{name}.png",dpi=200); f.savefig(FIG/f"{name}.pdf"); plt.close(f)
    f,ax = plt.subplots(figsize=(7.6,3.8),layout="constrained")
    speed_plot(ax,speed)
    f.savefig(FIG/"geschwindigkeitsgrenze.png",dpi=200)
    f.savefig(FIG/"geschwindigkeitsgrenze.pdf"); plt.close(f)
    f,ax = plt.subplots(figsize=(10,6.2),layout="constrained")
    spacetime(ax,data["spaceTime"])
    f.savefig(FIG/"raumzeit.png",dpi=200); f.savefig(FIG/"raumzeit.pdf"); plt.close(f)

    ref = rows("referenzvergleich.csv"); before,after = ref
    chosen = index(speed,"bestIndex")
    train_text = (f"Die Untersuchung beginnt bei N={int(p['baseTrainCount'])} (grüner Stern) und umfasst "
                  f"{len(vector(tr,'x'))} Zugzahlen. Bei N={int(tr['x'][common])} werden "
                  f"{fmt(tr['throughput'][common])} Züge/h und {fmt(tr['blockedSecondsPerTrainHour'][common])} "
                  "s Stillstand je Zug und Stunde gemessen. Ab hier erhöhen weitere Züge vor allem die Wartezeit.")
    dwell_text = (f"Sechs Profile: GTFS plus 0, 6, 12, 18, 24 oder 30 s je Station, durchgehend N={int(dw['trainCount'])}. "
                  f"GTFS+0 stimmt exakt mit N={int(tr['x'][common])} aus der ersten Grafik überein (violette Rauten). "
                  f"GTFS+{fmt(dw['x'][-1],0)} liefert {fmt(dw['throughput'][-1])} Züge/h und "
                  f"{fmt(dw['blockedSecondsPerTrainHour'][-1])} s Stillstand je Zug und Stunde.")
    with PdfPages(OUT/"Ausarbeitung_SBahn2.pdf",metadata={"Title":"S-Bahn-Ring: Kalibrierung und Parameterstudien"}) as pdf:
        f=page(1,"Aufgabe 1 · Parameter und optimale Geschwindigkeitsgrenze")
        paragraph(f,.89,"Der Modellkern aus Woche 1 wird als +sbahn2 verwendet. Vorab gewählte Größen: "
                  "Abfahrt Beusselstraße bis Rückkehrankunft zur Kalibrierung und 27 reine Abschnittsfahrzeiten "
                  "zur anschließenden Prüfung. Ein freier Zug; alle Kandidaten werden tatsächlich simuliert.")
        cells=[
            ["Strecke / Raster / Zugkörper",f"S41, {fmt(p['lengthMeters']/1000,3)} km; 1 m / 1 s; 148 m"],
            ["Ausgangsfall / Geschwindigkeit",f"N={int(p['baseTrainCount'])}; {fmt(p['cruiseSpeedKmhBefore'])} → {fmt(p['cruiseSpeedKmhAfter'])} km/h"],
            ["Dynamik / Blöcke",f"±1 m/s²; {int(p['blockCount'])} Modellblöcke zu {int(p['blockMinMeters'])}–{int(p['blockMaxMeters'])} m"],
            ["GTFS-Halte / Zuschlagsstudie",f"{fmt(p['dwellMinSeconds'],0)}–{fmt(p['dwellMaxSeconds'],0)} s; je Station zusätzlich 0–30 s"],
            ["Messung / Zufall",f"{fmt(p['warmupSeconds']/60,0)} min Einschwingen + {fmt(p['measurementSeconds']/60,0)} min Messung; deterministisch"],
        ]
        table_on(f,[.075,.665,.85,.145],cells,["Parameter","Wert"],[.35,.65])
        ax=f.add_axes([.105,.355,.74,.245]); speed_plot(ax,speed)
        ax.set_title("Geschwindigkeitsstudie: kleinster Fehler gegenüber dem Fahrplan",fontsize=9.5)
        table_on(f,[.075,.202,.85,.08],[
            ["Abfahrt → Rückkehr [s]",before['reference_s'],before['model_departure_return_s'],after['model_departure_return_s']],
            ["Abschnitts-MAE / RMSE [s]","0 / 0",f"{fmt(before['segment_mae_s'])} / {fmt(before['segment_rmse_s'])}",
             f"{fmt(after['segment_mae_s'])} / {fmt(after['segment_rmse_s'])}"]],
            ["Vergleich","GTFS","Vorher","Kalibriert"],[.39,.16,.225,.225],8)
        y=paragraph(f,.183,f"Das Minimum liegt bei {fmt(speed['xKmh'][chosen])} km/h: "
                    f"{fmt(speed['modelSeconds'][chosen],0)} statt {fmt(speed['referenceSeconds'][chosen],0)} s "
                    f"(Fehler {fmt(speed['absoluteErrorSeconds'][chosen],0)} s, {fmt(after['error_percent'],2)} %). "
                    f"Der volle Modellumlauf beträgt {fmt(p['freeArrivalLapSeconds'],0)} s; der Halt an der Startstation "
                    "wird für den Referenzvergleich abgezogen. Die Abschnittsprüfung wird nicht nachoptimiert.")
        paragraph(f,y,"Referenz: VBB-GTFS, S41 trip_id 308542990, 14.10.2026. Sollzeiten, keine Ist-Messungen. "
                  "Geometrie: © OpenStreetMap contributors, Relation 14981. Quellen und Lizenzen im Daten-README "
                  "unter Woche 1/NaSch-SBahn/daten/ringbahn_2026-10-14 (VBB CC BY 4.0; OSM ODbL).",size=7.7,width=122)
        finish_page(pdf,f,1)

        f=page(2,"Aufgabe 2 · Vergleichbare Studien zu Zugzahl und Stationshalten")
        paragraph(f,.89,"Gleiche Strecke, Geschwindigkeit, Blöcke und Achsenskalierungen. Q zählt Abfahrten an Station 1 "
                  "im Messfenster. Kleine Abweichungen zur freien Kurve entstehen durch die endliche Zählung. "
                  "Blockierter Stillstand enthält weder Stationshalte noch langsames Folgen.")
        ax=f.add_axes([.105,.58,.74,.23]); parameter_plot(ax,tr,"Zugzahl N · unverändertes GTFS-Profil","trains",qmax,waitmax)
        ax.set_title("Zugzahlstudie beginnt beim Ausgangsfall N=12",fontsize=10)
        paragraph(f,.525,train_text,size=8.5)
        ax=f.add_axes([.105,.22,.74,.23]); parameter_plot(ax,dw,"Zuschlag je GTFS-Stationshalt [s] · N=36","dwell",qmax,waitmax)
        ax.set_title("Haltezeitstudie: GTFS-Profil + regelmäßiger Zuschlag",fontsize=10)
        y=paragraph(f,.164,dwell_text,size=8.5)
        paragraph(f,y,"Das Stationsprofil bleibt erhalten. Für gültige Startbelegungen wird nötigenfalls die kleinste "
                  "gemeinsame Verschiebung der freien Zeitphasen gesucht; Zugzahl und Blöcke bleiben gleich. "
                  "Der identische Nullzuschlagsfall ist bitgenau geprüft.",size=8.0,width=119)
        finish_page(pdf,f,2)

        f=page(3,"Raum-Zeit-Diagramm · Zahlenprüfung und Fazit")
        st=data['spaceTime']
        paragraph(f,.89,f"N={int(st['trainCount'])}, unveränderte GTFS-Halte; Ausschnitt ab Minute {fmt(st['startMinute'],0)} "
                  f"für {fmt(st['durationMinutes'],0)} Minuten. Orange: verkehrsbedingt blockiert. "
                  "Gepunktete Linien und Nummern markieren die Stationen; Ringsprünge sind unterbrochen.")
        ax=f.add_axes([.105,.49,.79,.315]); spacetime(ax,st)
        y=paragraph(f,.435,"Zahlenweg und Prüfung",size=11)
        checked_values=sum(int(r['checked_numeric_values']) for r in audit)
        y=paragraph(f,y,f"MATLAB gibt alle Kurvenwerte direkt als results.plotData zurück und speichert sie in "
                    f"diagrammdaten.mat. Python zeichnet diese Vektoren unverändert. {len(audit)} Läufe und "
                    f"{checked_values} Zahlenwerte wurden aus Positionen, Halteuhren und Ereignissen erneut geprüft. "
                    f"Alle {len(tests)} MATLAB-Tests und zwölf Sanity-Check-Gruppen je Lauf bestehen. Die tatsächlichen "
                    "Linienkoordinaten werden auch beim Zeichnen gegen die MATLAB-Vektoren geprüft.")
        y=paragraph(f,y,"Fazit und Grenzen",size=11)
        y=paragraph(f,y,"Mehr Züge steigern zunächst den Durchsatz; im dichten Bereich wächst vor allem die Wartezeit. "
                    "Die Haltezeitstudie verändert jetzt ausschließlich den Zuschlag zum gleichen GTFS-Profil. "
                    "Die effektive Geschwindigkeitsgrenze bündelt örtliche Limits und Fahrplanreserven. Ideale Haltepunkte, "
                    "identische Züge und vereinfachte Blocklogik begrenzen die Übertragbarkeit auf den realen Betrieb.")
        y=paragraph(f,y,"Reproduktion und KI-Einsatz",size=11)
        paragraph(f,y,"SBahn2.m führt Tests, Studien, Zahlenprüfung und Berichterzeugung aus. CSV/JSON, vollständige "
                  "MAT-Läufe und Diagramme liegen in ergebnisse/. laufverzeichnis.csv definiert die aktuellen Läufe. "
                  "Codex unterstützte Codeänderungen, Prüfung, Auswertung und Text; alle Ergebnisse wurden in MATLAB berechnet.",size=8.0,width=119)
        finish_page(pdf,f,3)

    markdown=f"""# S-Bahn-Ring – Woche 2

## Datenweg und Versuchskonvention

`run_sbahn2` gibt die tatsächlich berechneten Zahlen als `results.plotData` zurück und schreibt sie nach `diagrammdaten.mat`. Python liest diese Zahlen direkt ein und prüft auch die gezeichneten Linienkoordinaten. Alle aktuellen Läufe stehen in `laufverzeichnis.csv`; `diagrammwerte_pruefung.csv` dokumentiert die unabhängige Zahlenprüfung. Es werden keine Kurvenwerte von Hand im Zeichenskript eingetragen.

## Aufgabe 1: Geschwindigkeitsgrenze

![Geschwindigkeitsgrenze](diagramme/geschwindigkeitsgrenze.png)

Neun vollständig simulierte Kandidaten; ein freier Zug. Kleinster absoluter Fehler bei {fmt(speed['xKmh'][chosen])} km/h: {fmt(speed['modelSeconds'][chosen],0)} statt {fmt(speed['referenceSeconds'][chosen],0)} s. Vorher: {before['model_departure_return_s']} s bei {fmt(before['speed_kmh'])} km/h. Kalibriert wird Abfahrt bis Rückkehrankunft; die 27 reinen Abschnittsfahrzeiten dienen anschließend zur Prüfung. Die Grenze ist ein effektiver Modellparameter, keine Messung der Fahrzeughöchstgeschwindigkeit.

## Aufgabe 2: Zugzahl

![Zugzahlstudie](diagramme/zugzahl.png)

{train_text}

## Aufgabe 2: Haltezeit

![GTFS-Halte plus Zuschlag](diagramme/haltezeit.png)

{dwell_text}

Es gelten jeweils dieselben GTFS-Stationsmediane plus Zuschlag. Der Nullzuschlag bei N=36 ist hinsichtlich vollständiger Trajektorien und Kennzahlen bitgenau identisch zum N=36-Fall der Zugzahlstudie. Die Phasenverschiebungen der sechs Anfangszustände betragen {', '.join(fmt(v,0) for v in vector(dw,'initialPhaseShiftSeconds'))} s; die regelmäßigen zeitlichen Zugabstände werden dabei erhalten. Die kleinste gültige Verschiebung verhindert bereits zu Beginn gemeinsam belegte Blöcke.

## Raum-Zeit-Diagramm

![Raum-Zeit-Diagramm](diagramme/raumzeit.png)

## Kennzahlen und Prüfungen

Je Lauf {fmt(p['warmupSeconds']/60,0)} Minuten Einschwingen und {fmt(p['measurementSeconds']/60,0)} Minuten Messung. Durchsatz: gezählte Abfahrten an Station 1 geteilt durch die Messdauer in Stunden. Stillstand: tatsächliche bewegungslose Sekunden ohne laufenden Stationshalt, normiert auf Zug und Stunde. Die gemeinsame Achsenskalierung macht beide Parameterdiagramme vergleichbar. Ohne Zufallseinflüsse genügt ein deterministischer Lauf je Einstellung.

{len(tests)} MATLAB-Tests, {len(audit)} ausgewertete Läufe und {checked_values} unabhängig geprüfte Zahlenwerte. Grundregeln, vollständige Tabellenexporte, gemessene Referenzfahrzeiten, gemeinsamer Betriebspunkt und optimale Geschwindigkeitsmarkierung sind geprüft. `headway_std_s` beschreibt zeitliche Zugabstände, keine Wiederholungsstreuung.

## Quellen, Grenzen und KI

VBB-GTFS: S41 trip_id 308542990 am 14.10.2026; Sollzeiten. Kartierte Geometrie: © OpenStreetMap contributors, Relation 14981. Quellen und Lizenzen im Daten-README aus Woche 1. Ideale Haltepunkte, identische Fahrzeuge, vereinfachte Blöcke und effektive Geschwindigkeitsgrenze begrenzen die Aussage über reale Streckenkapazität. Codex unterstützte Implementierung, Versuchsprüfung und Text. Alle Zahlen stammen aus ausgeführten MATLAB-Läufen.
"""
    (OUT/'Ausarbeitung_SBahn2.md').write_text(markdown,encoding='utf-8')
    origin=ROOT.parent/'Woche 1'/'NaSch-SBahn'/'+sbahn'
    manifest=[]
    local_model=ROOT/'modell'/'+sbahn2'
    # Woche 1 darf zusätzliche UI-Helfer erhalten, die nicht zu +sbahn2 gehören.
    for dest in sorted(local_model.rglob('*.m')):
        rel=dest.relative_to(local_model); src=origin/rel
        manifest.append({'file':rel.as_posix(),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
                         'local_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
                         'changed_beyond_namespace':src.read_text(encoding='utf-8-sig').replace('sbahn.','sbahn2.') != dest.read_text(encoding='utf-8-sig')})
    (OUT/'quellcode_herkunft.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
    print(f"Vier Diagramme und Bericht (3 Seiten): {OUT/'Ausarbeitung_SBahn2.pdf'}")
    print(f"Tests: {len(tests)}; gepruefte Laeufe: {len(audit)}; Zahlenwerte: {checked_values}")


if __name__ == '__main__':
    main()
