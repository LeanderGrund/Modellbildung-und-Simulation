function results = run_diffusion1()
% RUN_DIFFUSION1 Solve all parts of Diffusion1.pdf and export results.
% In MATLAB: cd to Woche 4, then run_diffusion1
root = fileparts(mfilename('fullpath'));
old = pwd;
cleanup = onCleanup(@() cd(old)); %#ok<NASGU>
out = fullfile(root,'ergebnisse');
if ~isfolder(out), mkdir(out); end
results.tests = pruefe_diffusion1();
cd(fullfile(root,'gol'));
clear myInit myUpdate myDrawnow
results.gameOfLife = aufgabe1(out);
cd(fullfile(root,'diff-2d'));
clear myInit myUpdate myDrawnow
results.diffusion = aufgabe2(out);
save(fullfile(out,'diffusion1_ergebnisse.mat'),'results');
fprintf('\nFertig. Ergebnisse: %s\n',out);
end
