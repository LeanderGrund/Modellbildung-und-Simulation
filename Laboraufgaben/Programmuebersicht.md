# Programmübersicht: NaSch- und S-Bahn-Simulation

**Modellbildung und Simulation · Laboraufgaben · Stand: 28.10.2026**

Diese Übersicht erklärt Aufbau, Funktionsweise und Regeln der aktuell vorhandenen Programme in **Woche 1** und **Woche 2**. Die Wochen bezeichnen die jeweiligen Ordnerstände; Zwischenstände innerhalb einer Woche werden nicht als eigene Versionen rekonstruiert. Dateilinks beziehen sich auf den Ordner `Laboraufgaben`.

## 1. Wochenstände im Überblick

| Stand | Programm und Einstieg | Aufgabe und Besonderheiten |
| --- | --- | --- |
| Woche 1: NaSch-Street | `Woche 1/NaSch-Street/NaSch_demo.mlx` | Ursprüngliches Nagel-Schreckenberg-Modell auf einer periodischen Straße: Beschleunigen, Abstand halten, zufällig bremsen und fahren. |
| Woche 1: NaSch-SBahn | `Woche 1/NaSch-SBahn/SBahn_demo.mlx` | Erweiterung zum S-Bahn-Ring mit Stationen, Zugkörpern, Fahrdynamik, optionalen Blöcken und Störungen. Bedienung im MATLAB Live Editor. |
| Woche 2: S-Bahn-Auswertung | `Woche 2/SBahn2.m` | Übernommener S-Bahn-Kern mit einstellbarer effektiver Geschwindigkeitsgrenze, Kalibrierung, Parameterstudien, zusätzlichen Sanity Checks und gespeicherten Ergebnissen. |

### Ordnerstruktur

```text
Laboraufgaben/
  Woche 1/
    NaSch-Street/        ursprüngliches Straßenmodell
    NaSch-SBahn/
      SBahn_demo.mlx    interaktive Bedienoberfläche
      +sbahn/           S-Bahn-Modellkern mit private/-Funktionen
      tests/            Modelltests
      daten/            lokaler OSM-/GTFS-Datenstand
  Woche 2/
    SBahn2.m / run_sbahn2.m   Einstieg und Studien
    sanity_check.m      zusätzliche unabhängige Prüfungen
    modell/             Modellkern +sbahn2 und tests/
    tools/              Auswertung, Ergebnisprüfung, PDF-Erzeugung
    ergebnisse/         CSV, JSON, MAT, Diagramme und Ausarbeitung
```

**Wichtig für die Einordnung:** Fahrdynamik, Zuglänge, Blocksteuerung, GTFS-Stationshalte und zuschaltbare Störungen sind bereits im vorhandenen S-Bahn-Stand der Woche 1 enthalten. Woche 2 ergänzt vor allem die systematische Untersuchung und die Geschwindigkeitsparametrisierung.

Der Woche-2-Kern ist ein eigenes MATLAB-Paket `sbahn2`. Er liest die Quelldaten weiterhin aus Woche 1. Beide Wochenordner müssen daher zusammen erhalten bleiben. Der ursprüngliche Kern `sbahn` wird durch die Woche-2-Auswertung nicht verändert.

**PDF aktualisieren:** Im Ordner `Woche 2` den Befehl `py tools/markdown_zu_pdf.py ../Programmuebersicht.md` ausführen. Er erzeugt die PDF direkt aus dieser Markdown-Datei; benötigt werden Python mit `mistune` sowie ein lokaler Chrome- oder Edge-Browser.

**Weiterlesen:** [Modellbeschreibung Woche 1](<Woche 1/NaSch-SBahn/MODELL.md>) · [Datenherkunft und Lizenzen](<Woche 1/NaSch-SBahn/daten/ringbahn_2026-10-14/README.md>) · [Anleitung Woche 2](<Woche 2/README.md>) · [Sanity Checks](<Woche 2/sanity_check.m>) · [Ausarbeitung](<Woche 2/ergebnisse/Ausarbeitung_SBahn2.pdf>). Daten: VBB-GTFS und © OpenStreetMap contributors, Stand 14.10.2026.

