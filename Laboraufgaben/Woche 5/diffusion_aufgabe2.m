function result = diffusion_aufgabe2(caStep)
% Aufgabe 2: Validierung eines Diffusionsautomaten.
% Aufruf: diffusion_aufgabe2  (Referenz-CA mit Ausschluss)
% Oder: diffusion_aufgabe2(@meinCASchritt) fuer einen eigenen binaeren CA.
% caStep(G) muss ein synchrones oder sequentielles periodisches Update liefern.
rng(42,'twister');
L=200; R=L/20; c=(L+1)/2; maxT=100000;
[X,Y]=meshgrid(1:L); G0=(X-c).^2+(Y-c).^2<=R^2;
if nargin==0, caStep=@referenceCA; end
names={'CA','Diskreter RW','Quadrat-RW','Kreis-RW'};
result=struct([]);
for k=1:4
    G=G0; [y,x]=find(G); n0=numel(x);
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
                G=caStep(G); assert(isequal(size(G),[L L]) && all(G(:)==0 | G(:)==1),'CA muss binaeres Gitter liefern.');
                [y,x]=find(G);
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
    D=p(1)/2; theory=[NaN 1/3 1/6 1/8];
    result(k).name=names{k}; result(k).history=H; result(k).D=D;
    result(k).D_theory=theory(k); result(k).hit=hit;
    result(k).initialN=n0; result(k).finalXY=[x y];
    fprintf('%s: t=%d, N0=%d, Nend=%d, D_fit=%.5f, Rand=%d\n',names{k},t,n0,n,D,hit);
    T=array2table(H,'VariableNames',{'t','N','x_mean','y_mean','v'});
    writetable(T,sprintf('diffusion_modell%d.csv',k));
    if ~hit, warning('Sicherheitslimit erreicht, kein Randkontakt.'); end
    if any(H(:,2)~=n0), warning('Teilchenzahl nicht erhalten!'); end
end
figure('Name','Aufgabe 2 - Kennwerte','Color','w');
for k=1:4
    H=result(k).history;
    subplot(2,2,1); hold on; plot(H(:,1),H(:,2),'DisplayName',names{k});
    subplot(2,2,2); hold on; plot(H(:,1),H(:,3),'DisplayName',names{k});
    subplot(2,2,3); hold on; plot(H(:,1),H(:,4),'DisplayName',names{k});
    subplot(2,2,4); hold on; plot(H(:,1),H(:,5),'DisplayName',names{k});
end
labs={'N(t)','x-Mittelwert','y-Mittelwert','v(t)'};
for j=1:4
    subplot(2,2,j); xlabel('Zeitschritt'); ylabel(labs{j}); grid on; legend('Location','best');
end
saveas(gcf,'diffusion_kennwerte.png');
figure('Name','CA Teilchenverteilung','Color','w');
subplot(1,2,1); imagesc(G0); axis image; set(gca,'YDir','normal'); title('Start');
subplot(1,2,2); xy=result(1).finalXY; scatter(xy(:,1),xy(:,2),8,'filled'); axis equal; xlim([0 L+1]); ylim([0 L+1]); title('Ende');
saveas(gcf,'diffusion_verteilung.png');
save('diffusion_ergebnisse.mat','result');
end

function G=referenceCA(G)
% Explizite Ersatzregel: pro Teilchen und Zeitschritt ein Versuch;
% zufaellige Reihenfolge, vier gleichwahrscheinliche Nachbarn, Ausschluss.
L=size(G,1); idx=find(G); idx=idx(randperm(numel(idx)));
d=[1 0;-1 0;0 1;0 -1];
for j=1:numel(idx)
    [y,x]=ind2sub(size(G),idx(j)); a=d(randi(4),:);
    xx=mod(x+a(1)-1,L)+1; yy=mod(y+a(2)-1,L)+1;
    if ~G(yy,xx), G(y,x)=false; G(yy,xx)=true; end
end
end
