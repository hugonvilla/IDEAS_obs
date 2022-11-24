function [Y0] = pulse_detect(fname,Pd,Pf)
%%%%% Script that detects the synchronizing tone in audio recordings
Km = 0.3; %0.9 minimum peak
Kd = 0.7; %thershold for boundaries
Kt = 0.5; %
Kp = 0.02; %
Tw = 300; %search time window in seconds
mpd=1; %minimum peak distancein seconds
mpw=0.98; %minimum prominence
MT = 30*60; %offset of search windows in seconds

Kf = 0; kk = 0;
info = audioinfo(fname);
MTt = min(info.TotalSamples,MT*info.SampleRate); %
Y0=nan; %initialize output
while Kf < MTt
    kk = kk+1;
    
    Ko = min(((kk-1)*Tw)*info.SampleRate+1,info.TotalSamples); %initial search time in samples
    Kf = min((kk*Tw)*info.SampleRate+1,info.TotalSamples); %final search time in samples

    [au,fs] = audioread(fname,[Ko,Kf]);
    au = mean(au,2);
    y = bandpass(au,[Pf-.1 Pf+.1],fs,'Steepness',0.99,'StopbandAttenuation',80); %Narrow bandpass to only allow Pd frequency
    yn = envelope(y,round(Pd*fs/2),'rms');
    my=max(yn);
    yn = normalize(yn,'range'); %normalize between 0 and 1
    lyn = length(yn); %length of yn
    [~,lpn,ww,pw] = findpeaks(yn,'MinPeakHeight',Km,'MinPeakDistance',mpd*fs); %first pass
    lpn(pw<mpw)=[];
    ww(pw<mpw)=[];
    pw(pw<mpw)=[];
    
    if numel(pw)==1 %&& my>=Kp %if there is only one prominent peak (>Km) in the window
        y0=[]; yf=[];
        for i = 1:length(lpn) 
            y0(i) = (find(yn(max(lpn(i)-Pd*fs,1):min(lpn(i),lyn))>Kd,1)+lpn(i)-Pd*fs)/fs; %find first time signal is above threshold
            yf(i) = (find(yn(max(lpn(i),1):min(lpn(i)+Pd*fs,lyn))>Kd,1,'last')+lpn(i))/fs; %last time signal is above threshold
        end
        Dp = abs((yf-y0)-Pd)/Pd;
        Dp(Dp>Kt)=nan; %delete peaks that are to short or long
        if any(~isnan(Dp))
            [~,ik] = min(Dp); %select the best fit
            Y0 = y0(ik)+Ko/fs; %Tone time in audio time (seconds)
            break
        end
    end
end
