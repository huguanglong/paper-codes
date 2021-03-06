%{
###########################################################################
##                                                                       ##
##                                                                       ##
##                       IIIT Hyderabad, India                           ##
##                      Copyright (c) 2015                               ##
##                        All Rights Reserved.                           ##
##                                                                       ##
##  Permission is hereby granted, free of charge, to use and distribute  ##
##  this software and its documentation without restriction, including   ##
##  without limitation the rights to use, copy, modify, merge, publish,  ##
##  distribute, sublicense, and/or sell copies of this work, and to      ##
##  permit persons to whom this work is furnished to do so, subject to   ##
##  the following conditions:                                            ##
##   1. The code must retain the above copyright notice, this list of    ##
##      conditions and the following disclaimer.                         ##
##   2. Any modifications must be clearly marked as such.                ##
##   3. Original authors' names are not deleted.                         ##
##   4. The authors' names are not used to endorse or promote products   ##
##      derived from this software without specific prior written        ##
##      permission.                                                      ##
##                                                                       ##
##  IIIT HYDERABAD AND THE CONTRIBUTORS TO THIS WORK                     ##
##  DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING      ##
##  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT   ##
##  SHALL IIIT HYDERABAD NOR THE CONTRIBUTORS BE LIABLE                  ##
##  FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES    ##
##  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN   ##
##  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,          ##
##  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF       ##
##  THIS SOFTWARE.                                                       ##
##                                                                       ##
###########################################################################
##                                                                       ##
##          Author :  Sivanand Achanta (sivanand.a@research.iiit.ac.in)  ##
##          Date   :  Jul. 2015                                          ##
##                                                                       ##
###########################################################################
%}

% open error text file
fid = fopen(strcat(errdir,'/err_',arch_name,'.err'),'w');

% load data onto GPU
% val_batchdata = (val_batchdata);
% val_batchtargets = (val_batchtargets);
% test_batchdata = (test_batchdata);
% test_batchtargets = (test_batchtargets);

% early stopping params (Theano DeepLearningTutorials)
patience = 10000;
patience_inc = 2;
imp_thresh = 0.995;
best_val_loss = inf;
best_iter = 0;
num_up = 0;

trainerr = 0;
valerr = 0;
testerr = 0;

train_test_numbats = round(train_numbats/2);

