function trafic_flow_parallel_worker(specFile)
%TRAFIC_FLOW_PARALLEL_WORKER Unabhängige Konfigurationen in einer Basissitzung.
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'modell'));
maxNumCompThreads(1); % Mehrere Prozesse teilen die verfügbaren CPU-Kerne.
loaded = load(specFile,'spec'); spec = loaded.spec;
for index = 1:numel(spec.indices)
    entry = spec.task(spec.configurations{index},spec.settings,spec.runFolder, ...
        spec.files{index},spec.x(index),spec.resume);
    save(spec.statusFiles(index),'entry','-v7');
end
end
