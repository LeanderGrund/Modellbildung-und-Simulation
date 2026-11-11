"""PDF und unabhängige Rohdatenprüfung der Woche-3-Beta-Untersuchung."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import re
import textwrap

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parent
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9,
                     "pdf.fonttype": 42, "axes.spines.top": False,
                     "axes.spines.right": False})


def fmt(value, digits=2):
    return f"{float(value):.{digits}f}".replace(".", ",")


def read_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def audit(folder, rows, plan):
    records = []
    reference = None
    for row in rows:
        raw = loadmat(folder / "laeufe" / row["file"], simplify_cells=True)
        p, g, metrics, config = raw["p"], raw["G"], raw["metrics"], raw["p"]["config"]
        assert raw["report"]["checksPassed"] and row["passed"] in {"1", "true"}
        n = int(p["trainCount"]); beta = float(row["beta"])
        assert n == 28 and config["trainCount"] == 28
        assert config["anticipationEnabled"] and config["anticipationMaxBlocks"] == 2
        np.testing.assert_allclose(config["anticipationBeta"], beta, atol=1e-12)
        assert config["randomBrakeEnabled"] and config["randomStopEnabled"]
        assert config["randomBrakeProbability"] == .2 and config["randomStopProbability"] == .2
        assert config["randomStopMinSeconds"] == 0 and config["randomStopMaxSeconds"] == 120
        assert config["randomSeed"] == 42 and config["dwellOffsetSeconds"] == 0
        assert config["durationMinutes"] == 240 and config["cruiseSpeedKmh"] == 80
        assert raw["plan"]["warmupMinutes"] == 60 and raw["plan"]["measurementMinutes"] == 180
        assert p["trainCells"] == 148 and p["stepSeconds"] == 1 and p["dxMeters"] == 1
        np.testing.assert_allclose(p["driveSpeedKmh"], 79.2, atol=1e-10)
        np.testing.assert_array_equal(p["stationDwellSeconds"], p["baseStationDwellSeconds"])
        position = np.asarray(g["position"], dtype=np.int64).reshape(-1, n)
        velocity = np.asarray(g["velocity"], dtype=np.int64).reshape(-1, n)
        waiting = np.asarray(g["waitSteps"]).reshape(-1, n)
        blocked = np.asarray(g["blocked"], dtype=bool).reshape(-1, n)[1:]
        times = np.asarray(g["timeSeconds"])
        assert position.shape == (14401, 28)
        selected = (times[:-1] >= 3600) & (times[:-1] < 14400)
        moved = (np.diff(position, axis=0) % int(p["cellCount"])) > 0
        station = np.atleast_1d(p["route"]["stationCells"])[0]
        count = int(np.count_nonzero(((position[:-1] == station) & moved)[selected]))
        assert count == int(metrics["departureCount"]) == int(float(row["departure_count"]))
        np.testing.assert_allclose(count / 3, float(row["throughput_trains_per_h"]), atol=1e-10)
        np.testing.assert_allclose(count / 3, metrics["throughputTrainsPerHour"], atol=1e-10)
        assert not np.any(blocked & (moved | (waiting[:-1] > 0)))
        assert np.max(np.abs(np.diff(velocity, axis=0))) <= 1

        # Unabhängige Rekonstruktion des Vorgängers, seines Zugendes und des
        # Blockabstands für jeden Zug und jeden Zeitschritt, einschließlich Ring.
        order = np.argsort(position[:-1], axis=1)
        leader = np.empty_like(order)
        np.put_along_axis(leader, order, np.roll(order, -1, axis=1), axis=1)
        front = np.take_along_axis(position[:-1], leader, axis=1)
        rear = (front - int(p["trainCells"])) % int(p["cellCount"]) + 1
        block_map = np.asarray(p["blocks"]["cellBlock"], dtype=np.int64)
        own_block = block_map[position[:-1] - 1]
        rear_block = block_map[rear - 1]
        ahead = (rear_block - own_block) % len(np.atleast_1d(p["blocks"]["startCells"]))
        leader_speed = np.take_along_axis(velocity[:-1], leader, axis=1)
        eligible = ((leader_speed < velocity[:-1]) & (waiting[:-1] == 0)
                    & (ahead >= 1) & (ahead <= 2) & (beta > 0))
        actual_eligible = np.asarray(g["anticipationEligible"], dtype=bool).reshape(-1, n)[1:]
        applied = np.asarray(g["anticipationApplied"], dtype=bool).reshape(-1, n)[1:]
        np.testing.assert_array_equal(actual_eligible, eligible)
        remainder = np.zeros(n)
        for k in range(len(eligible)):
            increment = np.minimum(1, beta * (velocity[k] - leader_speed[k]))
            remainder = np.where(eligible[k], remainder + increment, 0)
            decrement = np.minimum(1, np.floor(remainder + 1e-12))
            remainder -= decrement
            np.testing.assert_array_equal(applied[k], eligible[k] & (decrement > 0))
            cap = np.maximum(0, velocity[k] - decrement)
            assert np.all(velocity[k+1][eligible[k]] <= cap[eligible[k]])
        if beta == 0:
            assert not np.any(applied) and not np.any(eligible)
        records.append({"beta": beta, "file": row["file"], "departure_count": count,
                        "throughput_trains_per_h": count / 3, "verified": True,
                        "eligible_train_s_measurement": int(np.count_nonzero(eligible[selected])),
                        "anticipation_decrements_measurement": int(np.count_nonzero(applied[selected]))})
        if abs(beta - plan["representativeBeta"]) < 1e-12:
            reference = raw
        print(f"Rohdaten geprüft: beta={beta:.2f}; {count} Abfahrten", flush=True)
    assert reference is not None
    return records, reference


def page(title, subtitle="", portrait=False):
    fig = plt.figure(figsize=(8.27, 11.69) if portrait else (11.69, 8.27), facecolor="white")
    fig.text(.07, .95, title, fontsize=17, weight="bold", color="#173f55", va="top")
    fig.text(.07, .90, subtitle, fontsize=9, va="top", linespacing=1.4)
    return fig


def save(pdf, fig, figures, number, name):
    fig.text(.07, .03, "Woche 3 · p = 0,2 · N = 28 · ohne Ergebnisinterpretation", fontsize=7, color="#596773")
    fig.text(.93, .03, str(number), fontsize=8, ha="right")
    pdf.savefig(fig)
    fig.savefig(figures / f"{number:02d}_{name}.png", dpi=180)
    fig.savefig(figures / f"{number:02d}_{name}.pdf")
    plt.close(fig)


def table(ax, rows, headers, widths, font=8, scale=1.6):
    ax.axis("off")
    tab = ax.table(cellText=rows, colLabels=headers, colWidths=widths, cellLoc="left", loc="center")
    tab.auto_set_font_size(False); tab.set_fontsize(font); tab.scale(1, scale)
    for (r, _), cell in tab.get_celld().items():
        cell.set_edgecolor("#c6d2dc"); cell.set_linewidth(.55)
        cell.set_facecolor("#e5eef3" if r == 0 else "white" if r % 2 else "#f5f8fa")
        if r == 0: cell.set_text_props(weight="bold", ha="left")


def report(folder, rows, audits, raw, tests):
    figures = folder / "grafiken"; figures.mkdir(exist_ok=True)
    target = folder / "Woche3_Beta_zwei_Bloecke.pdf"
    beta = np.array([float(r["beta"]) for r in rows])
    q = np.array([float(r["throughput_trains_per_h"]) for r in rows])
    with PdfPages(target) as pdf:
        fig = page("Woche 3: Antizipation über zwei Blöcke", "Parameter und Messdefinition; β-Reihe einschließlich β = 0", portrait=True)
        parameters = [
            ["Zugzahl / Störungswahrscheinlichkeit", "N = 28 / p = 0,2, für beide Störungsarten"],
            ["β-Werte", "0; 0,05; 0,10; …; 0,50 1/s (11 Werte)"],
            ["β = 0", "Keine zusätzliche Antizipationswirkung; normale Beschleunigung"],
            ["Antizipationsbereich", "Zugende des Vorgängers im 1. oder 2. Block voraus"],
            ["Ausgangsblock / Ringschluss", "Block der eigenen Zugspitze / zyklische Blockzählung"],
            ["Strecke / Blöcke", "Reale S41 / 117 unterschiedlich lange OSM-Abschnitte"],
            ["Maximalgeschwindigkeit", "80 km/h Vorgabe / 79,2 km/h effektiv"],
            ["Raster / Zuglänge", "1 m / 1 s; 148 m"],
            ["Beschleunigung / Verzögerung", "Regulär bis +1 / −1 m/s²"],
            ["Antizipationsregel", "a = max(−1, β · (v_Vorgänger − v_Zug)) bei langsamerem Zug"],
            ["Rasterumsetzung", "Bruchteile sammeln; außerhalb des Bereichs zurücksetzen"],
            ["Stationshalte / fester Zuschlag", "GTFS-Stationshalte / 0 s"],
            ["Zufällige Stationszusatzzeit", "Bei Treffer mit p: diskret gleichverteilt 0 bis 120 s"],
            ["Zufallsbremsung", "Je Blockeinfahrt mit p; −1 m/s² bis floor(v_Eintritt/2)"],
            ["Einschwingen / Messdauer", "60 min / 180 min; Gesamtdauer 240 min je Lauf"],
            ["Zufallsstartwert / Läufe", "42 / ein Lauf je β-Wert"],
            ["Weg-Zeit-Diagramm", "β = 0,20 1/s; alle 28 Züge; Messfenster 60–240 min"],
            ["Haltezeituntersuchung", "Auf Wunsch vorerst ausgelassen"],
        ]
        table(fig.add_axes([.07, .28, .86, .57]), parameters, ["Parameter", "Wert"], [.37, .63], font=7.0, scale=1.65)
        notes = ("Durchsatz: Abfahrten an Station 1 im halboffenen Messfenster [3600,14400) s, "
                 "geteilt durch drei Stunden. Das Zugende ist die hinterste belegte Rasterzelle. "
                 "Die Entfernung wird in tatsächlichen OSM-Blöcken gezählt; der nominelle Zielabstand 500 m wirkt dabei nicht.")
        fig.text(.07, .18, "\n".join(textwrap.wrap(notes, 102)), va="top", fontsize=8, linespacing=1.4)
        fig.text(.07, .085, f"Prüfungen: {len(tests)} Grenzfalltests und alle 11 Rohdatensätze bestanden.\n"
                 "Blockbereich, Vorgänger-Zugende und Bremsbruchteile wurden je Zeitschritt nachgerechnet.", va="top", fontsize=8)
        save(pdf, fig, figures, 1, "parameter")

        fig = page("Durchsatz in Abhängigkeit von β", "p = 0,2; N = 28; fester Haltezeitzuschlag 0 s; Antizipation bis zum Zugende zwei Blöcke voraus")
        ax = fig.add_axes([.10, .19, .82, .61])
        line, = ax.plot(beta, q, "o-", color="#146b9c", linewidth=1.7, markersize=5)
        np.testing.assert_array_equal(line.get_xdata(), beta); np.testing.assert_array_equal(line.get_ydata(), q)
        k = np.flatnonzero(np.isclose(beta, .2))[0]
        ax.plot(beta[k], q[k], "o", color="#bb641b", markersize=9, label="Weg-Zeit-Diagramm bei β = 0,20")
        ax.set_xticks(beta, [fmt(x) for x in beta]); ax.set_xlim(-.01, .51)
        ax.set_ylim(0, max(q)*1.15); ax.grid(alpha=.2)
        ax.set_xlabel("Antizipationsfaktor β [1/s]"); ax.set_ylabel("Durchschnittlicher Durchsatz [Züge/h]")
        ax.legend(loc="best", fontsize=8)
        fig.text(.10, .09, "80 km/h Vorgabe / 79,2 km/h effektiv; 60 min Einschwingen + 180 min Messung; ein Lauf je Punkt", fontsize=8)
        save(pdf, fig, figures, 2, "durchsatz_beta")

        fig = page("Weg-Zeit-Diagramm bei β = 0,20", "p = 0,2; N = 28; fester Haltezeitzuschlag 0 s; Zugende des Vorgängers höchstens zwei Blöcke voraus")
        ax = fig.add_axes([.10, .18, .82, .62])
        p, g = raw["p"], raw["G"]
        t = np.asarray(g["timeSeconds"])
        selected = (t >= 3600) & (t <= 14400)
        time = t[selected] / 60
        positions = np.asarray(g["position"], dtype=np.int64)[selected]
        colors = plt.get_cmap("turbo")(np.linspace(.03, .97, 28))
        for station in np.atleast_1d(p["route"]["stationCells"]):
            ax.axhline((station-1)*p["dxMeters"]/1000, color="#e0e4e8", linewidth=.4, zorder=0)
        for train in range(28):
            position = (positions[:,train]-1)*p["dxMeters"]/1000
            wraps = np.flatnonzero(np.diff(positions[:,train]) < 0)+1
            x = np.insert(time, wraps, np.nan); y = np.insert(position, wraps, np.nan)
            drawn, = ax.plot(x, y, color=colors[train], linewidth=.55, alpha=.85)
            np.testing.assert_array_equal(drawn.get_xdata()[np.isfinite(x)], time)
            np.testing.assert_array_equal(drawn.get_ydata()[np.isfinite(y)], position)
        ax.set_xlim(60,240); ax.set_ylim(0,p["route"]["lengthMeters"]/1000)
        ax.set_xticks(np.arange(60,241,30)); ax.set_xlabel("Simulationszeit [min]")
        ax.set_ylabel("Position der Zugspitze auf dem Ring [km]"); ax.grid(axis="x", alpha=.15)
        fig.text(.10, .09, "Eine Linie je Zug; horizontale Hilfslinien: Stationen; Linienunterbrechung am Ringschluss. Nur das Messfenster ist gezeigt.", fontsize=8)
        save(pdf, fig, figures, 3, "weg_zeit_beta020")

        fig = page("Wertetabelle und Prüfprotokoll", "Durchsätze aus denselben gespeicherten Trajektorien wie im Diagramm")
        table(fig.add_axes([.13, .35, .74, .48]), [[fmt(r["beta"]), fmt(r["throughput_trains_per_h"]), str(r["departure_count"])]
              for r in audits], ["β [1/s]", "Durchsatz [Züge/h]", "Abfahrten im Messfenster"], [.25,.35,.40], font=9, scale=1.65)
        fig.text(.13, .24, f"Alle {len(audits)} Läufe: Modellprüfungen und unabhängige Rohdatenprüfung bestanden.", fontsize=9)
        fig.text(.13, .18, "Prüfung jedes Zeitschritts: Zugende im Blockbereich, β-Regel, Bruchteile, Beschleunigungsgrenzen und Detektorzahl.", fontsize=8)
        fig.text(.13, .12, "Keine Haltezeitreihe berechnet. Parameter, vollständige Rohdaten und Quellen sind im Ergebnisordner gespeichert.", fontsize=8)
        save(pdf, fig, figures, 4, "wertetabelle")
    content = target.read_bytes()
    assert content.startswith(b"%PDF-") and content.rstrip().endswith(b"%%EOF")
    assert len(re.findall(rb"/Type\s*/Page\b", content)) == 4
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("folder", type=Path)
    args = parser.parse_args(); folder = args.folder.resolve()
    plan = json.loads((folder/"parameter.json").read_text(encoding="utf-8"))
    assert json.loads((folder/"abschluss.json").read_text(encoding="utf-8"))["complete"]
    assert plan["leaderReference"] == "Zugende" and plan["anticipationMaxBlocks"] == 2
    assert not plan["holdStudyIncluded"]
    def hashes(path):
        return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob("*.m")}
    current = hashes(ROOT/"modell"/"+sbahn3")
    assert current and current == hashes(folder/"quellstand"/"+sbahn3")
    rows = read_rows(folder/"beta.csv"); tests = read_rows(folder/"blockpruefung.csv")
    assert len(rows) == 11 and len(tests) == 10 and all(r["passed"] in {"1","true"} for r in tests)
    np.testing.assert_allclose([float(r["beta"]) for r in rows], np.linspace(0,.5,11), rtol=0, atol=1e-12)
    saved = loadmat(folder/"ergebnis.mat", simplify_cells=True)["result"]
    np.testing.assert_allclose(saved["betaValues"], [float(r["beta"]) for r in rows], rtol=0, atol=1e-12)
    np.testing.assert_allclose(saved["throughput"], [float(r["throughput_trains_per_h"]) for r in rows], rtol=0, atol=1e-12)
    audits, representative = audit(folder, rows, plan)
    with (folder/"rohdatenaudit.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(audits[0])); writer.writeheader(); writer.writerows(audits)
    target = report(folder, rows, audits, representative, tests)
    proof = dict(complete=True, auditedRuns=11, perStepHorizonVerified=True, leaderReference="Zugende",
                 maxBlocks=2, zeroBetaVerified=True, blockBoundaryTests=10, representativeBeta=.2,
                 holdStudyIncluded=False, pdfPages=4, pdf=target.name,
                 pdfSha256=hashlib.sha256(target.read_bytes()).hexdigest())
    (folder/"bericht_pruefung.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2),encoding="utf-8")
    print(f"PDF erstellt: {target} (4 Seiten)")


if __name__ == "__main__":
    main()
