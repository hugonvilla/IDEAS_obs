function UD = input_clean(Fopath)
Elog = []; %initialize error log
UD.Elog=[];
%% Metadata read
[~,Fname] = fileparts(Fopath);
MDopts = delimitedTextImportOptions("NumVariables", 6, "Encoding", "UTF-8");
MDopts.VariableTypes = repmat("string",1,6);
MDopts.VariableNames = ["sys_sync", "tfreq", "tdur", "system_on", "system_off","timezone"];
MD = readtable(fullfile(Fopath,'MD.csv'), MDopts);
MD(1,:)=[]; %delete variable name line
MD.system_on = datetime(MD.system_on,'InputFormat','MMddyy_HHmmss','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS');%observation onset: 5 minutes after Ttone, assuming it takes that long to have all kids wearing the hardware. Manual entry if otherwise
MD.system_off = datetime(MD.system_off,'InputFormat','MMddyy_HHmmss','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS'); %observation offset
MD.sys_sync = datetime(MD.sys_sync,'InputFormat','MMddyy_HHmmss','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS');
MD.tfreq = str2num(MD.tfreq);
MD.tdur = str2num(MD.tdur);

%% Indiv read
Iopts = spreadsheetImportOptions("NumVariables", 6);
Iopts.VariableNames = ["ID", "Beacon_name","Recorder_name", "Beacon_on", "SyncTime","SyncTimeAudio"];
Iopts.VariableTypes = repmat("string",1,6);
Indiv = readtable(fullfile(Fopath,'INDIV.xlsx'), Iopts, "UseExcel", false);
Indiv(1,:)=[];
if ismember('X00',Indiv.ID) %if all children are located/enrolled
    MD.X00 = 1;
    Indiv(Indiv.ID=='X00',:)=[];
    if isempty(find(contains(Indiv.ID,'S')))
        msg = ['ERROR: in INDIV File in ' Fname '. To use X00, at least one children must be enrolled.'];
        disp(msg)
        Elog = [Elog;string(msg)];
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
        UD.Elog = Elog;
        return  
    end
else
    MD.X00 = 0;
end
if ismember('Y00',Indiv.ID)  %if all teachers are located/enrolled
    MD.Y00 = 1;
    Indiv(Indiv.ID=='Y00',:)=[];
    if isempty(find(contains(Indiv.ID,'T')))
        msg = ['ERROR: in INDIV File in ' Fname '. To use Y00, at least one teacher must be enrolled.'];
        disp(msg)
        Elog = [Elog;string(msg)];
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
        UD.Elog = Elog;
        return  
    end
else
    MD.Y00 = 0;
end
UD.MD = MD;
Indiv(ismissing(Indiv.Beacon_name),:)=[]; %delete entries with no beacons. This is old behavior
Bnamei = string(cellfun(@(x) extractAfter(x,length(x)-4),Indiv.Beacon_name,'UniformOutput',false)); %only keep last 4 digits
Indiv.Beacon_name = Bnamei;
inm = find(~ismissing(Indiv.Recorder_name));
Rnamei = string(cellfun(@(x) extractAfter(x,length(x)-3),Indiv.Recorder_name(inm),'UniformOutput',false)); %only keep last 3 digits
Indiv.Recorder_name(inm) = Rnamei;
Indiv.Beacon_on = datetime(Indiv.Beacon_on,'InputFormat','MMddyy_HHmmss','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS');
Indiv.SyncTime = datetime(Indiv.SyncTime,'InputFormat','MMddyy_HHmmss','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS');
Indiv.SyncTimeAudio = str2double(Indiv.SyncTimeAudio); %sync tone in seconds of audio recording
ID = unique(Indiv.ID);
for  i = 1:numel(ID)
    if ID(i) == "S00"
        msg = ['ERROR: INDIV File in ' Fname ' has invalid IDs like "S00".'];
        disp(msg)
        Elog = [Elog;string(msg)];
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
        UD.Elog = Elog;
        return   
    end
    idx = find(Indiv.ID==ID(i));
    for j = 1:numel(idx) %for each entry
        if ismissing(Indiv.Beacon_on(idx(j)))
            Indiv.Beacon_on(idx(j)) = MD.system_on;
        else
            Indiv.Beacon_on(idx(j)) = max([MD.system_on,Indiv.Beacon_on(idx(j))]);
        end
    end
    [~,ix] = sort(Indiv.Beacon_on(idx));
    Indiv.Beacon_off(idx(ix(end))) = MD.system_off;
    if numel(idx) > 1
        for j=numel(idx)-1:-1:1 %start from last
            Indiv.Beacon_off(idx(ix(j))) = Indiv.Beacon_on(idx(ix(j+1)));
        end 
    end   
end
for i = 1:size(Indiv,1) %for each entry
    if ismissing(Indiv.SyncTime(i)) %if no synctime, then assign general synctime
        Indiv.SyncTime(i) = MD.sys_sync;
    end
end
UD.Indiv=Indiv; %store table

%%%%% Check for errors in INDIV input
[Uid,~,ic] = unique(Indiv.ID);
Hc=histcounts(ic,numel(unique(ic)));
Re = find(Hc>1); %indices of repeated elements
if ~isempty(Re)
    for i = 1:length(Re)
        idi = find(Indiv.ID == Uid(Re(i)));
        if numel(unique(Indiv.Beacon_on(idi))) ~= numel(idi) 
            msg = ['ERROR: INDIV File in ' Fname ' has multiple simultaneous beacons with the same ID. Fix INDIV and run again'];
            disp(msg)
            Elog = [Elog;string(msg)];
            writematrix( Elog , fullfile(Fopath,'Elog.txt'));
            UD.Elog = Elog;
            return   
        end
    end
end
save(fullfile(Fopath,'Temp',['Idata_' Fname '.mat']),'UD')








