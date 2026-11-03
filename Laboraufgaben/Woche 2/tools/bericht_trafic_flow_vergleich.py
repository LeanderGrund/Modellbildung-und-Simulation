"""Gemeinsame PDF: zwei alte und drei neue Heatmaps mit Rohdatenprüfung.

py tools/bericht_trafic_flow_vergleich.py <Ausgabeordner>
--plan-only erzeugt ausschließlich den klar gekennzeichneten Messplan mit
den beiden vorhandenen Vergleichs-Heatmaps; es erfindet keine neuen Messwerte.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
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

from bericht_neue_verkehrsstromuntersuchungen import read_case
from bericht_trafic_flow_studien import read_rows, num, yes, fmt, table

ROOT = Path(__file__).resolve().parents[1]
AXES = {"p": "Störungswahrscheinlichkeit p je Prüfung", "beta": "Antizipationsfaktor beta [1/s]",
        "dwell": "Fester Haltezeitzuschlag je Station [s]"}


def audit_case(case, spec):
    audits = []
    for row in case["rows"]:
        audit = {"case": spec["id"], "file": row["file"], "train_count": int(num(row, "train_count")),
                 "x_value": num(row, "x_value"), "departure_count": num(row, "departure_count"),
                 "throughput_trains_per_h": num(row, "throughput_trains_per_h")}
        if not yes(row, "passed"):
            assert spec["axis"] == "dwell" and row["failure"].startswith(("SBahn:NoSafeInitialPhase", "SBahn:InitialBlockOverlap"))
            audits.append({**audit, "status": "keine sichere Startbelegung", "passed": False})
            continue
        data = loadmat(case["folder"] / "laeufe" / row["file"], simplify_cells=True)
        g, p, metrics = data["G"], data["p"], data["metrics"]
        n = int(p["trainCount"]); config = p["config"]
        assert n == audit["train_count"]
        assert data["settings"]["warmupMinutes"] == 60 and data["settings"]["measurementMinutes"] == 180
        position = np.asarray(g["position"], dtype=np.int64).reshape(-1, n)
        velocity = np.asarray(g["velocity"], dtype=np.int64).reshape(-1, n)
        waiting = np.asarray(g["waitSteps"]).reshape(-1, n)
        blocked = np.asarray(g["blocked"], dtype=bool).reshape(-1, n)[1:]
        times = np.atleast_1d(g["timeSeconds"])
        selected = (times[:-1] >= 3600) & (times[:-1] < 14400)
        moving = (np.diff(position, axis=0) % p["cellCount"]) > 0
        station = np.atleast_1d(p["route"]["stationCells"])[0]
        count = int(np.count_nonzero(((position[:-1] == station) & moving)[selected]))
        np.testing.assert_equal(count, int(metrics["departureCount"]))
        np.testing.assert_equal(count, int(audit["departure_count"]))
        np.testing.assert_allclose(count / 3, metrics["throughputTrainsPerHour"], atol=1e-10)
        np.testing.assert_allclose(count / 3, num(row, "throughput_trains_per_h"), atol=1e-10)
        assert not np.any(blocked & (moving | (waiting[:-1] > 0)))
        assert np.max(np.abs(np.diff(velocity, axis=0))) <= 1
        assert data["report"]["checksPassed"]
        assert config["cruiseSpeedKmh"] == 80 and config["randomSeed"] == 42
        assert config["durationMinutes"] == 240
        assert config["randomBrakeEnabled"] and config["randomStopEnabled"]
        np.testing.assert_allclose(p["driveSpeedKmh"], 79.2, atol=1e-10)
        assert bool(config["anticipationEnabled"]) == spec["anticipation"]
        x = num(row, "x_value")
        probability = x if spec["axis"] == "p" else spec["fixedP"]
        beta = x if spec["axis"] == "beta" else spec["fixedBeta"]
        extra = x if spec["axis"] == "dwell" else 0
        np.testing.assert_allclose(config["randomStopProbability"], probability, atol=1e-12)
        np.testing.assert_allclose(config["randomBrakeProbability"], probability, atol=1e-12)
        np.testing.assert_allclose(config["anticipationBeta"], beta, atol=1e-12)
        assert config["dwellOffsetSeconds"] == extra
        np.testing.assert_array_equal(np.atleast_1d(p["stationDwellSeconds"]),
                                      np.atleast_1d(p["baseStationDwellSeconds"]) + extra)
        assert config["randomStopMinSeconds"] == 0 and config["randomStopMaxSeconds"] == 120
        if "reuse_source" in data:
            original = loadmat(str(data["reuse_source"]), simplify_cells=True)
            for name in ["position", "velocity", "blocked", "waitSteps"]:
                np.testing.assert_array_equal(g[name], original["G"][name])
        audits.append({**audit, "status": "aus Rohdaten geprüft", "passed": True})
    print(f"Geprüft: {spec['id']} ({len(audits)} Punkte)", flush=True)
    return audits


def new_page(title, subtitle="", landscape=True):
    fig = plt.figure(figsize=(11.69, 8.27) if landscape else (8.27, 11.69), facecolor="white")
    fig.text(.07, .95, title, fontsize=17, color="#173f55", weight="bold", va="top")
    fig.text(.07, .90, subtitle, fontsize=9, va="top", linespacing=1.45)
    return fig


def save_page(pdf, fig, out, number, name):
    fig.text(.07, .03, "S-Bahn S41 · Parameter und Durchsatzwerte · ohne Ergebnisinterpretation", fontsize=7, color="#596773")
    fig.text(.93, .03, str(number), ha="right", fontsize=8)
    pdf.savefig(fig)
    fig.savefig(out / f"{number:02d}_{name}.png", dpi=160)
    fig.savefig(out / f"{number:02d}_{name}.pdf")
    plt.close(fig)


def fixed_text(spec):
    if not spec["anticipation"]:
        return "Langsames Abbremsen aus; beta-Eingabe 0,25 1/s ohne Wirkung; p je Spalte"
    if spec["axis"] == "p":
        return "Langsames Abbremsen an; beta = 0,20 1/s; p je Spalte"
    if spec["axis"] == "beta":
        return f"Langsames Abbremsen an; p = {fmt(spec['fixedP'], 1)}; beta je Spalte"
    return "Langsames Abbremsen an; p = 0,3; beta = 0,20 1/s; Haltezuschlag je Spalte"


def parameters(pdf, out, plan, number, pending):
    subtitle = "MESSPLAN: Die drei neuen Messreihen sind noch nicht ausgeführt (MATLAB-Lizenzfehler 15)." if pending else "Fünf Heatmaps mit gemeinsamen Parametern, Rohdatenprüfung und Wertetabellen"
    fig = new_page("Verkehrsstrom: Vergleich und Wiederholungen", subtitle, landscape=False)
    common = [
        ["Strecke / Darstellung", "Reale Ringbahn S41 / geografischer Verlauf"],
        ["Fahrmodell / Raster / Zuglänge", "Beschleunigen und Bremsen; 1 m / 1 s; 148 m"],
        ["Beschleunigungsgrenze", "höchstens ±1 m/s²"],
        ["Blocksteuerung", "117 OSM-Signalabschnitte; Zielabstand 500 m ohne Wirkung"],
        ["Stationshalte", "GTFS-Stationshalte; fester Zuschlag nur in Halteheatmap"],
        ["Maximalgeschwindigkeit", "80 km/h Eingabe / 79,2 km/h effektiv in allen Läufen"],
        ["Einschwingen / Messdauer", "60 min / 180 min; Gesamtdauer je Lauf 240 min"],
        ["Zufallsstartwert / Wiederholungen", "42 / ein Lauf je physikalischer Konfiguration"],
        ["Zugzahlen (y)", "12, 16, 20, 24, 28, 32, 36, 40"],
        ["p-Bereich (x)", "0; 0,1; …; 1 (11 Werte)"],
        ["beta-Bereich (x)", "0,05; 0,10; …; 0,50 1/s (10 Werte)"],
        ["Haltezuschläge (x)", "0, 6, 12, 18, 24, 30 s zusätzlich je Station (6 Werte)"],
        ["Störungsarten mit demselben p", "Zufallsbremsung je Blockeinfahrt; Zusatzhalt je Ankunft"],
        ["Zufallsbremsung", "−1 m/s² bis floor(v_Eintritt/2), danach wieder beschleunigen"],
        ["Zufälliger Stationszusatz", "diskrete Gleichverteilung U{0,…,120} s zusätzlich zum Sollhalt"],
        ["Antizipationsregel", "a = beta · (v_Vorgänger − v_Zug), bei langsamerem Vorgänger"],
    ]
    table(fig.add_axes([.07, .49, .86, .36]), common, ["Parameter", "Wert"], widths=[.35, .65], font=7.3, scale=1.48)
    cases = [
        ["1", "Zugzahl × p, bisher", "Antizipation aus", "88"],
        ["2", "Zugzahl × p, Wiederholung", "beta = 0,20 1/s, Antizipation an", "88"],
        ["3", "Zugzahl × beta, bisher", "p = 0, Antizipation an", "80"],
        ["4", "Zugzahl × beta, Wiederholung", "p = 0,3, Antizipation an", "80"],
        ["5", "Zugzahl × Haltezuschlag, neu", "p = 0,3; beta = 0,20 1/s, Antizipation an", "48"],
    ]
    table(fig.add_axes([.07, .27, .86, .16]), cases, ["Nr.", "Heatmap", "Feste Parameter", "Punkte"],
          widths=[.06, .34, .50, .10], font=7, scale=1.5)
    notes = ("Durchsatz: Abfahrten an Station 1 im halboffenen Messfenster [3600,14400) s, geteilt durch drei Stunden. "
             "Die 168 bisherigen Messpunkte werden unverändert aus dem vorigen Bericht übernommen. "
             "Acht Konfigurationen erscheinen jeweils in allen drei neuen Heatmaps. "
             "Für die 216 neuen Diagrammpunkte werden deshalb 200 Konfigurationen berechnet.")
    fig.text(.07, .18, "\n".join(textwrap.wrap(notes, 105)), va="top", fontsize=8, linespacing=1.45)
    if pending:
        note = "Diese Vorab-PDF zeigt nur die beiden bereits vorhandenen Heatmaps. Neue Messwerte werden erst nach wiederhergestellter MATLAB-Lizenzverbindung ergänzt."
    else:
        note = "Alle dargestellten Durchsätze werden aus den gespeicherten Zugpositionen erneut nachgezählt. Gemeinsame Punkte werden auf identische Konfiguration und Messfenster geprüft."
    fig.text(.07, .085, "\n".join(textwrap.wrap(note, 105)), va="top", fontsize=8, linespacing=1.4)
    save_page(pdf, fig, out, number, "parameter")


def heatmap(pdf, out, case, spec, qmax, number):
    fig = new_page(spec["title"], fixed_text(spec) + "\n80 km/h Eingabe / 79,2 km/h effektiv; 60 min Einschwingen + 180 min Messung")
    ax = fig.add_axes([.10, .20, .76, .60])
    colors = plt.get_cmap("viridis").copy(); colors.set_bad("#d5d5d5")
    artist = ax.imshow(case["matrix"], origin="lower", aspect="auto", vmin=0, vmax=qmax, cmap=colors)
    digits = {"p": 1, "beta": 2, "dwell": 0}[spec["axis"]]
    ax.set_xticks(range(len(case["x"])), [fmt(x, digits) for x in case["x"]])
    ax.set_yticks(range(len(case["trains"])), case["trains"])
    ax.set_xlabel(AXES[spec["axis"]]); ax.set_ylabel("Anzahl der Züge"); ax.grid(False)
    for i in range(len(case["trains"])):
        for j in range(len(case["x"])):
            ax.text(j, i, fmt(case["matrix"][i, j]), ha="center", va="center", fontsize=8,
                    bbox={"facecolor": "white", "edgecolor": "none", "alpha": .85, "pad": 1})
    bar = fig.colorbar(artist, cax=fig.add_axes([.88, .20, .025, .60]))
    bar.set_label("Durchschnittlicher Durchsatz [Züge/h]", fontsize=9)
    note = f"Quelle: {spec['origin']}. Farbwert und Zahlen: Durchsatz [Züge/h]. Gemeinsame Farbskala der dargestellten Heatmaps."
    fig.text(.10, .10, note, fontsize=8)
    np.testing.assert_array_equal(np.asarray(artist.get_array()), case["matrix"])
    save_page(pdf, fig, out, number, spec["id"])


def values(pdf, out, case, spec, number):
    fig = new_page("Wertetabelle: " + spec["title"], "Alle Durchsätze in Zügen/h. " + fixed_text(spec))
    digits = {"p": 1, "beta": 2, "dwell": 0}[spec["axis"]]
    headers = ["Züge"] + [fmt(x, digits) for x in case["x"]]
    cells = [[str(n)] + [fmt(x) for x in case["matrix"][i]] for i, n in enumerate(case["trains"])]
    table(fig.add_axes([.07, .40, .86, .42]), cells, headers, font=8.5, scale=1.8)
    details = ["80 km/h Eingabe / 79,2 km/h effektiv. Zufallsstartwert 42; ein Lauf je Konfiguration.",
               "60 min Einschwingen und 180 min Messung. Reale S41, OSM-Signalabschnitte, GTFS-Stationshalte."]
    if spec["axis"] == "dwell":
        details.append("Der x-Wert ist ein fester Zuschlag auf jeden GTFS-Stationshalt; zufällige Zusatzhalte kommen unabhängig hinzu.")
    else:
        details.append("Fester Haltezeitzuschlag: 0 s. Zufälliger Stationszusatz bei Treffer: gleichverteilt 0 bis 120 s.")
    failed = [r for r in case["rows"] if not yes(r, "passed")]
    if failed:
        details.append("n. v.: keine sichere Startbelegung. Betroffene Punkte: " + "; ".join(
            f"N={int(num(r,'train_count'))}, x={fmt(num(r,'x_value'),digits)}" for r in failed))
    for index, text in enumerate(details):
        fig.text(.07, .30-index*.055, text, fontsize=8.2)
    save_page(pdf, fig, out, number, "tabelle_"+spec["id"])


def verify_intersections(cases, specs):
    by_id = {s["id"]: c for s, c in zip(specs, cases)}
    if not {"p_beta020", "beta_p030", "halte_p030_beta020"}.issubset(by_id): return
    a, b, c = [by_id[k] for k in ["p_beta020", "beta_p030", "halte_p030_beta020"]]
    j = np.flatnonzero(np.isclose(a["x"], .3))[0]
    k = np.flatnonzero(np.isclose(b["x"], .2))[0]
    np.testing.assert_array_equal(a["matrix"][:,j], b["matrix"][:,k])
    np.testing.assert_array_equal(a["matrix"][:,j], c["matrix"][:,0])
    # p=0,beta=0,20 wurde neu gerechnet und muss zur bisherigen beta-Reihe passen.
    original = by_id["beta_bisher"]
    k0 = np.flatnonzero(np.isclose(original["x"], .2))[0]
    np.testing.assert_array_equal(a["matrix"][:,0], original["matrix"][:,k0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path); parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(); out = args.folder.resolve()
    plan = json.loads((out / "versuchsplan.json").read_text(encoding="utf-8"))
    def hashes(folder):
        return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in folder.rglob("*.m")}
    current = hashes(ROOT / "modell" / "+sbahn2")
    baseline = Path(plan["cases"][0]["folder"]).parent / "quellstand" / "+sbahn2"
    assert current and current == hashes(baseline), "Modellkern weicht von den bisherigen Messungen ab"
    manifest = out / "modell_hashes.json"
    if manifest.is_file():
        for name, digest in json.loads(manifest.read_text(encoding="utf-8")).items():
            assert hashlib.sha256((ROOT / "modell" / name).read_bytes()).hexdigest() == digest
    else:
        manifest.write_text(json.dumps({str(Path('+sbahn2') / name): digest for name, digest in current.items()},
                                       indent=2), encoding="utf-8")
    specs = plan["cases"]
    if args.plan_only:
        specs = [s for s in specs if s["origin"] == "vorhandene Messung"]
    else:
        assert json.loads((out / "abschluss.json").read_text(encoding="utf-8"))["complete"]
        assert current == hashes(out / "quellstand" / "+sbahn2")
    cases = [read_case(Path(s["folder"])) for s in specs]
    audits = []
    for case, spec in zip(cases, specs):
        expected_columns = {"p": 11, "beta": 10, "dwell": 6}[spec["axis"]]
        assert case["matrix"].shape == (8, expected_columns)
        audits.extend(audit_case(case, spec))
    verify_intersections(cases, specs)
    audit_name = "rohdatenaudit_bisher.csv" if args.plan_only else "rohdatenaudit.csv"
    with (out / audit_name).open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(audits[0])); writer.writeheader(); writer.writerows(audits)
    figure_folder = out / ("messplan_grafiken" if args.plan_only else "pdf_grafiken")
    figure_folder.mkdir(exist_ok=True)
    target = out / ("Messplan_und_bisherige_Heatmaps.pdf" if args.plan_only else "Verkehrsstrom_Gesamtvergleich.pdf")
    qmax = np.ceil(max(np.nanmax(c["matrix"]) if np.isfinite(c["matrix"]).any() else 0 for c in cases))
    number = 1
    with PdfPages(target) as pdf:
        parameters(pdf, figure_folder, plan, number, args.plan_only); number += 1
        for case, spec in zip(cases, specs):
            heatmap(pdf, figure_folder, case, spec, qmax, number); number += 1
        if not args.plan_only:
            for case, spec in zip(cases, specs):
                values(pdf, figure_folder, case, spec, number); number += 1
    content = target.read_bytes()
    assert content.startswith(b"%PDF-") and content.rstrip().endswith(b"%%EOF")
    assert len(re.findall(rb"/Type\s*/Page\b", content)) == number-1
    shutil.copy2(__file__, out / Path(__file__).name)
    print(f"PDF erstellt: {target} ({number-1} Seiten)")


if __name__ == "__main__":
    main()
