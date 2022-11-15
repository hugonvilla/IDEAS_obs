function PA = parameters()

%%%% Beacons
PA.Tsw = 3; %Time-step to resample beacon data. Default: 3

%%%%% General audio
PA.Fs = 16e3; %audio sample rate. Default: 16e3;
PA.stereo = 0; %stereo flag. Default: off (0).

%%%% CDS Detection
PA.Trssi = -75; %rssi threshold. default is -74
