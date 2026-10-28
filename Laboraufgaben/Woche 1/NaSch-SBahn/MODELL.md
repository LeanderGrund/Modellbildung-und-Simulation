# Fahrdynamik, Zugkörper und Blockabschnitte

## Raster und Einheiten

Δx = 1 m und Δt = 1 s. Die Zellposition ist MATLAB-typisch einsbasiert;
die physikalische Ringposition ist (x − 1) Meter. Die Streckenlänge wird
auf ganze Meter gerundet. Die unveränderte Quelllänge bleibt gespeichert.
Für S41 beträgt die Längenänderung +0,401 m; Stationsrundungen betragen
höchstens 0,5 m. Die geografische Anzeige skaliert entlang der Quellgeometrie.

Die Geschwindigkeit v ist die ganzzahlige Meterzahl des letzten Schritts.
Eine Stufe entspricht 1 m/s = 3,6 km/h. Die höchste Stufe ist 22 m/s
(79,2 km/h), da die Grenze von 80 km/h nicht überschritten werden darf.
Beschleunigung und Bremsverzögerung sind mit höchstens 1 m/s² angesetzt.
Dies sind vereinfachte Modellparameter, keine Anpassung an einzelne Fahrten.

## Gemeinsamer Bewegungsschritt

Für jeden Zug werden aus dem alten Zustand der Abstand zur nächsten Station
und der freie Weg zum vorausfahrenden Zugende beziehungsweise zum nächsten
fremdbelegten Block berechnet. Eine belegte Zelle oder gesperrte Blockgrenze
darf nicht erreicht werden. Die Positionsangabe bezeichnet die Zugspitze.

Mit d als kleinstem dieser Abstände wird die größte ganze Zahl w
gewählt, die beide Bedingungen erfüllt:

    max(0, v − 1) ≤ w ≤ min(v + 1, 22)
    B(w) = w(w + 1)/2 ≤ d

Die direkte Berechnung lautet:

    w = min(v + 1, 22, floor((sqrt(1 + 8d) − 1)/2))

Danach wird geprüft, dass w ≥ max(0,v − 1). Bei einer Verletzung wird
abgebrochen; ein unzulässig starker Bremsschritt wird nicht kaschiert.
Die neue Position ist 1 + mod(x + w − 1, N). Alle Züge werden gleichzeitig
aktualisiert. Eine zusätzliche Zufallsbremsung findet nicht statt.

Die Bremswegformel zählt die tatsächlichen diskreten Wege bis zum Stillstand:
bei w = 4 sind das 4 + 3 + 2 + 1 = 10 m. Nach dem ersten Schritt ist
die Reserve für den folgenden Bremsschritt weiterhin vorhanden.

## Stationen und Haltezeiten

Der Stationsabstand bezieht sich immer auf die nächste zu bedienende Station
in Fahrtrichtung. Sie darf nicht übersprungen werden. Der letzte Schritt
zur Station ist höchstens 1 m lang, weil B(w) ≤ d und eine Ankunft w = d
für positives w nur bei w = 1 gleichzeitig zulassen.

Im Folgeschritt steht der Zug; die gespeicherte Geschwindigkeit fällt von
1 auf 0. Dieser erste Schritt ohne Bewegung zählt bereits zur Haltezeit.
Nach genau der vorgegebenen Anzahl stationärer Schritte darf der Zug wieder
anfahren. Mindestens eine Sekunde Halt ist für einen vollständigen Stopp
erforderlich. Nullhalte werden in diesem Modus verständlich abgewiesen;
im On/Off-Vergleich bleiben sie zulässig.

Ankunftszeit ist das Ende des letzten Bewegungsschritts. Abfahrtszeit ist
der Anfang des ersten erneuten Bewegungsschritts. Bei Verkehrsblockierung
kann der tatsächliche Aufenthalt länger werden als der geplante Halt.

## Anfangszustand und Auswertung