## 2. Woche 1: ursprüngliches NaSch-Straßenmodell

### Aufbau und Daten

[`myInit.m`](<Woche 1/NaSch-Street/myInit.m>) erzeugt eine Straße mit `n` Zellen. Auf `round(density*n)` zufällig ausgewählten Zellen stehen Fahrzeuge mit Anfangsgeschwindigkeit null. Jedes Fahrzeug belegt genau eine Zelle und hat eine feste ID.

Der Zustand ist der komplexe Vektor `u`: `NaN` bedeutet freie Zelle, `real(u)` enthält die Geschwindigkeit und `imag(u)` die Fahrzeug-ID. Die Matrix `G` speichert aufeinanderfolgende Zustände; Zeilen entsprechen Zeitpunkten, Spalten Straßenpositionen.

```text
NaSch_demo.mlx
  myInit -> wiederholt myUpdate -> Zustände in G speichern
         -> myDrawnow zur Animation -> TimeSpacePlot zur Auswertung
```

### Die vier NaSch-Regeln

[`myUpdate.m`](<Woche 1/NaSch-Street/myUpdate.m>) bestimmt aus dem alten Zustand für jedes Fahrzeug den freien Abstand `d` als Anzahl leerer Zellen bis zum nächsten Fahrzeug. Danach gelten in dieser Reihenfolge:

1. **Beschleunigen:** `v = min(v + 1, vmax)`.
2. **Abstand halten:** `v = min(v, d)`; ein zuvor belegter Platz darf nicht erreicht werden.
3. **Zufällig bremsen:** Mit Wahrscheinlichkeit `brake` wird `v` um eine Stufe gesenkt, jedoch nicht unter null.
4. **Synchron bewegen:** Alle Fahrzeuge wechseln gemeinsam zu `x_neu = 1 + mod(x + v - 1, n)`.

Die Straße ist ein Ring: Hinter der letzten Zelle folgt die erste. Deshalb wird auch der Abstand zum ersten Fahrzeug über den Ringschluss berechnet. Fahrzeugzahl und IDs bleiben erhalten; Überholen oder doppelte Zellbelegung sind nicht vorgesehen. Eine leere Straße ist zulässig.

### Einstellungen und Grenzen

| Parameter | Standard in `myInit` | Im gespeicherten `NaSch_demo.mlx` |
| --- | --- | --- |
| Straßenlänge | 200 Zellen | 100 Zellen |
| Dichte | 0,2 | 0,5 |
| Zufallsbremswahrscheinlichkeit | 0,05 | 0 |
| Höchstgeschwindigkeit | 8 Zellen/Schritt | 5 Zellen/Schritt |

Das Live-Skript prüft die konstante Fahrzeugzahl. [`TimeSpacePlot.m`](<Woche 1/NaSch-Street/TimeSpacePlot.m>) zeigt Belegung, Fahrzeugtrajektorien und mittlere Geschwindigkeit. Die Werte sind zunächst **Zellen und Zeitschritte**; eine physikalische Zuordnung zu Metern und Sekunden wird hier nicht festgelegt.

Dieses Straßenmodell hat keine Stationen, Zuglängen oder Signalblöcke. Die Abstandsregel darf die Geschwindigkeit unmittelbar um mehrere Stufen reduzieren. Die spätere S-Bahn-Regel mit höchstens 1 m/s² Bremsverzögerung gilt hier nicht.

## 3. Woche 1: Aufbau des S-Bahn-Modells

### Bedienung und Programmablauf

[`SBahn_demo.mlx`](<Woche 1/NaSch-SBahn/SBahn_demo.mlx>) übernimmt die gewählten Einstellungen in `config` und ruft `[G,p,report] = sbahn.simulate(config)` auf. Animation, Zeit-Weg-Diagramm, Fahrdynamik und Kennzahlen erscheinen im Live-Skript. Geänderte Einstellungen wirken beim nächsten Start.

