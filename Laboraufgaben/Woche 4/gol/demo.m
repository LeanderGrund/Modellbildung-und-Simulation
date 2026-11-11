function demo(timeout)

if nargin == 0, timeout = inf; end

[G,p] = myInit([500 500],plot=1);

h = []; t = 0; frametime = tic; runtime = tic;

while toc(runtime) < timeout

    tnew = t + p.dt;
    G = myUpdate(G,p,tnew-t); % update rule
    t = tnew;

    h = myDrawnow(G,p,t,h);
    pause(max(0, 1/20 - toc(frametime)));
    frametime = tic;
end
 
end


