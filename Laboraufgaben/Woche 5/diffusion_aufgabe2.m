function result = diffusion_aufgabe2(caStep)
% Aufgabe 2: Validierung des Blockautomaten aus Woche 4.
% Optional: diffusion_aufgabe2(@meinCASchritt) mit eigenem binärem 2D-CA.
rng(42,'twister');
L=200; R=L/20; c=(L+1)/2; maxT=100000;
[X,Y]=meshgrid(1:L); G0=(X-c).^2+(Y-c).^2<=R^2;
useWeek4 = nargin == 0;
theory = [1/4 1/3 1/6 1/8];
names = {'Block-CA (Woche 4)','Diskreter RW','Quadrat-RW','Kreis-RW'};
if useWeek4
    update = week4Update();
    caStep = @(G) update(G,[],1);
else
    names{1} = 'Eigener 2D-CA';
    theory(1) = NaN;
end
result=struct([]);
for k=1:4
    G=G0; [y,x]=find(G0); n0=numel(x);
    if k == 1 && useWeek4
        % Ein Teilchen je Gitterort im Kreis, auf einem von vier Kanälen.
        % Die fünfte Ebene bleibt als Hindernismaske leer.
        G = false(L,L,5);
        G(sub2ind(size(G),y,x,randi(4,n0,1))) = true;
    end
    H=nan(maxT+1,5); t=0;
    while true
        n=numel(x); assert(n>0,'Keine Teilchen vorhanden.');
        mx=mean(x); my=mean(y);
        v=mean((x-mx).^2+(y-my).^2)/2;
        H(t+1,:)=[t n mx my v];
        if k<=2
            hit=any(x<=1 | x>=L | y<=1 | y>=L);
        else
            hit=any(x<=0.5 | x>=L+0.5 | y<=0.5 | y>=L+0.5);
        end
        if hit || t>=maxT, break; end
        switch k
            case 1
                G = caStep(G);
                if useWeek4
                    indices = find(G(:,:,1:4));
                    [y,x,~] = ind2sub([L L 4],indices);
                else
                    assert(isequal(size(G),[L L]) && all(G(:)==0 | G(:)==1), ...
                        'Ein eigener CA muss ein binäres 2D-Gitter liefern.');
                    [y,x] = find(G);
                end
            case 2
                x=x+randi(3,n,1)-2; y=y+randi(3,n,1)-2;
                x=mod(x-1,L)+1; y=mod(y-1,L)+1;
            case 3
                x=x+2*rand(n,1)-1; y=y+2*rand(n,1)-1;
                % Stop vor Umwicklung, damit die Randueberschreitung sichtbar bleibt.
            case 4
                a=2*pi*rand(n,1); r=sqrt(rand(n,1));
                x=x+r.*cos(a); y=y+r.*sin(a);
        end
        t=t+1;
    end
    H=H(1:t+1,:); assert(t>=1,'Zu wenige Messpunkte.');
    p=polyfit(H(:,1),H(:,5),1);
    D=p(1)/2;
    result(k).name=names{k}; result(k).history=H; result(k).D=D;
    result(k).D_theory=theory(k); result(k).hit=hit;
    result(k).initialN=n0; result(k).finalXY=[x y];
    result(k).matlabVersion = version;
    fprintf('%s: t=%d, N0=%d, Nend=%d, D_fit=%.5f, Rand=%d\n',names{k},t,n0,n,D,hit);
    T=array2table(H,'VariableNames',{'t','N','x_mean','y_mean','v'});
    writetable(T,sprintf('diffusion_modell%d.csv',k));
    if ~hit, warning('Maximale Schrittzahl erreicht, kein Randkontakt.'); end
    if any(H(:,2)~=n0), warning('Teilchenzahl nicht erhalten!'); end
end
figure('Name','Aufgabe 2 - Kennwerte','Color','w','Position',[60 60 1150 820]);
for k=1:4
    H=result(k).history;
    subplot(2,2,1); hold on; plot(H(:,1),H(:,2),'DisplayName',names{k});
    subplot(2,2,2); hold on; plot(H(:,1),H(:,3),'DisplayName',names{k});
    subplot(2,2,3); hold on; plot(H(:,1),H(:,4),'DisplayName',names{k});
    subplot(2,2,4); hold on; plot(H(:,1),H(:,5),'DisplayName',names{k});
end
labs={'N(t)','x-Mittelwert','y-Mittelwert','v(t)'};
for j=1:4
    subplot(2,2,j); xlabel('Zeitschritt'); ylabel(labs{j}); grid on;
end
subplot(2,2,1); legend('Location','best');
exportgraphics(gcf,'diffusion_kennwerte.png','Resolution',160);
figure('Name','CA Teilchenverteilung','Color','w','Position',[60 60 900 420]);
[y0,x0] = find(G0);
xy = result(1).finalXY;
positions = {[x0 y0],xy};
endTitle = sprintf('Erster Randkontakt, t = %d',result(1).history(end,1));
if ~result(1).hit
    endTitle = sprintf('Maximale Schrittzahl, t = %d',result(1).history(end,1));
end
titles = {'Start',endTitle};
for j = 1:2
    subplot(1,2,j);
    scatter(positions{j}(:,1),positions{j}(:,2),9,'filled');
    axis equal; xlim([0.5 L+0.5]); ylim([0.5 L+0.5]);
    xlabel('x'); ylabel('y'); title(titles{j});
end
exportgraphics(gcf,'diffusion_verteilung.png','Resolution',160);
save('diffusion_ergebnisse.mat','result');
end

function update = week4Update()
% Funktionshandle im Modellordner binden und danach den Aufrufordner wiederherstellen.
folder = fullfile(fileparts(mfilename('fullpath')),'..','Woche 4','diff-2d');
original = pwd;
cleanup = onCleanup(@() cd(original));
cd(folder);
update = @myUpdate;
details = functions(update);
assert(strcmp(details.file,fullfile(pwd,'myUpdate.m')), ...
    'Die Update-Regel aus Woche 4 konnte nicht geladen werden.');
end
