function flag = run_OBS()
%%%%% Runs Observation Protocol. Make sure all beacons and recorders are
%%%%% ON and the computer is connected to the reelyActive Wifi network.
%%%%% If errors occur, check protocol and run again
%%%%% Required: install node and logger packages
addpath(fullfile(pwd,'bin'))

%% Get classroom number
fl = 0;
while fl == 0
    Cnum = input('Input the four-digit classroom number (example: 0034):','s');
    ndig=numel(str2num(Cnum(:)));%number of digits
    if ndig ~= 4
        disp('The classroom number must have four digits.')
    else
        Cnums = Cnum;
        fl = 1;
    end
end
%% Run Parameters
Tf = 3000; %sync tone frequency
Tp = 15; %warm-up time
%% Diract warm-up
disp(['Warming-up Logger. This will take ' num2str(Tp) ' seconds'])
dnow = datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local'); %get current system time in local time
if isunix
    !node logger &
    pause(Tp)
    !killall node
elseif ispc
    !start /b node logger
    pause(Tp)
    !taskkill -f -im node.exe
end

Fopath = pwd;
Tdata = dir([Fopath '/*.csv']);
Tdata(~contains({Tdata.name}.','dynamb'),:)=[];
Tdata(cellfun(@(x) ismember(x(1),{'.','_','~'}), {Tdata.name}.'),:)=[];%delete ghost files
date = datetime({Tdata.date}.', 'InputFormat','dd-MMM-uuuu HH:mm:ss','TimeZone','local'); %last modified

if ~any(abs(seconds(date-dnow))<Tp*2) %if no file has been created or modified within 2*Tp seconds
    error('ERROR: The log file was not created. Check your connection to the reelyActive network')
end
[~,ik] = max(date); %get last created file
Tname = Tdata(ik).name;
T = read_dynamb(Tname);
T(strcmp(T.nearest,'[]'),:) = []; %delete inactive rows
[Bname,~,ic] = unique(T.deviceId); %get beacon names
Hab = histcounts(ic,numel(unique(ic)));%frequencies for beacons broadcast
Invbeac = Bname(Hab < ceil(0.2*max(Hab))); %also delete beacons with few appearances
T(contains(T.deviceId,Invbeac),:)=[]; 
Bname = unique(T.deviceId); %final beacon name
Nbeac = length(Bname);
delete *.csv
disp(['There are ' num2str(Nbeac) ' active beacons.'])
%% Audio Sync
disp('Audio synchronization tone will sound in 10 seconds.');
disp('Prepare the voice recorders. Make sure the computer volume is at 100%.')
Ta = sync_tone_gen(Tf);
%% Run Logger 
flag = 0;
if isunix
    !node logger &
elseif ispc
    !start /b node logger
end
    
don = datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local');  
disp('Logger running...')
while flag == 0
    SIU = input('Enter STOP to halt the data collection: ','s');
    if strcmp(SIU,'STOP')
       doff = datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local'); %get current system time
       if isunix
           !killall node
        elseif ispc
           !taskkill -f -im node.exe
       end
       flag = 1;
    end
end

Dur = minutes(doff-don);
if Dur > 15
    don = don+minutes(10); %if long observation, %%observation onset: 10 minutes after Ttone, assuming it takes that long to have all kids wearing the hardware. Manual entry if otherwise
end

%% Save Data
Dname = convertStringsToChars(string(don));
Dfol = fullfile(pwd,'data','to_clean',[Cnums,'_',Dname]); %destination folder (classroom name + onset date)
mkdir(Dfol)

Ta.system_on = string(don);
Ta.system_off = string(doff);
Ta.tzoffset = string(tzoffset(don)); %time zone offset
writetable(Ta,fullfile(Dfol,'MD.csv'));

%%%%% Check beacon data
disp('Processsing Data. This will take 5 seconds. Do not turn off the laptop.')
Tdata = dir([Fopath '/*.csv']);
Tdata(~contains({Tdata.name}.','dynamb'),:)=[];
Tdata(cellfun(@(x) ismember(x(1),{'.','_','~'}), {Tdata.name}.'),:)=[];%delete ghost files
for ii = 1:size(Tdata,1) %for each file 
    Tname = fullfile(Fopath,Tdata(ii).name);
    TA = read_dynamb(Tname);
    if ii > 1 %if second file or more
        T = [T;TA];
    else
        T = TA;
    end
    clear TA
end
T.deviceId = cellfun(@(x) x(end-3:end),T.deviceId,'UniformOutput',false); %merge beacons detected from different owls

[Bname,~,ic] = unique(T.deviceId); %get beacon names
Hab = histcounts(ic,numel(unique(ic)));%frequencies for beacons broadcast
Invbeac = Bname(Hab < ceil(0.2*max(Hab))); %delete beacons with few appearances
T(contains(T.deviceId,Invbeac),:)=[]; 
Bname = unique(T.deviceId); %final valid beacon name
Bnamei = string(cellfun(@(x) extractAfter(x,length(x)-4),Bname,'UniformOutput',false)); %only keep last 4 digits
Bnamei = append("B",Bnamei);
Bcol = strings(size(Bnamei,1),1); %blank column
Ncol = repmat("S00",size(Bnamei,1),1); %name column
Rcol = repmat("R000",size(Bnamei,1),1); %recorder column

Blev = [];
for jj = 1:length(Bname)
    Tbjj = T(strcmp(T.deviceId,Bname{jj}),:);
    Btraj = Tbjj.batteryPercentage;
    Blev(jj,1) = mean(Btraj(end-round(0.1*length(Btraj)):end),'omitnan');
end

Tindiv = table(Ncol,Bnamei,Rcol,Bcol,Bcol,Bcol,Bcol,Blev,...
              'VariableNames',{'ID','Beacon_name','Recorder_name','Beacon_on','SyncTime','SyncTimeAudio','Obs','Bat_level'});

movefile('*.csv',fullfile(Dfol,'Beacons'))
mkdir(Dfol,'Audio')

writetable(Tindiv,fullfile(Dfol,'INDIV.xlsx'));

rmpath(fullfile(pwd,'bin'))
disp('run_OBS ran successfully.')







