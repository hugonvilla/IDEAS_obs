function C = audio_clean(Fopath,UD,W)

%%%%% This script reads the audio file, synchronizes it, labels starting,
%%%%% end, and sync time in audio time

%addpath(fullfile(pwd,'util'))

%% Read Metadata and initialize output
[~,Fname] = fileparts(Fopath); %folder name
MD = UD.MD;
Bname = W.Bname;
Vdat = W.Vdat;
Indiv = UD.Indiv;
ID = Indiv.ID;
[~,ix] = sort(Indiv.SyncTime);
Indiv = Indiv(ix,:); %sort in chronological order

if exist(fullfile(Fopath,'Elog.txt'),'file')
    opts = delimitedTextImportOptions("NumVariables", 1);
    opts.Delimiter = "";
    opts.VariableTypes = "string";
    Elog = readmatrix(fullfile(Fopath,'Elog.txt'),opts);
else
    Elog = [];
end

PA = parameters();

C.AT = [];
C.AU=[];
C.Elog = Elog;

%% Synchronize
%%%%% Set approximate boundaries of audio recordings
Adata = dir([fullfile(Fopath,'Audio') '/*.wav']);
Adata(cellfun(@(x) ismember(x(1),{'.','_','~'}), {Adata.name}.'),:)=[]; %delete ghost files
AU=[];
varNames = {'filename','id','start_time','end_time','sync_time','sync_time_sys'};
for i = 1:size(Adata,1) %for each file
    namei = Adata(i).name;
    fold = Adata(i).folder;
    if ~contains(namei,Fname) %if file name does not have the folder name
        if numel(split(namei,'_')) ~= 2 %if not standard naming convention
            msg = ['ERROR: File "' namei '" is not named correctly. Please fix it and run again.'];
            disp(msg)
            Elog = [Elog; string(msg)]; %concatenate error log (string)
            writematrix( Elog , fullfile(Fopath,'Elog.txt'));
            C.Elog = Elog;
            return
        end
        name = [Fname '_' namei];
        movefile(fullfile(fold,namei),fullfile(fold,name));
    else
        name = namei;
    end
    fname = fullfile(fold,name);
    Rfname = split(name,'_');
    Rname(i) = string(Rfname{end-1}); %recorder name
    Finame(i) = str2num(erase(Rfname{end},{'.WAV','.wav'})); %part number
    info = audioinfo(fname);
    Dur(i) = seconds(info.Duration);
    if Finame(i) > 1 %%if continuation of a file
        if i == 1 || Rname(i) ~= Rname(i-1) %if continuation does not have a preceding
            msg = ['ERROR: File "' name '" is not named correctly (does not have a part 01.)'];
            disp(msg)
            Elog = [Elog; string(msg)]; %concatenate error log (string)
            writematrix( Elog , fullfile(Fopath,'Elog.txt'));
            C=C.Elog;
            return
        end
        To(i) = To(i-1)+Dur(i-1);
        Id(i) = Id(i-1); 
        Y0(i)  = -seconds(Dur(i-1))+ Y0(i-1); %negative sync time because it belongs to the previous file
    else    
        Indi = find(strcmp(Indiv.Recorder_name,Rname(i)));
        
        if isempty(Indi)
            msg = ['ERROR: Recorder "' Rname(i) '" is not assigned to an ID in INDIV.xlsx'];
            disp(msg)
            Elog = [Elog; string(msg)]; %concatenate error log (string)
            writematrix( Elog , fullfile(Fopath,'Elog.txt'));
            C=C.Elog;
            return
        end
        SyncT = Indiv.SyncTime(Indi(1));
        SyncTAudio = Indiv.SyncTimeAudio(Indi(1));
        Id(i) = Indiv.ID(Indi(1));
        if MD.tdur > 0
            if ismissing(SyncTAudio) %if no SyncTAudio provided
                Y0(i) = pulse_detect(fname,MD.tdur,MD.tfreq); %sync time in audio time (seconds)
            else
                Y0(i) = SyncTAudio;
            end
        else %if sync tone duration is zero in the MD file
            Y0(i) = 0; %set sync time as initial audio time
        end
        To(i) = datetime(SyncT-seconds(Y0(i)),'Format','MMddyy_HHmmssSSS','TimeZone',MD.timezone); %recording start time in system time
    end
    Tf(i) = To(i) + Dur(i);
    if ~ismissing(To(i))
        AU = [AU; table(string(name),Id(i),To(i),Tf(i),Y0(i),SyncT,'VariableNames',varNames)];
    else
        msg = ['ERROR: File "' name '" could not be synchronized. Synchronize manually'];
        disp(msg)
        Toe = NaT(1,1,'TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS'); %error time
        AU = [AU; table(string(name),Id(i),Toe,Toe,nan,Toe,'VariableNames',varNames)]; %write error
        Elog = [Elog; string(msg)]; %concatenate error log (string)
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
    end
end

%% Valid data
Aname = unique(AU.id);
for i=1:numel(Bname) %for each beacon
    if ~isempty(Vdat{i}) %if valid or ominipresent beacon data
        idb = find(strcmp(Aname,Bname(i)));
        if ~isempty(idb) %if participant has a recording
            AUi = AU(AU.id == Aname(idb),:);
            Vdati = [max(Vdat{i}(:,1),AUi.start_time(1)),min(Vdat{i}(:,2),AUi.end_time(end))];
            Vdati(seconds(Vdati(:,2)-Vdati(:,1))<=0,:)=[]; %delete out-of-bounds segments
            Vdat{i} = Vdati;
        end
    end
end

C.AU=AU;
C.Elog = Elog;
C.Vdat=Vdat;

save(fullfile(Fopath,'Temp',['AUdata_' Fname '.mat']),'C')