```text
simulate(config)
  prepare -> Strecke, Blöcke und Halteprofil laden -> initialize
  je Zeitpunkt: updateClosure -> Zustand speichern/anzeigen
                             -> advance, falls ein Schritt folgt
  summarizeRun -> verifyRun einschließlich verifyDisturbances
  Rückgabe: G, p mit letztem state, report
```

| Funktion im Paket `+sbahn` | Verantwortung |
| --- | --- |
| `defaultConfig`, `prepare` | Standards ergänzen, Eingaben prüfen und Modellparameter festlegen. |
| `loadRoute`, `loadDwellProfile`, `loadBlocks` | Strecke, geplante Stationshalte und Abschnittseinteilung laden. |
| `initialize` | Freien Referenzumlauf und zeitlich versetzte Startzustände berechnen. |
| `trafficLimits` | Freien Weg bis zum nächsten Zugende und fremdbelegten Block bestimmen. |
| `advance` | Einen gemeinsamen Bewegungsschritt sowie Ankünfte, Abfahrten und Halteuhren berechnen. |
| `updateClosure` | Zeitweise Zugangssperre und letzte Einfahrerlaubnisse verwalten. |
| `summarizeRun`, `verifyRun`, `verifyDisturbances` | Kennzahlen bilden und die gespeicherten Ergebnisse nachprüfen. |
| `drawState`, `plotResults`, `plotDynamics` | Animation, Raum-Zeit-Diagramm und Geschwindigkeit/Beschleunigung anzeigen. |

### Getrennte Datenbereiche

| Datenbereich | Inhalt |
| --- | --- |
| `p.config` | Tatsächlich verwendete Einstellungen. |
| `p.route`, `p.blocks` | Feste Strecken-, Stations- und Blockdaten. |
| `state`, am Ende `p.state` | Veränderliche Zugzustände; der Arrayindex ist die Zugnummer. |
| `state.position`, `state.velocity` | Zugspitze und Geschwindigkeit des letzten Schritts. |
| `state.waitSteps`, `extraWaitSteps` | Verbleibende gesamte bzw. zusätzliche Haltezeit. |
| `state.nextStation`, `dwellStation` | Nächste zu bedienende Station bzw. Station des laufenden Aufenthalts. |
| `G`, `report` | Vollständiger zeitlicher Verlauf bzw. daraus berechnete Kennzahlen und Prüfergebnis. |

`arrivalLog` und `departureLog` protokollieren Zeit, Zug und Station. `stopLog` ergänzt je Ankunft geplante, gezielte und zufällige Haltsekunden. `closureGraceLog` dokumentiert letzte Einfahrerlaubnisse.

**Initialisierung:** Ein freier Zug fährt mit derselben Funktion `advance` einen Referenzumlauf. Daraus werden zeitlich gleichmäßig versetzte Zugzustände einschließlich Geschwindigkeit und Resthaltezeit übernommen. Die Züge sind damit nicht zwingend räumlich gleichmäßig verteilt. Referenzumlauf und Anfangszustände enthalten keine Zusatzstörungen. Überlappende Körper, gemeinsam belegte Startblöcke oder fehlende Bremsreserven vor Zugenden führen zum Abbruch. Eine zu hohe Startgeschwindigkeit vor einer Blockgrenze wird abgesenkt.

## 4. Bewegungsregeln der S-Bahn: Woche 1 und Woche 2

Die folgenden Regeln gelten in beiden S-Bahn-Paketen. Woche 2 verändert die wählbare effektive Geschwindigkeitsgrenze, nicht die grundlegende Bewegungslogik.

### Ring, Raster und Zugkörper

