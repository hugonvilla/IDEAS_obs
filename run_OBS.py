import os   
import subprocess
import time
import numpy as np
import pandas as pd
from datetime import datetime
from bin.sync_tone_gen import sync_tone_gen


def run_OBS(*args,**kwargs):
    ##### Runs Observation Protocol. Make sure all beacons and recorders are
    ##### ON and the computer is connected to the reelyActive Wifi network.
    ##### If errors occur, check protocol and run again
    ##### Required: install node and logger packages
    pwd = os.getcwd()
    PATH_BIN = os.path.join(pwd, 'bin')
    #addpath(fullfile(pwd,'bin'))
    ## Get classroom number
    fl=0
    Cnums = ''
    while fl == 0:
        Cnums = input('Input the four-digit classroom number (example: 0034):')
        ndig = len(Cnums) #Number of digits
        if ndig != 4:
            print('The classroom number must have four digits.')
        else:
            fl=1

    
    ## Run Parameters
    Tf=3000 #sync tone frequency
    Tp=15 #warm-up time
    
    
    ## Diract warm-up
    print (f'Warming-up Logger. This will take {Tp} seconds')
    dnow = datetime.now()#.strftime('%m%d%y_%H%M%S') #get current system time in local time
    #print (dnow)

    #p = subprocess.Popen(["node","logger.js"])
    #time.sleep(Tp)
    #p.terminate()
    
    Fopath = pwd
    Tdata = [FILE for FILE in os.listdir(Fopath) if ".csv" in FILE]
    Tdata = [FILE for FILE in Tdata if "dynamb" in FILE]

    if Tdata == []: #If there is no .csv files
        print ('ERROR: The log file was not created. Check your connection to the reelyActive network')

    date = np.array([os.path.getmtime(os.path.join(Fopath,FILE)) for FILE in Tdata])
    idx = date.argmax() #get last modified file
    date = datetime.fromtimestamp(date[idx]) #last modified 
    diff = (date - dnow).total_seconds() #time difference
    
    #if diff < (Tp * 2): #if no file has been modified within 2*Tp seconds
    #    print('ERROR: The log file was not created. Check your connection to the reelyActive network')
    #    return
    
    Tname=Tdata[idx]
    
    T = pd.read_csv(os.path.join(pwd, Tname))
    T = T[T.nearest != '[]'] #delete inactive rows
    Beacons = T.deviceId.value_counts() #get beacon names and frequencies broadcast
    Beacons = Beacons[Beacons > np.ceil(0.2 * Beacons.max())] #delete beacons with few appearances
    Nbeac = Beacons.size
    #[os.remove(FILE) for FILE in os.listdir(Fopath) if ".csv" in FILE] #delete .csv files
    print (f'There are {Nbeac} active beacons.')

    ## Audio Sync
    print('Audio synchronization tone will sound in 10 seconds.')
    print('Prepare the voice recorders. Make sure the computer volume is at 100%.')
    Ta = sync_tone_gen(Tf)
    ## Run Logger
    flag=0
    #if isunix
    #    #node logger &
    #elif ispc
    #    #start /b node logger
    #end
    
    don=datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local')
    disp('Logger running...')
    while flag == 0:

        SIU=input_('Enter STOP to halt the data collection: ','s')
        if strcmp(SIU,'STOP'):
            doff=datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss','TimeZone','local')
            #if isunix
            #    #!killall node
            #elif ispc
            #    #!taskkill -f -im node.exe
            flag=1

    
    Dur=minutes(doff - don)
    if Dur > 15:
        don=don + minutes(10)
    
    ## Save Data
    Dname=convertStringsToChars(string(don))
    Dfol=fullfile(pwd,'data','to_clean',concat([Cnums,'_',Dname]))
    
    mkdir(Dfol)
    Ta.system_on = copy(string(don))
    Ta.system_off = copy(string(doff))
    Ta.tzoffset = copy(string(tzoffset(don)))
    
    writetable(Ta,fullfile(Dfol,'MD.csv'))
    ##### Check beacon data
    disp('Processsing Data. This will take 5 seconds. Do not turn off the laptop.')
    Tdata=dir(concat([Fopath,'/*.csv']))
    Tdata[logical_not(contains(cellarray([Tdata.name]).T,'dynamb')),arange()]=[]
    Tdata[cellfun(lambda x=None: ismember(x(1),cellarray(['.','_','~'])),cellarray([Tdata.name]).T),arange()]=[]
    
    for ii in arange(1,size(Tdata,1)).reshape(-1):
        Tname=fullfile(Fopath,Tdata(ii).name)
        TA=read_dynamb(Tname)
        if ii > 1:
            T=concat([[T],[TA]])
        else:
            T=copy(TA)
        clear('TA')
    
    T.deviceId = copy(cellfun(lambda x=None: x(arange(end() - 3,end())),T.deviceId,'UniformOutput',false))
    
    Bname,__,ic=unique(T.deviceId,nargout=3)
    
    Hab=histcounts(ic,numel(unique(ic)))
    
    Invbeac=Bname(Hab < ceil(dot(0.2,max(Hab))))
    
    T[contains(T.deviceId,Invbeac),arange()]=[]
    Bname=unique(T.deviceId)
    
    Bnamei=string(cellfun(lambda x=None: extractAfter(x,length(x) - 4),Bname,'UniformOutput',false))
    
    Bnamei=append('B',Bnamei)
    Bcol=strings(size(Bnamei,1),1)
    
    Ncol=repmat('S00',size(Bnamei,1),1)
    
    Rcol=repmat('R000',size(Bnamei,1),1)
    
    Blev=[]
    for jj in arange(1,length(Bname)).reshape(-1):
        Tbjj=T(strcmp(T.deviceId,Bname[jj]),arange())
        Btraj=Tbjj.batteryPercentage
        Blev[jj,1]=mean(Btraj(arange(end() - round(dot(0.1,length(Btraj))),end())),'omitnan')
    
    Tindiv=table(Ncol,Bnamei,Rcol,Bcol,Bcol,Bcol,Bcol,Blev,'VariableNames',cellarray(['ID','Beacon_name','Recorder_name','Beacon_on','SyncTime','SyncTimeAudio','Obs','Bat_level']))
    movefile('*.csv',fullfile(Dfol,'Beacons'))
    mkdir(Dfol,'Audio')
    writetable(Tindiv,fullfile(Dfol,'INDIV.xlsx'))
    rmpath(fullfile(pwd,'bin'))
    disp('run_OBS ran successfully.')


if __name__ == "__main__":
    run_OBS()