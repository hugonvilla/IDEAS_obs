function flag = run_OBS_audio()
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
%% Audio Sync
disp('Audio synchronization tone will sound in 10 seconds.');
disp('Prepare the voice recorders. Make sure the computer volume is at 100%.')
Ta = sync_tone_gen(Tf);
don = datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local');  
disp('Obs running...')
%% Save Data
Dname = convertStringsToChars(string(don));
Dfol = fullfile(pwd,'data','to_clean',[Cnums,'_',Dname]); %destination folder (classroom name + onset date)
mkdir(Dfol)

Ta.system_on = string(don);
Ta.system_off = string(don+seconds(8*60*60)); %placeholder
Ta.tzoffset = string(tzoffset(don)); %time zone offset
writetable(Ta,fullfile(Dfol,'MD.csv'));

mkdir(Dfol,'Audio')

rmpath(fullfile(pwd,'bin'))
disp('run_OBS_audio ran successfully.')
flag=0;







