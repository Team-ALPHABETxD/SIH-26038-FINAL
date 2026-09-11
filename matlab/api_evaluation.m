
function api_evaluation(outputPath)
% Export evaluationResults.mat to JSON for the web dashboard.
payload = struct("ok", false);
try
    f = load("evaluationResults.mat");
    payload.ok = true;
    payload.sensitivity = double(f.sensitivity);
    payload.specificity = double(f.specificity);
    rows = table2struct(f.results);
    payload.perClass = rows;
    writeJson(payload, outputPath);
catch ME
    payload.error = ME.message;
    writeJson(payload, outputPath);
end
end
function writeJson(s, path)
fid=fopen(path,"w"); fwrite(fid,jsonencode(s),"char"); fclose(fid);
end
