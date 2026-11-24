
%% Aufgabe 1 - Fundamentallösung / Gaußverteilung

clear;
clc;
close all;

%% Definition der Parameter

D = 1;          % Diffusionskoeffizient
c0 = 1;         % Gesamtteilchenzahl
mu = 0;         % Erwartungswert
sigma = 1;      % Standardabweichung

% Gaußverteilung nach Gleichung (3)
f = @(xt,mu,sigma) 1./(sigma*sqrt(2*pi)) ...
    .* exp(-(xt-mu).^2./(2*sigma^2));

% Fundamentallösung nach Gleichung (2)
u = @(x,t) c0./(2*sqrt(pi*D*t)) ...
    .* exp(-x.^2./(4*D*t));

% Zeitvektor
t = linspace(0.01,5,100);

% Gemeinsames Fenster für alle Graphen
figure('Name','Aufgabe 1 - Diffusion', ...
       'Position',[100 100 1400 800]);

%% (a) Zusammenhang zwischen x, x_tilde und mu

% x = x_tilde - mu
% mu ist der Erwartungswert und beschreibt
% den Mittelpunkt der Gaußverteilung.

%disp('Aufgabe (a):');
%disp('x = x_tilde - mu');
%disp('mu ist der Erwartungswert.');

%% (b) Zusammenhang zwischen sigma, D und t

% 2*sigma^2 = 4*D*t
% sigma = sqrt(2*D*t)
% sigma beschreibt die Breite der Verteilung.

sigma_t = sqrt(2*D*t);

%disp('Aufgabe (b):');
%disp('sigma = sqrt(2*D*t)');

%% (c) Gesamtzahl der Teilchen N(t)

% Analytische Lösung: N(t) = c0

N = zeros(size(t));

for i = 1:length(t)
    N(i) = integral(@(x) u(x,t(i)), -Inf, Inf);
end

subplot(2,3,1);

plot(t,N,'b','LineWidth',2);
xlabel('Zeit t');
ylabel('N(t)');
title('(c) Gesamtteilchenzahl');
ylim([0,1.2*c0]);
grid on;

%disp('Aufgabe (c):');
%disp('N(t) = c0 = konstant');

%% (d) Mittelpunkt der Teilchenverteilung xs(t)

% Analytische Lösung: xs(t) = 0

xs = zeros(size(t));

for i = 1:length(t)
    xs(i) = integral(@(x) x.*u(x,t(i)), -Inf, Inf);
end

subplot(2,3,2);

plot(t,xs,'b','LineWidth',2);
xlabel('Zeit t');
ylabel('x_s(t)');
title('(d) Mittelpunkt');
ylim([-1,1]);
grid on;

%disp('Aufgabe (d):');
%disp('xs(t) = 0');

%% (e) Varianz der Teilchenverteilung v(t)

% Analytische Lösung: v(t) = 2*c0*D*t

v = zeros(size(t));

for i = 1:length(t)
    v(i) = integral(@(x) x.^2.*u(x,t(i)), -Inf, Inf);
end

subplot(2,3,3);

plot(t,v,'b','LineWidth',2);
xlabel('Zeit t');
ylabel('v(t)');
title('(e) Varianz');
grid on;

%disp('Aufgabe (e):');
%disp('v(t) = 2*c0*D*t');

%% (f) Darstellung der Gaußverteilung

x_tilde = linspace(-5,5,1000);

subplot(2,3,4);

plot(x_tilde,f(x_tilde,mu,sigma),'b','LineWidth',2);

xlabel('$\tilde{x}$','Interpreter','latex');
ylabel('$f(\tilde{x})$','Interpreter','latex');

title('(f) Gaußverteilung');
grid on;

%% (g) Fundamentallösung zu verschiedenen Zeitpunkten

x = linspace(-10,10,1000);

% Verschiedene Zeitpunkte
T = [0.1, 0.5, 1, 2, 5];

subplot(2,3,5);

hold on;

for i = 1:length(T)

    plot(x,u(x,T(i)),'LineWidth',2, ...
        'DisplayName',sprintf('t = %.1f',T(i)));

end

xlabel('Ort x');
ylabel('u(x,t)');
title('(g) Fundamentallösung');
legend('show','Location','best');
grid on;

hold off;

%% Gemeinsame Überschrift

sgtitle('Aufgabe 1 - Fundamentallösung und Gaußverteilung');
