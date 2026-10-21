function runPhase6C1_CrossDatasetGovernance(projectRoot)

if nargin < 1 || isempty(projectRoot)
    projectRoot = 'C:\Internship Project';
end
if ~isfolder(projectRoot)
    error('Project root not found: %s', projectRoot);
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(projectRoot,'results',['Phase6C1_CrossDatasetGovernance_' stamp]);
if ~isfolder(outDir), mkdir(outDir); end
fprintf('\n===== PHASE 6C.1: CROSS-DATASET GOVERNANCE =====\n');
fprintf('Project root: %s\nOutput folder: %s\n',projectRoot,outDir);
fprintf('Read-only mode: source files will not be modified.\n\n');

% Load Phase 6C artifacts when present. They are reference inputs only.
phase6cDir = findLatestPhase6C(projectRoot);
manifestIn = table(); splitSummaryIn = table(); dupIn = table();
if ~isempty(phase6cDir)
    manifestIn = safeRead(fullfile(phase6cDir,'Phase6C_CanonicalDatasetManifest.csv'));
    splitSummaryIn = safeRead(fullfile(phase6cDir,'Phase6C_ProposedSplitSummary.csv'));
    dupIn = safeRead(fullfile(phase6cDir,'Phase6C_ExactDuplicateGroups.csv'));
end

% Inventory CSVs under data and results, excluding this run's output.
roots = {fullfile(projectRoot,'data'), fullfile(projectRoot,'results')};
files = {};
for ri=1:numel(roots)
    if isfolder(roots{ri})
        d = dir(fullfile(roots{ri},'**','*.csv'));
        for k=1:numel(d)
            if ~contains(d(k).folder,outDir)
                files{end+1,1} = fullfile(d(k).folder,d(k).name); %#ok<AGROW>
            end
        end
    end
end
files = unique(files,'stable');
N = numel(files);
if N==0, warning('No CSV files found under data or results.'); end

% Manifest inventory table.
FilePath = strings(N,1); FileName = strings(N,1); StorageArea = strings(N,1);
Topology = strings(N,1); Role = strings(N,1); Rows = nan(N,1); Columns = nan(N,1);
MissingCells = nan(N,1); SHA256 = strings(N,1); ReadStatus = strings(N,1);
ReadMessage = strings(N,1); Schema = strings(N,1); DatasetClass = strings(N,1);
GovernanceStatus = strings(N,1); SplitEligible = false(N,1);
for i=1:N
    fp = files{i}; FilePath(i)=string(fp); [~,nm,ex]=fileparts(fp); FileName(i)=string([nm ex]);
    low = lower(fp);
    if contains(low,[filesep 'data' filesep]), StorageArea(i)="data"; else, StorageArea(i)="results"; end
    Topology(i)=classifyTopology(fp);
    Role(i)=classifyRole(fp);
    SHA256(i)=string(fileSHA256(fp));
    try
        T = readtable(fp,'VariableNamingRule','preserve');
        Rows(i)=height(T); Columns(i)=width(T);
        try, MissingCells(i)=sum(ismissing(T),'all'); catch, MissingCells(i)=countMissingFallback(T); end
        ReadStatus(i)="OK"; ReadMessage(i)="";
        Schema(i)=strjoin(string(T.Properties.VariableNames),' | ');
        DatasetClass(i)=classifyDataset(fp,T,Topology(i),Role(i));
        if DatasetClass(i)=="SourceDatasetCandidate" && Role(i)=="Unclassified"
            GovernanceStatus(i)="REVIEW_REQUIRED"; SplitEligible(i)=true;
        elseif Role(i)=="TestOrEvaluation" || Role(i)=="Holdout"
            GovernanceStatus(i)="PROTECT_EXISTING_SPLIT"; SplitEligible(i)=false;
        elseif DatasetClass(i)=="DerivedOrPrediction"
            GovernanceStatus(i)="NOT_A_SOURCE_DATASET"; SplitEligible(i)=false;
        else
            GovernanceStatus(i)="REVIEW_REQUIRED"; SplitEligible(i)=false;
        end
    catch ME
        ReadStatus(i)="ERROR"; ReadMessage(i)=string(ME.message);
        DatasetClass(i)="UnreadableCSV"; GovernanceStatus(i)="DIAGNOSE_READ_ERROR";
        SplitEligible(i)=false;
    end
