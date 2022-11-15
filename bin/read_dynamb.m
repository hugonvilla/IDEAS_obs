function TA = read_dynamb(Tname)
%%%%%%% Reads Diract's dynamb files

    opts = delimitedTextImportOptions("NumVariables", 26);
    opts.VariableTypes = repmat("string",1,26);
    aux = readmatrix(Tname, opts);
    clear opts
    opts = detectImportOptions(Tname);
    
    k=0; flag=0;
    while flag == 0
        k=k+1;
        if strcmp(aux(k,1),"time")
            flag = 1;
        end
    end
    opts.VariableNamesLine = k;
    TA = readtable(Tname,opts);
    sa = min(size(TA,2),26);
    TA = TA(:,1:sa); 
    TA(k,:)=[];
end