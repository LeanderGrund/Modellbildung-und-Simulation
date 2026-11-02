function u = myUpdate(u,p)
%MYUPDATE Advance the periodic NaSch model by exactly one time step.
%
% The street state is stored as a complex-valued vector:
%   NaN     : empty cell
%   real(u) : vehicle velocity
%   imag(u) : vehicle ID

x = find(~isnan(u));
if isempty(x), return; end

v = real(u(x));
id = imag(u(x));
n = numel(u);

% Number of empty cells in front, including the periodic boundary.
d = [diff(x)-1, n+x(1)-x(end)-1];

% Nagel-Schreckenberg update.
v = min(p.vmax,v+1);
v = min(d,v);
v = max(0,v-(rand(size(v)) < p.brake));

% Move vehicles and wrap around periodically.
u(x) = nan;
x = mod(x+v-1,n)+1;
u(x) = v+1i*id;

end