Ein einzelner Zug wird zunächst über einen vollständigen freien Umlauf
gerechnet. Daraus werden zeitlich gleichmäßig versetzte Startphasen für
alle Züge entnommen, einschließlich Geschwindigkeiten und Resthaltezeiten.
Überlappende Startpositionen und unzureichende anfängliche Bremsreserven
werden abgewiesen. Die freie Referenzzugfolge ist Umlaufzeit / Zugzahl.

Geschwindigkeits- und Beschleunigungsdiagramme verwenden die gespeicherten
Ein-Sekunden-Schritte. Physikalische Geschwindigkeiten entstehen aus
Zellen/Schritt × Δx/Δt; Beschleunigungen aus deren Differenz / Δt.
Ausgaben dokumentieren das tatsächlich verwendete Fahrmodell.

## Zuglänge und ideale Stationen

Alle drei Blockmodi verwenden dieselbe Zuglänge von 148 m. Als Referenz
dienen zwei BR 484 mit je 73,6 m Länge über Kupplung: 147,2 m werden auf
148 Meterzellen aufgerundet. Quelle: [S-Bahn Berlin, Fahrzeugdaten](https://sbahn.berlin/das-unternehmen/fahrzeugpark/die-neue-s-bahn/).
Die Station bleibt ein idealer Haltepunkt der Zugspitze; reale Bahnsteig-
und Haltemarkerlängen werden nicht modelliert.

Ein Zug mit Spitze x belegt die Zellen x, x−1, …, x−l+1, jeweils modulo N.
Zwischen zwei Spitzen beträgt der freie Fahrweg Spitzenabstand − l. Der
Körper reicht am Ringanfang korrekt in das Ringende zurück. Im groben
On/Off-Raster gilt l = ceil(148/Δx); die effektive Länge ist dort etwas
größer als 148 m und wird angezeigt. Das On/Off-Raster und die freie
Standardumlaufzeit von 3600 s bleiben erhalten.

## Drei Blockmodi

* **Ohne Blocksteuerung:** Nur Körperabstand und Stationshalt begrenzen die Fahrt.
* **Gleichmäßige Blockabschnitte:** Anzahl = ceil(Ringlänge / Zielabstand).
  Die Grenzen werden gleichmäßig verteilt und auf Zellen gerundet. Alle
  Zellen gehören zu genau einem Block, auch am Ringübergang. Die tatsächlichen
  Abschnittslängen unterscheiden sich höchstens um eine Zelle; es entsteht
  kein kurzer Restblock. Der Zielabstand wirkt ausschließlich in diesem Modus.
* **OSM-Signalabschnitte:** 117 gerichtete Haupt-/Mehrabschnittssignale des
  lokalen S41-Datenstands dienen als Abschnittsanfänge. Es werden keine
  zusätzlichen Grenzen am Ringanfang oder an Stationen erfunden. Die
  Signalkandidaten und ihre Einzelquellen liegen in `s41_signalkandidaten.csv`.
  Sie sind ausdrücklich keine bestätigten betrieblichen Blockgrenzen.

Jeder Block umfasst seine Anfangszelle bis vor die nächste Anfangszelle.
Ein Zug belegt alle Blöcke, die sein Körper berührt; auch Blöcke unter 148 m
sind zulässig. Bei fremder Belegung endet der freie Fahrweg eine Zelle vor
deren Anfang. Die unveränderte Bremswegformel wird mit diesem zusätzlichen
Limit verwendet. Ein frei werdender Block ist wegen der synchronen
Aktualisierung erst im nächsten Schritt nutzbar. Das Zugende muss die letzte
Zelle vollständig verlassen haben. Es gibt keine zusätzliche Freigabeverzögerung.

Die Zeitphasen der Startpositionen sind in allen Modi gleich. Körperüberlappung,
unzureichende Bremsreserve hinter Zugenden und gemeinsam belegte Startblöcke
werden verständlich abgewiesen. Eine vor einem gesperrten Block zu hohe
Startgeschwindigkeit wird abgesenkt; die Positionen werden dabei nicht
verschoben. Dieser Anfangseffekt wird nicht als Stationsverspätung ausgegeben.
Die freie Referenzumlaufzeit wird mit einem einzelnen Zug berechnet und
enthält keine Wartezeit durch andere Züge oder Blöcke.

## Darstellung, Kennzahlen und Grenzen

Dicke Linien zeigen die Zugkörper, kleine Punkte die Spitzen. Kleine grüne
oder rote Punkte markieren freie beziehungsweise belegte Blockanfänge.
Orange Züge stehen nach Ablauf ihrer geplanten Haltezeit vor einem Zugende
oder einem gesperrten Block. Langsames Folgen zählt nicht als blockierte
Zugsekunde. `G.signalBlocked` und `report.signalBlockedTrainSeconds` weisen
den Anteil vor belegten Blöcken aus; dieser ist Teil der gesamten blockierten
Zugsekunden. Geplante Stationshalte werden dabei nicht mitgezählt.

Die Regel unterstellt bei fremder Belegung vorsichtshalber Stillstand.
Fahrstraßen, Weichen, Durchrutschwege, tatsächliche Gleisfreimeldegrenzen,
Signalbilder und ZBS werden nicht nachgebildet. Die 48 OSM-Kandidaten ohne
Funktionsunterklasse werden mitverwendet, weil Haupt-/Mehrabschnittssignaltyp
und Richtung vorhanden sind; Vorsignale und reine Geschwindigkeitstafeln
werden nicht als Grenzen verwendet. Die Betriebseigenschaften sind ungeprüft.

Die globale Geschwindigkeitsgrenze, idealen Stationen und das bisherige
Halteprofil bleiben bestehen. Abschnittsgeschwindigkeiten, zufälliges Bremsen
und Fahrplankalibrierung folgen später. Die Umlaufzeit wird nicht auf
60 Minuten erzwungen. Das Raster beschreibt diskrete Wege pro Sekunde.

## Den Programmablauf erklären

Die Bedienung bleibt vollständig in `SBahn_demo.mlx`. Intern ist der Ablauf:

    simulate
      prepare → Strecke, Blöcke und Halteprofil laden, initialize aufrufen
      advance → einen Zeitschritt für alle Züge berechnen
      summarizeRun → Ereignisse und Trajektorien auswerten
      verifyRun → Ergebnisse unabhängig prüfen

`p.config` enthält die Einstellungen, `p.route` die Streckendaten. Die
Veränderungen je Zug stehen in einem eigenen `state`: Position,
Geschwindigkeit, Resthaltezeit, nächste Station und Haltestation. Der
Arrayindex ist immer die Zugnummer. Am Ende steht dieser Zustand als
`p.state` im Workspace. Die Ereignislisten liegen entsprechend unter
`p.state.arrivalLog` und `p.state.departureLog`.

`initialize` lässt einen einzelnen Zug mit derselben Funktion `advance`
einen freien Umlauf fahren. Danach werden gleichmäßig verteilte Zeitpunkte
als Startzustände gewählt. Es gibt keine zweite Implementierung von
Ankunft und Stationshalt. Der Referenzumlauf enthält keine Zufallsstörungen.

`loadBlocks` erzeugt die gewählte Abschnittseinteilung. In `advance`
berechnet `trafficLimits` genau einmal aus den alten Zugkörpern und dem
Blockbesitz die räumliche Reihenfolge und den freien Fahrweg. Das Ergebnis
hat benannte Felder: `distance`, `bodyDistance`, `blockDistance`,
`blockOwner` und `order`. Es müssen keine positionsabhängigen Ausgaben
mehr zwischen Bewegung, Initialisierung und Darstellung zugeordnet werden.

Der Bewegungsschritt hat drei Teile:

1. Fahrweg zur nächsten Station mit dem freien Fahrweg kombinieren und
   die reguläre Geschwindigkeit wählen. Wartende Züge erhalten 0.
2. Alle Positionen, zurückgelegten Wege und Halteuhren gemeinsam aus dem
   alten Zustand fortschreiben. Blockierungen bleiben getrennt vom Stationshalt.
3. Nur für bewegte Züge Abfahrten und Ankünfte behandeln. Bei einer Ankunft
   werden Halteuhr, Haltestation und nächste Station gesetzt. Die bisherige
   Ereignisreihenfolge nach alter Position bleibt erhalten.

Eine zusätzliche Vollberechnung desselben Fahrwegs nach der Bewegung
entfällt. Der folgende Schritt prüft seine Eingangsbelegung; `verifyRun`
prüft weiterhin alle gespeicherten Zustände einschließlich des Endzustands
unabhängig von der Bewegungsberechnung.

## Drei zuschaltbare Störungen

Alle Funktionen sind im Live-Skript zunächst ausgeschaltet. Die Vorgaben sind
frei gewählte Versuchswerte, keine empirisch bestimmten Betriebsparameter.

* **Gezielter Zusatzhalt:** Zugnummer, Stationsnummer, frühester Ankunftszeitpunkt
  und Zusatzdauer sind einstellbar. Genau die erste passende Ankunft erhält
  den Zusatz. Ein beim Simulationsstart bereits laufender Halt zählt nicht.
  Vorgaben: Zug 1, Station 1, ab 900 s, zusätzlich 300 s.
* **Zufällige Zusatzhalte:** Pro Ankunft wird einmal eine Bernoulli-Entscheidung
  getroffen. Bei einem Treffer ist die Zusatzdauer ganzzahlig gleichverteilt
  zwischen Minimum und Maximum einschließlich beider Grenzen. Vorgaben:
  Wahrscheinlichkeit 0,05, Dauer 30–120 s, Zufallsstartwert 42.
* **Zeitweise Blocksperre:** Ein gewählter Blockzugang ist im Intervall
  [Start, Start + Dauer) gesperrt, unabhängig davon, ob der Block belegt ist.
  Vorgaben: Block 1, Beginn 900 s, Dauer 300 s. Blocksteuerung muss aktiv sein.

Gezielter und zufälliger Zusatz werden bei gemeinsamem Auftreten addiert.
Die Halteuhr umfasst geplanten Halt und Zusatz; zuerst läuft der geplante
Anteil ab, danach der Zusatz. Erst anschließend können Verkehrsblockierungen
die Abfahrt weiter verzögern. `extraWaitSteps` enthält den noch verbleibenden
Zusatz. Eine Störung würfelt nicht in jedem Warteschritt erneut.

Die Simulation erzeugt einen eigenen `RandStream` mit dem gewählten Startwert.
Die globale MATLAB-Zufallsfolge bleibt unverändert. Die Ereignisreihenfolge
ist weiterhin nach alten Zugpositionen sortiert und damit unabhängig von
Animation, Bildpause und Darstellung. Gleiche Einstellungen einschließlich
Startwert reproduzieren den Lauf; veränderte Einstellungen können auch die
spätere Reihenfolge der Zufallsziehungen verändern.

`initialize` ruft `advance` ohne Zufallsstrom auf. Die eigentliche Simulation
übergibt ihren lokalen Strom. Damit bleiben Referenzumlauf und Startphasen
störungsfrei; tatsächliche Umläufe können durch Störungen länger werden.

## Sichere Aktivierung und Aufhebung einer Blocksperre

`updateClosure` aktualisiert vor jedem aufgezeichneten Zeitschritt die Sperre.
Vor dem gesperrten Zugang ist der freie Weg d = Abstand zur Anfangszelle − 1.
Liegt die Spitze bereits auf der Anfangszelle, gilt der nächste Umlauf als
nächste Einfahrt. Bereits eingefahrene Züge können den Abschnitt verlassen.
Auch ein einziger Block über den ganzen Ring kann am nächsten Eintritt
gesperrt werden.

Bei Aktivierung wird für das dynamische Modell geprüft, ob der Zug noch mit
höchstens 1 m/s² stoppen kann: B(max(v−1,0)) ≤ d. Ist das nicht möglich,
erhält er genau eine letzte Einfahrt. Diese Erlaubnis wird beim Überfahren
der Anfangszelle verbraucht; beim nächsten Umlauf gilt die Sperre wieder.
Die tatsächliche Blockbelegung und der Körperabstand gelten auch mit Erlaubnis.
Im On/Off-Modell ist unmittelbares Stoppen ohnehin Teil der Modellannahme.

Nach Ende des Zeitfensters wird die Zusatzgrenze aufgehoben. Die normale
Block- und Körperbelegung bleibt maßgeblich. Das bildet eine vorübergehende
Zugangssperre ab, keine reale Signalstörung mit Fahrdienstleiter, Ersatzsignal,
Fahrt auf Sicht oder weiteren betrieblichen Verfahren.

## Darstellung und Störungsauswertung

Violette Züge zeigen tatsächlich laufende Zusatzhalte; ein violetter Blockpunkt
zeigt einen zeitweise gesperrten Zugang. Diese Zustandsfarben gelten
ausschließlich in der Animation; die Raum-Zeit-Auswertung verwendet die
Geschwindigkeit als gemeinsame Farbgröße. Ein Zug, der für einen Zusatzhalt noch seinen geplanten Halt
abwartet, wird bis zum Beginn des Zusatzanteils als normaler Stationshalt gezeigt.

`p.state.stopLog` enthält für jede Ankunft sechs Spalten:

    Ankunft_s | Zug | Station | Geplant_s | Gezielter_Zusatz_s | Zufallszusatz_s

`arrivalLog` und `departureLog` behalten ihre bisherigen drei Spalten.
`closureGraceLog` enthält Sperrbeginn, Zug und Block jeder letzten Einfahrerlaubnis.
Das Live-Skript zeigt Summen und höchstens die ersten 20 Zusatzhalte; alle
Ereignisse bleiben im Workspace verfügbar. Es werden keine Laufdateien gespeichert.

Zugewiesene Zusatzsekunden zählen auch am Simulationsende unvollständige Halte.
Beobachtete Zusatzhalte zählen ausschließlich tatsächlich simulierte Sekunden
nach Ablauf des geplanten Halts. Geplante Halte, Zusatzhalte und blockierter
Stillstand werden getrennt gezählt. Sperrwartezeit ist Teil der gesamten
Blockwartezeit; der übrige Anteil entsteht vor gewöhnlich belegten Abschnitten.
Diese Kategorien sind unmittelbare Wartegründe, keine eindeutige Zuordnung
aller Folgeverspätungen zur auslösenden Störung.

`verifyDisturbances` kontrolliert Ankunftsprotokolle, Zusatzdauern, Halteuhren,
einmalige gezielte Ereignisse und die letzten Einfahrten unabhängig aus den
Trajektorien. `verifyRun` berücksichtigt die rekonstruierte Sperrgrenze bei
Einfahrt, Wartegrund und Bremsreserve. Physische Belegung bleibt separat geprüft.

## Prüfungen und Projektumfang

Die 65 MATLAB-Tests unter `tests/` prüfen beide Fahrmodelle, Stationshalte,
Bremsreserven, Ringübergänge sowie Anzeige- und Animationsunabhängigkeit.
Beim Strukturumbau wurden zusätzlich zwölf Vorher/Nachher-Fälle mit exakt
gleichen Trajektorien, Stationsereignissen und bisherigen Kennzahlen geprüft.
Das Live-Skript wurde vollständig unter MATLAB R2026a ausgeführt.

Die Datenprüfung liegt zentral in `daten/ringbahn_2026-10-14/tools/quality_checks.py`.
Notebook-Kopien, alte Textausgaben und doppelte GeoJSON-Zwischenexporte
werden nicht mehr mitgeführt. `ringbahn.geojson` bleibt die gemeinsame
Kartenexportdatei. Quelldaten und Reproduktionswerkzeuge bleiben erhalten.
Die Geschwindigkeitsregel steht direkt in `advance.m`.
Blocktests prüfen zusätzlich kurze Abschnitte, Zugenden am Ringübergang,
OSM-Herkunft, freie und belegte Blöcke sowie tatsächlich entstehende Warteschlangen.

Die Störungstests prüfen zusätzlich p = 0 und p = 1, gleiche und verschiedene
Zufallsstartwerte, unveränderte globale Zufallsfolge, kombinierte Zusatzhalte,
unvollständige Halte am Laufende, sichere Aktivierung im Bremsweg, verbrauchte
Einfahrerlaubnisse, Sperren am Ringanfang und Wiederanlauf nach Sperrende.
Bei ausgeschalteten Störungen wurden die bisherigen Trajektorien, Ereignisse
und Kennzahlen zusätzlich in zwölf Fällen exakt verglichen.

## Raum-Zeit-Auswertung mit Geschwindigkeitsfarben

Die Übersicht zeigt alle Trajektorien über der Zeit mit einer gemeinsamen
Farbskala von 0 bis 80 km/h. Orange kennzeichnet Geschwindigkeit null,
Blau schnelle Fahrt. Jede Strecke zwischen zwei Zeitpunkten erhält die
Geschwindigkeit des zurückgelegten Intervalls, also G.velocity der Zielzeile.
Geschwindigkeit null kann sowohl regulären Stationshalt als auch eine
Störung oder Verkehrsblockierung bedeuten. Ursachen werden aus markierten
Ereignissen, Protokollen und dem Vergleich mit ungestörten Läufen erklärt.

Der Auswertungszug wird im Live-Skript gewählt, schwarz hervorgehoben und
etwa einmal pro Minute mit einem kleinen Kreis markiert. Rauten zeigen
gezielte Zusatzhalte sowie zufällige Zusatzhalte dieses Zuges. Eine
gestrichelte schwarze Spur markiert einen zeitweise gesperrten Zugang
während der Sperrdauer. Die Stationen bleiben dezente Hintergrundlinien.

Der zweite Plot zeigt etwa fünf Kilometer um ein tatsächlich beobachtetes
Ereignis. Priorität: gezielter Zusatzhalt, zeitweise Blocksperre, zufälliger
Zusatzhalt des Auswertungszuges, sein erster blockierter Halt, seine erste
Stationsankunft. Bei sehr kurzen Läufen dient seine Startposition als Zentrum.
Die Zeitspanne beginnt bis zu vier Minuten vor dem Ereignis und reicht
mindestens acht Minuten danach beziehungsweise vier Minuten über die
vergebene Halte-/Sperrdauer hinaus, begrenzt durch den simulierten Zeitraum.
Der Ausschnitt schneidet den Ring gegenüber dem Ereignis auf: Benachbarte
Positionen am Ringanfang und Ringende bleiben räumlich nebeneinander.
Die Achsenbeschriftung gibt Kilometer modulo Ringlänge an. Stationen im
Ausschnitt sind beschriftet. Übersicht und Detail verwenden dieselbe Farbskala.

Das Netzmittel einschließlich stehender Züge steht separat über der Zeit.
Die Referenzlinie beschreibt den freien störungsfreien Umlauf. Ein lokaler
Rückstau muss den Netzmittelwert nicht stark verändern. Geschwindigkeit
und Beschleunigung des gewählten Auswertungszuges folgen im eigenen Diagramm.
Der Auswertungszug wird beim Start übernommen; Bewegung, Zufallsfolge und
Animation bleiben davon unabhängig. Es wird kein dichtes 1-m-Zellbild erzeugt.
