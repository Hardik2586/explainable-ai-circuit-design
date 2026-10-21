%% PHASE 6B: Dataset Integrity, Duplication, and Leakage Audit
% MATLAB-only, read-only audit of source CSVs. Keeps MOSFET CS and BJT CE separate.
clear; clc; close all;
projectRoot = 'C:\Internship Project';
dataRoot = fullfile(projectRoot,'data'); resultsRoot = fullfile(projectRoot,'results');
timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6B_IntegrityAudit_' timestamp]);
if ~isfolder(outDir), mkdir(outDir); end
fprintf('\n===== PHASE 6B DATASET INTEGRITY AUDIT =====\n');

files = [dir(fullfile(dataRoot,'**','*.csv')); dir(fullfile(resultsRoot,'**','*.csv'))];
paths = strings(numel(files),1);
for i=1:numel(files), paths(i)=string(fullfile(files(i).folder,files(i).name)); end
pathsOut = string(outDir);
keep = ~contains(paths,pathsOut,'IgnoreCase',true); files=files(keep); paths=paths(keep);
n=numel(files); if n==0, error('No CSV files found under data/results.'); end
FileName=strings(n,1); FilePath=paths; Bytes=zeros(n,1); SHA256=strings(n,1);
Topology=strings(n,1); Role=strings(n,1); Rows=nan(n,1); Columns=nan(n,1);
MissingCells=nan(n,1); DuplicateRows=nan(n,1); ReadStatus=strings(n,1);
ColumnList=strings(n,1); IsLikelyDataset=false(n,1); Tables=cell(n,1);
for i=1:n
    f=files(i); FileName(i)=string(f.name); Bytes(i)=f.bytes;
    Topology(i)=classifyTopology(paths(i)); Role(i)=classifyRole(paths(i));
    SHA256(i)=hashFile(char(paths(i)));
    try
        opts=detectImportOptions(char(paths(i))); opts.VariableNamingRule='preserve';
        T=readtable(char(paths(i)),opts); Tables{i}=T; Rows(i)=height(T); Columns(i)=width(T);
        MissingCells(i)=missingCount(T); DuplicateRows(i)=duplicateRowCount(T);
        ColumnList(i)=strjoin(string(T.Properties.VariableNames),' | '); ReadStatus(i)="OK";
        cn=lower(regexprep(string(T.Properties.VariableNames),'[^a-zA-Z0-9]',''));
        % Infer topology from component-column signatures when folder names are generic.
        if Topology(i)=="Unknown"
            if any(cn=="rguohm") && any(cn=="rglohm") && any(cn=="rdohm") && any(cn=="rsohm")
                Topology(i)="MOSFET_Common_Source";
            elseif any(cn=="r1ohm") && any(cn=="r2ohm") && any(cn=="rcohm") && any(cn=="reohm")
                Topology(i)="BJT_Common_Emitter";
            end
        end
        hasR=any(ismember(cn,{'rdohm','rcohm','r1ohm','rguohm'}));
        hasOtherR=any(ismember(cn,{'rsohm','reohm','r2ohm','rglohm'}));
        hasTarget=any(contains(cn,'gain')|contains(cn,'target')|contains(cn,'bandwidth'));
        IsLikelyDataset(i)=hasR && hasOtherR && hasTarget && height(T)>1;
    catch ME
        ReadStatus(i)="READ_ERROR"; ColumnList(i)=string(ME.message);
    end
    if mod(i,50)==0, fprintf('Scanned %d/%d CSVs\n',i,n); end
end
Inventory=table(FileName,FilePath,Bytes,SHA256,Topology,Role,Rows,Columns, ...
    MissingCells,DuplicateRows,ReadStatus,IsLikelyDataset,ColumnList);
writetable(Inventory,fullfile(outDir,'Phase6B_FileInventory.csv'));

%% Exact duplicate files (SHA-256)
ExactDuplicateFiles=Inventory([],:);
ok=SHA256~="";
if any(ok)
    h=SHA256(ok); idx=find(ok); [u,~,g]=unique(h);
    dup=[]; for k=1:numel(u), z=idx(g==k); if numel(z)>1, dup=[dup;z(:)]; end, end %#ok<AGROW>
    ExactDuplicateFiles=Inventory(dup,:);
end
writetable(ExactDuplicateFiles,fullfile(outDir,'Phase6B_ExactDuplicateFiles.csv'));