for NE = 1:numepochs
    
    % for each epoch
    iter = (NE-1)*train_numbats;
    
    % Weight update step
    twu = tic;
    
    rp = randperm(train_numbats);
    
    % fp and bp for each batch
    for i = 1:train_numbats
        
        num_up = num_up + 1;
        
        % fp
        X = []; Y = [];
        X = (double(train_batchdata(train_clv(rp(i)):train_clv(rp(i)+1)-1,:)));
        Y = (double(train_batchtargets(train_clv(rp(i)):train_clv(rp(i)+1)-1,:)));
        bs = size(X,1);
        
        if spec_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_mgc,Wfr_mgc,U_mgc,bh_mgc,bo_mgc,f_mgc,nl_mgc,a_tanh,b_tanh,bs);       end;
        if f0_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_f0,Wfr_f0,U_f0,bh_f0,bo_f0,f_f0,nl_f0,a_tanh,b_tanh,bs);       end;
        
        if lno == 2 ; hcm = ym; end;
 
        % mean variance normalization of hcm
        if hmvnf ; hcm = bsxfun(@minus,hcm,mh);         hcm = bsxfun(@rdivide,hcm,vh); end;
        
        X = [X (hcm)];
        
        % train set variables
        otl = [1 bs*(nl(nlv+1))];
        otl = cumsum(otl);
        
        % fp
        [ol] = fpav_cpu(X,GW,Gb,nl,f,nh,a_tanh,b_tanh,wtl,btl,bs);
        
        % bp
        
        % gradients of weights of top most layer
        ol_m = reshape(ol(1,otl(end-1):otl(end)-1),bs,nl(end));
        ol_pl_m = reshape(ol(1,otl(end-2):otl(end-1)-1),bs,nl(end-1));
        
        switch f(end)
            case 'N'
                der_f = bby2a*((a_tanh - ol_m).*(a_tanh + ol_m));
            case 'S'
                der_f = b_tanh*(ol_m.*(1 - ol_m));
            case 'R' % added on 28/11/14
                der_f = ones(bs,nl(end)).*(ol_m > 0);
            case 'M' % Softmax layer
                der_f = (ol_m.*(1 - ol_m));
            case 'L'
                der_f = ones(bs,nl(end));
            otherwise
                disp('please enter a valid output function name (N/S/R/M/L)');
                return;
        end
        
        switch cfn
            case  'nll'
                %         costder = -(Out./ol_m);
                del_bp  = -(Y - ol_m)/bs;
            case 'ls'
                costder = -(Y - ol_m)/bs;
                del_bp = costder.*der_f;
        end
        
        own = reshape(GW(1,wtl(nh):wtl(nh+1)-1),nl(nh+1),nl(nh))';
        gbv = sum(del_bp,1);
        gWm = ((ol_pl_m'*del_bp) + l1*sign(own) + l2*2*own);
        
        gb = (zeros(1,btl(end-1)));
        gb(1,btl(nh):btl(end)-1) = gbv;
        gW = (zeros(1,wtl(end)-1));
        gW(1,wtl(nh):wtl(nh+1)-1) = reshape(gWm',1,numel(gWm));
        
        % gradients of weights of inner hidden layers
        for j = nh-1:-1:1
            
            ol_m = reshape(ol(1,otl(j):otl(j+1)-1),bs,nl(j+1));
            if (j-1) ~=0
                ol_pl_m = reshape(ol(1,otl(j-1):otl(j)-1),bs,nl(j));
            else
                ol_pl_m = X;
            end
            
            switch f(j)
                case 'N'
                    der_f = bby2a*((a_tanh - ol_m).*(a_tanh + ol_m));
                case 'S'
                    der_f = b_tanh*(ol_m.*(1 - ol_m));
                case 'R' % added on 28/11/14
                    der_f = ones(bs,nl(j+1)).*(ol_m > 0);
                case 'M' % Softmax layer
                    der_f = (ol_m.*(1 - ol_m));
                case 'L'
                    der_f = ones(bs,nl(j+1));
                otherwise
                    disp('error: please enter a valid output function name (N/S/R/M/L)');
                    return;
            end
            
            wdel_bp = del_bp*(own'); % weghted del_bps
            del_bp = wdel_bp.*der_f;
            gbv = sum(del_bp,1);
            own = reshape(GW(1,wtl(j):wtl(j+1)-1),nl(j+1),nl(j))'; % only weights are considered , ingore the first row which are biases
            gWm = ((ol_pl_m'*del_bp) + l1*sign(own) + l2*2*own);
            
            gb(1,btl(j):btl(j+1)-1) = gbv;
            gW(1,wtl(j):wtl(j+1)-1) = reshape(gWm',1,numel(gWm));
            
        end
        
        % Update Params using Appropriate SGD Method
        update_params
        
        
        if mod(num_up,check_valfreq) == 0
            tic
            trainerr = 0;
            % training error computation
            for li = 1:train_test_numbats
                % fp
                X = []; Y = [];
                X = (double(train_batchdata(train_clv(li):train_clv(li+1)-1,:)));
                Y = (double(train_batchtargets(train_clv(li):train_clv(li+1)-1,:)));
                bs = size(X,1);
                
                if spec_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_mgc,Wfr_mgc,U_mgc,bh_mgc,bo_mgc,f_mgc,nl_mgc,a_tanh,b_tanh,bs);       end;
                if f0_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_f0,Wfr_f0,U_f0,bh_f0,bo_f0,f_f0,nl_f0,a_tanh,b_tanh,bs);       end;

		if lno == 2 ; hcm = ym; end;                
                % mean variance normalization of hcm
                if hmvnf ; hcm = bsxfun(@minus,hcm,mh);         hcm = bsxfun(@rdivide,hcm,vh); end;
                X = [X (hcm)];
                
                % train set variables
                otl = [1 bs*(nl(nlv+1))];
                otl = cumsum(otl);
                
                % fp
                [ol] = fpav_cpu(X,GW,Gb,nl,f,nh,a_tanh,b_tanh,wtl,btl,bs);
                
                % compute error
                ol_mat = reshape(ol(1,otl(end-1):otl(end)-1),bs,nl(end));
                clear ol;
                
                switch cfn
                    case 'nll'
                        me = compute_zerooneloss(ol_mat,Y);
                    case 'ls'
                        me = mean(sum((Y - ol_mat).^2,2)./(sum(Y.^2,2)));
                end
                
                if isnan(me)
                    break
                end
                
                trainerr = trainerr + me/train_test_numbats;
                
            end
            toc
            
            tvde = tic;
            valerr = 0;
            
            % Validation data error computation
            for li = 1:val_numbats
                X = (double(val_batchdata(val_clv(li):val_clv(li+1)-1,:)));
                Y = (double(val_batchtargets(val_clv(li):val_clv(li+1)-1,:)));
                bs = size(X,1);
                
                if spec_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_mgc,Wfr_mgc,U_mgc,bh_mgc,bo_mgc,f_mgc,nl_mgc,a_tanh,b_tanh,bs);       end;
                if f0_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_f0,Wfr_f0,U_f0,bh_f0,bo_f0,f_f0,nl_f0,a_tanh,b_tanh,bs);       end;
                if lno == 2 ; hcm = ym; end;
	
                % mean variance normalization of hcm
                if hmvnf ; hcm = bsxfun(@minus,hcm,mh);         hcm = bsxfun(@rdivide,hcm,vh); end;
                X = [X (hcm)];
                
                % validation set variables
                otvl = [1 bs*(nl(nlv+1))];
                otvl = cumsum(otvl);
                
                % fp
                [ol] = fpav_cpu(X,GW,Gb,nl,f,nh,a_tanh,b_tanh,wtl,btl,bs);
                
                % compute error
                ol_mat = reshape(ol(1,otvl(end-1):otvl(end)-1),bs,nl(end));
                clear ol;
                
                switch cfn
                    case 'nll'
                        me = compute_zerooneloss(ol_mat,Y);
                    case 'ls'
                        me = mean(sum((Y - ol_mat).^2,2)./(sum(Y.^2,2)));
                end
                
                if isnan(me)
                    break
                end
                
                valerr = valerr + me/val_numbats;
            end
            toc(tvde)
            
            % Print error (validation) per epoc
            fprintf('Epoch : %d  Update : %d Train Loss : %f Val Loss : %f \n',NE,num_up,trainerr,valerr);
            
            if valerr < best_val_loss
                if valerr < (best_val_loss*imp_thresh)
                    patience = max(patience,iter*patience_inc);
                end
                best_val_loss = valerr;
                best_iter = iter;
                tic
                testerr = 0;
                % Test data error computation
                for li = 1:test_numbats
                    X = (double(test_batchdata(test_clv(li):test_clv(li+1)-1,:)));
                    Y = (double(test_batchtargets(test_clv(li):test_clv(li+1)-1,:)));
                    bs = size(X,1);

	                    
                    if spec_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_mgc,Wfr_mgc,U_mgc,bh_mgc,bo_mgc,f_mgc,nl_mgc,a_tanh,b_tanh,bs);       end;
                    if f0_flag; [hcm,ym] = fp_rnn((X(:,101:end)),Wi_f0,Wfr_f0,U_f0,bh_f0,bo_f0,f_f0,nl_f0,a_tanh,b_tanh,bs);       end;

                    if lno == 2 ; hcm = ym; end; 

                    % mean variance normalization of hcm
                    if hmvnf ; hcm = bsxfun(@minus,hcm,mh);         hcm = bsxfun(@rdivide,hcm,vh); end;
                    
                    X = [X (hcm)];
                    
                    
                    % % test error set variables
                    ottl = [1 bs*(nl(nlv+1))];
                    ottl = cumsum(ottl);
                    
                    % fp
                    [ol] = fpav_cpu(X,GW,Gb,nl,f,nh,a_tanh,b_tanh,wtl,btl,bs);
                    
                    % compute error
                    ol_mat = reshape(ol(1,ottl(end-1):ottl(end)-1),bs,nl(end));
                    clear ol;
                    
                    switch cfn
                        case 'nll'
                            me = compute_zerooneloss(ol_mat,Y);
                        case 'ls'
                            me = mean(sum((Y - ol_mat).^2,2)./(sum(Y.^2,2)));
                    end
                    
                    clear ol_mat;
                    testerr = testerr + me/test_numbats;
                end
                toc
                % Print error (testing) per epoc
                fprintf('\t Epoch : %d  Update: %d Test Loss : %f \n',NE,num_up,testerr);
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%% save weight file %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % save parameters every epoch
                W = (GW); b = (Gb);
                save(strcat(wtdir,'W_',arch_name,'.mat'),'W','b');
            end
            
            % Print error (validation and testing) per epoc
            fprintf(fid,'%d %d %f %f %f \n',NE,num_up,trainerr,valerr,testerr);
            
        end
        
        if isnan(valerr) || isnan(testerr)
            break;
        end
        
    end
    clear ol
    toc(twu)
    
    if isnan(valerr) || isnan(testerr)
        break;
    end
    
    
end

fclose(fid);

fprintf('Training done !!!\n')
fprintf('Best val error : %f ; at epoch : %d ; with test error : %f \n', best_val_loss,floor(best_iter/train_numbats),testerr)