end
manifest = table(FileName,FilePath,StorageArea,Topology,Role,Rows,Columns,MissingCells,SHA256,ReadStatus,ReadMessage,DatasetClass,GovernanceStatus,SplitEligible,Schema);
writetable(manifest,fullfile(outDir,'Phase6C1_FileInventory.csv'));

% Exact duplicate file groups from fresh hashes.
validHash = SHA256~="";
[gh,~,gix] = unique(SHA256(validHash)); %#ok<ASGLU>
idxValid=find(validHash); duplicateRows=[]; groupNum=0;
for g=1:numel(gh)
    loc=idxValid(gix==g);
    if numel(loc)>1
        groupNum=groupNum+1;
        for j=1:numel(loc)
            duplicateRows(end+1,:)=[loc(j),groupNum,numel(loc)]; %#ok<AGROW>
        end
    end
end
if isempty(duplicateRows)
    exactDup = table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'DuplicateGroup','SHA256','FilePath','Rows','GroupFileCount'});
else
    rr=duplicateRows(:,1); gg=duplicateRows(:,2); cc=duplicateRows(:,3);
    exactDup=table("HASHGROUP_"+string(gg),SHA256(rr),FilePath(rr),Rows(rr),cc, ...
        'VariableNames',{'DuplicateGroup','SHA256','FilePath','Rows','GroupFileCount'});
end
writetable(exactDup,fullfile(outDir,'Phase6C1_ExactDuplicateGroups.csv'));

% Build candidate list for cross-dataset configuration overlap. Only source candidates
% with readable CSVs and a recognized topology are examined. Test/holdout artifacts
% are still inspected for overlap, but never become split-eligible by this script.
readable=find(ReadStatus=="OK");
configRows = table();
for ii=1:numel(readable)
    i=readable(ii);
    if ~(Topology(i)=="BJT_Common_Emitter" || Topology(i)=="MOSFET_Common_Source"), continue; end
    try, T=readtable(char(FilePath(i)),'VariableNamingRule','preserve'); catch, continue; end
    pcols=parameterColumns(T,Topology(i));
    if numel(pcols)<3, continue; end
    [keys,usable] = makeConfigKeys(T,pcols);
    if ~any(usable), continue; end
    ds = repmat(i,sum(usable),1);
    rowIdx=find(usable);
    tmp=table(ds,rowIdx,keys(usable),repmat(string(strjoin(pcols,',')),sum(usable),1), ...
        'VariableNames',{'ManifestIndex','SourceRow','ConfigKey','KeyColumns'});
    if isempty(configRows), configRows=tmp; else, configRows=[configRows; tmp]; end %#ok<AGROW>
end

% Cross-file overlaps are calculated within topology only; overlap means shared
% parameter configurations, not proof of model leakage.
overlap = table();
if ~isempty(configRows)
    tops = unique(Topology(configRows.ManifestIndex));
    for ti=1:numel(tops)
        top=tops(ti); sub=configRows(Topology(configRows.ManifestIndex)==top,:);
        keyList=unique(sub.ConfigKey);
        for ki=1:numel(keyList)
            hit=sub(sub.ConfigKey==keyList(ki),:);
            src=unique(hit.ManifestIndex);
            if numel(src)<2, continue; end
            for a=1:numel(src)-1
                for b=a+1:numel(src)
                    ia=src(a); ib=src(b);
                    ra=hit.SourceRow(hit.ManifestIndex==ia); rb=hit.SourceRow(hit.ManifestIndex==ib);
                    oneOverlap=table(top,FileName(ia),FilePath(ia),FileName(ib),FilePath(ib), ...
                        keyList(ki),numel(ra),numel(rb),Role(ia),Role(ib), ...
                        'VariableNames',{'Topology','FileA','PathA','FileB','PathB','ConfigKey','RowsAForKey','RowsBForKey','RoleA','RoleB'});
                    if isempty(overlap), overlap=oneOverlap; else, overlap=[overlap; oneOverlap]; end %#ok<AGROW>
                end
            end
        end
    end
