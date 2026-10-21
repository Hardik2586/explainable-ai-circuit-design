function runPhase6C2_CanonicalLineageAndSplitPolicy()
% Phase 6C.2 - Canonical dataset lineage and proposed split policy.
% READ-ONLY: does not modify source CSVs, train models, or apply splits.
% Run from MATLAB: runPhase6C2_CanonicalLineageAndSplitPolicy

clc;
root = 'C:\Internship Project';
dataRoot = fullfile(root,'data'); resultsRoot = fullfile(root,'results');
if ~isfolder(root), error('Project root not found: %s',root); end
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6C2_CanonicalLineage_' stamp]);
mkdir(outDir);
fprintf('\n===== PHASE 6C.2: CANONICAL LINEAGE AND SPLIT POLICY =====\n');
fprintf('Project root: %s\nOutput folder: %s\nRead-only mode enabled.\n',root,outDir);

files = [listCsv(dataRoot); listCsv(resultsRoot)];
files = unique(files,'stable'); files = files(~contains(lower(string(files)),lower(string(outDir))));
n = numel(files); Tlist = cell(n,1); readable = false(n,1); rows = cell(n,1);
for i=1:n
    p=files{i}; [~,fn,ext]=fileparts(p); topo=topology(p); role=fileRole(p);
    hash=""; nr=NaN; nc=NaN; miss=NaN; cols=""; err=""; bytes=NaN;
    try
        d=dir(p); if ~isempty(d), bytes=d(1).bytes; end
        hash=sha256(p);
        opts=detectImportOptions(p,'FileType','text'); opts.VariableNamingRule='preserve';
        T=readtable(p,opts); Tlist{i}=T; readable(i)=true;
        nr=height(T); nc=width(T); miss=countMissing(T); cols=strjoin(string(T.Properties.VariableNames),'|');
    catch ME
        err=string(ME.message);
    end
    rows{i,1}={string(p),string(relativePath(p,root)),string([fn ext]),string(topo),string(role),bytes,string(hash),nr,nc,miss,string(cols),readable(i),string(err)};
    if mod(i,50)==0 || i==n, fprintf('Scanned %d/%d\n',i,n); end
end
M=cell2table(vertcat(rows{:}),'VariableNames',{'FullPath','RelativePath','FileName','Topology','ProvisionalRole','Bytes','SHA256','Rows','Columns','MissingCells','ColumnNames','Readable','ReadError'});
writetable(M,fullfile(outDir,'Phase6C2_FileManifest.csv'));

% Exact duplicate hashes (file identity only; not proof of model leakage).
dup={}; hs=string(M.SHA256); uh=unique(hs(hs~=""));
for j=1:numel(uh)
    ix=find(hs==uh(j)); if numel(ix)>1
        for k=ix(:)', dup(end+1,:)={uh(j),numel(ix),M.FullPath(k),M.Topology(k),M.ProvisionalRole(k)}; end %#ok<AGROW>
    end
end
D=cell2table(dup,'VariableNames',{'SHA256','FilesInHashGroup','FullPath','Topology','ProvisionalRole'});
writetable(D,fullfile(outDir,'Phase6C2_ExactDuplicateFiles.csv'));

% Review known BJT pairs identified in Phase 6C.1.
pairs={ 'CE_Amplifier_ML_Valid.csv','CE_Amplifier_OperatingPoint_660.csv'; ...
        'CE_Amplifier_Dataset_v3_500.csv','CE_Amplifier_Dataset_v4_500_1GHz.csv'};
