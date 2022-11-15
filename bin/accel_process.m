function T = accel_process(Ati,svmax)
Win = 100;
mer = 2; %merge separateed svm detections
PA = parameters();
Tsw = PA.Tsw;

Len = size(Ati,1);
Inan = find(~isnan(Ati)); 
Atim = Ati(Inan);
Atim = Atim-movmean(Atim,2*Win,'omitnan'); %2100
Atim(isnan(Atim))=0;
Bt = buffer(Atim,Win,0,'nodelay');
Yp=[];
for z = 1:size(Bt,2)
    Xp = Bt(:,z)';
    Yp(z) = svmax.predictFcn(Xp);
end
RYp = binmask2sigroi(Yp);
RYp = Win*(mergesigroi(RYp,mer)-1)+1;
Ypr = sigroi2binmask(RYp,size(Atim,1));
Ypn = zeros(Len,1);
Ypn(Inan) = Ypr;
T = binmask2sigroi(Ypn);
T(:,2) = T(:,2)+Win*Tsw; %to debufferize
T = mergesigroi(T,Win*10);
T = removesigroi(T,10*Win*Tsw); %remove less than 10 minutes