"""Erweiterte Woche-3-PDF: vier Zugzahlen, Beta und fester Stationszuschlag."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
from scipy.io import loadmat
from bericht_woche3 import page, table, fmt, read_rows

ROOT = Path(__file__).resolve().parent
TRAINS = [20, 28, 36, 44]
COLORS = {20: "#d88700", 28: "#146b9c", 36: "#00966e", 44: "#a351a0"}
MARKERS = {20: "s", 28: "o", 36: "^", 44: "D"}


def hashes(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob("*.m")}


def verify_case(folder, row):
    raw = loadmat(folder / "laeufe" / row["file"], simplify_cells=True)
    p, g, m = raw["p"], raw["G"], raw["metrics"]
    c = p["config"]; n = int(row["train_count"])
    beta, extra = float(row["beta"]), float(row["extra_dwell_s"])
    assert raw["report"]["checksPassed"] and row["passed"] in {"1", "true"}
    assert n in TRAINS and c["trainCount"] == p["trainCount"] == n
    assert c["initializationMode"] == "Ruhende Blockaufstellung" and not c["initialPhaseSearch"]
    assert c["randomBrakeEnabled"] and c["randomStopEnabled"] and c["anticipationEnabled"]
    assert c["randomBrakeProbability"] == .2 and c["randomStopProbability"] == .2
    assert c["randomStopMinSeconds"] == 0 and c["randomStopMaxSeconds"] == 120
    assert c["randomSeed"] == 42 and c["durationMinutes"] == 240
    assert c["cruiseSpeedKmh"] == 80 and c["anticipationMaxBlocks"] == 2
    np.testing.assert_allclose(c["anticipationBeta"], beta, atol=1e-12)
    assert c["dwellOffsetSeconds"] == extra
    np.testing.assert_array_equal(np.asarray(p["stationDwellSeconds"]), np.asarray(p["baseStationDwellSeconds"])+extra)
    assert p["trainCells"] == 148 and p["stepSeconds"] == p["dxMeters"] == 1
    np.testing.assert_allclose(p["driveSpeedKmh"], 79.2, atol=1e-10)
    assert m["warmupSeconds"] == 3600 and m["measurementSeconds"] == 10800
    pos = np.asarray(g["position"], dtype=np.int64).reshape(-1, n)
    vel = np.asarray(g["velocity"], dtype=np.int64).reshape(-1, n)
    wait = np.asarray(g["waitSteps"]).reshape(-1, n)
    blocked = np.asarray(g["blocked"], dtype=bool).reshape(-1, n)[1:]
    times = np.asarray(g["timeSeconds"])
    assert pos.shape == (14401, n) and np.all(vel[0] == 0)
    starts = np.asarray(p["blocks"]["startCells"], dtype=np.int64)
    block_map = np.asarray(p["blocks"]["cellBlock"], dtype=np.int64)
    selected_blocks = 1 + np.floor(np.arange(n)*len(starts)/n).astype(int)
    expected_positions = (starts[selected_blocks % len(starts)]-2) % int(p["cellCount"])+1
    np.testing.assert_array_equal(pos[0], expected_positions)
    np.testing.assert_array_equal(block_map[pos[0]-1], selected_blocks)
    np.testing.assert_array_equal(p["initialHeadBlocks"], selected_blocks)
    assert np.all(np.diff(np.r_[selected_blocks, selected_blocks[0]]) % len(starts) >= 2)
    # Die reservierten Anfangsblöcke dürfen auch unter den Zugkörpern nicht überlappen.
    occupied = set()
    for front in pos[0]:
        body = (front-1-np.arange(148)) % int(p["cellCount"])
        blocks = set(block_map[body].tolist())
        assert not occupied.intersection(blocks)
        occupied.update(blocks)

    selected = (times[:-1] >= 3600) & (times[:-1] < 14400)
    moved = np.diff(pos, axis=0) % int(p["cellCount"]) > 0
    station = np.atleast_1d(p["route"]["stationCells"])[0]
    count = int(np.count_nonzero(((pos[:-1] == station) & moved)[selected]))
    assert count == m["departureCount"] == int(float(row["departure_count"]))
    np.testing.assert_allclose(count/3, float(row["throughput_trains_per_h"]), atol=1e-10)
    np.testing.assert_allclose(count/3, m["throughputTrainsPerHour"], atol=1e-10)
    assert not np.any(blocked & (moved | (wait[:-1] > 0)))
    assert np.max(np.abs(np.diff(vel, axis=0))) <= 1

    order = np.argsort(pos[:-1], axis=1)
    leader = np.empty_like(order)
    np.put_along_axis(leader, order, np.roll(order, -1, axis=1), axis=1)
    leader_front = np.take_along_axis(pos[:-1], leader, axis=1)
    leader_end = (leader_front-int(p["trainCells"])) % int(p["cellCount"])+1
    ahead = (block_map[leader_end-1]-block_map[pos[:-1]-1]) % len(starts)
    leader_speed = np.take_along_axis(vel[:-1], leader, axis=1)
    eligible = ((leader_speed < vel[:-1]) & (wait[:-1] == 0)
                & (ahead >= 1) & (ahead <= 2) & (beta > 0))
    actual = np.asarray(g["anticipationEligible"], dtype=bool).reshape(-1, n)[1:]
    applied = np.asarray(g["anticipationApplied"], dtype=bool).reshape(-1, n)[1:]
    np.testing.assert_array_equal(actual, eligible)
    expected = np.zeros_like(applied); remainder = np.zeros(n)
    for k in range(len(eligible)):
        increment = np.minimum(1, beta*(vel[k]-leader_speed[k]))
        remainder = np.where(eligible[k], remainder+increment, 0)
        decrement = np.minimum(1, np.floor(remainder+1e-12)); remainder -= decrement
        expected[k] = eligible[k] & (decrement > 0)
        cap = np.maximum(0, vel[k]-decrement)
        assert np.all(vel[k+1][eligible[k]] <= cap[eligible[k]])
    np.testing.assert_array_equal(applied, expected)
    if beta == 0:
        assert not np.any(applied) and not np.any(eligible)
    audit = dict(file=row["file"], train_count=n, beta=beta, extra_dwell_s=extra,
                 departure_count=count, throughput_trains_per_h=count/3, verified=True,
                 eligible_train_s_measurement=int(np.count_nonzero(eligible[selected])),
                 anticipation_decrements_measurement=int(np.count_nonzero(applied[selected])))
    return audit, raw


def save(pdf, fig, figures, index, name):
    fig.text(.07, .03, "Woche 3 · p = 0,2 · N = 20 / 28 / 36 / 44 · ohne Ergebnisinterpretation", fontsize=7, color="#596773")
    fig.text(.93, .03, str(index), ha="right", fontsize=8)
    pdf.savefig(fig)
    fig.savefig(figures/f"{index:02d}_{name}.png", dpi=180)
    fig.savefig(figures/f"{index:02d}_{name}.pdf")
    plt.close(fig)


def parameter_page(pdf, figures):
    fig = page("Woche 3: β und zusätzliche Haltezeiten", "Vier Zugzahlen; gemeinsame Parameter und einheitliche Initialisierung", portrait=True)
    rows = [
        ["Zugzahlen / Farben", "20 orange; 28 blau; 36 grün; 44 violett"],
        ["Störungswahrscheinlichkeit", "p = 0,2 für beide unabhängigen Störungsarten"],
        ["β-Untersuchung", "β = 0:0,05:0,50 1/s; fester Haltezuschlag 0 s"],
        ["Haltezeituntersuchung", "Zuschlag 0, 6, 12, 18, 24, 30, 36, 42, 45 s; β = 0,20"],
        ["Haltezeitstufen", "9 ganzzahlige Stufen; letzter Schritt 3 s"],
        ["Bedeutung des Zuschlags", "Feste zusätzliche Sekunden auf jeden GTFS-Stationshalt"],
        ["Strecke / Blocksteuerung", "Reale S41 / 117 unterschiedlich lange OSM-Signalabschnitte"],
        ["Antizipationsbereich", "Zugende des Vorgängers im 1. oder 2. Block voraus"],
        ["Antizipationsregel", "a = max(−1, β · (v_Vorgänger − v_Zug)); β in 1/s"],
        ["β = 0", "Keine Zusatzbremsung und keine Beschleunigungssperre"],
        ["Raster / Zuglänge", "1 m / 1 s; 148 m"],
        ["Beschleunigung / Verzögerung", "Bis +1 / −1 m/s²; reguläre Sicherheitsregeln bleiben aktiv"],
        ["Maximalgeschwindigkeit", "80 km/h Vorgabe / 79,2 km/h effektiv"],
        ["Zufälliger Stationszusatz", "Bei Treffer mit p: diskret gleichverteilt 0 bis 120 s"],
        ["Zufallsbremsung", "Je Blockeinfahrt mit p; −1 m/s² bis floor(v_Eintritt/2)"],
        ["Einschwingen / Messdauer", "60 min / 180 min; insgesamt 240 min je Lauf"],
        ["Start / Zufallsstartwert", "Ruhende Blockaufstellung für alle N / Startwert 42"],
        ["Weg-Zeit-Diagramme", "N = 28; β = 0,20; Zuschlag 0 s und 18 s"],
        ["Umfang", "44 β-Punkte + 36 Haltezeitpunkte; 76 verschiedene Läufe"],
    ]
    table(fig.add_axes([.07, .27, .86, .58]), rows, ["Parameter", "Wert"], [.35,.65], font=6.8, scale=1.6)
    fig.text(.07, .18, "Startaufstellung: Zugspitzen gleichmäßig über Blocknummern verteilt, jeweils am Blockende;\n"
             "alle Anfangsgeschwindigkeiten 0. Zugkörper und belegte Blöcke überschneiden sich nicht.\n"
             "Für N = 44 findet die bisherige freie Phasenverteilung keine sichere Startaufstellung.\n"
             "Deshalb sind alle Kurven einschließlich N = 28 mit derselben neuen Methode berechnet.", va="top", fontsize=7.6, linespacing=1.4)
    fig.text(.07, .075, "Durchsatz: Abfahrten an Station 1 im Fenster [3600,14400) s / 3 h. Ein Lauf je Konfiguration.\n"
             "Die vier Punkte bei β = 0,20 und Zuschlag = 0 s erscheinen identisch in beiden Kurvenscharen.", va="top", fontsize=7.5)
    save(pdf, fig, figures, 1, "parameter")


def curves(pdf, figures, rows, beta_axis, ymax, index):
    title = "Durchsatz für verschiedene β" if beta_axis else "Durchsatz für zusätzliche Stationshalte"
    subtitle = "p = 0,2; fester Haltezeitzuschlag 0 s" if beta_axis else "p = 0,2; β = 0,20 1/s; fester Zuschlag auf jeden GTFS-Halt"
    fig = page(title, subtitle+"; Antizipation anhand des Zugendes in höchstens zwei Blöcken")
    ax = fig.add_axes([.10, .19, .82, .61])
    for n in TRAINS:
        selected = [r for r in rows if int(r["train_count"]) == n]
        x = np.array([float(r["x_value"]) for r in selected]); y = np.array([float(r["throughput_trains_per_h"]) for r in selected])
        line, = ax.plot(x, y, marker=MARKERS[n], color=COLORS[n], label=f"N = {n}", linewidth=1.5, markersize=4)
        np.testing.assert_array_equal(line.get_xdata(), x); np.testing.assert_array_equal(line.get_ydata(), y)
    target_x = .2 if beta_axis else 18
    marked = next(r for r in rows if int(r["train_count"]) == 28 and abs(float(r["x_value"])-target_x) < 1e-12)
    ax.plot(target_x, float(marked["throughput_trains_per_h"]), "*", color="#222222", markersize=11, label="Weg-Zeit-Diagramm (N = 28)")
    ticks = [float(r["x_value"]) for r in rows if int(r["train_count"]) == 28]
    ax.set_xticks(ticks, [fmt(x,2 if beta_axis else 0) for x in ticks])
    ax.set_xlabel("Antizipationsfaktor β [1/s]" if beta_axis else "Fester zusätzlicher Stationshalt je Station [s]")
    ax.set_ylabel("Durchschnittlicher Durchsatz [Züge/h]"); ax.set_ylim(0,ymax)
    ax.grid(alpha=.2); ax.legend(loc="lower left", fontsize=9)
    fig.text(.10, .09, "80 km/h Vorgabe / 79,2 km/h effektiv; 60 min Einschwingen + 180 min Messung; gleiche Farben in beiden Kurvenscharen", fontsize=8)
    save(pdf, fig, figures, index, "durchsatz_beta" if beta_axis else "durchsatz_haltezuschlag")


def space_time(pdf, figures, raw, extra, index):
    fig = page(f"Weg-Zeit-Diagramm: N = 28, Zuschlag {extra} s", "p = 0,2; β = 0,20 1/s; gleiche Startaufstellung und Messdauer wie in den Durchsatzkurven")
    ax = fig.add_axes([.10,.18,.82,.62]); p, g = raw["p"], raw["G"]
    t = np.asarray(g["timeSeconds"]); selected = (t >= 3600) & (t <= 14400)
    time = t[selected]/60; positions = np.asarray(g["position"],dtype=np.int64)[selected]
    colors = plt.get_cmap("turbo")(np.linspace(.03,.97,28))
    for station in np.atleast_1d(p["route"]["stationCells"]):
        ax.axhline((station-1)/1000,color="#e0e4e8",linewidth=.4,zorder=0)
    for train in range(28):
        position = (positions[:,train]-1)/1000
        wraps = np.flatnonzero(np.diff(positions[:,train]) < 0)+1
        x = np.insert(time,wraps,np.nan); y = np.insert(position,wraps,np.nan)
        line, = ax.plot(x,y,color=colors[train],linewidth=.55,alpha=.85)
        np.testing.assert_array_equal(line.get_xdata()[np.isfinite(x)],time)
        np.testing.assert_array_equal(line.get_ydata()[np.isfinite(y)],position)
    ax.set_xlim(60,240); ax.set_ylim(0,p["route"]["lengthMeters"]/1000)
    ax.set_xticks(np.arange(60,241,30)); ax.grid(axis="x",alpha=.15)
    ax.set_xlabel("Simulationszeit [min]"); ax.set_ylabel("Position der Zugspitze auf dem Ring [km]")
    fig.text(.10,.09,"Eine Linie je Zug; horizontale Hilfslinien: Stationen; Linienunterbrechung am Ringschluss. Gezeigt wird das Messfenster.",fontsize=8)
    save(pdf,fig,figures,index,f"weg_zeit_zuschlag_{extra:02d}")


def values(pdf, figures, matrix, x, beta_axis, index):
    fig = page("Wertetabelle: β-Reihe" if beta_axis else "Wertetabelle: Haltezeitzuschlag", "Alle Durchsätze in Zügen/h; p = 0,2; identische Werte wie in den Kurvenscharen")
    cells = [[fmt(value,2 if beta_axis else 0)]+[fmt(matrix[n,j]) for n in range(4)] for j,value in enumerate(x)]
    table(fig.add_axes([.10,.33,.80,.50]),cells,["β [1/s]" if beta_axis else "Zuschlag [s]"]+[f"N = {n}" for n in TRAINS],[.20]*5,font=9,scale=1.65)
    fig.text(.10,.22,"Fester Stationszuschlag 0 s." if beta_axis else "β = 0,20 1/s. Der Zuschlag wird zusätzlich zu jedem GTFS-Halt angewendet.",fontsize=9)
    fig.text(.10,.16,"Alle Werte aus Rohdaten nachgezählt. Modellprüfungen, Blockbereich am Vorgänger-Zugende und Bremsbruchteile geprüft.",fontsize=8)
    fig.text(.10,.10,"Ein Lauf je Konfiguration; Zufallsstartwert 42. Zufällige Stationszusätze bleiben unabhängig vom festen Zuschlag aktiv.",fontsize=8)
    save(pdf,fig,figures,index,"werte_beta" if beta_axis else "werte_haltezuschlag")


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("folder",type=Path)
    folder = parser.parse_args().folder.resolve()
    plan = json.loads((folder/"parameter.json").read_text(encoding="utf-8"))
    complete = json.loads((folder/"abschluss.json").read_text(encoding="utf-8"))
    assert complete["complete"] and complete["uniqueConfigurations"] == 76 and complete["diagramPoints"] == 80
    assert plan["trainCounts"] == TRAINS and plan["initializationMode"] == "Ruhende Blockaufstellung"
    assert plan["leaderReference"] == "Zugende" and plan["anticipationMaxBlocks"] == 2
    assert hashes(ROOT/"modell"/"+sbahn3x") == hashes(folder/"quellstand"/"+sbahn3x")
    data_hashes = json.loads((folder/"quellstand"/"erweiterung_daten_hashes.json").read_text(encoding="utf-8"))
    for relative,digest in data_hashes.items():
        assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest() == digest
    beta_rows = read_rows(folder/"beta.csv"); dwell_rows = read_rows(folder/"haltezeiten.csv")
    unique = read_rows(folder/"laufindex.csv")
    assert len(beta_rows) == 44 and len(dwell_rows) == 36 and len(unique) == 76
    assert len({r["file"] for r in unique}) == 76
    saved = loadmat(folder/"ergebnis.mat",simplify_cells=True)["result"]
    beta_matrix = np.asarray(saved["betaThroughput"]); dwell_matrix = np.asarray(saved["dwellThroughput"])
    for rows,matrix,x_values in [(beta_rows,beta_matrix,plan["betaValues"]),(dwell_rows,dwell_matrix,plan["dwellValuesSeconds"])]:
        assert matrix.shape == (4,len(x_values))
        for i,n in enumerate(TRAINS):
            part = [r for r in rows if int(r["train_count"]) == n]
            np.testing.assert_allclose([float(r["x_value"]) for r in part],x_values,rtol=0,atol=1e-12)
            np.testing.assert_allclose([float(r["throughput_trains_per_h"]) for r in part],matrix[i],rtol=0,atol=1e-12)
    np.testing.assert_array_equal(beta_matrix[:,4],dwell_matrix[:,0])
    audits = []; representatives = {}; by_file = {}
    for k,row in enumerate(unique,1):
        checked,raw = verify_case(folder,row); audits.append(checked); by_file[row["file"]] = checked
        if checked["train_count"] == 28 and abs(checked["beta"]-.2) < 1e-12 and checked["extra_dwell_s"] in {0,18}:
            representatives[int(checked["extra_dwell_s"])] = raw
        if k % 4 == 0 or k == len(unique): print(f"Rohdaten geprüft: {k}/76",flush=True)
    for row in beta_rows+dwell_rows:
        record = by_file[row["file"]]
        assert record["train_count"] == int(row["train_count"])
        np.testing.assert_allclose(record["beta"],float(row["beta"]),atol=1e-12)
        assert record["extra_dwell_s"] == float(row["extra_dwell_s"])
        np.testing.assert_allclose(record["throughput_trains_per_h"],float(row["throughput_trains_per_h"]),atol=1e-10)
    assert set(representatives) == {0,18}
    with (folder/"rohdatenaudit.csv").open("w",encoding="utf-8",newline="") as stream:
        writer = csv.DictWriter(stream,fieldnames=list(audits[0])); writer.writeheader(); writer.writerows(audits)
    figures = folder/"grafiken"; figures.mkdir(exist_ok=True)
    target = folder/"Woche3_Beta_und_Haltezeiten.pdf"
    ymax = np.ceil(max(np.max(beta_matrix),np.max(dwell_matrix))*1.15)
    with PdfPages(target) as pdf:
        parameter_page(pdf,figures)
        curves(pdf,figures,beta_rows,True,ymax,2)
        space_time(pdf,figures,representatives[0],0,3)
        curves(pdf,figures,dwell_rows,False,ymax,4)
        space_time(pdf,figures,representatives[18],18,5)
        values(pdf,figures,beta_matrix,plan["betaValues"],True,6)
        values(pdf,figures,dwell_matrix,plan["dwellValuesSeconds"],False,7)
    content = target.read_bytes()
    assert content.startswith(b"%PDF-") and content.rstrip().endswith(b"%%EOF")
    assert len(re.findall(rb"/Type\s*/Page\b",content)) == 7
    proof = dict(complete=True,auditedUniqueRuns=76,verifiedDiagramPoints=80,betaPoints=44,dwellPoints=36,
                 sharedPoints=4,pdfPages=7,initializationMode=plan["initializationMode"],
                 fixedDwellBeta=.2,representativeTrainCount=28,representativeDwellSeconds=18,
                 sourceModelUnchangedDuringRuns=True,inputDataHashesVerified=True,
                 perStepHorizonVerified=True,leaderReference="Zugende",maxBlocks=2,
                 pdf=target.name,pdfSha256=hashlib.sha256(content).hexdigest())
    (folder/"bericht_pruefung.json").write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"PDF erstellt: {target} (7 Seiten)")


if __name__ == "__main__":
    main()
