import numpy as np
import sounddevice as sd
import time
import os
from datetime import datetime, timedelta

# Code to generate synchronization tone. This script should be run at
# the beginning and end of the observations (before turning off the
# voice recorders.)
def sync_tone_gen (Tf):
    # Tone Parameters
    BIT_RATE = 16
    MAX_AMP = (2**BIT_RATE/2)-1
    Td = 0.5 # duration of tone
    DT = 10 # tone delay in seconds
    Tf = Tf

    #Tone time
    Tnow = datetime.now()
    Ttone = (Tnow + timedelta(seconds=DT)).strftime('%m%d%y_%H%M%S')

    # Run code
    sf = Tf * 4 #sampling frequency
    t = np.arange(start = 0, stop = Td, step = 1/sf)
    y = np.sin((2*np.pi*Tf)*t)*MAX_AMP
    fm = Tf/5 #different than fs warm up tone
    Tm = 0.1
    tm = np.arange(start = 0, stop = Tm, step = 1/sf)
    ym = np.sin((2*np.pi*fm)*tm)*MAX_AMP

    sd.play(ym,sf) # warm up sound card with short tone

    time.sleep(DT)

    sd.play(y,sf)

    return {'sys_sync' : [Ttone], 'tfreq' : [Tf], 'tdur' : [Td]}

if __name__ == '__main__':
    sync_tone_gen(3000)