%% Dataset-level quality and configuration duplication
idx=find(IsLikelyDataset & ReadStatus=="OK");
DatasetPath=strings(0,1); DatasetTopology=strings(0,1); DatasetRole=strings(0,1);
DatasetRows=[]; MissingCellsN=[]; DuplicateFullRows=[]; UniqueConfigurations=[];
DuplicateConfigurationRows=[]; InvalidSimulationRows=[]; NonfiniteNumericCells=[]; KeyColumns=strings(0,1);
KeySets=cell(numel(idx),1); KeyCols=cell(numel(idx),1);
for q=1:numel(idx)
    i=idx(q); T=Tables{i}; [keys,cols]=configKeys(T); KeySets{q}=keys; KeyCols{q}=cols;
    DatasetPath(end+1,1)=FilePath(i); DatasetTopology(end+1,1)=Topology(i); DatasetRole(end+1,1)=Role(i); %#ok<SAGROW>
    DatasetRows(end+1,1)=height(T); MissingCellsN(end+1,1)=MissingCells(i); %#ok<SAGROW>
    DuplicateFullRows(end+1,1)=DuplicateRows(i); %#ok<SAGROW>
    if isempty(keys), UniqueConfigurations(end+1,1)=NaN; DuplicateConfigurationRows(end+1,1)=NaN; %#ok<SAGROW>
    else, UniqueConfigurations(end+1,1)=numel(unique(keys)); DuplicateConfigurationRows(end+1,1)=numel(keys)-numel(unique(keys)); %#ok<SAGROW>
    end
    InvalidSimulationRows(end+1,1)=invalidRows(T); NonfiniteNumericCells(end+1,1)=nonfiniteCount(T); %#ok<SAGROW>
    KeyColumns(end+1,1)=strjoin(cols,','); %#ok<SAGROW>
end
DatasetIntegrity=table(DatasetPath,DatasetTopology,DatasetRole,DatasetRows,MissingCellsN, ...
    DuplicateFullRows,UniqueConfigurations,DuplicateConfigurationRows,InvalidSimulationRows, ...
    NonfiniteNumericCells,KeyColumns);
writetable(DatasetIntegrity,fullfile(outDir,'Phase6B_DatasetIntegrity.csv'));

%% Cross-file configuration overlaps: same topology only
OverlapPairs=table();
for a=1:numel(idx)
 for b=a+1:numel(idx)
    ia=idx(a); ib=idx(b);
    if Topology(ia)~=Topology(ib) || Topology(ia)=="Unknown", continue; end
    shared=intersect(KeyCols{a},KeyCols{b},'stable'); if numel(shared)<3, continue; end
    ka=configKeys(Tables{ia},shared); kb=configKeys(Tables{ib},shared);
    if isempty(ka)||isempty(kb), continue; end
    overlap=numel(intersect(unique(ka),unique(kb))); if overlap==0, continue; end
    ra=Role(ia); rb=Role(ib);
    splitLike=ismember(ra,["Train","Development","Holdout","Test","OutOfFold"]) && ...
              ismember(rb,["Train","Development","Holdout","Test","OutOfFold"]);
    row=table(FilePath(ia),FilePath(ib),Topology(ia),strjoin(shared,','),overlap,ra,rb,splitLike, ...
      'VariableNames',{'FileA','FileB','Topology','SharedKeyColumns','OverlappingUniqueConfigurations','RoleA','RoleB','PotentialSplitLeakage'});
    OverlapPairs=[OverlapPairs;row]; %#ok<AGROW>
 end
end
if isempty(OverlapPairs)
 OverlapPairs=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),zeros(0,1),strings(0,1),strings(0,1),false(0,1), ...
 'VariableNames',{'FileA','FileB','Topology','SharedKeyColumns','OverlappingUniqueConfigurations','RoleA','RoleB','PotentialSplitLeakage'});
end
writetable(OverlapPairs,fullfile(outDir,'Phase6B_ConfigOverlapPairs.csv'));

%% Topology summary
uTop=unique(Topology); TopologySummary=table();
for k=1:numel(uTop)
 z=Topology==uTop(k);
 row=table(uTop(k),sum(z),sum(z&IsLikelyDataset),sum(z&ReadStatus=="OK"),sum(z&ReadStatus~="OK"), ...
    sum(MissingCells(z),'omitnan'),sum(DuplicateRows(z),'omitnan'), ...
    'VariableNames',{'Topology','CSVFiles','LikelyDatasets','ReadableFiles','ReadErrors','MissingCellsTotal','DuplicateRowsTotal'});
 TopologySummary=[TopologySummary;row]; %#ok<AGROW>
end
writetable(TopologySummary,fullfile(outDir,'Phase6B_TopologySummary.csv'));
save(fullfile(outDir,'Phase6B_AuditBundle.mat'),'Inventory','ExactDuplicateFiles','DatasetIntegrity','OverlapPairs','TopologySummary');

