# Ringbahn-Daten für S41 und S42

Separater Datenbestand für eine spätere Erweiterung des MATLAB-Modells.
Der bestehende Simulationscode wurde weder angepasst noch mit diesen Daten verbunden.

Abruf: **14. Oktober 2026**, etwa 15:55–16:00 Uhr Europe/Berlin; genaue UTC-Zeitpunkte und HTTP-Metadaten stehen in `raw/`.
Bezugsdatum der beiden Beispiel-Fahrpläne: **14. Oktober 2026**.

## Direkt verwendbare Dateien

| Datei | Inhalt |
| --- | --- |
| `s41_stations.csv`, `s42_stations.csv` | Je 27 Stationen in Fahrtrichtung, OSM-Haltepositionen, Entfernung entlang des Gleises und zugeordnete GTFS-Stations-IDs |
| `s41_track_points.csv`, `s42_track_points.csv` | Geordnete Gleispunkte einschließlich Ringschluss; Koordinaten und kumulierte Entfernung |
| `s41_segments.csv`, `s42_segments.csv` | Je 27 Stationsabschnitte: OSM-Gleislänge und geplante Fahrzeit aus dem ausgewählten GTFS-Umlauf |
| `ringbahn.geojson` | Beide Gleisringe und Stationspunkte als GeoJSON für GIS/Kartenprogramme |
| `ringbahn.mat` | MATLAB-Tabellen zu Stationen, Streckenpunkten und Abschnitten sowie Herkunftsmetadaten |
| `ringbahn_vorschau.png` | Geografische Kontrollansicht ohne Hintergrundkarte |

Die direkt verwendbaren Tabellen beginnen für beide Richtungen an **Beusselstraße**.
S41 verläuft im Uhrzeigersinn, S42 gegen den Uhrzeigersinn.
`distance_m = 0` liegt am jeweiligen OSM-Haltepunkt an der Beusselstraße.
Die Stationspunkte beziehen sich auf die Gleise, nicht auf Bahnhofsgebäude oder Eingänge.

## Quellen und Lizenzen

**Gleisgeometrie und Haltepositionen:** © OpenStreetMap contributors, ODbL 1.0.

- S41: https://www.openstreetmap.org/relation/14981
- S42: https://www.openstreetmap.org/relation/14983
- Tatsächlicher Abruf: https://api.openstreetmap.org/api/0.6/relation/14981/full und entsprechend `/14983/full`
- Lizenz und Namensnennung: https://www.openstreetmap.org/copyright

**Soll-Fahrplandaten:** Verkehrsverbund Berlin-Brandenburg GmbH (VBB), CC BY 4.0 laut Anbieter.

- Datensatzbeschreibung: https://unternehmen.vbb.de/digitale-services/datensaetze/
- Download: https://unternehmen.vbb.de/gtfs
- Formatbeschreibung: https://gtfs.org/documentation/schedule/reference/

Die vollständige VBB-Quelldatei war 66.108.161 Bytes groß. Im Paket liegt der relevante S41/S42-Auszug als `raw/vbb_ringbahn_gtfs_subset.zip`; Dateigröße und SHA-256 der vollständigen Quelle sind dokumentiert. Der Auszug enthält nur S-Bahn-Routen mit den Liniennamen S41/S42 und `route_type = 109`. Gleichnamige Bus-Ersatzverkehrsrouten wurden ausgeschlossen.
Der Kalender der ausgewählten Ringbahnservices reicht vom 13.10.2026 bis 12.12.2026; konkrete Verkehrstage ergeben sich aus Kalender und Ausnahmen.

## Rohdaten und aufbereitete Daten

`raw/` enthält die unveränderten OSM-XML-Antworten, Abrufmetadaten und den gefilterten GTFS-Auszug.
Der GTFS-Auszug erhält die ursprünglichen Feldwerte, ist jedoch neu als ZIP zusammengestellt; er ist kein byteidentischer Ausschnitt der ursprünglichen ZIP-Datei.

`processed/` enthält:

