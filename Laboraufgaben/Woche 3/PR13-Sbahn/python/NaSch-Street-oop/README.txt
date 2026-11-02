NaSch-Street-oop – Lernziel

Diese Version beschreibt dieselbe periodische NaSch-Straße wie NaSch-Street, nun als Objekt.

Zentrale Klasse:
- Road.m: enthält Zustand, Parameter, Historie und die zugehörigen Methoden.

Direkte Zuordnung zur prozeduralen Version:
- myInit        -> Road-Konstruktor
- myUpdate      -> road.update()
- myDrawnow     -> road.draw()
- Zeit-Historie -> road.G
- TimeSpacePlot -> road.plotTimeSpace()

Road.update() führt wie myUpdate genau einen Zeitschritt aus. Der NaSch-Algorithmus bleibt dadurch beim Vergleich der beiden Versionen unmittelbar erkennbar.

Didaktischer Fokus:
1. Daten und Methoden werden in einem Objekt gekapselt.
2. Der Algorithmus selbst ändert sich nicht.
3. draw() verwaltet seine Grafikobjekte selbst und aktualisiert nach der Initialisierung nur die Fahrzeugdarstellung.

Übergang zur nächsten Version:
In NaSch-Map-oop wird die periodische Randbedingung entfernt. Eine Road erhält stattdessen mit temp eine Schnittstelle zu benachbarten Straßen. Eine Map koordiniert mehrere Road-Objekte und die Knoten zwischen ihnen.
