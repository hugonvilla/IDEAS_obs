function W = logger_clean(Fopath,UD,obsflag)
%%%% Decodes logger output

%addpath(fullfile(pwd,'util'))
%% Read Metadata and initialize output
%initialize output
[~,Fname] = fileparts(Fopath);
if isempty(UD)
    UD = input_clean(Fopath);
end

if exist(fullfile(Fopath,'Elog.txt'),'file')
    opts = delimitedTextImportOptions("NumVariables", 1);
    opts.Delimiter = "";
    opts.VariableTypes = "string";
    Elog = readmatrix(fullfile(Fopath,'Elog.txt'),opts);
else
    Elog = [];
end

MD = UD.MD;   
Indiv = UD.Indiv;
W.Bname = [];
W.Tvec= []; 
W.Btraj = []; 
W.Atraj = []; 
W.Wtraj = [];    
W.Msr= [];
W.Vdat = [];
W.Elog=Elog;

svmax = load('svm_accel.mat'); svmax = svmax.trainedModel; %load accelerometer classifier
WGname = fullfile(Fopath,'Beacons',['WG_' Fname '.mat']); %name of externally generated data
%% Parameters
PA = parameters(); %load parameters
Ebft = PA.Tsw; % 3; %expected beacon sampling time in seconds. Depends on diract.js
Sdur = seconds(MD.system_off-MD.system_on);
MinDet = min(150,0.5*Sdur/Ebft); %minimum beacon detection events (Merge/2 = 7.5)
Trssi = PA.Trssi; %-75; %rssi threshold. default is -74
Tsw = PA.Tsw;
%% Read files and Create Master Table TAL
Tdata = dir([fullfile(Fopath,'Beacons') '/*.csv']); %make sure they are in chronological order, which they should be based on how logger outputs filenames
Tdata(~contains({Tdata.name}.','dynamb'),:)=[];
Tdata(cellfun(@(x) ismember(x(1),{'.','_','~'}), {Tdata.name}.'),:)=[];%delete ghost files
if size(Tdata,1)>=1
    for ii = 1:size(Tdata,1) %for each file 
        Tname = fullfile(Fopath,'Beacons',Tdata(ii).name);
        TA = read_dynamb(Tname);
        if ii > 1 %if second file or more
            T = [T;TA];
        else
            T = TA;
        end
        clear TA
    end
    %% Decode Dynamb
    T = T(find(T.timestamp >= 1000*posixtime(MD.system_on) & T.timestamp <= 1000*posixtime(MD.system_off)),:); %within observations
    if isempty(T)
        msg = join(['No valid beacon data was detected within the observation times in folder ' Fname '.'],'');
        disp(msg)
        Elog = [Elog;string(msg)];
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
        %return
    end
    T.deviceId = cellfun(@(x) x(end-3:end),T.deviceId,'UniformOutput',false); %merge beacons detected from different owls
    
    [Bn,~,ic] = unique(T.deviceId); %get beacon names
    Hab = histcounts(ic,numel(unique(ic)));%frequencies for beacons broadcast
    Invbeac = Bn(Hab<MinDet); %also delete beacons with few appearances
    T(contains(T.deviceId,Invbeac),:)=[]; 
    %%%%%%%% Change beacon names to Subject ID
    for i = 1:size(Indiv,1) %for each entry in Indiv table
        toi = Indiv.Beacon_on(i);
        tfi = Indiv.Beacon_off(i);
        Ind = find(contains(T.deviceId,Indiv.Beacon_name(i)) & T.timestamp >= 1000*posixtime(toi) & T.timestamp <= 1000*posixtime(tfi));
        T.SID(Ind) = Indiv.ID(i);
    end
    T(ismissing(T.SID),:)=[]; %delete invalid veacons
    Bname = unique(T.SID); %Subject list
    DN = setdiff(Indiv.ID,Bname);
    if ~isempty(DN)
        msg = join(['Beacons associated with ID ' join(DN,',') ' in folder ' Fname ' show no valid data. Correct INDIV.xlsx file'],'');
        disp(msg)
        Elog = [Elog;string(msg)];
        writematrix( Elog , fullfile(Fopath,'Elog.txt'));
        %return
    end
    Tvec = sort(unique(T.timestamp)); %time vector
    
    %% Main Loop
    Btraj=nan(size(Tvec,1),length(Bname)); Atraj=Btraj; Msr=[]; Vdat=[];
    Wtraj = nan(length(Bname),length(Bname),size(Tvec,1));
    for jj = 1:length(Bname) %for each Individual
        %% Battery, Accelerometer, sampling rate
        Tbjj = T(strcmp(T.SID,Bname{jj}),:);
        [Tvecj,itvecj] = unique(Tbjj.timestamp); %avoid uncommon double reporting
        Ind = find(ismember(Tvec,Tvecj));
        if isempty(Ind) == 0
            Btraj(Ind,jj) = Tbjj.batteryPercentage(itvecj);
            Atraj(Ind,jj) = cellfun(@(x) norm(str2num(x)), Tbjj.acceleration(itvecj));
        end
        Tjj = Tvec(find(~isnan(Btraj(:,jj))))/1000; %times in seconds
        Msr(jj,:) = [mean(diff(Tjj)) std(diff(Tjj))]; %mean and standard deviation of sample rate
        %% Valid data
        if Sdur > 10*60 && obsflag == 1 %if OBS was less than 10 minutes, it's probably a test
            Iati = accel_process(Atraj(:,jj),svmax);
            %Iati = [1 length(Tvec)]; %bypass accel_process
            Iati = max(1,min(length(Tvec),Iati));
        else
            Iati = [1 length(Tvec)];
        end
        Tati = [Tvec(Iati(:,1)) Tvec(Iati(:,2))]; %valid times in posix*1000
        Vdat{jj} = datetime(Tati/1000,'ConvertFrom','posixtime','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS'); 
        %% Dynamic Adjacency Matrix
        for k = 1:size(Tbjj,1) %for each broadcast     
            Tkind = find(Tvec==Tbjj.timestamp(k)); %time index in Tvec (posix*1000)
            newString = strsplit(Tbjj.nearest{k},',');
            if size(newString,2) > 1 %if there is some detection
                for ik = 1:2:length(newString) %for each nearestid in broadcast k (odd elements in newString)
                    NearId = extractAfter(newString{ik},':'); %near ID beacon
                    Idxnam = find(contains(Indiv.Beacon_name,NearId(end-3:end)) & 1000*posixtime(Indiv.Beacon_on) <= Tbjj.timestamp(k) & 1000*posixtime(Indiv.Beacon_off) >= Tbjj.timestamp(k)); %index of detected person
                    if ~isempty(Idxnam)
                        idxn = find(strcmp(Bname,Indiv.ID(Idxnam)));
                        Rssi = str2double(extractBetween(newString{ik+1},':','}'));
                        Wtraj(idxn,jj,Tkind) = Rssi;
                    end
                end
            end
        end
    end
    
    %% Process Logger
    %%%%% Make Adjacency Matrices symmetric
    Wtrajsym = Wtraj;
    for jj = 1:length(Bname) %for each subject
        Wjj = squeeze(Wtraj(:,jj,:)); %observed by jj
        for uu = 1:length(Bname) %for each subject
            Wuu = squeeze(Wtraj(:,uu,:)); %observed by uu
            Wjj(uu,:) = mean([Wjj(uu,:);Wuu(jj,:)],'omitnan'); %average of observation, but it could be the max
        end 
        Wtrajsym(:,jj,:)=Wjj;
    end
    Wtraj = Wtrajsym; clear Wtrajsym
    %%%%% Threshold
    Wtraj(Wtraj<Trssi) = nan; %remove indices less than threshold\
    %%%% Resample by using "retime" with timetable
    Wprox = Wtraj; 
    Wprox = permute(Wprox,[3 1 2]);
    Tdat = datetime(Tvec/1000,'ConvertFrom','posixtime','TimeZone',MD.timezone,'Format','MMddyy_HHmmssSSS'); 
    Tm = timetable(Tdat,Wprox,Btraj,Atraj);
    WR = retime(Tm,'regular','mean','TimeStep',seconds(Tsw)); %resample regularly every Tsw seconds
    Tmr = timetable2table(WR);
    Wtraj = permute(Tmr.Wprox,[2 3 1]); %Resampled Trajectory
    Atraj = Tmr.Atraj;
    Btraj = Tmr.Btraj;
    Tvec = posixtime(Tmr.Tdat)*1000; %resampled time vector
elseif exist(WGname,'file') %if externally generated proximity data exists 
    WG = load(WGname); WG=WG.WG;
    Bname = WG.Bname;
    Tvec = WG.Tvec;
    Vdat = WG.Vdat;
    Wtraj = WG.Wtraj;
    Atraj = zeros(length(Tvec),length(Bname));
    Btraj = zeros(length(Tvec),length(Bname));
    Msr=[];
else %if no beacon data, generate synthetic omnipresent data
    Bname = Indiv.ID;
    Tvec = MD.system_on + seconds(0:Ebft:Sdur);
    Tvec = posixtime(Tvec)*1000;
    Wtraj = 0.9*Trssi*(ones(length(Bname),length(Bname),length(Tvec))...
            - repmat(eye(length(Bname)),1,1,length(Tvec))); %fully, loosely connected (above Tcs)
    Vdat = cell(1,1);
    for i = 1:length(Bname)
        Vdat{i} = [MD.system_on MD.system_off]; %omnipresent data
    end
    Atraj = zeros(length(Tvec),length(Bname));
    Btraj = zeros(length(Tvec),length(Bname));
    Msr=[];
end
Vdata = vertcat(Vdat{:});
if ~isempty(Vdata)
    Vmin = min(Vdata(:,1));
    Vmax = max(Vdata(:,2));
else
    Vmin=[];
    Vmax=[];
end
if MD.Y00 == 0 %simulate generic, distant, omnipresent teacher
    Bname(end+1,1) = "T00"; %simulated teacher ID
    Wtraj(:,end+1,:) = 1.1*Trssi*ones(size(Wtraj,1,3));
    Wtraj(end+1,:,:) = 1.1*Trssi*ones(size(Wtraj,2,3));
    Wtraj(end,end,:)=0;
    %Vdat{end+1} = [MD.system_on MD.system_off];
    Vdat{end+1} = [Vmin Vmax];
end

if MD.X00 == 0 %simulate generic, distant, omnipresent peer
    Bname(end+1) = "S00"; %simulated peer ID
    Wtraj(:,end+1,:) = 1.1*Trssi*ones(size(Wtraj,1,3));
    Wtraj(end+1,:,:) = 1.1*Trssi*ones(size(Wtraj,2,3));
    Wtraj(end,end,:)=0;
    %Vdat{end+1} = [MD.system_on MD.system_off];
    Vdat{end+1} = [Vmin Vmax];
end

W.Bname = string(Bname);
W.Tvec= Tvec; 
W.Btraj = Btraj; 
W.Atraj = Atraj; 
W.Wtraj = Wtraj;    
W.Msr= Msr;
W.Vdat = Vdat;

W.Elog = Elog;
save(fullfile(Fopath,'Temp',['Wdata_' Fname '.mat']),'W')