lin={};
for q=1:size(pairs,1)
    ia=find(strcmpi(string(M.FileName),pairs{q,1}) & M.Topology=="BJT_Common_Emitter");
    ib=find(strcmpi(string(M.FileName),pairs{q,2}) & M.Topology=="BJT_Common_Emitter");
    if isempty(ia)||isempty(ib)
        lin(end+1,:)={pairs{q,1},pairs{q,2},NaN,NaN,NaN,"MISSING_FILE","Review paths and topology classification."}; %#ok<AGROW>
        continue
    end
    for a=ia(:)', for b=ib(:)'
        if ~readable(a)||~readable(b), continue; end
        A=Tlist{a}; B=Tlist{b}; [ka,ca]=keysFor(A,"BJT_Common_Emitter"); [kb,cb]=keysFor(B,"BJT_Common_Emitter");
        shared=intersect(ka,kb); common=intersect(string(A.Properties.VariableNames),string(B.Properties.VariableNames),'stable');
        uniqueA=setdiff(string(A.Properties.VariableNames),string(B.Properties.VariableNames)); uniqueB=setdiff(string(B.Properties.VariableNames),string(A.Properties.VariableNames));
        targets=common(contains(lower(common),'gain')|contains(lower(common),'bandwidth')|contains(lower(common),'phase')|contains(lower(common),'vce')|contains(lower(common),'ic')|contains(lower(common),'gm')|contains(lower(common),'status')|contains(lower(common),'valid')|contains(lower(common),'freq'));
        lin(end+1,:)={M.FullPath(a),M.FullPath(b),numel(ka),numel(kb),numel(shared),"REVIEW_REQUIRED", ...
          "Common columns="+strjoin(common,'|')+"; only-A="+strjoin(uniqueA,'|')+"; only-B="+strjoin(uniqueB,'|')+ ...
          "; possible measurement/target columns="+strjoin(targets,'|')+"; key columns A="+strjoin(ca,'|')+"; B="+strjoin(cb,'|')}; %#ok<AGROW>
    end, end
end
L=cell2table(lin,'VariableNames',{'FileA','FileB','UniqueKeysA','UniqueKeysB','SharedConfigurationKeys','Status','SchemaAndTargetReview'});
writetable(L,fullfile(outDir,'Phase6C2_KnownBJTLineageReview.csv'));

% Cross-dataset config overlap scan by topology; excludes obvious derived/evaluation artifacts.
over={}; summ={};
for topo=["BJT_Common_Emitter","MOSFET_Common_Source"]
    rec=struct('idx',{},'keys',{},'cols',{});
    ix=find(M.Topology==topo & M.Readable);
    for z=ix(:)'
        if M.ProvisionalRole(z)=="DerivedOrReport" || M.ProvisionalRole(z)=="ProtectedEvaluation", continue; end
        [kk,cc]=keysFor(Tlist{z},topo);
        if numel(kk)<2 || isempty(cc), continue; end
        r.idx=z; r.keys=kk; r.cols=cc; rec(end+1)=r; %#ok<AGROW>
    end
    for a=1:numel(rec), for b=a+1:numel(rec)
        sh=intersect(rec(a).keys,rec(b).keys); if isempty(sh), continue; end
        ia=rec(a).idx; ib=rec(b).idx; fa=numel(sh)/max(1,numel(unique(rec(a).keys))); fb=numel(sh)/max(1,numel(unique(rec(b).keys)));
        summ(end+1,:)={topo,M.FullPath(ia),M.FullPath(ib),numel(unique(rec(a).keys)),numel(unique(rec(b).keys)),numel(sh),fa,fb,strjoin(rec(a).cols,'|'),strjoin(rec(b).cols,'|'),"Overlap is a review flag, not proof of leakage."}; %#ok<AGROW>
        for t=1:numel(sh), over(end+1,:)={topo,M.FullPath(ia),M.FullPath(ib),sh(t),fa,fb}; end %#ok<AGROW>
    end, end
end
O=cell2table(over,'VariableNames',{'Topology','FileA','FileB','ConfigurationKey','FractionAKeysShared','FractionBKeysShared'});
S=cell2table(summ,'VariableNames',{'Topology','FileA','FileB','UniqueKeysA','UniqueKeysB','SharedKeys','FractionAKeysShared','FractionBKeysShared','KeyColumnsA','KeyColumnsB','Interpretation'});
writetable(O,fullfile(outDir,'Phase6C2_CrossDatasetConfigurationOverlap.csv'));
writetable(S,fullfile(outDir,'Phase6C2_OverlapPairSummary.csv'));