| Größe | Regel |
| --- | --- |
| Strecke | Eine Fahrtrichtung auf einem geschlossenen Ring; 27 Stationen in fester Reihenfolge. |
| Zeit | Ein Rechenschritt entspricht 1 s. Animationstempo und Bildabstand ändern diese Zeit nicht. |
| On/Off-Modus | 2790 Zellen; Zelllänge = Ringlänge / 2790. Fahren mit 1 Zelle/Schritt oder Stillstand. |
| Dynamischer Modus | 1 m je Zelle; Streckenlänge und Stationspositionen werden auf Meterzellen gerundet. |
| Zugkörper | 148 m, auf ganze Zellen aufgerundet; die gespeicherte Position ist die Zugspitze. |
| Ringbewegung | `x_neu = 1 + mod(x + w - 1, N)`, mit Zellzahl `N` und neuer Geschwindigkeit `w`. |

Ein Zug mit Spitze `x` belegt `x, x-1, ..., x-l+1` modulo `N`, wobei `l` seine Zellenzahl ist. Zum vorausfahrenden Zug ist der freie Weg der Spitzenabstand minus `l`. Zugkörper dürfen sich nicht überlappen; es gibt weder Überholen noch Einsetzen oder Entfernen von Zügen während eines Laufs.

### Geschwindigkeitswahl je Sekunde

Alle Züge verwenden denselben **alten Zustand**. Der zulässige Weg `d` ist das Minimum aus Entfernung zur nächsten zu bedienenden Station, freiem Weg zum Zugende und gegebenenfalls zur begrenzenden Blockgrenze oder Zugangssperre.

Im **On/Off-Modus** gilt `w = min(1,d)`; während einer Haltezeit gilt `w = 0`. Sofortige Geschwindigkeitswechsel gehören zu dieser Modellannahme. Auf dem idealen Ring ergibt der freie Standardfall mit 30 s Halt je Station `2790 + 27*30 = 3600 s` pro Umlauf.

Im **dynamischen Modus** sind Geschwindigkeiten ganzzahlig in m/s. Es gelten maximal eine Stufe Beschleunigung und eine Stufe Bremsen je Sekunde. Der diskrete Bremsweg lautet:

```text
B(w) = w*(w+1)/2
w = min(v+1, vmax, floor((sqrt(1+8*d)-1)/2))
Zusätzliche Bedingung: w >= max(0,v-1)
Während eines geplanten oder zusätzlichen Halts: w = 0
```

Beispiel: Bei `w = 4 m/s` werden bei anschließendem Bremsen `4+3+2+1 = 10 m` benötigt. Diese Reserve muss vor einer Station oder einem Hindernis vorhanden sein. Ein Zustand, der nur stärkeres Bremsen zuließe, wird als unzulässig abgewiesen.

In beiden S-Bahn-Kernen bestimmt `cruiseSpeedKmh` die Obergrenze. Seit 28.10.2026 ist sie auch in `SBahn_demo.mlx` zwischen 3,6 und 80 km/h eingebbar. Die Eingabe gilt für „Beschleunigen und Bremsen“ und wird auf ganze m/s abgerundet: 60 km/h ergibt 57,6 km/h; 80 km/h ergibt 79,2 km/h. Die tatsächliche Geschwindigkeit bleibt abhängig von Stationen, Bremsweg und Verkehr. **Zufälliges NaSch-Bremsen ist in den S-Bahn-Kernen nicht implementiert.**

## 5. Stations-, Block- und Störungsregeln der S-Bahn

### Stationen und Haltezeiten

Jede Station muss in Fahrtrichtung bedient werden. Eine Station ist ein idealer Haltepunkt der Zugspitze. Im dynamischen Modus erfolgt der letzte Ankunftsschritt mit 1 m/s; im Folgeschritt steht der Zug. Dieser erste stationäre Schritt zählt bereits zur Haltezeit. Deshalb ist dort mindestens 1 s Stationshalt erforderlich; im On/Off-Modus sind auch Nullhalte zulässig.

