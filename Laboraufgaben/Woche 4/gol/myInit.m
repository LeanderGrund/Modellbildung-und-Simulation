function [G,p] = myInit(siz,p)

arguments
    
    % Simulationsgebiet 2D
    siz (1,2) double {mustBePositive,mustBeInteger} = [500 500]

    % Coarse Graining Box Kantenlänge
    p.dt (1,1) double {mustBePositive,mustBeInteger} = 1;
    p.tend (1,1) double {mustBePositive,mustBeInteger} = 1000;

    p.send (1,1) double {mustBeInteger,mustBeNonnegative} = 1;
    p.plot (1,1) double {mustBeInteger} = 0;

    p.N0 (1,1) double {mustBeInRange(p.N0,0,1)} = 0.2; % Grundbesetzung
end

n1 = siz(1); n2 = siz(2); N0 = p.N0;

% create scenario
G = rand([n1 n2]) < N0;

end

% ------------------------------------------------------------------------