% Conservative canonical-candidate review.
cr={};
for i=1:height(M)
    topo=M.Topology(i); role=M.ProvisionalRole(i); fn=lower(M.FileName(i)); rec="HOLD_FOR_REVIEW"; why="Verify provenance, target definitions, and lineage.";
    if ~M.Readable(i), rec="BLOCK_READ_ERROR"; why="CSV import failed; inspect ReadError.";
    elseif role=="ProtectedEvaluation", rec="PROTECT_NO_REUSE"; why="Preserve existing evaluation role; do not use to build or tune splits.";
    elseif role=="DerivedOrReport", rec="NOT_CANONICAL_SOURCE"; why="Likely derived analysis/report/prediction artifact.";
    elseif topo=="Unknown", rec="TOPOLOGY_REVIEW"; why="Topology is not confidently identified.";
    elseif contains(fn,"ml_valid") && topo=="BJT_Common_Emitter", rec="STRONG_CANDIDATE_REVIEW"; why="Candidate clean BJT table; verify relation to operating-point file and label provenance.";
    elseif topo=="BJT_Common_Emitter" || topo=="MOSFET_Common_Source", rec="SOURCE_CANDIDATE_REVIEW"; end
    cr(end+1,:)={M.FullPath(i),M.FileName(i),topo,role,M.Rows(i),M.Columns(i),M.MissingCells(i),rec,why}; %#ok<AGROW>
end
C=cell2table(cr,'VariableNames',{'FullPath','FileName','Topology','ProvisionalRole','Rows','Columns','MissingCells','Recommendation','Reason'});
writetable(C,fullfile(outDir,'Phase6C2_CanonicalDatasetReview.csv'));

policy={ 'BJT','CE_Amplifier_ML_Valid.csv + CE_Amplifier_OperatingPoint_660.csv','660 shared configuration keys reported by Phase 6C.1','Do not split independently; compare labels/features and provenance first.'; ...
 'BJT','CE_Amplifier_Dataset_v3_500.csv + CE_Amplifier_Dataset_v4_500_1GHz.csv','500 shared configuration keys reported by Phase 6C.1','Do not split independently; compare frequency/target definitions first.'; ...
 'BJT','CE_Amplifier_Dataset_v5_2000_1GHz.csv','Substantial missingness reported in Phase 6C','Quarantine from final training until missingness and lineage are understood.'; ...
 'MOSFET','Common-source candidate files','Analyze independently from BJT; overlap scan depends on recognized parameter columns','Do not interpret no reported overlap as proof of no leakage.'; ...
 'ALL','Historical test/holdout/evaluation artifacts','Roles inferred conservatively from names and paths','Protect; do not repurpose for training, tuning, or split construction.'; ...
 'ALL','New split assignments','This phase creates recommendations only','No splits approved or applied.'};
P=cell2table(policy,'VariableNames',{'Scope','DatasetOrArtifact','Evidence','ProposedPolicy'});
writetable(P,fullfile(outDir,'Phase6C2_ProposedSplitPolicy.csv'));

known={ 'CS_AC_Performance_Labels.csv';'CS_Bandwidth_Reference_Analysis.csv'}; diag={};
for k=1:numel(known)
    ix=find(strcmpi(string(M.FileName),known{k}));
    if isempty(ix), diag(end+1,:)={known{k},"NOT_FOUND","Check scan scope and exact filename."}; %#ok<AGROW>
    else, for j=ix(:)', if M.Readable(j), st="READABLE_NOW"; detail="Previously reported error did not reproduce."; else, st="READ_ERROR"; detail=M.ReadError(j); end; diag(end+1,:)={M.FullPath(j),st,detail}; end, end %#ok<AGROW>
end
G=cell2table(diag,'VariableNames',{'File','Status','Details'}); writetable(G,fullfile(outDir,'Phase6C2_ReadErrorDiagnostics.csv'));
meta=table(string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),string(root),n,sum(readable),sum(~readable),height(D),height(O),height(S), ...
 'VariableNames',{'RunTime','ProjectRoot','CSVScanned','ReadableCSV','ReadErrors','ExactDuplicateFileRows','ConfigurationOverlapRows','OverlapFilePairs'});