Bei Ankunft wird die Halteuhr gesetzt. Solange sie positiv ist, bleibt die Position unverändert und die Uhr sinkt pro Schritt um eins. Erst danach darf der Zug wieder fahren, sofern der Fahrweg frei ist. Ankunftszeit ist das Ende des letzten Bewegungsschritts, Abfahrtszeit der Anfang des ersten erneuten Bewegungsschritts.

Es gibt einheitliche Halte oder **GTFS-Stationshalte**: je Station der Median gültiger Zwischenhalte aktiver S41-Fahrten am 14.10.2026. Tripanfang und -ende werden ausgeschlossen. Das Profil liegt bei 30–48 s, im Mittel 33,78 s; alle Züge verwenden dasselbe Profil. Die Daten beschreiben geplante Zeiten.

### Blocksteuerung

| Modus | Regel |
| --- | --- |
| Ohne Blocksteuerung | Stationshalt und Abstand zum Zugkörper bleiben wirksam. |
| Gleichmäßige Blockabschnitte | `ceil(Ringlänge/Zielabstand)` Abschnitte werden über den Ring verteilt. Gerundete Längen unterscheiden sich höchstens um eine Zelle. |
| OSM-Signalabschnitte | 117 gerichtete S41-Signalkandidaten bilden Abschnittsanfänge. Sie sind keine bestätigten betrieblichen Blockgrenzen. |

Ein Zug belegt jeden Block, den sein Körper berührt; er kann mehrere Blöcke zugleich belegen. Ein fremdbelegter Block darf nicht befahren werden. Die Weggrenze liegt eine Zelle vor dessen Anfang. Freigabe erfolgt erst nach vollständigem Verlassen durch das Zugende. Wegen der synchronen Aktualisierung ist ein gerade frei werdender Abschnitt erst im nächsten Schritt nutzbar.

### Drei zuschaltbare Störungen

- **Gezielter Zusatzhalt:** Die erste passende Ankunft des gewählten Zuges an der gewählten Station ab einem Mindestzeitpunkt erhält genau einmal die Zusatzdauer.
- **Zufälliger Zusatzhalt:** Je Ankunft eine Bernoulli-Entscheidung; bei einem Treffer wird eine ganzzahlige Zusatzdauer gleichverteilt zwischen Minimum und Maximum gezogen. Ein lokaler Zufallsstrom mit festem Startwert macht gleiche Einstellungen reproduzierbar.
- **Zeitweise Blocksperre:** Der Zugang zu einem Block wird im Intervall `[Beginn, Beginn+Dauer)` gesperrt. Bereits eingefahrene Züge können ausfahren. Wer beim Sperrbeginn nicht mehr mit höchstens 1 m/s² rechtzeitig stoppen kann, erhält einmalig eine letzte Einfahrt. Körper- und Blockbelegung gelten weiterhin.

Treffen gezielter und zufälliger Zusatz zusammen, werden sie addiert. Die Reihenfolge lautet: **geplanter Halt → Zusatzhalt → gegebenenfalls verkehrsbedingtes Warten**. Nach Sperrende gelten wieder die normalen Belegungsregeln.

**Gespeicherte Einstellungen beachten:** `sbahn.defaultConfig` schaltet alle drei Störungen aus. Das derzeit gespeicherte `SBahn_demo.mlx` setzt dagegen alle drei Schalter auf `true` und verwendet reale S41, Fahrdynamik, GTFS-Halte und OSM-Blöcke. Maßgeblich für einen konkreten Lauf ist immer `p.config`. Die Woche-2-Studien schalten alle Störungen ausdrücklich aus.

## 6. Woche 2: Kalibrierung und Parameterstudien

### Ergänzungen und Arbeitsablauf

[`SBahn2.m`](<Woche 2/SBahn2.m>) führt zuerst die Modelltests aus, ruft danach [`run_sbahn2.m`](<Woche 2/run_sbahn2.m>) und die ergänzende Ergebnisprüfung auf und erzeugt abschließend mit Python die Diagramme und die dreiseitige Ausarbeitung.

