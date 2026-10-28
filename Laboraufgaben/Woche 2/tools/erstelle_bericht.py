"""Drei PDF-Seiten und Diagramme aus den tatsächlich berechneten MATLAB-Daten.

Aufruf: py tools/erstelle_bericht.py
Abhängigkeiten: numpy, scipy, matplotlib (kein Netzwerkzugriff).
"""
from __future__ import annotations

import csv
import hashlib
import json
import textwrap
from pathlib import Path

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
FIG.mkdir(exist_ok=True)
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9,
                     "axes.spines.top": False, "axes.grid": True,
                     "grid.alpha": .22, "pdf.fonttype": 42})


def rows(name: str) -> list[dict]:
    with (OUT / name).open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def numbers(data: list[dict], key: str) -> np.ndarray:
    return np.array([float(r[key]) for r in data])


def fmt(x: float, digits: int = 1) -> str:
    return f"{x:.{digits}f}".replace(".", ",")


def paragraph(fig, y, text, *, x=.075, width=104, size=9.1, color="#202a34"):
    lines = textwrap.wrap(text, width=width, break_long_words=False,
                          break_on_hyphens=False)
    fig.text(x, y, "\n".join(lines), ha="left", va="top", fontsize=size,
             linespacing=1.35, color=color)
    return y - len(lines) * size * 1.35 / (11.69 * 72) - .012


def heading(fig, y, title):
    fig.text(.075, y, title, fontsize=11, weight="bold", va="top", color="#123650")
    return y - .032


def page(number, subtitle):
    f = plt.figure(figsize=(8.27, 11.69), facecolor="white")
    f.text(.075, .958, "S-Bahn-Ring simulieren und validieren", fontsize=16,
           weight="bold", color="#123650", va="top")
    f.text(.075, .928, subtitle, fontsize=9.4, color="#4a5966", va="top")
    f.text(.075, .027, "Modellbildung und Simulation · Woche 2 · Datenstand 14.10.2026", fontsize=8, color="#596570")
    f.text(.925, .027, f"{number} / 3", fontsize=8, color="#596570", ha="right")
    return f


def table_on(fig, bounds, cells, labels, widths=None, size=8.5):
    ax = fig.add_axes(bounds)
    ax.axis("off")
    t = ax.table(cellText=cells, colLabels=labels, colWidths=widths,
                 cellLoc="left", colLoc="left", bbox=[0, 0, 1, 1])
    t.auto_set_font_size(False)
    t.set_fontsize(size)
    for (r, c), cell in t.get_celld().items():
        cell.set_edgecolor("#d6e0e7")
        cell.set_linewidth(.5)
        cell.set_facecolor("#e7eff4" if r == 0 else ("#f5f8fa" if r % 2 else "white"))
        if r == 0:
            cell.set_text_props(weight="bold", color="#123650")
    return t


def parameter_plot(ax, data, key, label):
    x = numbers(data, key)
    q = numbers(data, "throughput_trains_per_h")
    free = numbers(data, "free_throughput_trains_per_h")
    wait = numbers(data, "blocked_s_per_train_h")
    ax.plot(x, q, "o-", color="#146b9c", lw=1.8, label="gemessener Durchsatz")
    ax.plot(x, free, "--", color="#778b96", lw=1.3, label="freier Referenzbetrieb")
    ax.set(xlabel=label, ylabel="Durchsatz [Züge/h]")
    ax.set_ylim(bottom=0)
    twin = ax.twinx()
    twin.plot(x, wait, "s-", color="#c57618", lw=1.5, ms=4, label="blockierter Stillstand")
    twin.set_ylabel("Stillstand [s/(Zug·h)]", color="#a7600e")
    twin.set_ylim(0, max(1, float(wait.max()) * 1.15))
    twin.grid(False)
    handles, labels = ax.get_legend_handles_labels()
    handles2, labels2 = twin.get_legend_handles_labels()
    ax.legend(handles + handles2, labels + labels2, loc="lower left", fontsize=7.4)


