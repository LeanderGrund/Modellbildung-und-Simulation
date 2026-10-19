# Geplante Erweiterungen

Alle Erweiterungen verwenden denselben Modellkern und dieselbe Bedienoberfläche
in `SBahn_demo.mlx`. Es entstehen keine auswählbaren Codekopien.

## Umgesetzt

1. Einheitliche oder stationsabhängige geplante GTFS-Haltezeiten.
2. Auswahl des Fahrmodells: On/Off oder Beschleunigen und Bremsen.
3. Fahrdynamik mit Δx = 1 m und Δt = 1 s, ganzzahligen Geschwindigkeiten,
   höchstens 1 m/s² Beschleunigung und Bremsverzögerung sowie diskreter
   Bremswegprüfung vor Stationen und vorausfahrenden Zügen.
4. Geschwindigkeit und Beschleunigung von Zug 1 direkt im Live-Skript.
5. Zugkörper mit 148 m Länge; Stationen weiterhin ideal.
6. Drei Blockmodi: ohne Blocksteuerung, gleichmäßig gewählte Zielabstände
   oder 117 vorläufige OSM-Signalabschnitte. Freigabe hinter dem Zugende,
   exklusive Belegung, Bremswegprüfung und Anzeige im selben Live-Skript.
7. Gezielte und zufällige Zusatzhalte mit lokalem Zufallsstrom sowie zeitweise
   gesperrte Blockzugänge. Sichere Aktivierung, einmalige letzte Einfahrten,
   vollständige Zusatzhalte und getrennte Wartezeit-Auswertung.

Das On/Off-Raster bleibt als bisheriger Vergleich erhalten. Die neue
Fahrdynamik erhält ihre eigene freie Referenzumlaufzeit; 60 Minuten werden
nicht automatisch erzwungen. Einzelheiten und Annahmen stehen in MODELL.md.

## Bereinigte Grundlage

Züge besitzen explizite Zustandsfelder; Einstellungen und Strecke sind
getrennt. Referenzumlauf und Simulation verwenden dieselbe Bewegung.
Streckendaten und Halteprofile werden nur einmal pro Start vorbereitet.
Die unabhängige Modellprüfung bleibt von den Kennzahlen getrennt.
Der Bewegungsschritt trennt Fahrweg und Geschwindigkeitswahl, gemeinsame
Zustandsfortschreibung sowie Stationsereignisse. `trafficLimits` liefert
benannte Fahrweggrenzen und die Zugreihenfolge ohne zweite Sortierung.
Zusatzhalte und zeitweise gesperrte Blockzugänge nutzen diese Ansatzpunkte.
Zufälliges Bremsen ist weiterhin eine mögliche spätere Erweiterung.

## Weitere Schritte

1. Abschnittsabhängige Geschwindigkeiten auf Grundlage geprüfter Streckendaten.
2. Optional zufälliges Bremsen nach dem NaSch-Prinzip innerhalb der
   bestehenden Bremsgrenze; weitere Störungsarten erst nach Auswahl.
3. OSM-Signalabschnitte gegen betriebliche Block- und Freimeldegrenzen
   prüfen, sobald verlässliche zusätzliche Daten verfügbar sind.
4. Fahrzeiten mit GTFS vergleichen; erreichbare Parameter nachvollziehbar
   kalibrieren und ausgewählte Fälle mit feinerem Raster gegenprüfen.

Die konkreten Ausprägungen dieser späteren Erweiterungen bleiben offen.
Jeder Schritt erhält eigene fachliche Prüfungen. Identische Stationsprofile
und gleichmäßig versetzte Züge müssen nicht von selbst Staus erzeugen.

## Zurückgestellte Idee: Simulationsläufe speichern

Es gibt keine automatische Laufaufzeichnung. Später könnten Ergebnisse,
Konfiguration, Zufallsstartwert sowie Code- und Datenstand gemeinsam über
das Live-Skript gesichert werden. Das wird erst auf ausdrücklichen Wunsch
umgesetzt; eine erneute Versionsauswahl ist nicht vorgesehen.
