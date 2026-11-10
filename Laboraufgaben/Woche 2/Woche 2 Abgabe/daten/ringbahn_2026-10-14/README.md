# Mitgelieferter Laufzeit-Datenbestand

Unveränderter Auszug aus dem lokalen Datenstand `ringbahn_2026-10-14`.
Bezugsdatum der Fahrplandaten ist der 14.10.2026. Es werden keine Daten
nachgeladen.

## Verwendete Dateien

- `s41_stations.csv`: Stationen und deren Position auf dem Ring.
- `s41_track_points.csv`: Geografischer Streckenverlauf.
- `s41_signalkandidaten.csv`: Grundlage der OSM-Signalabschnitte.
- `processed/gtfs_routes.csv`, `gtfs_trips.csv`, `gtfs_calendar.csv`,
  `gtfs_calendar_dates.csv`, `gtfs_stops.csv`, `gtfs_stop_times.csv`:
  Grundlage zur Bestimmung der geplanten Stationshalte.
- `processed/s41_example_timetable.csv`: GTFS-Fahrzeitvergleich im Einzellauf.

## Herkunft

Die im Originalbestand dokumentierten Quellen und Lizenzangaben sind:

- Geometrie und Haltepositionen: © OpenStreetMap contributors, ODbL 1.0;
  https://www.openstreetmap.org/copyright
- Soll-Fahrplandaten: Verkehrsverbund Berlin-Brandenburg GmbH (VBB), CC BY 4.0
  laut ursprünglicher Datendokumentation;
  https://unternehmen.vbb.de/digitale-services/datensaetze/

`sources.json` und `HERKUNFT_ORIGINAL.md` wurden unverändert aus dem
ursprünglichen Datenpaket übernommen. Die Originaldokumentation beschreibt
auch S42, Rohdaten und Aufbereitungswerkzeuge, die nicht zu diesem
Laufzeit-Auszug gehören. Die Prüfsummen dieses Abgabepakets stehen in
`../../SHA256SUMS.txt`.
