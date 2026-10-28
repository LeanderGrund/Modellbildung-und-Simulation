S-Bahn-Simulation für Aufgabe 2.2

EINSTIEG UND BEDIENUNG
SBahn_demo.mlx im MATLAB Live Editor öffnen. Einstellungen auswählen und
„Simulation starten“ drücken; alternativ das gesamte Live-Skript ausführen.
Änderungen an Steuerelementen starten keine Berechnung. Animation,
Diagramme, Kennzahlen und Modellprüfungen erscheinen im Live-Skript.
Der Projektpfad wird beim Start automatisch eingebunden. Nach der Animation
werden die tatsächlich verwendeten Einstellungen angezeigt. MATLAB Stop
bricht einen Lauf ab. Die zuletzt gespeicherten Einstellungen bleiben erhalten.

DIE DREI DATENBEREICHE
p.config: tatsächlich verwendete Einstellungen.
p.route: feste Strecke, Stationen, Rasterpositionen und Quelldaten.
p.state: letzter Zustand aller Züge; der Arrayindex ist die Zugnummer.
Zum Beispiel p.state.position(3), p.state.velocity(3) und
p.state.waitSteps(3) gehören zu Zug 3. Es gibt keine komplex codierte
Belegungsmatrix mehr. G enthält die Trajektorien, report die Kennzahlen.

ABLAUF IM MODELLKERN
simulate: einmal vorbereiten, Zeitschritte rechnen, auswerten und prüfen.
prepare: Einstellungen prüfen, Strecke und Halteprofil einmal laden.
initialize: zeitlich gleichmäßig verteilte Startzustände bestimmen.
advance: alle Züge gleichzeitig bewegen, Halte und Ankünfte behandeln.
summarizeRun: Kennzahlen berechnen. verifyRun: unabhängig nachprüfen.
Der Referenzumlauf verwendet dieselbe Funktion advance wie der eigentliche
Lauf. Er bleibt deterministisch. Weitere Erklärungen stehen in MODELL.md.

FAHRMODELLE
On/Off: Vergleich mit 2790 Fahrzellen, Δt = 1 s und
Δx = Streckenlänge / 2790. Bei 27 Halten zu 30 s beträgt der freie
Umlauf 3600 s; zwölf Züge ergeben 300 s Referenzzugfolge.

Beschleunigen und Bremsen: Δx = 1 m, Δt = 1 s, ganzzahlige Geschwindigkeit.
Pro Schritt höchstens ±1 m/s, also höchstens ±1 m/s². Die höchste Stufe
unter 80 km/h ist 22 m/s = 79,2 km/h. Der diskrete Bremsweg ist
B(v) = v(v+1)/2. Vor Stationen, Zugenden und gesperrten Blockanfängen muss diese
Reserve vorhanden sein. Mindestens 1 s Stationshalt ist erforderlich.
Die Umlaufzeit wird nicht auf 60 Minuten erzwungen: ideal mit 30-s-Halten
3078 s; reale S41 mit GTFS-Halten 3173 s. Das sind freie Referenzwerte.

HALTEZEITEN UND REALDATEN
Einheitliche Halte oder GTFS-Stationshalte sind auswählbar. GTFS benötigt
die reale S41 und verwendet je Station den Median gültiger Zwischenhalte
am 14.10.2026. Tripanfang und Tripende sind ausgeschlossen. Die Halte
betragen 30–48 s, zusammen 912 s; es sind geplante Zeiten, keine Ist-Daten.
Alle Züge verwenden dasselbe geplante Profil. Zuschaltbare Zusatzhalte
werden bei der jeweiligen Ankunft zusätzlich vergeben. In der Animation markiert Orange blockierten Stillstand nach Ablauf
des geplanten Halts; langsames Folgen zählt nicht als blockierte Zugsekunde.

Der lokale Datenstand liegt in daten/ringbahn_2026-10-14. S41 beginnt an
Beusselstraße. Im neuen Fahrmodell wird die Ringlänge von 36971,599 m
auf 36972 m gerundet; Stationsrundungen betragen höchstens 0,5 m.
Die geografische Animation verwendet die unveränderte lokale Geometrie,
ohne Online-Karten oder zusätzliche Toolboxes. Quellen und Lizenzen stehen
im README.md des Datenordners; dessen Einleitung beschreibt den damaligen
separaten Datenabruf. Der heutige Modellstand ist hier dokumentiert.