- GTFS-Tabellen für 3.640 S41/S42-Fahrten, 75.911 Haltereignisse, 252 Shapes und 124.500 Shape-Punkte.
- Die beiden ausgewählten Beispiel-Fahrpläne mit 28 Haltezeilen: 27 verschiedene Stationen plus Rückkehr zur Startstation.
- Unveränderte OSM-Tags der verwendeten Gleisabschnitte, einschließlich vorhandener Geschwindigkeitsangaben.
- Quellenzusammenfassungen und den dokumentierten Geometrievergleich.

Beispiel S41: `trip_id = 308542990`, `shape_id = 2915`, Abfahrt Beusselstraße 08:03:24, Rückkehrankunft 09:02:42.
Beispiel S42: `trip_id = 308548978`, `shape_id = 3050`, Abfahrt Beusselstraße 08:03:18, Rückkehrankunft 09:02:36.
Beide Fahrten sind laut Kalender einschließlich Ausnahmen am 14.10.2026 gültig.

## Einheiten und Berechnung

- CSV: UTF-8 mit BOM, Komma als Trennzeichen, Punkt als Dezimalzeichen.
- Koordinaten: WGS84, `latitude` und `longitude` in Grad.
- GeoJSON-Reihenfolge: `[longitude, latitude]`.
- Entfernungen: Meter, entlang der geordneten Gleislinie, nicht Luftlinie zwischen Stationen.
- Entfernung je aufeinanderfolgenden Punktpaar: geodätische Distanz auf dem WGS84-Ellipsoid, GeographicLib 2.1; anschließend aufsummiert.
- Rundung auf Millimeter dient dem Datenaustausch und behauptet keine Vermessungsgenauigkeit.
- `planned_drive_seconds`: Ankunft an der nächsten Station minus Abfahrt an der vorherigen Station.
- `derived_osm_segment_average_kmh`: berechneter Abschnittsdurchschnitt aus OSM-Länge und Soll-Fahrzeit; keine gemessene Geschwindigkeit.
- GTFS-Zeitangaben sind lokale Fahrplanzeiten. Werte oberhalb 24:00 beziehen sich auf denselben Verkehrstag über Mitternacht hinaus.
- OSM und GTFS wurden über normalisierte Stationsnamen zugeordnet. Die ursprünglichen Namen, IDs und Koordinatendifferenzen bleiben zur Kontrolle erhalten.

## Qualitätsprüfung und wichtige Grenzen

**Geprüft:** Beide OSM-Ringe sind lückenlos und geschlossen, haben jeweils 27 Stationen und 27 Abschnitte und sind in der passenden Fahrtrichtung geordnet. Die GTFS-Schlüssel sind eindeutig, die benötigten Fremdschlüssel vollständig aufgelöst und die Beispiel-Fahrten am Bezugsdatum gültig. Die Abschnittslängen summieren sich jeweils zur Ringlänge.

| Richtung | OSM-Gleislänge | GTFS-Beispiel-Shape | Abweichung |
| --- | ---: | ---: | ---: |
| S41 | 36.971,599 m | 39.606,482 m | +7,127 % |
| S42 | 37.008,668 m | 39.741,099 m | +7,383 % |

**Hohe Relevanz für Streckenlängen, hohe Sicherheit der beobachteten Abweichung:** Zwischen Storkower Straße und Frankfurter Allee ergeben die GTFS-Shapes rund 2,75 km, die OSM-Gleise dagegen rund 1,22 km. Zusammen mit den Soll-Fahrzeiten würden die GTFS-Längen Abschnittsdurchschnitte von etwa 110 bzw. 103 km/h ergeben. Die Ursache ist nicht geklärt. Deshalb sind in den direkt verwendbaren Tabellen die OSM-Gleislängen maßgeblich. Die GTFS-Shapes werden separat zur Nachprüfung erhalten, aber nicht als belastbare Gleislängen empfohlen. Einzelheiten: `processed/geometry_quality.json`.

**Haltezeiten:** Die 26 inneren Stationshalte der ausgewählten Fahrten liegen zwischen 30 und 48 Sekunden. Die erste und letzte Haltezeile einer GTFS-Fahrt geben hier 0 Sekunden an; daraus darf kein tatsächlicher Null-Sekunden-Halt abgeleitet werden. Diese Zeilen sind als `endpoint_dwell_unknown` markiert. Abfahrt bis Rückkehrankunft dauert 59 Minuten 18 Sekunden; ein Umlauf von Abfahrt bis zur nächsten Abfahrt enthält zusätzlich den Halt am Startbahnhof.

