"""PDF mit Parametern, MATLAB-Ergebnissen und unabhängiger Rohdatenprüfung.

py tools/bericht_trafic_flow_studien.py ergebnisse/trafic_flow/studie_...
Python zeichnet die exportierten MATLAB-Werte unverändert. Die erneute
Berechnung von Kennzahlen dient ausschließlich der unabhängigen Prüfung.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import shutil
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.table import Table
import numpy as np
from scipy.io import loadmat

BLUE, ORANGE, GRAY = "#146b9c", "#bb641b", "#77818a"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9,
                     "pdf.fonttype": 42, "axes.spines.top": False,
                     "axes.grid": True, "grid.alpha": .2})


def read_rows(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def num(row, name):
    return float(row[name])


def yes(row, name):
    return str(row[name]).lower() in {"1", "true"}


def vector(rows, name):
    return np.array([num(row, name) for row in rows])


def fmt(value, digits=2):
    if not np.isfinite(float(value)):
        return "n. v."
    return f"{float(value):.{digits}f}".replace(".", ",")


def verify_raw(out, rows, plan):
    audits = []
    start = plan["warmupMinutes"] * 60
    finish = start + plan["measurementMinutes"] * 60
    hours = plan["measurementMinutes"] / 60
    for index, row in enumerate(rows, 1):
        if not yes(row, "passed"):
            audits.append({"file": row["file"], "status": "nicht simuliert", "verified": False})
            continue
        raw = loadmat(out / "laeufe" / row["file"], simplify_cells=True)
        p, g, m = raw["p"], raw["G"], raw["metric"]
        n = int(p["trainCount"])
        # MATLAB kann ganzzahlige Werte kompakt als unsigned speichern.
        # Differenzen müssen vorab in einen vorzeichenbehafteten Typ wechseln.
        position = np.asarray(g["position"], dtype=np.int64).reshape(-1, n)
        velocity = np.asarray(g["velocity"], dtype=np.int64).reshape(-1, n)
        wait = np.asarray(g["waitSteps"]).reshape(-1, n)
        blocked = np.asarray(g["blocked"], dtype=bool).reshape(-1, n)[1:]
        t = np.atleast_1d(g["timeSeconds"])
        selected = (t[:-1] >= start) & (t[:-1] < finish)
        moving = (np.diff(position, axis=0) % p["cellCount"]) > 0
        station = np.atleast_1d(p["route"]["stationCells"])[0]
        count = int(np.count_nonzero(((position[:-1] == station) & moving)[selected]))
        np.testing.assert_allclose(count / hours, num(row, "throughput_trains_per_h"), atol=1e-10)
        np.testing.assert_equal(count, int(m["departure_count"]))
        assert not np.any(blocked & (moving | (wait[:-1] > 0)))
        arrivals = np.asarray(p["state"]["arrivalLog"]).reshape(-1, 3)
        blocked_samples = []
        for train in range(1, n + 1):
            times = arrivals[(arrivals[:, 1] == train) & (arrivals[:, 2] == 1), 0]
            for first, last in zip(times[:-1], times[1:]):
                if first >= start and last <= finish:
                    blocked_samples.append(np.count_nonzero(blocked[int(first):int(last), train - 1]))
        actual = float(np.mean(blocked_samples)) if blocked_samples else float("nan")
        np.testing.assert_allclose(actual, num(row, "blocked_s_per_train_lap"), atol=1e-10, equal_nan=True)
        np.testing.assert_equal(len(blocked_samples), int(num(row, "complete_lap_count")))
        np.testing.assert_equal(np.count_nonzero(blocked[selected]), num(row, "blocked_train_s_measurement"))
        assert np.max(np.abs(np.diff(velocity, axis=0))) <= 1
        assert raw["report"]["checksPassed"]
        config = p["config"]
        assert bool(config["anticipationEnabled"]) == yes(row, "anticipation")
        assert config["anticipationBeta"] == plan["beta"]
        np.testing.assert_allclose(config["randomStopProbability"], num(row, "probability"))
        np.testing.assert_allclose(config["randomBrakeProbability"], num(row, "probability"))
        np.testing.assert_allclose(np.atleast_1d(p["stationDwellSeconds"]),
                                   np.atleast_1d(p["baseStationDwellSeconds"]) + num(row, "extra_dwell_s"))
        np.testing.assert_allclose(m["free_throughput_trains_per_h"],
                                   3600 * n / p["expectedLapSeconds"])
        audits.append({"file": row["file"], "status": "geprüft", "verified": True})
        if index % 20 == 0:
            print(f"Rohdaten geprüft: {index}/{len(rows)}", flush=True)
    with (out / "rohdatenaudit.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["file", "status", "verified"])
        writer.writeheader(); writer.writerows(audits)
    return audits


def page(title, subtitle=""):
    fig = plt.figure(figsize=(8.27, 11.69), facecolor="white")
    fig.text(.08, .957, title, fontsize=17, weight="bold", color="#173f55", va="top")
    if subtitle:
        fig.text(.08, .916, subtitle, fontsize=9, va="top", linespacing=1.45)
    return fig


def paragraph(fig, y, text, width=105, size=8.5):
    lines = "\n".join(textwrap.wrap(text, width))
    fig.text(.08, y, lines, fontsize=size, va="top", linespacing=1.5)


def table(ax, data, headers=None, widths=None, font=8, scale=1.4):
    ax.axis("off")
    result = ax.table(cellText=data, colLabels=headers, loc="upper center",
                      cellLoc="left", colLoc="left", colWidths=widths)
    result.auto_set_font_size(False); result.set_fontsize(font); result.scale(1, scale)
    for (r, _), cell in result.get_celld().items():
        cell.set_edgecolor("#c9d3d9"); cell.set_linewidth(.5)
        if headers is not None and r == 0:
            cell.set_facecolor("#e4eef4"); cell.set_text_props(weight="bold")
        elif r % 2 == 0:
            cell.set_facecolor("#f5f8fa")
    return result


def save_page(pdf, fig, out, stem, number):
    fig.text(.08, .025, "S-Bahn S41 · Parameter und Ergebnisse · ohne Interpretation", fontsize=7, color="#596773")
    fig.text(.92, .025, str(number), ha="right", fontsize=8)
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    for item in fig.findobj(match=Table):
        bounds = item.get_window_extent(renderer).transformed(fig.transFigure.inverted())
        assert bounds.x0 >= .02 and bounds.x1 <= .98 and bounds.y0 >= .055 and bounds.y1 <= .90, \
            f"Tabelle außerhalb des Seitenbereichs: {stem}, {bounds}"
    pdf.savefig(fig)
    fig.savefig(out / "grafiken" / f"{stem}.png", dpi=160)
    fig.savefig(out / "grafiken" / f"{stem}.pdf")
    plt.close(fig)


def parameter_page(pdf, out, plan, critical, number):
    fig = page("Verkehrsfluss: Versuchsreihen", "Verwendete Parameter und Messdefinitionen")
    parameters = [
        ["Strecke / Darstellung", "Reale Ringbahn S41 / geografischer Verlauf"],
        ["Fahrmodell / Zuglänge", "Beschleunigen und Bremsen / 148 m"],
        ["Raster / Beschleunigungsgrenze", "1 m / 1 s; maximal ±1 m/s²"],
        ["Blocksteuerung", "117 OSM-Signalabschnitte"],
        ["Zielblockabstand", "500 m; bei OSM-Signalabschnitten ohne Wirkung"],
        ["Stationshalte", "GTFS vom 14.10.2026; fester Zuschlag nur in Haltezeitserie"],
        ["Maximalgeschwindigkeit", "80 km/h Eingabe; 79,2 km/h effektiv (außer Heatmap)"],
        ["Antizipation", "aus / an; beta = 0,25 1/s; bei N = 1 ohne Vorgänger"],
        ["Antizipationsregel", "a = beta · (v_Vorgänger − v_Zug), bei langsamerem Vorgänger"],
        ["Einschwingen / Messdauer", "60 min / 180 min; Gesamtdauer je Lauf 240 min"],
        ["Zufall / Wiederholungen", "Startwert 42; ein Lauf je Kombination"],
        ["Zugzahlserie", "12, 16, 20, 24, 28, 32, 36, 40; Zuschlag 0 s; p = 0"],
        ["Haltezeitserie", "0, 6, 12, 18, 24, 30 s je Station; N = jeweiliges N_grenz; p = 0"],
        ["Störungsserie", "p = 0; 0,1; …; 1; N = max(1, round(0,6 · N_grenz))"],
        ["Zufälliger Stationszusatz", "diskrete Gleichverteilung U{0,…,120} s; fester Zuschlag 0 s"],
        ["Zufallsbremsung", "Prüfung je Blockeinfahrt mit p; Ziel floor(v_Eintritt / 2)"],
        ["Bremsablauf bei Störung", "−1 m/s² bis zum Ziel, danach sofortiges Beschleunigen soweit möglich"],
        ["Stationszusatz-Prüfung", "unabhängig je Ankunft mit demselben p"],
        ["Heatmap", "Antizipation an; N = 12:4:40; p = 0; fester Zuschlag 0 s"],
        ["Heatmap: effektive Geschwindigkeiten", "36,0; 43,2; 50,4; 57,6; 64,8; 72,0; 79,2 km/h"],
        ["Bildpause / Bildabstand", "0,05 s / 10 Schritte; Animation im Batch ausgeschaltet"],
    ]
    table(fig.add_axes([.08, .42, .84, .45]), parameters,
          ["Parameter", "Wert"], widths=[.34, .66], font=7.5, scale=1.6)
    paragraph(fig, .345, "Durchsatz: Abfahrten an Station 1 (Beusselstraße) im halboffenen "
              "Messfenster [3600,14400) s, geteilt durch drei Stunden.")
    paragraph(fig, .275, "Blockierter Stillstand: ausschließlich die modellseitig als blockiert "
              "markierten Sekunden ohne Bewegung und ohne laufende Stationshalteuhr. Geplante Halte, "
              "zufällige Stationszusätze und langsames Folgen bei noch freiem Fahrweg zählen nicht dazu.")
    paragraph(fig, .18, "Je-Zug-je-Umlauf-Wert: mittlere blockierte Dauer der vollständig im Messfenster "
              "beobachteten Zugumläufe, jeweils von Ankunft an Station 1 bis zur nächsten Ankunft dort. "
              "Jeder vollständige Zugumlauf zählt einmal. Ohne vollständigen Umlauf: n. v. / NaN.")
    paragraph(fig, .085, f"Berechnet am {plan['createdBerlin']} (Europe/Berlin), MATLAB {plan['matlabVersion']}.", size=7.5)
    save_page(pdf, fig, out, "01_parameter", number)


def critical_pages(pdf, out, plan, critical, scan, first_page):
    nmax = max(int(num(r, "train_count")) for r in scan)
    pages = 0
    for first in range(1, nmax + 1, 20):
        last = min(first + 19, nmax)
        fig = page("Bestimmung der Grenzzugzahl", f"Ganzzahlige Prüfung N = {first} bis {last}; p = 0; fester Haltezuschlag 0 s")
        summary = [["an" if yes(r, "anticipation") else "aus", int(num(r, "critical_trains")),
                    int(num(r, "probability_trains"))] for r in critical]
        table(fig.add_axes([.08, .80, .84, .07]), summary,
              ["Langsames Abbremsen", "N_grenz", "N für Störungsserie"], font=8)
        paragraph(fig, .76, "Freier Referenzdurchsatz Q_frei = 3600 · N / T_frei. Ein Punkt erfüllt "
                  "das Kriterium, wenn gegenüber dem freien Referenzwert höchstens eine Abfahrt im "
                  "dreistündigen Messfenster fehlt (Toleranz 1/3 Zug/h). N_grenz ist die größte "
                  "geprüfte, gültige Zugzahl mit erfülltem Kriterium. Alle Q-Werte in Zügen/h.", size=8)
        data = []
        for n in range(first, last + 1):
            values = []
            for mode in [False, True]:
                match = next((r for r in scan if int(num(r, "train_count")) == n and yes(r, "anticipation") == mode), None)
                if match is None:
                    values.extend(["—", "—", "—"])
                else:
                    values.extend([fmt(num(match, "throughput_trains_per_h")),
                                   fmt(num(match, "free_throughput_trains_per_h")),
                                   "ja" if yes(match, "free_match") else "nein"])
            data.append([n] + values)
        table(fig.add_axes([.08, .07, .84, .59]), data,
              ["N", "Q aus", "Q frei", "Kriterium", "Q an", "Q frei", "Kriterium"],
              font=7.7, scale=1.5)
        save_page(pdf, fig, out, f"{first_page+pages:02d}_grenzsuche", first_page + pages)
        pages += 1
    return pages


def series_page(pdf, out, rows, title, xlabel, subtitle, stem, page_number):
    fig = page(title, subtitle)
    ax = fig.add_axes([.115, .43, .755, .40])
    x = vector(rows, "x")
    q = vector(rows, "throughput_trains_per_h")
    free = vector(rows, "free_throughput_trains_per_h")
    blocked = vector(rows, "blocked_s_per_train_lap")
    line, = ax.plot(x, q, "o-", color=BLUE, lw=1.8, label="gemessener Durchsatz")
    reference, = ax.plot(x, free, "--", color=GRAY, lw=1.2, label="freier Referenzbetrieb")
    ax.set(xlabel=xlabel, ylabel="Durchsatz [Züge/h]")
    ax.set_xticks(x)
    ax.set_ylim(bottom=0)
    twin = ax.twinx(); twin.grid(False)
    waiting, = twin.plot(x, blocked, "s-", color=ORANGE, lw=1.4, ms=4,
                         label="blockierter Stillstand je Zugumlauf")
    twin.set_ylabel("Blockierter Stillstand [s/(Zug · Umlauf)]", color=ORANGE, fontsize=8)
    twin.tick_params(axis="y", colors=ORANGE)
    finite = blocked[np.isfinite(blocked)]
    twin.set_ylim(0, max(1, float(finite.max()) * 1.15) if len(finite) else 1)
    ax.legend(handles=[line, reference, waiting], fontsize=7.5, loc="lower left",
              bbox_to_anchor=(0, 1.02), borderaxespad=0, frameon=False)
    for artist, values in [(line, q), (reference, free), (waiting, blocked)]:
        np.testing.assert_array_equal(artist.get_xdata(), x)
        np.testing.assert_array_equal(artist.get_ydata(), values)
    display = [[fmt(num(r, "x"), 1), fmt(num(r, "throughput_trains_per_h")),
                fmt(num(r, "free_throughput_trains_per_h")),
                fmt(num(r, "blocked_s_per_train_lap")), fmt(num(r, "complete_lap_count"), 0),
                fmt(num(r, "trains_with_complete_laps"), 0)] for r in rows]
    table(fig.add_axes([.08, .12, .84, .23]), display,
          ["x", "Q [Züge/h]", "Q frei", "blockiert [s]", "Umläufe", "Züge erfasst"],
          font=7.5, scale=1.45)
    paragraph(fig, .075, "Stillstand bezieht sich auf einen vollständigen Zugumlauf. n. v.: kein gültiger "
              "Wert; null bedeutet einen beobachteten Umlauf ohne blockierten Stillstand.", size=7.5)
    save_page(pdf, fig, out, stem, page_number)


def heat_page(pdf, out, rows, page_number):
    fig = page("Verkehrsstromuntersuchung", "Langsames Abbremsen an · beta = 0,25 1/s · p = 0 · fester Haltezuschlag 0 s")
    speeds = np.unique(vector(rows, "effective_kmh"))
    trains = np.unique(vector(rows, "train_count")).astype(int)
    matrix = np.full((len(trains), len(speeds)), np.nan)
    for row in rows:
        y = np.flatnonzero(trains == num(row, "train_count"))[0]
        x = np.flatnonzero(np.isclose(speeds, num(row, "effective_kmh")))[0]
        matrix[y, x] = num(row, "throughput_trains_per_h")
    ax = fig.add_axes([.11, .27, .75, .56])
    cmap = plt.get_cmap("viridis").copy(); cmap.set_bad("#d5d5d5")
    image = ax.imshow(matrix, origin="lower", aspect="auto", cmap=cmap)
    ax.set_xticks(range(len(speeds)), [fmt(x, 1) for x in speeds], rotation=45, ha="right")
    ax.set_yticks(range(len(trains)), trains)
    ax.set(xlabel="Effektive Maximalgeschwindigkeit [km/h]", ylabel="Anzahl der Züge")
    ax.grid(False)
    for y in range(len(trains)):
        for x in range(len(speeds)):
            ax.text(x, y, fmt(matrix[y, x]), ha="center", va="center", fontsize=7,
                    bbox={"facecolor": "white", "edgecolor": "none", "alpha": .85, "pad": 1})
    cb = fig.colorbar(image, cax=fig.add_axes([.88, .27, .025, .56]))
    cb.set_label("Durchschnittlicher Durchsatz [Züge/h]", fontsize=8)
    paragraph(fig, .16, "56 Kombinationen, jeweils ein Lauf. Eingabebereich Geschwindigkeit 36–80 km/h "
              "mit Schrittweite 7,2 km/h und eingeschlossener Obergrenze. 80 km/h und 79,2 km/h "
              "führen zur gleichen Rasterstufe; diese wird nur einmal verwendet.")
    paragraph(fig, .085, "Je Lauf 60 min Einschwingen und 180 min Messung. Graue Felder / n. v. "
              "kennzeichnen ungültige Läufe. Alle Werte stehen zusätzlich in heatmap.csv.", size=8)
    np.testing.assert_array_equal(np.asarray(image.get_array()), matrix)
    save_page(pdf, fig, out, f"{page_number:02d}_verkehrsstrom", page_number)


def status_page(pdf, out, runs, audits, page_number):
    fig = page("Prüfung und gespeicherte Daten", "Dokumentation der Ausführung")
    failed = [r for r in runs if not yes(r, "passed")]
    no_laps = [r for r in runs if yes(r, "passed") and num(r, "complete_lap_count") == 0]
    facts = [
        ["Unterschiedliche Konfigurationen", str(len(runs))],
        ["Erfolgreiche Simulationen", str(len(runs) - len(failed))],
        ["Nicht ausführbare Konfigurationen", str(len(failed))],
        ["Gültige Läufe ohne vollständigen Messumlauf", str(len(no_laps))],
        ["Unabhängig geprüfte Rohdatensätze", str(sum(a["verified"] for a in audits))],
        ["Kennzahlenprüfung mit synthetischen Ereignissen", "bestanden"],
        ["Modellprüfungen in jedem erfolgreichen Lauf", "bestanden"],
        ["Positionsdetektor gegen Abfahrtsprotokoll", "übereinstimmend"],
        ["Blockierter Stillstand je vollständigem Umlauf", "unabhängig aus Rohdaten nachgezählt"],
        ["Gezeichnete Linien / Heatmap", "mit exportierten MATLAB-Werten abgeglichen"],
    ]
    table(fig.add_axes([.08, .57, .84, .29]), facts, ["Prüfung", "Ergebnis"], font=8, scale=1.6)
    paragraph(fig, .48, "Dateien: versuchsplan.json und basiskonfiguration.json dokumentieren die Eingaben. "
              "Die sechs Serien-CSV-Dateien, grenzsuche.csv und heatmap.csv enthalten alle Diagrammwerte. "
              "laufverzeichnis.csv verknüpft jede Konfiguration mit den Rohdaten unter laeufe/. "
              "Jede erfolgreiche MAT-Datei enthält Trajektorien, Ereignisse, Modellparameter, "
              "Kennzahlen und die einzeln ausgewerteten Umläufe.")
    paragraph(fig, .35, "quellstand/ enthält die verwendeten Modellfunktionen und die MATLAB-Auswertung. "
              "rohdatenaudit.csv dokumentiert die zusätzliche Python-Prüfung. grafiken/ enthält jede "
              "Berichtsseite als PNG und PDF. matlab.log protokolliert die Simulationsausführung.")
    if failed:
        paragraph(fig, .23, "Nicht ausführbare Läufe: " + "; ".join(r["key"] for r in failed), size=7)
    else:
        paragraph(fig, .23, "Alle untersuchten Konfigurationen wurden erfolgreich simuliert.")
    paragraph(fig, .12, "Es wurde genau ein Lauf je unterschiedlicher Konfiguration berechnet. Identische "
              "Konfigurationen werden zwischen Serien wiederverwendet. Es erfolgt keine Mittelung über "
              "mehrere Zufallsstartwerte. Der Bericht enthält Parameter und Zahlenwerte ohne Interpretation.", size=8)
    save_page(pdf, fig, out, f"{page_number:02d}_pruefung", page_number)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    out = args.folder.resolve()
    plan = json.loads((out / "versuchsplan.json").read_text(encoding="utf-8"))
    runs = read_rows(out / "laufverzeichnis.csv")
    audits = verify_raw(out, runs[:args.limit] if args.limit else runs, plan)
    if args.check_only:
        print(f"Rohdatenprüfung bestanden: {len(audits)} Konfigurationen.")
        return
    completed = json.loads((out / "abschluss.json").read_text(encoding="utf-8"))
    assert completed["complete"]
    assert len(runs) == completed["uniqueRuns"]
    (out / "grafiken").mkdir(exist_ok=True)
    critical = read_rows(out / "grenzzugzahlen.csv")
    scan = read_rows(out / "grenzsuche.csv")
    target = out / "Verkehrsfluss_Untersuchungen.pdf"
    page_number = 1
    with PdfPages(target) as pdf:
        pdf.infodict().update(Title="S-Bahn S41: Verkehrsfluss-Untersuchungen",
                              Subject="Parameter und numerische Ergebnisse ohne Interpretation")
        parameter_page(pdf, out, plan, critical, page_number); page_number += 1
        page_number += critical_pages(pdf, out, plan, critical, scan, page_number)
        for mode in ["ohne_abbremsen", "mit_abbremsen"]:
            anticipation = mode == "mit_abbremsen"
            label = "mit langsamem Abbremsen" if anticipation else "ohne langsames Abbremsen"
            boundary = next(r for r in critical if yes(r, "anticipation") == anticipation)
            definitions = [
                ("zugzahl", "Zugzahlserie", "Anzahl der Züge", "Haltezuschlag 0 s · p = 0"),
                ("haltezeit", "Zusätzliche Stationshaltezeit", "Fester Haltezuschlag je Station [s]",
                 f"N = {int(num(boundary, 'critical_trains'))} (Grenzzugzahl) · p = 0"),
                ("stoerung", "Störungswahrscheinlichkeit", "Wahrscheinlichkeit p je Prüfung",
                 f"N = {int(num(boundary, 'probability_trains'))} (gerundet 60 % von N_grenz) · Zufallszusatz 0–120 s"),
            ]
            for prefix, title, xlabel, subtitle in definitions:
                rows = read_rows(out / f"{prefix}_{mode}.csv")
                expected = {"zugzahl": 8, "haltezeit": 6, "stoerung": 11}[prefix]
                assert len(rows) == expected
                series_page(pdf, out, rows, title, xlabel,
                            f"{label}\n{subtitle} · 60 min Einschwingen + 180 min Messung",
                            f"{page_number:02d}_{prefix}_{mode}", page_number)
                page_number += 1
        heat = read_rows(out / "heatmap.csv"); assert len(heat) == 56
        # Dieselbe physikalische Konfiguration muss in Kurve und Heatmap übereinstimmen.
        reference_rows = read_rows(out / "zugzahl_mit_abbremsen.csv")
        for row in reference_rows:
            same = next(r for r in heat if num(r, "train_count") == num(row, "train_count")
                        and abs(num(r, "effective_kmh") - 79.2) < 1e-8)
            np.testing.assert_allclose(num(same, "throughput_trains_per_h"),
                                       num(row, "throughput_trains_per_h"), equal_nan=True)
        heat_page(pdf, out, heat, page_number); page_number += 1
        status_page(pdf, out, runs, audits, page_number)
    (out / "README.md").write_text(
        "# Verkehrsfluss-Untersuchungen\n\n"
        "[PDF mit Parametern und Ergebnissen](Verkehrsfluss_Untersuchungen.pdf)\n\n"
        f"{len(runs)} Konfigurationen; {sum(yes(r, 'passed') for r in runs)} erfolgreich. "
        f"{page_number} PDF-Seiten. Rohdaten und Diagrammwerte liegen daneben.\n\n"
        "Wiederholen: `run_trafic_flow_studien` in MATLAB, danach "
        "`py tools/bericht_trafic_flow_studien.py <Ausgabeordner>`.\n", encoding="utf-8")
    shutil.copy2(Path(__file__), out / "quellstand" / Path(__file__).name)
    print(f"PDF erstellt: {target} ({page_number} Seiten)")


if __name__ == "__main__":
    main()