end
if isempty(overlap)
    overlap=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
        zeros(0,1),zeros(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',{'Topology','FileA','PathA','FileB','PathB','ConfigKey','RowsAForKey','RowsBForKey','RoleA','RoleB'});
end
writetable(overlap,fullfile(outDir,'Phase6C1_CrossDatasetConfigurationOverlap.csv'));

% Per-pair summary, including protected evaluation artifacts.
if height(overlap)>0
    pairKeys = strings(height(overlap),1);
    for i=1:height(overlap)
        pairKeys(i)=overlap.Topology(i)+"|"+overlap.PathA(i)+"|"+overlap.PathB(i);
    end
    up=unique(pairKeys); sumRows=cell(numel(up),7);
    for i=1:numel(up)
        ix=find(pairKeys==up(i)); first=ix(1);
        sumRows(i,:)={overlap.Topology(first),overlap.FileA(first),overlap.PathA(first),overlap.FileB(first),overlap.PathB(first),numel(ix), ...
            any(overlap.RoleA(ix)=="TestOrEvaluation" | overlap.RoleA(ix)=="Holdout" | overlap.RoleB(ix)=="TestOrEvaluation" | overlap.RoleB(ix)=="Holdout")};
    end
    pairSummary=cell2table(sumRows,'VariableNames',{'Topology','FileA','PathA','FileB','PathB','SharedConfigurationCount','ProtectedEvaluationInvolved'});
else
    pairSummary=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1),zeros(0,1),false(0,1), ...
        'VariableNames',{'Topology','FileA','PathA','FileB','PathB','SharedConfigurationCount','ProtectedEvaluationInvolved'});
end
writetable(pairSummary,fullfile(outDir,'Phase6C1_OverlapPairSummary.csv'));

% Source dataset review register: conservative recommendations, not automatic approval.
reviewIdx=find(Topology=="BJT_Common_Emitter" | Topology=="MOSFET_Common_Source");
review=manifest(reviewIdx,{'FileName','FilePath','Topology','Role','Rows','Columns','MissingCells','ReadStatus','DatasetClass','GovernanceStatus','SplitEligible'});
review.RecommendedAction = strings(height(review),1);
for i=1:height(review)
    if review.ReadStatus(i)~="OK"
        review.RecommendedAction(i)="Diagnose import error; do not use until repaired and validated";
    elseif review.Role(i)=="TestOrEvaluation" || review.Role(i)=="Holdout"
        review.RecommendedAction(i)="Protect existing evaluation role; exclude from split generation";
    elseif review.DatasetClass(i)=="SourceDatasetCandidate"
        review.RecommendedAction(i)="Review provenance, schema, validity, and overlap before canonical approval";
    elseif review.DatasetClass(i)=="DerivedOrPrediction"
        review.RecommendedAction(i)="Do not treat as a raw training dataset";
    else
        review.RecommendedAction(i)="Manual role/provenance review required";
    end
end
writetable(review,fullfile(outDir,'Phase6C1_CanonicalDatasetReview.csv'));

% Read-error diagnostic report for the known files and any new errors.
errIdx=find(ReadStatus=="ERROR");
readErrors=manifest(errIdx,{'FileName','FilePath','Topology','ReadStatus','ReadMessage','SHA256'});
writetable(readErrors,fullfile(outDir,'Phase6C1_ReadErrorDiagnostics.csv'));

