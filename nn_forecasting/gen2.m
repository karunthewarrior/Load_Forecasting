function visible = gen2(numframes, fr)

    % This program uses the 2-level CRBM to generate data
    % More efficient version than the original
    
    %Loading all required variables bms
%     load Results/model.mat
%     load Results/layer1.mat
%     load Results/layer2.mat
%     load Data/st1.mat
%     load Data/me1.mat
    
    
    %testsite
%     load Results/modeltest.mat
%     load Results/layer1test.mat
%     load Results/layer2test.mat
%     load Data/st2.mat
%     load Data/me2.mat
    
    load Results/model2.mat
    load Results/layer12.mat
    load Results/layer22.mat
    load Data/st1.mat
    load Data/me1.mat




    A2flat = reshape(A2,numhid1,n2*numhid1);
    B2flat = reshape(B2,numhid2,n2*numhid1);

    numGibbs = 30; %number of alternating Gibbs iterations

    %We have saved some initialization data in "initdata"
    %How many frames of it do we need to make a prediction for the first h2
    %frame? we need n1 + n2 frames of data
    max_clamped = n1+n2;

    %use this data to get the posteriors at layer 1
    numcases = n2; %number of hidden units to generate
    numdims = size(initdata,2);

    %initialize visible data
    visible = zeros(numframes,numdims);
    visible(1:max_clamped,:) = initdata(fr:fr+max_clamped-1,:);

    data = zeros(numcases,numdims,n1+1);
    dataindex = n1+1:max_clamped;

    data(:,:,1) = visible(dataindex,:); %store current data
    %store delayed data
    for hh=1:n1
      data(:,:,hh+1) =visible(dataindex-hh,:);
    end

    %Calculate contributions from directed visible-to-hidden connections
    bjstar = zeros(numhid1,numcases);
    for hh = 1:n1
        bjstar = bjstar + B1(:,:,hh)*data(:,:,hh+1)';
    end

    %Calculate "posterior" probability -- hidden state being on
    %Note that it isn't a true posterior
    eta =  w1*(data(:,:,1)./gsd)' + ...   %bottom-up connections
        repmat(bj1, 1, numcases) + ...    %static biases on unit
        bjstar;                           %dynamic biases

    hposteriors = 1./(1 + exp(-eta));     %logistic

    %initialize hidden layer 1
    %first n1 frames are just padded
    hidden1 = ones(numframes,numhid1);
    hidden1(n1+1:n1+n2,:) = hposteriors';

    %initialize second layer (first n1+n2 frames padded)
    hidden2 = ones(numframes,numhid2);

    %keep the recent past in vector form
    %for input to directed links
    %it's slightly faster to pre-compute this vector and update it (by
    %shifting) at each time frame, rather than to fully recompute each time
    %frame
    past = reshape(hidden1(max_clamped:-1:max_clamped+1-n2,:)',numhid1*n2,1);


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %First generate a hidden sequence (top layer)
    %Then go down through the first CRBM
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    for tt=max_clamped+1:numframes  
      %initialize using the last frame
      %noise is not added for binary units
      hidden1(tt,:) = hidden1(tt-1,:);

      %Dynamic biases aren't re-calculated during Alternating Gibbs
      bistar = A2flat*past;
      bjstar = B2flat*past;

      %Gibbs sampling
      for gg = 1:numGibbs
        %Calculate posterior probability -- hidden state being on (estimate)
        %add in bias
        bottomup =  w2*hidden1(tt,:)';
        eta = bottomup + ...                   %bottom-up connections
          bj2 + ...                            %static biases on unit
          bjstar;                              %dynamic biases

        hposteriors = 1./(1 + exp(-eta));      %logistic

        hidden2(tt,:) = double(hposteriors' > rand(1,numhid2)); %Activating hiddens

        %Downward pass; visibles are binary logistic units     
        topdown = hidden2(tt,:)*w2;

        eta = topdown + ...                      %top down connections
          bi2' + ...                             %static biases
          bistar';                               %dynamic biases   

        hidden1(tt,:) = 1./(1 + exp(-eta));      %logistic 
      end

      %If we are done Gibbs sampling, then do a mean-field sample

      topdown = hposteriors'*w2;  %Very noisy if we don't do mean-field here

      eta = topdown + ...                        %top down connections
          bi2' + ...                             %static biases
          bistar';                               %dynamic biases
      hidden1(tt,:) = 1./(1 + exp(-eta));

      %update the past
      past(numhid1+1:end) = past(1:end-numhid1); %shift older history down
      past(1:numhid1) = hidden1(tt,:); %place most recent frame at top

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Now that we've decided on the "filtering distribution", generate visible
    %data through CRBM 1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    for tt=max_clamped+1:numframes
        %Add contributions from autoregressive connections
        bistar = zeros(numdims,1);
        for hh=1:n1
            bistar = bistar +  A1(:,:,hh)*visible(tt-hh,:)' ;
        end

        %Mean-field approx; visible units are Gaussian
        %(filtering distribution is the data we just generated)
        topdown = gsd.*(hidden1(tt,:)*w1);
        visible(tt,:) = topdown + ...             %top down connections
            bi1' + ...                            %static biases
            bistar';                              %dynamic biases
    end
    
    le = size(visible, 1);
    visible = visible.*repmat(st, le, 1) + repmat(me, le, 1);
    %extracting power
    visible = visible(:, end);
end
