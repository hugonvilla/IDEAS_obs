function Ta = sync_tone_gen(Tf)
%%%% Code to generate synchronization tone. This script should be run at
%%%% the beggining and end of the observations (before turning off the
%%%% voice recorders.)

%% Tone Parameters
Td = 0.5; %duration of tone
DT = 10; %Tone delay in seconds
%% Tone time
Tnow = dateshift(datetime(now,'ConvertFrom','datenum','Format','MMddyy_HHmmss'),'start','second');
Ttone = Tnow+seconds(DT);
Ta = table(string(Ttone),Tf,Td,'VariableNames',{'sys_sync','tfreq','tdur'});
%%%%%% Run code
sf = Tf*4; %sampling frequency
t = 0:(1/sf):Td;
y = sin(2*pi*Tf*t);
fm = Tf/5; %different than fs warm up tone
Tm = 0.1;
tm = 0:(1/sf):Tm;
ym = sin(2*pi*fm*tm);
sound(ym,sf) %warm up sound card with short tone
while true
    if datetime('now')-Ttone > 0 %when current time is after tone time
        sound(y,sf) %sound tone
        break
    end
end