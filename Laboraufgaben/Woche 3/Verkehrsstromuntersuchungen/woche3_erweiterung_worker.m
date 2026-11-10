function woche3_erweiterung_worker(specFile)
%WOCHE3_ERWEITERUNG_WORKER Lokale MATLAB-Basissitzung ohne Zusatztoolbox.
root = fileparts(mfilename('fullpath')); addpath(root,fullfile(root,'modell'));
maxNumCompThreads(1);
d = load(specFile,'spec'); spec = d.spec;
for index = 1:numel(spec.tasks)
    entry = spec.task(spec.tasks{index},spec.plan,spec.rawFolder);
    save(spec.statusFiles(index),'entry','-v7');
end
end