```text
SBahn2.m
  Modelltests -> run_sbahn2
    Versuchsplan -> Geschwindigkeitsraster -> Referenzprüfung
    -> Zugzahlstudie -> Haltezeitstudie
    je Auswertungslauf: simulate -> sanity_check -> Daten speichern
  pruefe_ergebnisse -> erstelle_bericht.py -> Ausarbeitung und Diagramme
```

`modell/+sbahn2` übernimmt den Woche-1-Kern. Sechs Dateien ergänzen Geschwindigkeitsgrenze, Datenpfad, geplanten Haltezuschlag und optionale Suche nach gültigen Startphasen. Die Kernstandards bleiben 80 km/h, +0 s und die bisherige Initialisierung; die Studien aktivieren die Phasensuche. Sie verschiebt bei Bedarf alle freien Zugphasen gemeinsam, bis Körper-/Blockbelegung und Bremsreserven gültig sind. Zugzahl, zeitliche Phasenabstände und Blocklängen bleiben erhalten.

### Kalibrierung und getrennte Prüfung

Ein freier Zug auf der realen S41 wird auf **Abfahrt Beusselstraße bis Rückkehrankunft** abgestimmt. Alle neun Stufen 14–22 m/s werden vollständig simuliert. Minimiert wird der absolute Fehler gegenüber 3558 s aus dem lokalen GTFS-Beispieltrip `308542990`. Die reinen Fahrzeiten der 27 Stationsabschnitte dienen anschließend zur Prüfung. Die neue [Geschwindigkeitsgrafik](<Woche 2/ergebnisse/diagramme/geschwindigkeitsgrenze.png>) zeigt Referenz, Fahrzeit, Fehler und Optimum.

| Vergleich | Vorher | Nach Kalibrierung |
| --- | --- | --- |
| Effektive Geschwindigkeitsgrenze | 79,2 km/h | 57,6 km/h = 16 m/s |
| Abfahrt bis Rückkehrankunft | 3131 s | 3599 s; Fehler +41 s bzw. +1,15 % |
| Mittlerer absoluter Abschnittsfehler | 15,8 s | 8,0 s |

Der vollständige freie Modellumlauf beträgt danach 3641 s. Für den Referenzvergleich wird der 42-s-Halt an der Startstation abgezogen: `3641-42=3599 s`. Der unbekannte Endpunkthalt des GTFS-Beispiels wird nicht als Nullhalt behandelt. Die effektive Geschwindigkeitsgrenze bündelt unter anderem örtliche Limits und Fahrplanreserven; sie ist keine gemessene Fahrzeughöchstgeschwindigkeit.

### Die beiden Studien

Die Studie verwendet Fahrdynamik, reale S41, 148-m-Züge und 74 gleichmäßige Modellblöcke zu 499–500 m. Alle Störungen und die Animation sind ausgeschaltet. Je Lauf gelten 60 min Einschwingen und 180 min Messung.

- **Zugzahl:** 12, 16, 20, 24, 28, 32, 36 und 40; Start bei N=12, als grüner Stern markiert. Das GTFS-Profil bleibt unverändert. Bei N=36: 32,0 Züge/h und 226,4 s blockierter Stillstand je Zug und Stunde.
- **Haltezuschlag:** GTFS plus 0, 6, 12, 18, 24 oder 30 s an jeder Station, durchgehend N=36. GTFS+0 ist bitgenau identisch zum N=36-Fall der Zugzahlstudie; violette Rauten markieren diesen gemeinsamen Punkt. Bei GTFS+30: 25,3 Züge/h und 357,0 s Stillstand je Zug und Stunde. Beide Diagramme verwenden gleiche Achsenskalierungen.

## 7. Auswertung, Prüfungen und Bedienhinweise

### Was die Kennzahlen bedeuten