% Compare original Phase 6C split proposals to the new manifest by basename.
% This is a review table only; existing proposals are not accepted as approved splits.
proposalReview=table();
if ~isempty(splitSummaryIn) && all(ismember({'DatasetFile','Topology','RowsAssigned','UniqueConfigurationGroups','TrainRows','ValidationRows','TestRows'},splitSummaryIn.Properties.VariableNames))
    for r=1:height(splitSummaryIn)
        nm=string(splitSummaryIn.DatasetFile(r)); ix=find(FileName==nm & Topology==string(splitSummaryIn.Topology(r)));
        if isempty(ix)
            pathFound=""; roleFound="NOT_FOUND"; status="REVIEW_SOURCE_PATH";
        else
            pathFound=strjoin(FilePath(ix),' || '); roleFound=strjoin(Role(ix),' || ');
            if any(Role(ix)=="TestOrEvaluation" | Role(ix)=="Holdout")
                status="DO_NOT_REPARTITION_PROTECTED_FILE";
            elseif numel(ix)>1
                status="AMBIGUOUS_DUPLICATE_BASENAME_REVIEW_PATHS";
            else
                status="PROPOSAL_ONLY_CHECK_CROSS_FILE_OVERLAP";
            end
        end
        oneProposal=table(nm,string(splitSummaryIn.Topology(r)),double(splitSummaryIn.RowsAssigned(r)), ...
            double(splitSummaryIn.UniqueConfigurationGroups(r)),double(splitSummaryIn.TrainRows(r)), ...
            double(splitSummaryIn.ValidationRows(r)),double(splitSummaryIn.TestRows(r)),string(pathFound),string(roleFound),string(status), ...
            'VariableNames',{'DatasetFile','Topology','RowsAssigned','UniqueConfigurationGroups','TrainRows','ValidationRows','TestRows','ResolvedPaths','DetectedRoles','GovernanceDecision'});
        if isempty(proposalReview), proposalReview=oneProposal; else, proposalReview=[proposalReview; oneProposal]; end %#ok<AGROW>
    end
end
writetable(proposalReview,fullfile(outDir,'Phase6C1_ProposedSplitReview.csv'));

% Duplicate artifact cross-check (the supplied Phase6C duplicate list is preserved
% as a reference, and current hashes are freshly calculated above).
if ~isempty(dupIn)
    try, writetable(dupIn,fullfile(outDir,'Phase6C1_InputPhase6C_DuplicateGroups.csv')); catch, end
end
if ~isempty(manifestIn)
    try, writetable(manifestIn,fullfile(outDir,'Phase6C1_InputPhase6C_Manifest.csv')); catch, end
end

% Summary by topology.
topNames=unique(Topology); sumCell=cell(numel(topNames),7);
for t=1:numel(topNames)
    ix=Topology==topNames(t);
    sumCell(t,:)={topNames(t),sum(ix),sum(ReadStatus(ix)=="OK"),sum(ReadStatus(ix)=="ERROR"), ...
        sum(DatasetClass(ix)=="SourceDatasetCandidate"),sum(Role(ix)=="TestOrEvaluation" | Role(ix)=="Holdout"),sum(MissingCells(ix),'omitnan')};
end
topSummary=cell2table(sumCell,'VariableNames',{'Topology','CSVCount','ReadableCount','ReadErrorCount','SourceCandidates','ProtectedEvaluationFiles','TotalMissingCells'});
writetable(topSummary,fullfile(outDir,'Phase6C1_TopologySummary.csv'));

% Metadata and human-readable summary.
meta=table(string(projectRoot),string(outDir),string(stamp),N,sum(ReadStatus=="OK"),sum(ReadStatus=="ERROR"),height(exactDup),height(overlap),height(pairSummary), ...
    'VariableNames',{'ProjectRoot','OutputFolder','RunTimestamp','CSVScanned','ReadableCSV','ReadErrors','DuplicateFileRows','ConfigurationOverlapRows','OverlapFilePairs'});
writetable(meta,fullfile(outDir,'Phase6C1_RunMetadata.csv'));
writeSummary(fullfile(outDir,'PHASE6C1_README.txt'),projectRoot,outDir,N,ReadStatus,Topology,exactDup,overlap,pairSummary,review,readErrors);