def spacetime(ax, trace, start=10800, stop=12600):
    t = np.asarray(trace["traceTime"]).ravel()
    take = (t >= start) & (t <= stop)
    x = np.asarray(trace["tracePosition"])[take, :] / 1000 - .001
    tt = (t[take] - start) / 60
    blocked = np.asarray(trace["traceBlocked"], dtype=bool)[take, :]
    station = (np.asarray(trace["stationCells"]).ravel() - 1) / 1000
    for s in station:
        ax.axvline(s, color="#9ba9b4", lw=.6, ls=":", zorder=0)
    paths = []
    for k in range(x.shape[1]):
        xx = x[:, k].copy()
        xx[np.r_[False, np.diff(xx) < 0]] = np.nan
        paths.append(np.column_stack((xx, tt)))
    ax.add_collection(LineCollection(paths, colors="#18618b", linewidths=.65, alpha=.75))
    ridx, cidx = np.where(blocked)
    ax.scatter(x[ridx, cidx], tt[ridx], s=1.2, c="#d57909", zorder=3,
               label="verkehrsbedingt blockiert")
    ax.plot([], [], color="#18618b", label="Zugspitzen")
    ax.plot([], [], ":", color="#9ba9b4", label="Stationen (Nummern oben)")
    ax.set(xlim=(0, float(trace["cellCount"]) / 1000), ylim=(30, 0),
           xlabel="Position entlang der S41 [km]", ylabel="Zeit ab Minute 180 [min]")
    ax.legend(loc="lower left", fontsize=7, framealpha=.95)
    top = ax.secondary_xaxis("top")
    top.set_xticks(station, [str(i + 1) for i in range(len(station))], fontsize=6.8)
    return ax


