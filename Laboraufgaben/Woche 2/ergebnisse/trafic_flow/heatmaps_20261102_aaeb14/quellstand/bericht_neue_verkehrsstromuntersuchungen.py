"""PDF und unabhängige Rohdatenprüfung für die p- und beta-Heatmaps.

py tools/bericht_neue_verkehrsstromuntersuchungen.py <Testordner>
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime
import json
from pathlib import Path
import re
import shutil
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
from scipy.io import loadmat

from bericht_trafic_flow_studien import read_rows, num, yes, fmt, table


def read_case(folder):
    result = loadmat(folder / "ergebnis.mat", simplify_cells=True)["result"]
    rows = read_rows(folder / "verkehrsstrom.csv")
    x = np.atleast_1d(result["xValues"]).astype(float)
    trains = np.atleast_1d(result["trainCounts"]).astype(int)
    matrix = np.asarray(result["throughput"], dtype=float).reshape(len(trains), len(x))
    assert len(rows) == matrix.size
    reproduced = np.full(matrix.shape, np.nan)
    seen = np.zeros(matrix.shape, dtype=int)
    for row in rows:
        i = np.flatnonzero(trains == num(row, "train_count"))[0]
        j = np.flatnonzero(np.isclose(x, num(row, "x_value"), atol=1e-12))[0]
        reproduced[i, j] = num(row, "throughput_trains_per_h")
        seen[i, j] += 1
    assert np.all(seen == 1)
    # CSV rundet die letzte Dezimalstelle; die MAT-Matrix bleibt die Zeichenquelle.
    np.testing.assert_allclose(matrix, reproduced, rtol=0, atol=1e-12)
    return {"folder": folder, "result": result, "rows": rows, "x": x,
            "trains": trains, "matrix": matrix}


def verify_case(case, probability_mode):
    audits = []
    for index, row in enumerate(case["rows"], 1):
        assert yes(row, "passed"), row["failure"]
        data = loadmat(case["folder"] / "laeufe" / row["file"], simplify_cells=True)
        p, g, metrics = data["p"], data["G"], data["metrics"]
        n = int(p["trainCount"])
        position = np.asarray(g["position"], dtype=np.int64).reshape(-1, n)
        velocity = np.asarray(g["velocity"], dtype=np.int64).reshape(-1, n)
        wait = np.asarray(g["waitSteps"]).reshape(-1, n)
        blocked = np.asarray(g["blocked"], dtype=bool).reshape(-1, n)[1:]
        time = np.atleast_1d(g["timeSeconds"])
        selected = (time[:-1] >= 3600) & (time[:-1] < 14400)
        station = np.atleast_1d(p["route"]["stationCells"])[0]
        moved = (np.diff(position, axis=0) % p["cellCount"]) > 0
        count = int(np.count_nonzero(((position[:-1] == station) & moved)[selected]))
        np.testing.assert_equal(count, int(metrics["departureCount"]))
        np.testing.assert_equal(count, int(num(row, "departure_count")))
        np.testing.assert_allclose(count / 3, num(row, "throughput_trains_per_h"), atol=1e-10)
        assert not np.any(blocked & (moved | (wait[:-1] > 0)))
        assert np.max(np.abs(np.diff(velocity, axis=0))) <= 1
        config = p["config"]
        assert config["cruiseSpeedKmh"] == 80
        np.testing.assert_allclose(p["driveSpeedKmh"], 79.2, atol=1e-10)
        np.testing.assert_allclose(num(row, "effective_kmh"), 79.2, atol=1e-10)
        assert config["dwellOffsetSeconds"] == 0
        assert config["durationMinutes"] == 240 and config["randomSeed"] == 42
        assert config["randomStopMinSeconds"] == 0 and config["randomStopMaxSeconds"] == 120
        assert bool(config["anticipationEnabled"]) == (not probability_mode)
        if probability_mode:
            np.testing.assert_allclose(config["randomStopProbability"], num(row, "x_value"), atol=1e-12)
            np.testing.assert_allclose(config["randomBrakeProbability"], num(row, "x_value"), atol=1e-12)
            assert config["anticipationBeta"] == 0.25
        else:
            np.testing.assert_allclose(config["anticipationBeta"], num(row, "x_value"), atol=1e-12)
            assert config["randomStopProbability"] == 0 and config["randomBrakeProbability"] == 0
        assert data["report"]["checksPassed"]
        audits.append({"axis": "p" if probability_mode else "beta", "file": row["file"],
                       "train_count": n, "x": num(row, "x_value"),
                       "departure_count": count, "throughput_trains_per_h": count / 3, "passed": True})
        if index % 20 == 0:
            print(f"Rohdaten {'p' if probability_mode else 'beta'}: {index}/{len(case['rows'])}", flush=True)
    return audits


def verify_previous_reference(out, probability, beta):
    old = out.parent / "studie_20261101_150306"
    if not old.is_dir():
        return 0
    comparisons = 0
    for case, filename, x in [(probability, "zugzahl_ohne_abbremsen.csv", 0),
                              (beta, "zugzahl_mit_abbremsen.csv", 0.25)]:
        old_rows = read_rows(old / filename)
        for row in old_rows:
            n = int(num(row, "train_count"))
            current = next(r for r in case["rows"] if int(num(r, "train_count")) == n
                           and abs(num(r, "x_value") - x) < 1e-10)
            np.testing.assert_allclose(num(current, "throughput_trains_per_h"),
                                       num(row, "throughput_trains_per_h"), atol=1e-10)
            comparisons += 1
    return comparisons


def new_page(title, subtitle="", landscape=False):
    fig = plt.figure(figsize=(11.69, 8.27) if landscape else (8.27, 11.69), facecolor="white")
    fig.text(.07, .95, title, fontsize=18, weight="bold", color="#173f55", va="top")
    if subtitle:
        fig.text(.07, .90, subtitle, fontsize=9, va="top", linespacing=1.5)
    return fig


def paragraph(fig, y, text, width=105, size=8.5):
    fig.text(.07, y, "\n".join(textwrap.wrap(text, width)), va="top", fontsize=size, linespacing=1.5)


def save_page(pdf, fig, out, name, page):
    fig.text(.07, .03, "S-Bahn S41 · Verkehrsstromuntersuchungen bei 80 km/h Eingabe", fontsize=7, color="#596773")
    fig.text(.93, .03, str(page), fontsize=8, ha="right")
    fig.canvas.draw()
    pdf.savefig(fig)
    fig.savefig(out / "pdf_grafiken" / f"{page:02d}_{name}.png", dpi=160)
    fig.savefig(out / "pdf_grafiken" / f"{page:02d}_{name}.pdf")
    plt.close(fig)


def parameter_page(pdf, out, cases, model_tests, audit_count, references):
    fig = new_page("Neue Verkehrsstromuntersuchungen", "Verwendete Parameter und Testumfang")
    rows = [
        ["Strecke / Darstellung", "Reale Ringbahn S41 / geografischer Verlauf"],
        ["Fahrmodell", "Beschleunigen und Bremsen, höchstens ±1 m/s²"],
        ["Raster / Zuglänge", "1 m / 1 s; 148 m"],
        ["Blocksteuerung", "117 OSM-Signalabschnitte; Zielabstand 500 m ohne Wirkung"],
        ["Stationshalte", "GTFS-Stationshalte; kein fester Haltezuschlag"],
        ["Maximalgeschwindigkeit", "80 km/h eingegeben; 79,2 km/h effektiv, in allen Läufen"],
        ["Einschwingzeit / Messdauer", "60 min / 180 min; Gesamtdauer je Lauf 240 min"],
        ["Durchsatzmessung", "Abfahrten an Station 1 im Fenster [3600,14400) s / 3 h"],
        ["Zufallsstartwert / Wiederholungen", "42 / ein Lauf je Kombination"],
        ["Gemeinsame Zugzahlen (y)", "12, 16, 20, 24, 28, 32, 36, 40"],
        ["p-Untersuchung (x)", "0, 0,1, …, 1; 8 × 11 = 88 Läufe"],
        ["Langsames Abbremsen bei p", "aus; beta-Einzelwert 0,25 1/s ohne Wirkung"],
        ["Zufällige Bremsung", "Prüfung je Blockeinfahrt mit p; Ziel floor(v_Eintritt/2)"],
        ["Bremsablauf", "−1 m/s² bis zum Ziel, danach Wiederbeschleunigen soweit möglich"],
        ["Zufälliger Stationszusatz", "Prüfung je Ankunft mit demselben p; Dauer U{0,…,120} s"],
        ["beta-Untersuchung (x)", "0,05; 0,10; …; 0,50 1/s; 8 × 10 = 80 Läufe"],
        ["Langsames Abbremsen bei beta", "automatisch an; p bleibt fest 0"],
        ["Antizipationsregel", "a = beta · (v_Vorgänger − v_Zug), bei langsamerem Vorgänger"],
        ["Bildpause / Bildabstand", "0,05 s / 10 Schritte; Animation im Batch ausgeschaltet"],
    ]
    table(fig.add_axes([.07, .39, .86, .46]), rows, ["Parameter", "Wert"],
          widths=[.35, .65], font=7.5, scale=1.6)
    paragraph(fig, .34, "Das Live Script bietet eine Auswahl für die x-Achse und getrennte Minimum-, "
              "Maximum- und Schrittweitenfelder für p und beta. Die y-Achse ist stets die Zugzahl. "
              "Die bisherige Geschwindigkeitsuntersuchung und der Einzellauf bleiben verfügbar.")
    paragraph(fig, .24, f"Prüfung: {model_tests} vorhandene Modelltests sowie Einzellauf und bisherige "
              f"Geschwindigkeitsheatmap bestanden. Alle {audit_count} neuen Simulationen wurden über "
              "das von MATLAB aus dem ausgelieferten Live Script exportierte Programm ausgeführt.")
    paragraph(fig, .14, f"Durchsätze wurden unabhängig aus den gespeicherten Positionen nachgezählt. "
              f"{references} passende Betriebspunkte stimmen mit der vorherigen Versuchsreihe überein. "
              "Vier zusätzliche kurze Konfigurationen liefern in sequentieller und paralleler Ausführung "
              "bitgleiche Trajektorien und Ereignisse. Berechnung in vier lokalen MATLAB-Sitzungen.", size=8)
    paragraph(fig, .075, "Die folgenden Seiten enthalten die beiden Heatmaps und vollständige Wertetabellen "
              "ohne Ergebnisinterpretation.", size=8)
    save_page(pdf, fig, out, "parameter", 1)


def heatmap_page(pdf, out, case, probability_mode, qmax, page):
    label = "Störungswahrscheinlichkeit p" if probability_mode else "Antizipationsfaktor beta"
    fixed = "Langsames Abbremsen aus; p je Spalte" if probability_mode else "Langsames Abbremsen an; p = 0"
    fig = new_page(f"Zugzahl und {label}",
                   f"80 km/h Eingabe, 79,2 km/h effektiv · {fixed}\n"
                   "60 min Einschwingen + 180 min Messung · Zufallsstartwert 42", landscape=True)
    ax = fig.add_axes([.10, .20, .76, .60])
    cmap = plt.get_cmap("viridis").copy(); cmap.set_bad("#d5d5d5")
    chart = ax.imshow(case["matrix"], origin="lower", aspect="auto", cmap=cmap, vmin=0, vmax=qmax)
    ax.set_xticks(range(len(case["x"])), [fmt(x, 1 if probability_mode else 2) for x in case["x"]])
    ax.set_yticks(range(len(case["trains"])), case["trains"])
    ax.set_xlabel("Störungswahrscheinlichkeit p je Prüfung" if probability_mode else "Antizipationsfaktor beta [1/s]")
    ax.set_ylabel("Anzahl der Züge"); ax.grid(False)
    for i in range(case["matrix"].shape[0]):
        for j in range(case["matrix"].shape[1]):
            ax.text(j, i, fmt(case["matrix"][i, j]), ha="center", va="center", fontsize=8,
                    bbox={"facecolor": "white", "edgecolor": "none", "alpha": .85, "pad": 1})
    cb = fig.colorbar(chart, cax=fig.add_axes([.88, .20, .025, .60]))
    cb.set_label("Durchschnittlicher Durchsatz [Züge/h]", fontsize=9)
    fig.text(.10, .10, "Farbwert und Zahlen: Durchsatz [Züge/h]. Beide Heatmaps verwenden dieselbe Farbskala.", fontsize=8)
    np.testing.assert_array_equal(np.asarray(chart.get_array()), case["matrix"])
    save_page(pdf, fig, out, "heatmap_p" if probability_mode else "heatmap_beta", page)


def values_page(pdf, out, case, probability_mode, page):
    label = "p" if probability_mode else "beta [1/s]"
    fig = new_page(f"Wertetabelle: Zugzahl und {label}",
                   "Alle Durchsätze in Zügen/h. Zeilen: Zugzahl; Spalten: ausgewählter x-Wert.", landscape=True)
    headers = ["Züge"] + [fmt(x, 1 if probability_mode else 2) for x in case["x"]]
    rows = [[str(n)] + [fmt(value) for value in case["matrix"][i]] for i, n in enumerate(case["trains"])]
    table(fig.add_axes([.07, .40, .86, .42]), rows, headers, font=8.5, scale=1.8)
    p = case["result"]["settings"]
    fig.text(.07, .34, "Feste Parameter dieses Versuchs:", fontsize=10, weight="bold")
    details = ["Maximalgeschwindigkeit: 80 km/h Eingabe, 79,2 km/h effektiv.",
               "Einschwingen: 60 min; Messdauer: 180 min; ein Lauf je Kombination; Zufallsstartwert: 42.",
               "GTFS-Stationshalte, fester Haltezuschlag: 0 s; OSM-Signalabschnitte."]
    if probability_mode:
        details.append("Langsames Abbremsen: aus. Zufälliger Stationszusatz: 0 bis 120 s. Beide Störungen verwenden p der jeweiligen Spalte.")
    else:
        details.append("Langsames Abbremsen: automatisch an. Beide Zufallsstörungen ausgeschaltet (p = 0). beta wird je Spalte gesetzt.")
    for index, text in enumerate(details):
        fig.text(.07, .29 - index * .045, text, fontsize=8.5)
    save_page(pdf, fig, out, "tabelle_p" if probability_mode else "tabelle_beta", page)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args(); out = args.folder.resolve()
    completion = json.loads((out / "abschluss.json").read_text(encoding="utf-8"))
    assert completion["complete"]
    assert completion["parallelEquivalencePassed"] and completion["legacyAxisRechecked"]
    probability = read_case(out / "zugzahl_p")
    beta = read_case(out / "zugzahl_beta")
    assert probability["matrix"].shape == (8, 11) and beta["matrix"].shape == (8, 10)
    audits = verify_case(probability, True) + verify_case(beta, False)
    assert len(audits) == 168
    with (out / "rohdatenaudit.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(audits[0]))
        writer.writeheader(); writer.writerows(audits)
    references = verify_previous_reference(out, probability, beta)
    if args.check_only:
        print(f"168 Rohdatensätze und {references} Referenzpunkte erfolgreich geprüft.")
        return
    model_rows = read_rows(out / "regression" / "modelltests.csv")
    assert all(yes(row, "Passed") and not yes(row, "Failed") for row in model_rows)
    old_cases = read_rows(out / "regression" / "testfaelle.csv")
    assert len(old_cases) == 2 and all(yes(row, "passed") for row in old_cases)
    (out / "pdf_grafiken").mkdir(exist_ok=True)
    target = out / "Verkehrsstrom_p_und_beta.pdf"
    qmax = np.ceil(max(np.nanmax(probability["matrix"]), np.nanmax(beta["matrix"])))
    with PdfPages(target) as pdf:
        pdf.infodict().update(Title="S-Bahn: Zugzahl über Störungswahrscheinlichkeit und beta",
                              Subject="Parameter und geprüfte Ergebnisse bei 80 km/h Eingabe")
        parameter_page(pdf, out, [probability, beta], len(model_rows), len(audits), references)
        heatmap_page(pdf, out, probability, True, qmax, 2)
        heatmap_page(pdf, out, beta, False, qmax, 3)
        values_page(pdf, out, probability, True, 4)
        values_page(pdf, out, beta, False, 5)
    raw = target.read_bytes()
    assert raw.startswith(b"%PDF-") and raw.rstrip().endswith(b"%%EOF")
    assert len(re.findall(rb"/Type\s*/Page\b", raw)) == 5
    (out / "README.md").write_text(
        "# Neue Verkehrsstromuntersuchungen\n\n"
        "[PDF: Zugzahl, Störungswahrscheinlichkeit und beta](Verkehrsstrom_p_und_beta.pdf)\n\n"
        "88 p-Läufe und 80 beta-Läufe bei 80 km/h Eingabe / 79,2 km/h effektiv. "
        f"Alle 168 Rohdatensätze und {references} alte Referenzpunkte geprüft.\n\n"
        f"{len(model_rows)} Modelltests sowie Einzellauf und Geschwindigkeitsheatmap bestanden.\n\n"
        "Vier kurze Konfigurationen sind sequentiell und parallel bitgleich. "
        "Die 168 Hauptläufe wurden mit vier lokalen MATLAB-Basissitzungen berechnet "
        "bzw. nach Prüfung identischer Konfigurationen aus dem begonnenen Lauf übernommen.\n\n"
        "Die Unterordner zugzahl_p/ und zugzahl_beta/ enthalten Eingaben, CSV, "
        "vollständige MAT-Rohdaten sowie jeweils eine Heatmap als PNG und FIG. "
        "pdf_grafiken/ enthält alle fünf PDF-Seiten als PNG und einzelne PDFs.\n", encoding="utf-8")
    shutil.copy2(__file__, out / "quellstand" / Path(__file__).name)
    print(f"PDF erstellt: {target} (5 Seiten).")


if __name__ == "__main__":
    main()