fprintf('\n===== PHASE 6C.1 COMPLETE =====\n');
fprintf('CSV scanned: %d | readable: %d | read errors: %d\n',N,sum(ReadStatus=="OK"),sum(ReadStatus=="ERROR"));
fprintf('Exact-duplicate file rows: %d\n',height(exactDup));
fprintf('Cross-dataset configuration overlap rows: %d\n',height(overlap));
fprintf('Cross-dataset file-pair summaries: %d\n',height(pairSummary));
fprintf('Read errors: %s\n',fullfile(outDir,'Phase6C1_ReadErrorDiagnostics.csv'));
fprintf('Overlap review: %s\n',fullfile(outDir,'Phase6C1_OverlapPairSummary.csv'));
fprintf('Canonical review: %s\n',fullfile(outDir,'Phase6C1_CanonicalDatasetReview.csv'));
fprintf('No splits were approved or applied.\n');
end

function phaseDir=findLatestPhase6C(root)
phaseDir=''; d=dir(fullfile(root,'results','Phase6C_DatasetGovernance_*'));
if isempty(d), return; end
[~,ix]=max([d.datenum]); candidate=fullfile(d(ix).folder,d(ix).name);
if isfile(fullfile(candidate,'Phase6C_CanonicalDatasetManifest.csv'))
    phaseDir=candidate;
else
    % If the latest folder is incomplete, search backwards for a complete one.
    [~,ord]=sort([d.datenum],'descend');
    for j=ord
        c=fullfile(d(j).folder,d(j).name);
        if isfile(fullfile(c,'Phase6C_CanonicalDatasetManifest.csv'))
            phaseDir=c; return;
        end
    end
end
end

function T=safeRead(fp)
T=table(); if isfile(fp), try, T=readtable(fp,'VariableNamingRule','preserve'); catch, T=table(); end, end
end

function top=classifyTopology(fp)
p=lower(fp);
if contains(p,'common_source') || contains(p,'mosfet') || contains(p,'cs_dataset') || contains(p,'phase5') || contains(p,'2n7000')
    top="MOSFET_Common_Source";
elseif contains(p,'common_emitter') || contains(p,'bjt') || contains(p,'ce_amplifier') || contains(p,'emitter')
    top="BJT_Common_Emitter";
else
    top="Unknown";
end
end

function role=classifyRole(fp)
p=lower(fp); [~,nm]=fileparts(p); n=string(nm);
if contains(p,'holdout') || contains(p,'independentvalidation') || contains(p,'freshcircuitdataset')
    role="Holdout";
elseif contains(n,'test') || contains(p,'test_predictions') || contains(p,'evaluation') || contains(p,'externalvalidation')
    role="TestOrEvaluation";
elseif contains(p,'prediction') || contains(p,'sensitivity') || contains(p,'performance') || contains(p,'analysis') || contains(p,'publication') || contains(p,'tables')
    role="Derived";
else
    role="Unclassified";
end
end

function cls=classifyDataset(fp,T,top,role)
p=lower(fp); vars=lower(string(T.Properties.VariableNames));
if role=="TestOrEvaluation" || role=="Holdout"
    cls="TestOrEvaluation";
elseif role=="Derived" || contains(p,'prediction') || contains(p,'analysis') || contains(p,'publication')
    cls="DerivedOrPrediction";
elseif top=="BJT_Common_Emitter" && sum(ismember(vars,["r1","r2","rc","re","rl","cin","cout","ce","vcc"]))>=6 && height(T)>=20
    cls="SourceDatasetCandidate";
elseif top=="MOSFET_Common_Source" && sum(ismember(vars,["vdd","vds","vgs","rd","rs","rg","gain_db","gain","gm","id","rload","rl"]))>=3 && height(T)>=10
    cls="SourceDatasetCandidate";
else
    cls="Unclassified";
end
end

function pcols=parameterColumns(T,top)
vars=string(T.Properties.VariableNames); low=lower(vars);
if top=="BJT_Common_Emitter"
    preferred=["R1","R2","RC","RE","RL","Cin","Cout","Ce","VCC","Temperature","Transistor_Model"];
else
    preferred=["VDD","VDS","VGS","RD","RS","RG","RL","Rload","Temperature","MOSFET_Model","Model"];
end
pcols={};
for p=preferred
    ix=find(strcmpi(vars,p),1);
    if ~isempty(ix), pcols{end+1}=char(vars(ix)); end %#ok<AGROW>
