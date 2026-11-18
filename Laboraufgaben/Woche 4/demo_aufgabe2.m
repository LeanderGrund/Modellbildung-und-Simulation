function result = demo_aufgabe2(teil,varargin)
% DEMO_AUFGABE2 Einzelne Versuche zu Aufgabe 2 aus Woche 4 starten.
%   demo_aufgabe2("a")                       % Kollision und Streaming
%   demo_aufgabe2("b",scenario="leer")        % Feldtests
%   demo_aufgabe2("b",scenario="voll")
%   demo_aufgabe2("b",scenario="rand",N=1)
%   demo_aufgabe2("b",scenario="mitte")
%   demo_aufgabe2("b",scenario="donut")
%   demo_aufgabe2("c")                       % Laufzeitmessungen
%   demo_aufgabe2("d",model="i")             % vier Random-Walk-Modelle
% Fuer alle Teile: plot=false unterdrueckt die Grafik.
% Weitere Optionen und einzelne Aufrufe stehen in demos_aufgabe2.m.
if nargin < 1, teil = "b"; end
teil = string(teil);
mustBeScalarOrEmpty(teil);
mustBeMember(teil,["a","b","c","d"]);
root = fileparts(mfilename('fullpath'));
old = pwd; oldRng = rng;
cleanup = onCleanup(@() restore_environment(old,oldRng)); %#ok<NASGU>
cd(fullfile(root,'diff-2d'));
clear myInit myUpdate
switch teil
    case "a", result = demo_regel(varargin{:});
    case "b", result = demo_feld(varargin{:});
    case "c", result = demo_laufzeit(varargin{:});
    case "d", result = demo_random_walk(varargin{:});
end
end

function restore_environment(old,oldRng)
cd(old);
rng(oldRng);
end
