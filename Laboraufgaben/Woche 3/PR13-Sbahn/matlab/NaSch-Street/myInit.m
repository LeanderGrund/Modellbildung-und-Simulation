function [u,p] = myInit(n,p)
%MYINIT Initialize the NaSch traffic model.
%
% The street state is stored as a complex-valued vector:
%   NaN     : empty cell
%   real(u) : vehicle velocity
%   imag(u) : vehicle ID
%
% Vehicles are distributed randomly with zero initial velocity and
% assigned unique IDs.
%
% p contains the model and simulation parameters.

arguments

    % number of cells of the street
    n (1,1) double {mustBePositive,mustBeInteger} = 200

    % number of simulation time steps
    p.tend (1,1) double {mustBePositive,mustBeInteger} = 100;

    % number of single model steps between two displayed states
    % (used only by the interactive interface)
    p.dt (1,1) double {mustBeNonnegative,mustBeInteger} = 1;

    % initial vehicle density
    p.density (1,1) double {mustBeInRange(p.density,0,1)} = 0.2;

    % probability of random braking
    p.brake (1,1) double {mustBeInRange(p.brake,0,1)} = 0.05;

    % maximum vehicle velocity in cells per time step
    p.vmax (1,1) double {mustBeInteger,mustBePositive} = 8;

    % visualization
    % 0 = no plot
    % 1 = color represents velocity
    % 2 = color represents vehicle ID
    p.plot (1,1) double {mustBeInteger,mustBeBetween(p.plot,0,2)} = 1;

end

% number of vehicles
m = round(p.density*n);

% initialize empty street
u = nan(1,n);

% distribute vehicles randomly and assign unique vehicle IDs
u(randperm(n,m)) = 1i*(1:m);

end