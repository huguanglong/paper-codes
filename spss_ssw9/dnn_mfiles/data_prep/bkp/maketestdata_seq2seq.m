% Purpose : make test or validation data ... the silences are not removed
% unlike the DNN training

clear all; close all; clc;

foldname = {'Telugu'};

tftname = 'hts_seq2seq_5s';
aftname = 'mgcmapf048k';

for j = 1%:4%length(foldname)
    foldname{j}
    tvstr = 'test';
    apath1 = strcat('../../voices/',foldname{j},'/','data/',tvstr,'/acoustic_feats/feats_48k/','mgc','/');
    apath2 = strcat('../../voices/',foldname{j},'/','data/',tvstr,'/acoustic_feats/feats_48k/','stmap','/');
    apath3 = strcat('../../voices/',foldname{j},'/','data/',tvstr,'/acoustic_feats/feats_48k/','stf0','/');
    tpath = strcat('../../voices/',foldname{j},'/','data/',tvstr,'/text_feats/',tftname,'/');
    
    files = dir(tpath);
    
    expname = strcat('exp_',tftname,'_',aftname,'_',foldname{j});
    aext1 = '.mgc';
    aext2 = '.txt';
    aext3 = '.txt';
    datadir = strcat('../../',expname,'/data/');
    mkdir(datadir);
    
    
    numfiles_batch = 400;
    num_bats = ceil((length(files)-2)/numfiles_batch)
    
    for nb = 1:num_bats
        nb
        data = [];
        targets = [];
        clv_t = [];
        clv_s = [];
        
        efno = (numfiles_batch*(nb)+2);
        if efno > length(files)
            efno = length(files);
        end
        
        for i = (numfiles_batch*(nb-1)+1+2):efno
            
            [str,tok] = strtok(files(i).name,'.');
            str
            T = dlmread(strcat(tpath,files(i).name));
            A1 = dlmread(strcat(apath1,str,aext1));
            A2 = dlmread(strcat(apath2,str,aext2));
            A3 = dlmread(strcat(apath3,str,aext3));
            
            [tN,td] = size(T);
            [aN1,ad1] = size(A1);
            [aN2,ad2] = size(A2);
            [aN3,ad3] = size(A3);
            
            nframes = min([aN1 aN2 aN3]);
            
            %             T = T(1:nframes,:);
            A1 = A1(1:nframes,:);
            A2 = A2(1:nframes,:);
            A3 = A3(1:nframes,:);
            
            if sum(sum(isnan(T)))
                fprintf('File %s has NaN elements in Text Feats\n',str)
                %                 pause
            end
            
            if sum(sum(isnan(A1)))
                fprintf('File %s has NaN elements in Spec Feats\n',str)
                %                 pause
            end
            
            if sum(sum(isnan(A2)))
                fprintf('File %s has NaN elements in f0 Feats\n',str)
                %                 pause
            end
            
            if sum(sum(isnan(A3)))
                fprintf('File %s has NaN elements in f0 Feats\n',str)
                pause
                
            end
            
            %             % find if the central frame is silence phone
            %             ixall = zeros(nframes,1);
            %             for k = 1:nframes
            %                 ixall(k) = find(T(k,cpidx));
            %             end
            %             ixint = find(ixall == silid);
            %
            %             % drop 80% of the silence frames
            %             berv =  binornd(1,0.2,[size(ixint)]);
            %             ixint_80 = ixint(berv==0);
            %
            %             T(ixint_80,:) = [];
            %             A1(ixint_80,:) = [];
            %             A2(ixint_80,:) = [];
            %             A3(ixint_80,:) = [];
            
            % cat data
            data = single([data;T]);
            targets = single([targets;[A1 A2 A3]]);
            clv_t = [clv_t size(T,1)];
            clv_s = [clv_s size(A1,1)];
            
        end
        
        if sum(sum(isnan(data)))
            fprintf('There are NaN elements in data Feats\n')
            pause
            
        end
        
        if sum(sum(isnan(targets)))
            fprintf('There are NaN elements in target Feats\n')
            pause
            
        end
        
        save(strcat(datadir,tvstr,'.mat'),'data','targets','clv_t','clv_s','-v7.3');
    end
    
end