DATEIEN UND GRENZEN
SBahn_demo.mlx ist die einzige Bedienoberfläche. +sbahn enthält den
gemeinsamen Modellkern; tests die MATLAB-Tests. MODELL.md erklärt die
Regeln und Prüfungen, WEITERENTWICKLUNG.md die nächsten Schritte. PDF, Quelldaten und vorhandene Ergebnisse bleiben erhalten.
Es gibt keine automatische Laufaufzeichnung oder Versionsauswahl.
Züge sind 148 m lang; im groben On/Off-Raster wird auf ganze Zellen aufgerundet.
Stationen bleiben ideale Haltepunkte der Zugspitze. Im Live-Skript stehen
drei Blockoptionen bereit: Ohne Blocksteuerung, Gleichmäßige Blockabschnitte
und OSM-Signalabschnitte. Der Ziel-Blockabstand wirkt nur bei gleichmäßigen
Abschnitten. OSM verwendet 117 unbestätigte Signalkandidaten der realen S41.
Die Anzahl und tatsächlichen Längen werden nach dem Start angezeigt.
Ein Abschnitt wird erst nach vollständiger Räumung durch das Zugende frei.
Ungültige Startbelegungen werden mit einer Erklärung abgewiesen.
Reale Stellwerkslogik, Streckengeschwindigkeiten und zufälliges Bremsen
sind noch nicht modelliert. Voraussetzung: MATLAB R2026a.

BEISPIELE FÜR BLOCKBEDINGTE WARTEZEITEN
Reale S41, GTFS-Halte, Beschleunigen und Bremsen, jeweils 20 Minuten:
20 Züge und gleichmäßige 1000-m-Zielblöcke: 29 blockierte Zugsekunden.
30 Züge und OSM-Signalabschnitte: 1161 blockierte Zugsekunden.
Die Angaben gelten für den deterministischen Modellstand ohne Zufallsstörungen.
Zu lange Blöcke können bereits die zeitlich verteilten Startzüge gemeinsam
belegen; dann bitte Zugzahl oder Zielabstand reduzieren.

STÖRUNGEN IM LIVE-SKRIPT
Die drei Funktionen stehen im Abschnitt „Störungen auswählen“ und sind
anfangs ausgeschaltet. Sie können unabhängig kombiniert werden:
Gezielter Zusatzhalt: Zug, Station, frühester Zeitpunkt und Zusatzdauer.
Zufällige Zusatzhalte: Wahrscheinlichkeit pro Ankunft, Dauerbereich und Startwert.
Zeitweise Blocksperre: Blocknummer, Beginn und Dauer; benötigt Blocksteuerung.
Alle Störungszeiten sind Sekunden. Die Vorgaben sind Versuchswerte.
In der Animation markiert Violett Zusatzhalte und gesperrte Blockzugänge.
Die Störungsauswertung zeigt vergebene und beobachtete Zusatzzeiten sowie
gewöhnliche Blockwartezeiten und Sperrwartezeiten getrennt. Details der
Zusatzhalte stehen in p.state.stopLog. Der freie Referenzumlauf bleibt unverändert.
Die Sperre lässt bei Beginn bereits unvermeidbare Einfahrten einmalig zu;
andere Züge bremsen regulär davor. Das ist ein vereinfachtes Sperrmodell.

RAUM-ZEIT-AUSWERTUNG
Die Übersicht und der Detailausschnitt verwenden dieselbe Geschwindigkeitsskala
von 0 bis 80 km/h: Orange ist Stillstand, Blau schnelle Fahrt. Zugfarben und
dichte Haltepunktketten entfallen. „Auswertungszug für Diagramme“ wählt eine
schwarz hervorgehobene Trajektorie und den Zug für das Fahrdynamikdiagramm.
Rauten markieren Zusatzhalt-Ereignisse; eine gestrichelte schwarze Spur zeigt
einen gesperrten Blockzugang während des gewählten Zeitfensters.
Der Detailausschnitt folgt einem relevanten Ereignis und verbindet dabei
auch benachbarte Positionen über den Ringübergang. Die mittlere Geschwindigkeit
aller Züge erscheint separat. Die Simulation wird durch diese Auswahl nicht verändert.
