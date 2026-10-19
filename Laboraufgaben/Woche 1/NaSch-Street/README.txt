NaSch-Street – Lernziel

Diese Version zeigt das Nagel-Schreckenberg-Modell ohne Objektorientierung auf einer periodischen Straße.

Zentrale Dateien:
- myInit.m: erzeugt den Straßenzustand u und die Parameter p. Auch density = 0 ist zulässig.
- myUpdate.m: führt genau einen Zeitschritt aus. Die vier NaSch-Regeln und die periodische Randbedingung sind direkt sichtbar.
- myDrawnow.m: visualisiert die periodische Straße als Ellipse.
- TimeSpacePlot.m: zeigt Zeit-Ort-Diagramm und mittlere Geschwindigkeit.

Didaktischer Fokus:
1. Zustandsdarstellung mit NaN, Geschwindigkeit im Realteil und Fahrzeug-ID im Imaginärteil.
2. Vier NaSch-Regeln.
3. Periodische Randbedingung.
4. Trennung von Initialisierung, Update und Darstellung.