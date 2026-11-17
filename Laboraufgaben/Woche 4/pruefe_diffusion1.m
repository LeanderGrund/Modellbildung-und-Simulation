function result = pruefe_diffusion1()
% PRUEFE_DIFFUSION1 Tests of known patterns and physical invariants.
root = fileparts(mfilename('fullpath')); old = pwd;
cleanup = onCleanup(@() cd(old)); %#ok<NASGU>
messages = strings(0,1); rng(2026,'twister');
cd(fullfile(root,'gol')); clear myInit myUpdate myDrawnow
[G,p] = myInit([20 20],scenario="block");
assert(isequal(G,myUpdate(G,p,10))); record("Life: Block bleibt konstant");
[G,p] = myInit([20 20],scenario="blinker");
assert(~isequal(G,myUpdate(G,p,1)) && isequal(G,myUpdate(G,p,2)));
record("Life: Blinker hat Periode 2");
[G,p] = myInit([20 20],scenario="glider");
assert(isequal(circshift(G,[1 1]),myUpdate(G,p,4)));
record("Life: Gleiter verschiebt sich nach 4 Schritten um (1,1)");
G = circshift(G,[9 9]);
assert(isequal(circshift(G,[1 1]),myUpdate(G,p,4)));
record("Life: Gleiter ueberquert den periodischen Rand");
[G,p] = myInit([20 20],scenario="empty");
assert(~any(myUpdate(G,p,50),'all')); record("Life: Leeres Feld bleibt ohne Geburt leer");
p.pBirth = 1;
assert(all(myUpdate(G,p,1),'all')); record("Life: Geburtswahrscheinlichkeit 1 fuellt das Feld");
[G,p] = myInit([20 20],scenario="glider",pDeath=1);
assert(~any(myUpdate(G,p,1),'all')); record("Life: Sterbewahrscheinlichkeit 1 loescht alle Zellen");
[G,p] = myInit([100 100],scenario="empty",pBirth=1e-3);
count = 0;
for k = 1:100, count = count + nnz(myUpdate(G,p,1)); end
assert(abs(count-1000) < 6*sqrt(1000*.999));
record("Life: spontane Geburtsrate stimmt statistisch mit 10^-3 ueberein");

cd(fullfile(root,'diff-2d')); clear myInit myUpdate myDrawnow
for scenario = ["one","cg","kreis","rechteck","cgx"]
    [G,p] = myInit([30 40],scenario=scenario,periodic=true,cg=5);
    H = myUpdate(G,p,80);
    assert(islogical(H) && isequal(size(G),size(H)));
    assert(nnz(H(:,:,1:4)) == p.sum && ~any(H(:,:,5),'all'));
end
record("Diffusion: alle Szenarien initialisieren, Teilchenzahl und Format bleiben erhalten");
[G,p] = myInit([5 7],scenario="one",cg=1);
assert(nnz(G(:,:,1:4)) == 1); record("Diffusion: Einteilchenstart auch auf ungeradem Gitter");
G = false(12,16,5); p = struct;
assert(isequal(G,myUpdate(G,p,7))); record("Diffusion: leeres Gitter bleibt leer");
G(:,:,1:4) = true;
assert(isequal(G,myUpdate(G,p,7))); record("Diffusion: voll besetztes Gitter bleibt voll");
% All 16 local occupations. Undo streaming to test local mass conservation.
G = false(4,4,5);
for k = 1:4, G(:,:,k) = reshape(logical(bitget(uint16(0:15),k)),4,4); end
H = myUpdate(G,p,1); U = H(:,:,1:4);
shifts = [1 0; 0 1; 0 -1; -1 0];
for k = 1:4, U(:,:,k) = circshift(U(:,:,k),shifts(k,:)); end
assert(isequal(sum(G(:,:,1:4),3),sum(U,3)));
record("Diffusion: Kollision erhaelt lokal die Masse fuer alle 16 Belegungen");
% An a particle turns into b or c, then crosses the corresponding boundary.
G = false(12,16,5); G(6,1,1) = true;
for k = 1:30
    H = myUpdate(G,p,1); [row,col,dir] = ind2sub([12 16 4],find(H(:,:,1:4)));
    assert(row == 6 && ((dir == 2 && col == 16) || (dir == 3 && col == 2)));
end
record("Diffusion: Richtungswechsel um 90 Grad und periodischer Rand");
% Recover an unwrapped coordinate from successive wrapped positions.
G = false(12,16,5); G(6,8,1) = true; previous = [6 8];
lastAxis = 1; position = [0 0];
for t = 1:300
    G = myUpdate(G,p,1); assert(nnz(G(:,:,1:4)) == 1);
    [r,c,~] = ind2sub([12 16 4],find(G(:,:,1:4)));
    delta = mod([r c]-previous+[6 8],[12 16])-[6 8];
    assert(sum(abs(delta)) == 1);
    thisAxis = find(delta); assert(thisAxis ~= lastAxis);
    position = position + delta; previous = [r c]; lastAxis = thisAxis;
end
record("Diffusion: Einteilchenweg bleibt erhalten und wechselt jeden Schritt die Achse");
result = struct('passed',numel(messages),'messages',messages,'lastUnwrappedPosition',position);
fprintf('\n%d Tests bestanden.\n',result.passed);

    function record(message)
        messages(end+1) = message;
        fprintf('OK: %s\n',message);
    end
end