- **Durchsatz:** Abfahrten an Station 1 im Messintervall `[3600,14400)` s, geteilt durch 3 h. Ein zusätzlich gezähltes Ereignis entspricht 0,33 Zügen/h.
- **Freier Referenzdurchsatz:** `3600*Zugzahl/freieUmlaufzeit`; Wechselwirkungen können den tatsächlich gemessenen Durchsatz senken.
- **Blockierte Zugsekunden:** Stillstand wegen fehlenden Fahrwegs nach Ablauf der Haltezeit. Geplante und zusätzliche Stationshalte werden getrennt gezählt; langsames Folgen ist kein blockierter Stillstand.
- **Zugfolge:** Abstand aufeinanderfolgender Abfahrten an Station 1. `headway_std_s` ist deren zeitliche Streuung, keine Streuung zwischen Wiederholungsläufen.
- **Gemessene Halte-/Umlaufzeiten:** Es zählen vollständig beobachtete Ereignisse. Bei zu kurzen Läufen kann ein Kennwert `NaN` sein.

Ohne Zufallseinflüsse genügt in den Woche-2-Studien ein deterministischer Lauf je Einstellung. Bei Untersuchungen mit zufälligen Einflüssen fordert das Aufgabenblatt mindestens zehn Läufe je Parametersatz mit Mittelwert und Streuung.

### Wo welche Prüfungen stattfinden

| Zeitpunkt / Stand | Prüfungen |
| --- | --- |
| Vorbereitung, beide S-Bahn-Kerne | Gültige Einstellungen, eindeutige Stationen, geschlossener Ring, zulässige Haltezeiten und Startbelegungen. |
| Bewegung, beide S-Bahn-Kerne | Körper-/Blockbelegung aus altem Zustand; im dynamischen Modus ausreichende Bremsreserve ohne unzulässigen Bremsschritt. |
| Nach jedem Lauf, beide S-Bahn-Kerne | `verifyRun` und `verifyDisturbances`: Zugerhaltung, Geschwindigkeiten, Bewegung, Stationsreihenfolge, Mindesthalte, exklusive Blöcke, Störungen und Sperreintritte. |
| Zusätzlich in Woche 2 | `sanity_check` rekonstruiert Grundregeln aus `G` einschließlich synchroner Bewegung und unabhängigem Abfahrtsdetektor; `pruefe_ergebnisse` prüft absichtlich falsche Positionen/Geschwindigkeiten sowie einzelne Messstunden. |

**71 MATLAB-Tests bestehen** (65 aus Woche 1, sechs aus Woche 2), außerdem zwölf Prüfgruppen für je 25 neu berechnete Läufe. 377 Kennzahlen, Raum-Zeit-Koordinaten und der gemeinsame Betriebspunkt sind gegen Rohdaten geprüft. MATLAB gibt die Kurven als `results.plotData` zurück; Python zeichnet die Vektoren aus `diagrammdaten.mat` unverändert. `laufverzeichnis.csv` benennt die aktuellen Läufe.

### Starten und Ergebnisse finden

Woche 1: Das gewünschte `.mlx` im MATLAB Live Editor öffnen, Einstellungen prüfen und starten. Woche 2: `Woche 2/SBahn2.m` ausführen. Die Simulation benötigt MATLAB; die Berichterzeugung zusätzlich Python mit `numpy`, `scipy` und `matplotlib`.

Woche 1 zeigt Ergebnisse im Live-Skript/Workspace. Woche 2 speichert zusätzlich Läufe unter `ergebnisse/laeufe/`, Tabellen, Parameter, Diagramme und Ausarbeitung. Erneutes Ausführen ersetzt diese Ergebnisdateien.

**Modellgrenzen:** Eine Fahrtrichtung, ideale Haltepunkte, identische Züge und vereinfachte Blocklogik. Keine Weichen, Fahrstraßen, ZBS-Detailsteuerung, Fahrplanregelung, abschnittsweisen Geschwindigkeitsprofile oder real gemessenen Störungsraten. GTFS liefert Sollzeiten; OSM liefert kartierte Geometrie und ungeprüfte Signalkandidaten. Die Auswertung beschreibt den untersuchten Modellbereich und keine nachgewiesene reale Streckenkapazität.

