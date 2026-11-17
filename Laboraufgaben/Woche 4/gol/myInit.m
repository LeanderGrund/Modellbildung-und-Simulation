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

    p.scenario (1,1) string {mustBeMember(p.scenario,["random","empty","glider","block","blinker"])} = "random";
    p.pDeath (1,1) double {mustBeInRange(p.pDeath,0,1)} = 0;
    p.pBirth (1,1) double {mustBeInRange(p.pBirth,0,1)} = 0;
end

n1 = siz(1); n2 = siz(2); N0 = p.N0;

% create scenario
switch p.scenario
    case "random"
        G = rand([n1 n2]) < N0;
    case "empty"
        G = false(n1,n2);
    otherwise
        if min(siz) < 5
            error('myInit:SmallGrid','Strukturen brauchen mindestens 5 x 5 Zellen.');
        end
        G = false(n1,n2);
        switch p.scenario
            case "glider", pattern = logical([0 1 0; 0 0 1; 1 1 1]);
            case "block", pattern = true(2);
            case "blinker", pattern = true(1,3);
        end
        start = floor((siz-size(pattern))/2)+1;
        G(start(1)+(0:size(pattern,1)-1),start(2)+(0:size(pattern,2)-1)) = pattern;
end

end

% ------------------------------------------------------------------------

