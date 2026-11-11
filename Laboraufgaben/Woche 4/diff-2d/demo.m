function demo()

[G,p] = myInit(plot=2,scenario='rechteck',periodic=0); 

h = []; t = 0;
while t < p.tend
    tnew = min( p.tend , t + p.dt );
    G = myUpdate(G,p,tnew-t); % update rule
    t = tnew;
    h = myDrawnow(G,p,tnew,h);
end

end


