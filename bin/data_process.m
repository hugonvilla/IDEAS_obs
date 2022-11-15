function DP = data_process(Fopath,obsflag)
warning('off','all')
%%%% Initialize output
DP.UD=[];
DP.W=[];
DP.C=[];
Elog=[];
DP.Elog = Elog;
    

%%%%%% Input data
[~,Fname] = fileparts(Fopath);
Iname = fullfile(Fopath,['Idata_',Fname,'.mat']);
if exist(Iname,'file')
    UD= load(Iname);
    UD = UD.UD;
else
    delete(Iname);
    UD = input_clean(Fopath);
end
DP.UD=UD;
Elog = [Elog;UD.Elog];
if ~isempty(UD.Elog)
    disp(['Input data for folder ' Fname ' has errors. Check error log file for details.'])
    return
end

%%%%%% Logger clean
Wname = fullfile(Fopath,'Beacons',['Wdata_',Fname,'.mat']);
if exist(Wname,'file')
    W= load(Wname);
    W = W.W;
else
    delete(Wname);
    W = logger_clean(Fopath,UD,obsflag);
end
DP.W=W;
Elog = [Elog;W.Elog];
if ~isempty(W.Elog)
    disp(['Beacon data for folder ' Fname ' has errors. Check error log file for details.'])
    return
end

%%%%%% Audio clean
AUname = fullfile(Fopath,'Audio',['AUdata_',Fname,'.mat']);
if exist(AUname,'file')
    C= load(AUname);
    C = C.C;
else
    delete(AUname);
    C = audio_clean(Fopath,UD,W);
end
DP.C=C;
Elog = [Elog;C.Elog];
if ~isempty(C.Elog)
    disp(['Audio clean data for folder ' Fname ' has errors. Check error log file for details.'])
    return %comment if we want to continue with processing valid audio data
end

DP.Elog = Elog;




