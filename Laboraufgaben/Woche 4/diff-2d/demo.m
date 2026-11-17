function demo()

[G,p] = myInit(plot=3,scenario='rechteck',periodic=true);

h = []; t = 0;
h = myDrawnow(G,p,t,h);
while t < p.tend
    tnew = min( p.tend , t + p.dt );
    G = myUpdate(G,p,tnew-t); % update rule
    t = tnew;
    h = myDrawnow(G,p,tnew,h);
end

end


