function eflag = run_CHECK(varargin)

%%%%% Check data for IDEAS
%%%%%%%%%%% Function arguments, in order:
obsflag = 1; %0 if data correspond is not from a valid observation (disables accelerometer processing)
Ifolder = fullfile(pwd,'data/to_clean'); %path to folder that contains the observation folders to process

if length(varargin)>=1
    obsflag = varargin{1};
    if length(varargin)>=2
        Ifolder = varargin{2};
    end
end

if obsflag == 0
    disp('Data is from a test. No valid data checks will be performed.')
end

addpath(fullfile(pwd,'bin'))

%% Read and Process Data 
eflag=0; %initialize exit flag
[FIname,Iname] = fileparts(Ifolder);
Tdata = dir(Ifolder);
Tdata(cellfun(@(x) ismember(x(1),{'.','_','~'}), {Tdata.name}.'),:)=[];
if isempty(Tdata)
    error(['No folders to process in "' Iname '"'])
end


for i = 1:size(Tdata,1) %for each folder to process
    Fopath = fullfile(Tdata(i).folder,Tdata(i).name); %folder path
    Fname = Tdata(i).name; %folder name
    if exist(fullfile(Fopath,'Elog.txt'),'file')
        delete(fullfile(Fopath,'Elog.txt')); %delete previous error log file
    end
    Tpdir = fullfile(Fopath,'Temp');
    if ~exist(Tpdir,'dir')
        mkdir(Tpdir) %create temporary directory
    end

    DPi = data_process(Fopath,obsflag); %process data
    if ~isempty(DPi.Elog)
        disp(['Data in folder ' Fname  ' has errors. Check error log files for details.'])
        eflag=1;
    end
end
disp(['Data pre-processing has concluded.'])

if eflag==1
    error('Some folders contain errors. Check error log files in those folders')
end

rmpath(fullfile(pwd,'bin'))