**Geschwindigkeiten:** OSM enthält an Gleisabschnitten auch Werte von 90 oder 100 km/h. Das sind übernommene Infrastruktur-Tags, keine geprüfte Freigabe für euren Zug. Die bisherige Modellobergrenze von 80 km/h wird durch diese Daten nicht geändert. Fahrtrichtungsabhängige Tags bleiben getrennt erhalten.

**Weitere Grenzen:** Es handelt sich um kartierte Geometrie und Soll-Fahrpläne, nicht um gemessene Fahrzeugtrajektorien, tatsächliche Haltezeiten oder Verspätungen. Die Koordinaten unterscheiden sich je nach Haltepunktdarstellung zwischen den Quellen um bis zu etwa 98 m. Es wurden keine Echtdaten zu Störungen oder Signalblockbelegung ergänzt.

## Prüfung und Reproduktion

`python3 tools/quality_checks.py` prüft den lokal gespeicherten Datenbestand ohne Zusatzpakete.
Die Aufbereitungsskripte in `tools/` können die Tabellen aus den gespeicherten Rohdaten erneut erzeugen. Für die Längenberechnung wird `geographiclib==2.1` benötigt; siehe `tools/requirements.txt`.
`SHA256SUMS.txt` enthält Prüfsummen aller vorhandenen Dateien dieses Datenpakets außer sich selbst. Die zentrale Kartenexportdatei ist `ringbahn.geojson`; doppelte GeoJSON-Zwischenexporte und gespeicherte Prüfprotokolle werden nicht mehr mitgeführt.

## Später in MATLAB laden

```matlab
daten = load("daten/ringbahn_2026-10-14/ringbahn.mat");
stationen = daten.s41Stationen;
strecke = daten.s41Strecke;
```

Das Laden allein verändert oder erweitert das bestehende Simulationsmodell nicht.


## S41-Signalkandidaten für das vereinfachte Blockmodell

`s41_signalkandidaten.csv` ergänzt die bestehende Momentaufnahme ohne neue
Online-Abfrage. `python3 tools/prepare_signals.py` leitet die Tabelle aus
`raw/osm_relation_14981_full.osm` und `s41_track_points.csv` ab. Dabei wird
die OSM-Wegrichtung mit der tatsächlichen S41-Punktfolge abgeglichen;
`railway:signal:direction` wird relativ zu dieser Richtung ausgewertet.
Berücksichtigt werden ausschließlich aktive kartierte Haupt-/Mehrabschnittssignale
auf den verwendeten Gleisknoten, keine Vorsignale oder Geschwindigkeitstafeln.
„Aktiv“ bedeutet hier lediglich: im Datensatz nicht mit `deactivated=yes` markiert.

117 Kandidaten gelten für S41: 62 mit Funktion block, 48 ohne Funktionsunterklasse,
3 entry, 2 intermediate, 2 exit. Typ und Richtung sind auch bei fehlender
Funktionsunterklasse vorhanden. Jede Zeile enthält OSM-ID, direkten Quelllink,
Streckenposition, Signaltyp und den Hinweis auf die fehlende betriebliche Prüfung.
Signalabstände liegen ungefähr zwischen 104 und 1207 m.

Dies sind **keine bestätigten Block- oder Gleisfreimeldegrenzen**. Das Modell
setzt vereinfachend an jedem Kandidaten einen Abschnittsanfang und betrachtet
alle Abschnitte als exklusive Fahrabschnitte. Fahrstraßen, Durchrutschwege,
ZBS-Details und tatsächliche Freigabeverfahren sind nicht abgedeckt.
Die Stationen bleiben ideale Modellhaltepunkte; Bahnsteige werden nicht abgeleitet.
Tag-Grundlage: [OpenStreetMap Signal-Dokumentation](https://wiki.openstreetmap.org/wiki/Tag:railway%3Dsignal).
Die Daten unterliegen wie die zugrunde liegenden OSM-Daten der ODbL 1.0,
© OpenStreetMap-Mitwirkende.
