import os   
import subprocess
import time
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from bin.sync_tone_gen import sync_tone_gen


def run_OBS():
    ##### Runs Observation Protocol. Make sure all beacons and recorders are
    ##### ON and the computer is connected to the reelyActive Wifi network.
    ##### If errors occur, check protocol and run again
    ##### Required: install node and logger packages
    pwd = os.getcwd()

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
    dnow = datetime.now() #get current system time in local time

    p = subprocess.Popen(["node","logger.js"])
    time.sleep(Tp)
    p.terminate()
    
    Fopath = pwd
    Tdata = [FILE for FILE in os.listdir(Fopath) if ".csv" in FILE]
    Tdata = [FILE for FILE in Tdata if "dynamb" in FILE] #delete ghost files

    if Tdata == []: #If there is no .csv files
        print ('ERROR: The log file was not created. Check your connection to the reelyActive network')
        return

    date = np.array([os.path.getmtime(os.path.join(Fopath,FILE)) for FILE in Tdata]) #get modified date of all .csv files
    idx = date.argmax() #get last modified file
    date = datetime.fromtimestamp(date[idx]) #last modified 
    diff = np.abs((date - dnow).total_seconds()) #time difference
    
    if not diff < (Tp * 2): #if no file has been modified within 2*Tp seconds
        print('ERROR: The log file was not created. Check your connection to the reelyActive network')
        return
    
    
    Tname=Tdata[idx]
    T = pd.read_csv(os.path.join(pwd, Tname)) #get last modified file
    T = T[T.nearest != '[]'] #delete inactive rows
    Beacons = T.deviceId.value_counts() #get beacon names and frequencies broadcast
    Beacons = Beacons[Beacons > np.ceil(0.2 * Beacons.max())] #delete beacons with few appearances
    Nbeac = Beacons.size
    [os.remove(FILE) for FILE in os.listdir(Fopath) if ".csv" in FILE] #delete .csv files
    print (f'There are {Nbeac} active beacons.')

    ## Audio Sync
    print('Audio synchronization tone will sound in 10 seconds.')
    print('Prepare the voice recorders. Make sure the computer volume is at 100%.')
    Ta = sync_tone_gen(Tf)

    ## Run Logger
    flag=0
    logger_log = open("logger.log", "w")
    p = subprocess.Popen(["node","logger.js"], stdout = logger_log)
    
    don = datetime.now()
    print('Logger running...')
    while flag == 0:

        SIU = input('Enter STOP to halt the data collection: ')
        if SIU == 'STOP':
            doff = datetime.now() #get current system time
            p.terminate()
            flag = 1

    Dur = (doff - don).total_seconds() / 60
    if Dur > 15:
        don = don + timedelta(minutes=10) #if long observation, %%observation onset: 10 minutes after Ttone, assuming it takes that long to have all kids wearing the hardware. Manual entry if otherwise

    offset = don.astimezone().utcoffset()
    offset_hours = int(offset.total_seconds() // 3600)
    offset_minutes = int((offset.total_seconds() % 3600) // 60)
    offset_string = f"{offset_hours:+03}:{offset_minutes:02}" #time zone offset from UTC
    
    don  = don.strftime('%m%d%y_%H%M%S')
    doff = doff.strftime('%m%d%y_%H%M%S')
    
    ## Save Data
    Dfol = os.path.join(pwd,'data','to_clean',f'{Cnums}_{don}') #destination folder (classroom name + onset date)
    os.mkdir(Dfol)
    Ta['system_on'] = [don]
    Ta['system_off'] = [doff]
    Ta['tzoffset'] = [offset_string]
    pd.DataFrame.from_dict(Ta).to_csv(os.path.join(Dfol, 'MD.csv'), index = False)
    
    ##### Check beacon data
    print('Processsing Data. This will take 5 seconds. Do not turn off the laptop.')
    Tdata = [FILE for FILE in os.listdir(Fopath) if ".csv" in FILE]
    Tdata = [FILE for FILE in Tdata if "dynamb" in FILE] # delete ghost files
    
    for ii in range (len(Tdata)): #for each file
        Tname = os.path.join(Fopath,Tdata[ii])
        TA = pd.read_csv(Tname)
        if ii > 1: #if second file or more
            #TODO add line below
            #T=concat([[T],[TA]])
            pass
        else:
            T = TA
    
    
    T['deviceId'] = T['deviceId'].str[-4:] # merge beacons detected from different owls
    Beacons = T.deviceId.value_counts() #get beacon names and frequencies broadcast
    Beacons = Beacons[Beacons > np.ceil(0.2 * Beacons.max())] #delete beacons with few appearances
    
    #TODO add line below
    #T[contains(T.deviceId,Invbeac),arange()]=[]
    Bname  = T.deviceId.unique()
    Bnamei = "B" + Bname
    
    
    Blev = []
    for jj in range(len(Bname)):
        Tbjj  =  T.loc[T['deviceId'] == Bname[jj]]
        Btraj = Tbjj.batteryPercentage
        Blev.append(np.round(Btraj.mean(skipna=True), decimals=0))
    
    column_names = ['ID','Beacon_name','Recorder_name','Beacon_on','SyncTime','SyncTimeAudio','Obs','Bat_level']
    Ncol = np.array(['S00' for x in range(len(Bname))]) #name column
    Rcol = np.array(['R000' for x in range(len(Bname))]) #recorder column
    Bcol = np.array(['' for x in range(len(Bname))]) #blank column
    Tindiv = pd.DataFrame(np.array([Ncol,Bnamei,Rcol,Bcol,Bcol,Bcol,Bcol,Blev]).T, columns=column_names)
    Tindiv.to_excel(os.path.join(Dfol,'INDIV.xlsx'), index=False, engine = 'xlsxwriter')
    os.mkdir(os.path.join(Dfol,'Audio'))
    os.mkdir(os.path.join(Dfol,'Beacons'))
    [os.rename(os.path.join(pwd,FILE), os.path.join(Dfol,'Beacons',FILE)) for FILE in os.listdir(pwd) if ".csv" in FILE]
    
    print('run_OBS ran successfully.')


if __name__ == "__main__":
    run_OBS()