def main():
    p = json.loads((OUT / "parameter.json").read_text(encoding="utf-8-sig"))
    ref = rows("referenzvergleich.csv")
    tr = rows("zugzahlstudie.csv")
    dw = rows("haltezeitstudie.csv")
    val = rows("abschnittsvalidierung.csv")
    checks = rows("sanity_checks.csv")
    tests = rows("matlab_tests.csv") if (OUT / "matlab_tests.csv").exists() else []
    assert all(str(value).lower() in {"1", "true"} for row in checks
               for key, value in row.items() if key != "run"), "Sanity Check fehlgeschlagen"
    assert tests and all(str(r["Passed"]).lower() in {"1", "true"} for r in tests), "MATLAB-Tests fehlen oder sind fehlgeschlagen"
    before, after = ref
    peak = max(tr, key=lambda r: float(r["throughput_trains_per_h"]))
    first, last = tr[0], tr[-1]
    trace = loadmat(OUT / "raumzeit.mat", squeeze_me=True)

    for name, data, key, label in [
        ("zugzahl", tr, "train_count", "Zugzahl N (GTFS-Halte unverändert)"),
        ("haltezeit", dw, "mean_dwell_s", "Einheitliche Haltezeit je Station [s] (N = 36)")]:
        f, ax = plt.subplots(figsize=(7.6, 3.7), layout="constrained")
        parameter_plot(ax, data, key, label)
        f.savefig(FIG / f"{name}.png", dpi=200)
        f.savefig(FIG / f"{name}.pdf")
        plt.close(f)
    f, ax = plt.subplots(figsize=(10, 6.2), layout="constrained")
    spacetime(ax, trace)
    f.savefig(FIG / "raumzeit.png", dpi=200)
    f.savefig(FIG / "raumzeit.pdf")
    plt.close(f)

    valid = [r for r in val if r["stage"] == "kalibriert"]
    worst = max(valid, key=lambda r: abs(float(r["error_s"])))
    conclusions = (
        f"Der Durchsatz steigt von {fmt(float(first['throughput_trains_per_h']))} Zügen/h bei N={first['train_count']} "
        f"bis maximal {fmt(float(peak['throughput_trains_per_h']))} Zügen/h bei N={peak['train_count']}. "
        f"Bei N={last['train_count']} werden {fmt(float(last['throughput_trains_per_h']))} Züge/h und "
        f"{fmt(float(last['blocked_s_per_train_h']))} s blockierter Stillstand je Zug und Stunde gemessen. "
        "Ab N=36 liegt die Zugfolge bei 112 s (32,14 Züge/h). Unterschiede um einen Zählwert entsprechen "
        "0,33 Zügen/h; mehr Züge vergrößern hier vor allem Rückstaus."
    )
    dwell_conclusion = (
        f"Bei N=36 verändert eine Erhöhung der einheitlichen Haltezeit von {dw[0]['mean_dwell_s']} auf "
        f"{dw[-1]['mean_dwell_s']} s den Durchsatz von {fmt(float(dw[0]['throughput_trains_per_h']))} auf "
        f"{fmt(float(dw[-1]['throughput_trains_per_h']))} Züge/h. "
        "Längere Halte erhöhen die freie Umlaufzeit um 27 s je zusätzlicher Haltsekunde. "
        "Hier bleibt der blockierte Stillstand durchweg null. Bei ähnlichem Mittelwert liefert das gleichmäßige "
        "34-s-Profil 35,33 Züge/h, das GTFS-Profil 32,00: Auch die Stationsverteilung der Halte ist entscheidend."
    )
    limits = (
        "Die effektive Geschwindigkeitsgrenze bündelt unbekannte örtliche Limits und Fahrplanreserven. "
        "Sie ist keine gemessene Fahrzeughöchstgeschwindigkeit. Ein guter Umlaufwert allein bestätigt die lokalen Fahrzeiten nicht. "
        "Ideale Haltepunkte, identische Fahrzeuge, konstante Beschleunigung und modellhafte 500-m-Blöcke erklären weitere Unterschiede. "
        "Die Ergebnisse gelten für diesen deterministischen Modellbereich und das endliche Messfenster; sie bestimmen keine reale Streckenkapazität."
    )

    with PdfPages(OUT / "Ausarbeitung_SBahn2.pdf", metadata={
        "Title": "S-Bahn-Ring: Kalibrierung und Parameterstudien", "Author": "Laboraufgabe Woche 2",
        "Subject": "Aufgaben aus SBahn2.pdf, auf Grundlage des MATLAB-Modells aus Woche 1"}) as pdf:
        f = page(1, "Aufgabe 1 · Referenzabgleich und aktualisierte Parameter")
        y = heading(f, .89, "Versuchsplan und Modellgrundlage")
        y = paragraph(f, y, "Der MATLAB-Modellkern aus Woche 1 wird als +sbahn2 weiterverwendet und um eine effektive "
                      "Geschwindigkeitsgrenze sowie den Datenpfad ergänzt. Der Referenzabgleich verwendet einen freien Zug. "
                      "Vorab festgelegt: Kalibrierung auf Abfahrt Beusselstraße bis Rückkehrankunft; Prüfung an den 27 reinen "
                      "Abschnittsfahrzeiten (Abfahrt bis nächste Ankunft). Nur die erste Größe wird optimiert.")
        cells = [
            ["Strecke / Raster", f"S41, {fmt(p['lengthMeters']/1000,3)} km; Δx = 1 m, Δt = 1 s"],
            ["Züge / Zugkörper", "Ausgangsfall N = 12; Länge 148 m"],
            ["Geschwindigkeit vorher → nachher", "79,2 → 57,6 km/h (22 → 16 m/s); Sicherheitsgrenze 80 km/h"],
            ["Beschleunigung / Bremsen", "höchstens ±1 m/s²; diskreter Bremsweg B(v)=v(v+1)/2"],
            ["Geplante Stationshalte", f"GTFS-Mediane: {fmt(p['dwellMeanSeconds'],2)} s im Mittel; 30–48 s; Summe 912 s"],
            ["Blocksteuerung", f"{p['blockCount']} gleichmäßige Modellblöcke zu 499–500 m; Freigabe am Zugende"],
            ["Messung / Zufall", "60 min Einschwingen + 180 min Messung; keine Zufallsstörungen"],
        ]
        table_on(f, [.075, .548, .85, .222], cells, ["Parameter", "Tatsächlich verwendeter Wert"], [.32, .68], 8.1)
        y = heading(f, .535, "Kalibrierung und Prüfung")
        comp = [
            ["Abfahrt → Rückkehr [s]", "3558", before["model_departure_return_s"], after["model_departure_return_s"]],
            ["Relativer Fehler [%]", "0", fmt(float(before["error_percent"]),2), fmt(float(after["error_percent"]),2)],
            ["Abschnitts-MAE / RMSE [s]", "0 / 0", f"{fmt(float(before['segment_mae_s']))} / {fmt(float(before['segment_rmse_s']))}",
             f"{fmt(float(after['segment_mae_s']))} / {fmt(float(after['segment_rmse_s']))}"],
        ]
        table_on(f, [.075, .395, .85, .102], comp, ["Vergleichsgröße", "GTFS", "Vorher", "Kalibriert"], [.40,.16,.22,.22], 8.5)
        y = paragraph(f, .378, "Getestet werden alle ganzzahligen Geschwindigkeitsstufen 14–22 m/s. Das Minimum des absoluten "
                      f"Umlauffehlers liegt bei 16 m/s: 3599 statt 3558 s, also +41 s (+{fmt(float(after['error_percent']),2)} %). "
                      "Die Definition ist entscheidend: Der modellierte volle Umlauf beträgt 3641 s; der 42-s-Halt an der "
                      "Startstation gehört nicht zur Referenz von Abfahrt bis Rückkehrankunft.")
        y = paragraph(f, y, f"Die Abschnittsprüfung wird nicht zur Anpassung verwendet. Die größte Abweichung beträgt "
                      f"{fmt(float(worst['error_s']),0)} s auf {worst['from_station']} → {worst['to_station']}. "
                      "Die zweite Größe stammt aus demselben Fahrplan: Sie prüft die zeitliche Verteilung, ist aber keine "
                      "unabhängige Messkampagne. GTFS beschreibt Sollbetrieb, keine Ist-Fahrten.")
        y = heading(f, y-.004, "Referenz und Herkunft")
        paragraph(f, y, "VBB-GTFS, 14.10.2026, S41 trip_id 308542990: 08:03:24–09:02:42; 26 innere Halte, "
                  "Summe 870 s. Anfangs-/Endhalte sind unbekannt und werden nicht als Nullhalte verwendet. "
                  "Geometrie: OpenStreetMap, Relation 14981, 36 971,599 m, auf 36 972 m gerundet. "
                  "Quellen, Lizenzen und Rohdaten: ../Woche 1/NaSch-SBahn/daten/ringbahn_2026-10-14/README.md "
                  "(VBB CC BY 4.0; © OpenStreetMap contributors, ODbL).", size=8.2, width=115)
        f.savefig(FIG / 'bericht_seite_1.png', dpi=130)
        pdf.savefig(f); plt.close(f)

        f = page(2, "Aufgabe 2 · Zugzahl und mittlere Haltezeit")
        paragraph(f, .89, "Durchsatz Q = Abfahrten an Station 1 / Messdauer in Stunden, gezählt im Intervall [3600,14400) s. "
                  "Stillstand zählt ausschließlich verkehrsbedingtes Warten nach Ende des Stationshalts; langsames Folgen "
                  "wird nicht als Stillstand gezählt. Alle Läufe sind deterministisch, deshalb ein Lauf pro Einstellung.")
        ax = f.add_axes([.105,.567,.74,.245])
        parameter_plot(ax,tr,"train_count","Zugzahl N · GTFS-Halte, 500-m-Blöcke")
        ax.set_title("Zugzahlstudie: zehn Werte um den Ausgangsfall N=12", fontsize=10)
        paragraph(f,.51,conclusions,size=8.7,width=110)
        ax = f.add_axes([.105,.205,.74,.23])
        parameter_plot(ax,dw,"mean_dwell_s","Einheitliche Haltezeit je Station [s] · N=36")
        ax.set_title("Haltezeitstudie: acht Werte bei fester Zugzahl", fontsize=10)
        y = paragraph(f,.147,dwell_conclusion,size=8.5,width=112)
        paragraph(f,y,"Die zweite Studie variiert einheitliche Halte bei N=36; die erste verwendet GTFS-Stationshalte. "
                  "Null blockierter Stillstand schließt langsames Folgen nicht aus. Unterschiede von einem Detektorereignis "
                  "entsprechen 0,33 Zügen/h. Ohne Zufallseinflüsse sind zehn Wiederholungen nicht erforderlich.",size=8.0,width=119)
        f.savefig(FIG / 'bericht_seite_2.png', dpi=130)
        pdf.savefig(f); plt.close(f)

        f = page(3, "Aufgabe 2 · Rückstaus, Sanity Checks und Fazit")
        paragraph(f,.89,"Raum-Zeit-Diagramm: N=40, GTFS-Halte, 500-m-Blöcke; Ausschnitt Minute 180–210 des Laufs. "
                  "Senkrechte Trajektorien zeigen Stillstand. Orange markiert verkehrsbedingte Rückstaus; die "
                  "gepunkteten Linien und Stationsnummern zeigen die Haltepunkte. Ringsprünge werden unterbrochen.")
        ax = f.add_axes([.105,.48,.79,.315])
        spacetime(ax,trace)
        y = heading(f,.425,"Prüfung der grundlegenden Regeln")
        y = paragraph(f,y,f"Alle {len(checks)} Läufe bestehen zwölf zusätzliche Sanity Checks: Zugerhaltung, Ringpositionen, "
                      "Geschwindigkeit, Beschleunigung, synchrone Bewegung, Kollisionsfreiheit, Stationshalt, Bremsreserve, "
                      "Stationsbedienung und unabhängiger Detektor. Die Modellprüfungen kontrollieren auch exklusive "
                      f"Blockbelegung und Mindesthalte. Alle {len(tests)} MATLAB-Tests bestehen, einschließlich zweier "
                      "Vergleiche der Grunddynamik mit Woche 1.",size=8.5,width=114)
        y = heading(f,y-.004,"Begründetes Fazit und Grenzen")
        y = paragraph(f,y,"Zusätzliche Züge erhöhen zunächst den Durchsatz, ab N=36 überwiegend die Wartezeit. "
                      "Längere Halte verlängern die Umlaufzeit; ihr Stationsprofil beeinflusst Rückstaus. Die effektive "
                      "Geschwindigkeitsgrenze bündelt örtliche Limits und Fahrplanreserven und ist keine gemessene Fahrzeuggrenze. "
                      "Ideale Haltepunkte, identische Züge, konstante Beschleunigung und modellhafte Blöcke erklären verbleibende "
                      "Abweichungen. Das endliche, deterministische Messfenster beschreibt keine reale Streckenkapazität. "
                      "Ein guter Umlaufwert ersetzt die lokale Fahrzeitprüfung nicht.",size=8.5,width=114)
        y = heading(f,y-.003,"Änderungen, KI-Einsatz und Reproduktion")
        paragraph(f,y,"KI (Codex) unterstützte Codeübernahme, Geschwindigkeitsparametrisierung, Versuchsauswertung und "
                  "Bericht. Zahlen stammen aus ausgeführten MATLAB-Läufen; Regeln wurden durch Sanity Checks, "
                  "Regressionen und Modelltests geprüft. Start: SBahn2.m; Bericht: py tools/erstelle_bericht.py. "
                  "CSV/JSON, vollständige Laufdaten, Testprotokolle und Diagramme liegen unter ergebnisse/.",size=8.0,width=120)
        f.savefig(FIG / 'bericht_seite_3.png', dpi=130)
        pdf.savefig(f); plt.close(f)

    markdown = f"""# S-Bahn-Ring – Woche 2

## Aufgabe 1: Referenzabgleich

Vor der Anpassung gewählte Größen: Abfahrt Beusselstraße bis Rückkehrankunft (Kalibrierung) und die 27 reinen Abschnittsfahrzeiten (Prüfung). Die GTFS-Referenz beträgt 3558 s, Fahrt S41 `308542990` am 14.10.2026 von 08:03:24 bis 09:02:42. Es handelt sich um Sollbetrieb.

Die effektive Geschwindigkeitsgrenze wird in allen zulässigen ganzzahligen Stufen 14–22 m/s untersucht; alle anderen Parameter bleiben unverändert. Das kleinste absolute Residuum ergibt sich bei 16 m/s = 57,6 km/h: 3599 s (+41 s, +{fmt(float(after['error_percent']),2)} %). Vorher: 3131 s. Der volle Modellumlauf beträgt 3641 s; der Anfangshalt von 42 s wird zum Vergleich abgezogen. Die Innenhalte ergeben genau die 870 s der Referenz. Endpunkte werden nicht als Nullhalte behandelt.

Abschnittsvalidierung: MAE vorher {fmt(float(before['segment_mae_s']))} s, nachher {fmt(float(after['segment_mae_s']))} s; RMSE vorher {fmt(float(before['segment_rmse_s']))} s, nachher {fmt(float(after['segment_rmse_s']))} s. Keine Nachoptimierung auf diese Werte. Prüfung und Kalibrierung verwenden denselben Fahrplan, keine unabhängigen Ist-Messungen.

## Aufgabe 2: Parameterstudien

{conclusions}

![Zugzahlstudie](diagramme/zugzahl.png)

{dwell_conclusion}

![Haltezeitstudie](diagramme/haltezeit.png)

Bei der Zugzahlstudie bleiben die GTFS-Halte unverändert; bei der Haltezeitstudie sind alle Halte je Lauf gleich und N=36 bleibt fest. Zehn Zugzahlen und acht Haltezeiten, jeweils 60 min Einschwingen und 180 min Messung. Q ist die Zahl der Abfahrten an Station 1 im Intervall [3600,14400) geteilt durch 3 h. Blockierter Stillstand schließt geplante Stationshalte und langsames Folgen aus. Keine Zufallseinflüsse, deshalb ein deterministischer Lauf pro Parametersatz; `headway_std_s` ist die Streuung der beobachteten Zugabstände, keine Wiederholungsstreuung.

![Raum-Zeit-Diagramm](diagramme/raumzeit.png)

## Sanity Checks und Grenzen

{len(checks)} Läufe mit jeweils zwölf zusätzlichen Sanity Checks; {len(tests)} MATLAB-Tests bestanden. Grundregeln: Zugerhaltung, ganzzahlige Ringzustände, zulässige Geschwindigkeiten/Beschleunigungen, korrekte synchrone Ringbewegung, Kollisionsfreiheit, Stationshalt, Bremsreserve und unabhängig rekonstruierter Abfahrtsdetektor. Die Modellprüfungen aus Woche 1 kontrollieren außerdem Stationsreihenfolge, Mindesthalte und exklusive Blockbelegung samt Freigabe am Zugende. Zwei Regressionen vergleichen On/Off und Fahrdynamik bei Standardgeschwindigkeit mit dem Original aus Woche 1. `sanity_checks.csv` und `matlab_tests.csv` enthalten die Ergebnisse.

{limits}

## Code, Quellen und KI-Einsatz

Modellkern aus `../Woche 1/NaSch-SBahn/+sbahn` als lokales Paket `modell/+sbahn2`; die vier Bewegungsschritte und Blockregeln bleiben erhalten. Geändert wurden konfigurierbare effektive Geschwindigkeitsgrenze und Datenpfad. Quelldaten werden direkt aus Woche 1 gelesen. Das Original bleibt unverändert. `quellcode_herkunft.json` dokumentiert Hashes und betroffene Dateien.

VBB-GTFS, CC BY 4.0: https://unternehmen.vbb.de/digitale-services/datensaetze/ ; Gleisgeometrie © OpenStreetMap contributors, ODbL: https://www.openstreetmap.org/relation/14981 . Dokumentierter Abruf 14.10.2026; Herkunft, Rohdaten, Lizenzen und Geometriegrenzen im Daten-README aus Woche 1.

Codex unterstützte Übernahme und Erweiterung des MATLAB-Codes, Versuchsauswertung, Prüfungen und Text. Ergebnisse wurden in MATLAB R2026a ausgeführt, nicht aus Referenzwerten erfunden. Reproduktion: `SBahn2.m`, anschließend `py tools/erstelle_bericht.py`; vollständige Daten unter `ergebnisse/laeufe/`.
"""
    (OUT / "Ausarbeitung_SBahn2.md").write_text(markdown, encoding="utf-8")
    origin = ROOT.parent / "Woche 1" / "NaSch-SBahn" / "+sbahn"
    manifest = []
    for src in sorted(origin.rglob("*.m")):
        rel = src.relative_to(origin)
        dest = ROOT / "modell" / "+sbahn2" / rel
        original = src.read_text(encoding="utf-8-sig")
        local = dest.read_text(encoding="utf-8-sig")
        manifest.append({"file": rel.as_posix(), "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
                         "local_sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                         "changed_beyond_namespace": original.replace("sbahn.", "sbahn2.") != local})
    (OUT / "quellcode_herkunft.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Bericht (3 Seiten): {OUT / 'Ausarbeitung_SBahn2.pdf'}")
    print(f"MATLAB-Tests bestanden: {len(tests)}; geprüfte Auswertungsläufe: {len(checks)}")


if __name__ == "__main__":
    main()