end
% Avoid using target/output columns as configuration identifiers.
exclude={'gain','gain_db','gain_db_mean','bandwidth','power','gm','id','ib','ic','vce','simulation_status','dc_status','ac_status','success','physicalvalid','exitcode','errormessage','fL','fH'};
keep=true(size(pcols));
for k=1:numel(pcols), if any(strcmpi(pcols{k},exclude)), keep(k)=false; end, end
pcols=pcols(keep);
% Require at least three parameter columns to reduce accidental weak keys.
end

function [keys,usable]=makeConfigKeys(T,pcols)
n=height(T); keys=strings(n,1); usable=true(n,1);
for c=1:numel(pcols)
    v=T.(pcols{c});
    vals=string(v);
    if isnumeric(v) || islogical(v)
        vals=string(v);
        vals(ismissing(vals))="<MISSING>";
        % Normalize numeric formatting so equivalent numeric values key together.
        for r=1:n
            if isnumeric(v) && isfinite(double(v(r)))
                vals(r)=string(sprintf('%.12g',double(v(r))));
            elseif isnumeric(v) && ~isfinite(double(v(r)))
                vals(r)="<MISSING>";
            end
        end
    else
        vals=strip(vals);
        vals(ismissing(vals) | vals=="")="<MISSING>";
    end
    usable=usable & vals~="<MISSING>";
    keys=keys+"|"+lower(vals);
end
keys=extractAfter(keys,1);
end

function h=fileSHA256(fp)
h="";
try
    fid=fopen(fp,'rb'); if fid<0, return; end
    cleaner=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'*uint8'); %#ok<NASGU>
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(bytes);
    digest=typecast(md.digest(),'uint8'); h=lower(string(reshape(dec2hex(digest,2).',1,[])));
catch
    % Hash unavailable is recorded as blank; no fallback can be mistaken for SHA-256.
    h="";
end
end

function n=countMissingFallback(T)
n=0;
for c=1:width(T)
    v=T.(T.Properties.VariableNames{c});
    try, n=n+sum(ismissing(v)); catch, end
end
end

function writeSummary(fp,root,outDir,N,readStatus,Topology,dup,overlap,pairs,review,readErrors)
fid=fopen(fp,'w'); if fid<0, return; end
cl=onCleanup(@()fclose(fid));
fprintf(fid,'PHASE 6C.1 CROSS-DATASET GOVERNANCE AUDIT\n');
fprintf(fid,'Project root: %s\nOutput folder: %s\n\n',root,outDir);
fprintf(fid,'CSV scanned: %d\nReadable: %d\nRead errors: %d\n',N,sum(readStatus=="OK"),sum(readStatus=="ERROR"));
fprintf(fid,'Exact duplicate file rows: %d\nCross-dataset configuration overlap rows: %d\nOverlap file-pair summaries: %d\n\n',height(dup),height(overlap),height(pairs));
fprintf(fid,'SAFETY / INTERPRETATION NOTES\n');
fprintf(fid,'1. This audit is read-only and does not train models or alter source files.\n');
fprintf(fid,'2. Configuration overlap is a review flag, not proof of train/test leakage.\n');
fprintf(fid,'3. Roles and dataset classes are heuristic and require provenance review.\n');
fprintf(fid,'4. Existing test and holdout files are protected from split generation.\n');
fprintf(fid,'5. No proposed train/validation/test split is approved by this script.\n');
fprintf(fid,'6. BJT and MOSFET are audited separately; their keys are never cross-compared.\n\n');
fprintf(fid,'FILES TO REVIEW FIRST\n');
fprintf(fid,'- Phase6C1_CanonicalDatasetReview.csv\n- Phase6C1_OverlapPairSummary.csv\n- Phase6C1_CrossDatasetConfigurationOverlap.csv\n- Phase6C1_ReadErrorDiagnostics.csv\n- Phase6C1_ProposedSplitReview.csv\n');
if height(readErrors)>0
    fprintf(fid,'\nREAD ERRORS DETECTED:\n');
    for i=1:height(readErrors), fprintf(fid,'- %s\n  %s\n  %s\n',char(readErrors.FileName(i)),char(readErrors.FilePath(i)),char(readErrors.ReadMessage(i))); end
end
end
