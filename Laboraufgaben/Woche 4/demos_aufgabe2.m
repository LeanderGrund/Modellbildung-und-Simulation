% DEMOS_AUFGABE2 Einzelne Abschnitte im Editor ausfuehren (Strg+Enter).
% Aufrufe direkt aus Woche 4. Vorhandene Ergebnisdateien werden nicht ersetzt.
% Fuer Berechnungen ohne Fenster jeweils plot=false ergaenzen.

%% Aufgabe 2a: Kollision und Streaming an einem Teilchen nachvollziehen
a = demo_aufgabe2("a");
% Alternative: mehrere Kanaele am selben Ort besetzen.
% a = demo_aufgabe2("a",occupation=[1 1 0 0],seed=2202);

%% Aufgabe 2b: Leeres Feld bleibt leer
b_leer = demo_aufgabe2("b",scenario="leer");

%% Aufgabe 2b: Volles Feld bleibt in allen vier Kanaelen voll
b_voll = demo_aufgabe2("b",scenario="voll");

%% Aufgabe 2b: Rechteck am linken Rand, Wiedereintritt am rechten Rand
% N=1: alle Kanaele im Rechteck voll, Uebertritt schon nach Schritt 1 sicher.
b_rand = demo_aufgabe2("b",scenario="rand",N=1);
% b_rand.checks.periodicBoundaryObserved muss true sein.

%% Aufgabe 2b: Rechteck in der Mitte verbreitert sich
b_mitte = demo_aufgabe2("b",scenario="mitte");

%% Aufgabe 2b: Donut in der Mitte, Diffusion nach innen und aussen
b_donut = demo_aufgabe2("b",scenario="donut");

%% Aufgabe 2c: Laufzeit gegen Gitterorte und Zeitschritte, je fuenf Messungen
c = demo_aufgabe2("c");
% Kleinerer Messversuch:
% c = demo_aufgabe2("c",sides=[50 100 200],stepCounts=[10 30 100],repeats=3);

%% Aufgabe 2d (i): Block-CA, Laenge 1 und Drehung um +/-90 Grad
d_i = demo_aufgabe2("d",model="i");

%% Aufgabe 2d (ii): Diskrete Komponenten aus {-1,0,+1}
d_ii = demo_aufgabe2("d",model="ii");

%% Aufgabe 2d (iii): Stetige Komponenten aus [-1,+1]
d_iii = demo_aufgabe2("d",model="iii");

%% Aufgabe 2d (iv): Flaechengleichverteilte Einheitskreisscheibe
d_iv = demo_aufgabe2("d",model="iv");

%% Schneller Feldtest ohne Animation
% steps = physikalische Zeitschritte; dt = Schritte je Bild/Messpunkt.
b_kurz = demo_aufgabe2("b",scenario="rand",N=1,steps=20,dt=1,plot=false);
disp(b_kurz.history);
disp(b_kurz.checks);

%% Anderer Random Walk: Beispielweg nach jeweils 5 Schritten abtasten
d_anderer_seed = demo_aufgabe2("d",model="iv",seed=42,sampleEvery=5);
% d_anderer_seed.sampledPositions enthaelt die angezeigten Positionen.