fprintf('\n===== PHASE 6B SUMMARY =====\nCSV files scanned: %d\nReadable: %d\nRead errors: %d\n',n,sum(ReadStatus=="OK"),sum(ReadStatus~="OK"));
fprintf('Likely circuit datasets: %d\nExact-duplicate file rows: %d\n',sum(IsLikelyDataset),height(ExactDuplicateFiles));
fprintf('Dataset integrity records: %d\nConfiguration-overlap pairs: %d\n',height(DatasetIntegrity),height(OverlapPairs));
disp(TopologySummary);
fprintf('\nPotential split leakage pairs (review manually):\n');
if any(OverlapPairs.PotentialSplitLeakage), disp(OverlapPairs(OverlapPairs.PotentialSplitLeakage,:)); else, fprintf('None flagged by filename-role heuristic.\n'); end
fprintf('\nReports saved to: %s\n',outDir);
fprintf('Overlap means shared configurations, not proof of leakage; inspect split methodology.\n');

%% Local helper functions
function top=classifyTopology(p)
 s=lower(string(p));
 if contains(s,'common_source')||contains(s,'mosfet')||contains(s,'2n7000'), top="MOSFET_Common_Source";
 elseif contains(s,'common_emitter')||contains(s,'bjt')||contains(s,'ce_'), top="BJT_Common_Emitter";
 else, top="Unknown"; end
end
function role=classifyRole(p)
 s=lower(string(p));
 if contains(s,'train'), role="Train";
 elseif contains(s,'holdout')||contains(s,'independentvalidation'), role="Holdout";
 elseif contains(s,'test'), role="Test";
 elseif contains(s,'dev')||contains(s,'development'), role="Development";
 elseif contains(s,'oof')||contains(s,'outoffold'), role="OutOfFold";
 else, role="Unclassified"; end
end
function h=hashFile(p)
 h="";
 try
  md=java.security.MessageDigest.getInstance('SHA-256'); fis=java.io.FileInputStream(java.io.File(p)); c=onCleanup(@()fis.close());
  dis=java.security.DigestInputStream(fis,md); buf=zeros(1,65536,'int8');
  while dis.read(buf,0,numel(buf))~=-1, end
  b=typecast(md.digest(),'uint8'); h=lower(string(reshape(dec2hex(b,2).',1,[])));
 catch
 end
end
function m=missingCount(T)
 m=0;
 for j=1:width(T)
  v=T{:,j};
  if isnumeric(v), m=m+sum(ismissing(v(:)) | (isfloat(v(:)) & ~isfinite(v(:))));
  else
   try, s=string(v(:)); m=m+sum(ismissing(s)|strlength(strtrim(s))==0); catch, end
  end
 end
end
function d=duplicateRowCount(T)
 d=0; if height(T)<2, return; end
 try, [~,ia]=unique(T,'rows','stable'); d=height(T)-numel(ia); catch, end
end
function [keys,cols]=configKeys(T,forceCols)
 names=string(T.Properties.VariableNames); norm=lower(regexprep(names,'[^a-zA-Z0-9]',''));
 candidates=["rguohm","rglohm","rdohm","rsohm","cinf","vddv", ...
             "r1ohm","r2ohm","rcohm","reohm","rlohm","cinh","couth","ceh","vccv"];
 candidates=replace(candidates,' ','');
 if nargin>1, want=lower(regexprep(string(forceCols),'[^a-zA-Z0-9]','')); else, want=candidates; end
 cols=names(ismember(norm,want)); keys=strings(0,1); if numel(cols)<3, return; end
 X=T(:,cols); keys=strings(height(X),1);
 for r=1:height(X)
  p=strings(1,width(X));
  for c=1:width(X)
   v=X{:,c};
   if isnumeric(v), val=double(v(r)); if isfinite(val), p(c)=string(sprintf('%.12g',val)); else, p(c)="NaN"; end
   else, p(c)=strtrim(string(v(r))); end
  end
  keys(r)=strjoin(p,'|');
 end
end
function n=invalidRows(T)
 n=0; names=string(T.Properties.VariableNames);
 for wanted=["SimulationValid","DCSuccess","ACSuccess","Simulation_Status","Status"]
  j=find(strcmpi(names,wanted),1); if isempty(j), continue; end
  v=T{:,j};
  if islogical(v), bad=~v(:); elseif isnumeric(v), bad=~isfinite(v(:))|v(:)==0;
  else, s=lower(strtrim(string(v(:)))); bad=ismember(s,["false","0","failed","fail","error","invalid"]); end
  n=max(n,sum(bad));
 end
end
function n=nonfiniteCount(T)
 n=0; for j=1:width(T), v=T{:,j}; if isnumeric(v), n=n+sum(~isfinite(v(:))); end, end
end