writetable(meta,fullfile(outDir,'Phase6C2_RunMetadata.csv'));
fprintf('\n===== PHASE 6C.2 SUMMARY =====\nCSV scanned: %d | readable: %d | read errors: %d\n',n,sum(readable),sum(~readable));
fprintf('Exact-duplicate file rows: %d\nConfiguration-overlap rows: %d\nFile-pair summaries: %d\n',height(D),height(O),height(S));
fprintf('No source files modified. No splits approved or applied.\nReports saved to: %s\n',outDir);
end

function f=listCsv(root)
f={}; if ~isfolder(root), return; end
d=dir(fullfile(root,'**','*.csv'));
for i=1:numel(d), if ~d(i).isdir, f{end+1,1}=fullfile(d(i).folder,d(i).name); end, end %#ok<AGROW>
end
function r=relativePath(p,root)
p=char(p); root=char(root); if startsWith(lower(p),lower(root)), r=p(numel(root)+1:end); if startsWith(r,filesep), r=r(2:end); end; else, r=p; end
end
function t=topology(p)
s=lower(string(p)); if contains(s,'common_emitter')||contains(s,'bjt')||contains(s,'ce_amplifier'), t="BJT_Common_Emitter"; elseif contains(s,'common_source')||contains(s,'mosfet')||contains(s,'cs_'), t="MOSFET_Common_Source"; else, t="Unknown"; end
end
function r=fileRole(p)
s=lower(string(p)); if contains(s,'holdout')||contains(s,'test100')||contains(s,'freshcircuit')||contains(s,'test_predictions')||contains(s,'independentvalidation'), r="ProtectedEvaluation"; elseif contains(s,'prediction')||contains(s,'progress')||contains(s,'report')||contains(s,'analysis')||contains(s,'summary')||contains(s,'metrics')||contains(s,'audit')||contains(s,'failure')||contains(s,'sweep'), r="DerivedOrReport"; else, r="SourceCandidateReview"; end
end
function h=sha256(p)
h=""; fid=fopen(p,'rb'); if fid<0, return; end; c=onCleanup(@()fclose(fid)); md=java.security.MessageDigest.getInstance('SHA-256');
while true, b=fread(fid,1024*1024,'*uint8'); if isempty(b), break; end; md.update(b); end
raw=typecast(md.digest(),'uint8'); h=lower(string(reshape(dec2hex(raw,2).',1,[])));
end
function n=countMissing(T)
n=0; for c=1:width(T), v=T.(T.Properties.VariableNames{c}); try, if isnumeric(v)||islogical(v)||isstring(v)||iscategorical(v)||isdatetime(v)||isduration(v), n=n+sum(ismissing(v),'all'); elseif iscell(v), for j=1:numel(v), if isempty(v{j})||(isnumeric(v{j})&&isscalar(v{j})&&isnan(v{j})), n=n+1; end, end, end; catch, end, end
end
function [keys,cols]=keysFor(T,topo)
names=string(T.Properties.VariableNames); low=lower(names);
if topo=="BJT_Common_Emitter", cand=["R1","R2","RC","RE","RL","Cin","Cout","Ce","VCC"]; else, cand=["RGU_Ohm","RGL_Ohm","RD_Ohm","RS_Ohm","CIN_F","VDD_V","RGU","RGL","RD","RS","CIN","VDD"]; end
cols=strings(0,1); for c=cand, ix=find(low==lower(c),1); if ~isempty(ix), cols(end+1)=names(ix); end, end %#ok<AGROW>
if numel(cols)<4, keys=strings(0,1); cols=strings(0,1); return; end
parts=strings(height(T),numel(cols));
for j=1:numel(cols), v=T.(char(cols(j))); if isnumeric(v)||islogical(v), x=double(v(:)); z=strings(numel(x),1); for r=1:numel(x), if isnan(x(r)), z(r)="<MISSING>"; else, z(r)=string(sprintf('%.12g',x(r))); end, end; parts(:,j)=z; else, parts(:,j)=strtrim(string(v(:))); parts(ismissing(parts(:,j)),j)="<MISSING>"; end, end
bad=any(parts=="<MISSING>"|parts=="",2); keys=strings(height(T),1); for r=1:height(T), if ~bad(r), keys(r)=strjoin(parts(r,:),'|'); end, end; keys=keys(keys~="");
end
