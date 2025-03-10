function [EEG, command] = loadcurry(fullfilename, varargin)
%   Import a Neuroscan Curry file into EEGLAB. Currently supports Curry version 6, 7, 8,
%   and 9 data files (both continuous and epoched). Epoched
%   datasets are loaded in as continuous files with boundary events. Data
%   can be re-epoched using EEGLAB/ERPLAB functions.
%
%   Input Parameters:
%        1    Specify the filename of the Curry file (extension should be either .cdt, .dap, .dat, or .rs3). 
%
%   Example Code:
%
%       >> EEG = pop_loadcurry;   % an interactive uigetfile window
%       >> EEG = loadcurry;   % an interactive uigetfile window
%       >> EEG = loadcurry('C:\Studies\File1.cdt');    % no pop-up window 
%
%   Optional Parameters:
%       1     'CurryLocations' - Boolean parameter to determine if the sensor
%               locations are carried forward from Curry [1, 'True'] or if the channel
%               locations from EEGLAB should be used [0, 'False' Default].
%       2     'KeepTriggerChannel' - Boolean parameter to determine if the trigger channel is retained in the array [1, 'True' Default] or if the trigger channel
%               should be removed [0, 'False']. I debated adjusting this parameter but given the EEGLAB/ERPLAB
%               bugs associated with trigger events, this provides a nice
%               data check. You can always delete the channel or relocate
%               it later.
%       3     'Archive' - Paramater to select a previous version of loadcurry (3.2 or 2.1).
%
%   Author for reading into Matlab: Neuroscan 
%   Author for translating to EEGLAB: Matthew B. Pontifex, Health Behaviors and Cognition Laboratory, Michigan State University, February 17, 2021
%   Github: https://github.com/mattpontifex/loadcurry
%   revision 3.3 - 
%               .0 - Received new read in function from Neuroscan
%
%   revision 3.1 - Note that you can run loadcurryThreeTwo(fullfilename, varargin) to use this version
%               .1 - Rebuilt trigger module in response to Grael bug.
%               .2 - Updated Curry Channel Locations.
%               .3 - Fixed time to be in milliseconds
%
%   revision 3.0 - Curry9 compatibility.
%
%   revision 2.1 - Note that you can run loadcurryTwoOne(fullfilename, varargin) to use this version
%     Updated to make sure event latencies are in double format.
%
%   revision 2.0 - 
%     Updated for Curry8 compatibility and compatibility with epoched
%     datasets. Note that Curry only carries forward trigger events used in
%     the epoching process.
%
%   revision 1.3 -
%     Revised to be backward compatible through r2010a - older versions may work but have not been tested.
%
%   revision 1.2 -
%     Fixed an issue related to validating the trigger markers.
%
%   revision 1.1 - 
%     Fixed a problem with reading files in older versions of matlab.
%     Added import of impedance check information for the most recent check
%        as well as the median of the last 10 checks. Data is available in
%        EEG.chanlocs
%     Moved function to loadcurry() and setup pop_loadcurry() as the pop up shell. 
%     Created catch for user cancelling file selection dialog. Now throws
%        an error to not overwrite what is in the EEG variable
%
%   If there is an error with this code, please email pontifex@msu.edu with the issue and I'll see what I can do.


    command = '';
    if nargin < 1 % No file was identified in the call
        try
            % flip to pop_loadcurry()
            [EEG, command] = pop_loadcurry();
        catch
            % only error that should occur is user cancelling prompt
            error('loadcurry(): File selection cancelled. Error thrown to avoid overwriting data in EEG.')
        end
    else
        
        if ~isempty(varargin)
             r=struct(varargin{:});
        end
        try, r.CurryLocations; catch, r.CurryLocations = 'False'; end
        try, r.KeepTriggerChannel; catch, r.KeepTriggerChannel = 'True'; end
        try, r.Archive; catch, r.Archive = 'Current'; end
        if strcmpi(r.CurryLocations, 'True') | (r.CurryLocations == 1)
            r.CurryLocations = 'True';
        else
            r.CurryLocations = 'False';
        end
        if strcmpi(r.KeepTriggerChannel, 'True') | (r.KeepTriggerChannel == 1)
            r.KeepTriggerChannel = 'True';
        else
            r.KeepTriggerChannel = 'False';
        end
        
        if ~strcmpi(r.Archive, 'Current')
            % allows user ability to use old read in if wanted
            if (r.Archive < 3) | (r.Archive == 2.1)
                [EEG, command] = loadcurryTwoOne(fullfilename, 'CurryLocations', r.CurryLocations, 'KeepTriggerChannel', r.KeepTriggerChannel);
            elseif (r.Archive < 3.3) | (r.Archive == 3.2)
                [EEG, command] = loadcurryThreeTwo(fullfilename, 'CurryLocations', r.CurryLocations, 'KeepTriggerChannel', r.KeepTriggerChannel);
            end
        else

            EEG = [];
            EEG = eeg_emptyset;
            [pathstr,name,ext] = fileparts(fullfilename);
            filename = [name,ext];
            filepath = [pathstr, filesep];
            file = [pathstr, filesep, name];

            % Ensure the appropriate file types exist under that name
            boolfiles = 1;
            curryvers = 9;
            if strcmpi(ext, '.cdt')
                curryvers = 9;
                if (exist([file '.cdt'], 'file') == 0) || ((exist([file '.cdt.dpa'], 'file') == 0) && (exist([file '.cdt.dpo'], 'file') == 0))
                    boolfiles = 0;

                    if (exist([file '.cdt'], 'file') == 0)
                        error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have a .cdt file created by Curry 8 and 9.', name, filepath)
                    end
                    if ((exist([file '.cdt.dpa'], 'file') == 0) && (exist([file '.cdt.dpo'], 'file') == 0))
                        error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have a .cdt.dpa/o file created by Curry 8 and 9.', name, filepath)
                    end
                end
            else
                curryvers = 7;
                if (exist([file '.dap'], 'file') == 0) || (exist([file '.dat'], 'file') == 0) || (exist([file '.rs3'], 'file') == 0)
                    boolfiles = 0;
                    error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have all three file components (.dap, .dat, .rs3) created by Curry 6 and 7.', name, filepath)
                end
            end

            if (boolfiles == 1)

                % user could choose different file types, but the function
                % expects a particular type
                if (curryvers == 7)
                    outstruct = LoadCurryDataFile([file '.dat'], 0, 0);
                elseif (curryvers > 7)
                    outstruct = LoadCurryDataFile([file '.cdt'], 0, 0);
                end
                data = outstruct.data;
                nChannels = outstruct.numChannels;
                nSamples = outstruct.numSamples;
                fFrequency = outstruct.samplingFreqHz;
                nTrials = outstruct.numTrials;
                fOffsetUsec = outstruct.trigOffsetUsec;
                labels = outstruct.labels;
                sensorpos = outstruct.sensorLocations;
                events = outstruct.events;
                annotations = outstruct.annotations;
                epochinformationlist = outstruct.epochInfo;
                epochlabelslist = outstruct.epochLabels;
                impedancematrix = outstruct.impedanceMatrix;                

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % time axis
                time = linspace(fOffsetUsec/1000,fOffsetUsec/1000+(nSamples*nTrials-1)*1000/fFrequency,nSamples*nTrials);

                %% Created to take this data and place it into EEGLAB format (v13.4.4b)

                EEG.setname = 'Neuroscan Curry file';
                if (curryvers == 7)
                    datafileextension = '.dap';
                elseif (curryvers > 7)
                    datafileextension = '.cdt';
                end
                EEG.filename = [name, datafileextension];
                EEG.filepath = filepath;
                EEG.comments = sprintf('Original file: %s%s', filepath, [name, datafileextension]);

                EEG.srate = fFrequency;

                EEG.ref = 'Common';
                EEG.urchanlocs = [];
                EEG.chaninfo.plotrad = [];
                EEG.chaninfo.shrink = [];
                EEG.chaninfo.nosedir = '+X';
                EEG.chaninfo.nodatchans = [];
                EEG.chaninfo.icachansind = [];

                % Populate channel labels
                try, sensorpos; booler = 0; catch; booler = 1; end
                if (booler == 0)
                    try
                    sensorpos = sensorpos / 1000;
                    catch
                        booler = 1;
                    end
                else
                    r.CurryLocations = 'False';
                end
                EEG.chanlocs = struct('labels', [], 'ref', [], 'theta', [], 'radius', [], 'X', [], 'Y', [], 'Z', [],'sph_theta', [], 'sph_phi', [], 'sph_radius', [], 'type', [], 'urchan', []);
                for cC = 1:(numel(labels))
                    EEG.chanlocs(cC).labels = char(upper(labels(cC))); % Convert labels to uppercase and store as character array string
                    EEG.chanlocs(cC).urchan = cC;

                    % Curry (x,y,z) is (left,back,up) and the unit is [mm]
                    % To convert Curry rs3/dpa/dpo coordinates to BESA sfp coordinates, simply divide all values by 1000 and invert the x axis.

                    % MATLAB/EEGLAB system:
                    % x is towards the nose, 
                    % y is towards the left ear, 
                    % z towards the vertex.
                    if (booler == 0)
                       if (cC <= size(sensorpos,2))
                           EEG.chanlocs(cC).Y = sensorpos(1,cC); 
                           EEG.chanlocs(cC).X = sensorpos(2,cC)*-1; 
                           EEG.chanlocs(cC).Z = sensorpos(3,cC); 
                       end
                    end
                end
                try
                    if (booler == 0)

                        EEG.chanlocs = convertlocs( EEG.chanlocs, 'cart2all');

                    end
                catch
                    booler = 1;
                end

                % Manage Triggers
                trigindx = find(strcmpi({EEG.chanlocs.labels},'Trigger'));
                if isempty(trigindx)
                    % no trigger channel exists
                     data(end+1,:) = zeros(1, size(data, 2));
                     EEG.chanlocs(end+1).labels = 'TRIGGER';
                else
                    % a trigger channel already exists
                    % Remove baseline from trigger channel
                    data(trigindx,:) = data(trigindx,:) - median(data(trigindx,:)); % should be unnecessary
                end
                trigindx = find(strcmpi({EEG.chanlocs.labels},'Trigger'));
                EEG.nbchan = size(data,1);
                EEG.pnts = size(data,2);
                EEG.xmin = 0; % (in seconds)
                EEG.xmax = (EEG.pnts-1)/EEG.srate+EEG.xmin; % (in seconds)
                EEG.times = double(linspace(EEG.xmin,EEG.xmax,EEG.pnts) * 1000); % times in miliseconds
                EEG.trials = 1;

                % Handle Epoched Datasets
                if (nTrials > 1)

                    % find the zero point for the epoch
                    currytime = linspace(0,nSamples/fFrequency,nSamples);
                    currytime = currytime + (fOffsetUsec/1000000);
                    [~, zeropoint] = min(abs(currytime));

                    startpoint = 1;
                    for cC = 1:nTrials

                        % See if there are actual event information to add
                        if size(epochinformationlist,1) > 0
                           data(trigindx, startpoint+zeropoint-1) = epochinformationlist(cC,3);
                        else
                            % for some reason there is no event information
                           data(trigindx, startpoint+zeropoint-1) = 10;
                        end

                        % Place a boundary event
                        data(trigindx, startpoint+nSamples-1) = -99;

                        startpoint = startpoint + nSamples;
                    end % end trials
                end

                % Populate Event List

                %  -- On data recorded from Grael Amplifiers, the event sample noted in the .ceo file differs from the event sample in the Trigger channel.
                %  -- Clarification from Reyko Tech, Software Engineer at Compumedics, received Feb 24, 2021
                %  The sample in the event file (ceo) is the time the TTL pulse happened in sync with the EEG data. 
                %  The signal in the Grael trigger channel has a variable delay which depends on the sampling rate.
                %  If you would measure a TTL pulse through the trigger channel and a bipolar input at the same time,
                %  you will see that the trigger event from the ceo file sits where you see the TTL pulse in the bipolar channel.
                %  The trigger channel shows the TTL pulse at a slightly different time. The Grael behaves differently
                %  in this regards, than other Compumedics amplifiers.
                %  The .ceo sample time should be viewed as the most accurate.

                %  For Grael V1 amplifiers, the event should precede the signal in the Trigger channel. 
                %  For Grael V2 amplifiers the Trigger channel should precede the event.

                %  Here is an overview of the expected delays (time delay of the event in relation to signal in the Trigger channel):
                %   Grael V1 at 2048 Hz: -20 ms
                %   Grael V2 at 4096 Hz: +18.6 ms
                %   Grael V2 at 2048 Hz: +29.8 ms
                %   Grael V2 at 1024 Hz: +52.7 ms
                %   Grael V2 at 512 Hz: +41.0 ms
                %   Grael V2 at 256 Hz: +70.3 ms
                %   Grael V2 at 128 Hz: +78.1 ms

                %  In all cases the .ceo sample time is the most correct.

                if (~isempty(events))

                    samplesoffby = 0;
                    if (sum(abs(data(trigindx,:))) > 0)
                        % There are events in the trigger channel that could need to be adjusted
                        try
                            % try to adjust the event alignment with existing events
                            eventpull = NaN(size(events,2),2);
                            eventpull(:,1) = events(1,:);
                            eventpull(:,2) = events(2,:);

                            templat = find(data(trigindx,:) ~= 0);
                            templatrem = [];
                            for cC = 2:numel(templat)
                                % If the sampling point is one off
                                if ((templat(cC)-1) == templat(cC-1))
                                    if (data(trigindx,(templat(cC)-1)) == data(trigindx,(templat(cC))))
                                        templatrem(end+1) = templat(cC);
                                    end
                                end
                            end
                            templat = setdiff(templat,templatrem);
                            triggerpull = NaN(size(templat,2),2);
                            triggerpull(:,1) = templat(1,:);
                            triggerpull(:,2) = data(trigindx,templat);

                            commonstimcodes = intersect(eventpull(:,2),triggerpull(:,2));
                            eventpull(~ismember(eventpull(:,2),commonstimcodes),:) = [];
                            triggerpull(~ismember(triggerpull(:,2),commonstimcodes),:) = [];

                            try
                                I = samplealign(eventpull, triggerpull);
                            catch
                                % find most frequenly occuring event and just  use that
                                pullcounts = zeros(size(commonstimcodes,1),2);
                                for cC = 1:size(commonstimcodes,1)
                                    pullcounts(cC,1) = numel(find(eventpull(:,2) == commonstimcodes(cC,1)));
                                    pullcounts(cC,2) = numel(find(triggerpull(:,2) == commonstimcodes(cC,1)));
                                end
                                pullcounts(:,3) = pullcounts(:,1)+pullcounts(:,2);
                                [~, tindx] = max(pullcounts(:,3));
                                commonstimcodes = commonstimcodes(tindx,1);
                                eventpull(~ismember(eventpull(:,2),commonstimcodes),:) = [];
                                triggerpull(~ismember(triggerpull(:,2),commonstimcodes),:) = [];
                                I = samplealign(eventpull, triggerpull);
                            end

                            alignmatrixindices = NaN(size(I,1),5);
                            for index = 1:size(I,1)
                                alignmatrixindices(index,1) = eventpull(I(index),1);
                                alignmatrixindices(index,2) = eventpull(I(index),2);
                                alignmatrixindices(index,3) = triggerpull(index,1);
                                alignmatrixindices(index,4) = triggerpull(index,2);
                                if (alignmatrixindices(index,2) ~= alignmatrixindices(index,4))
                                    alignmatrixindices(index,5) = 0;
                                else
                                    alignmatrixindices(index,5) = 1;
                                end
                            end
                            alignmatrixindices(find(alignmatrixindices(:,5)==0),:) = [];
                            tempvect = alignmatrixindices(:,3) - alignmatrixindices(:,1);
                            samplesoffby = median(tempvect);
                        catch 
                           try
                               % see if they generally align
                               if (size(eventpull,1) == size(triggerpull,1))
                                   alignmatrixindices = NaN(size(eventpull,1),5);
                                   alignmatrixindices(:,1) = eventpull(:,1);
                                   alignmatrixindices(:,2) = eventpull(:,2);
                                   alignmatrixindices(:,3) = triggerpull(:,1);
                                   alignmatrixindices(:,4) = triggerpull(:,2);
                                   alignmatrixindices(:,5) = eventpull(:,2) - triggerpull(:,2);
                                   % same number of events and only when those events line up
                                   alignmatrixindices(find(alignmatrixindices(:,5)~=0),:) = [];
                                   tempvect = alignmatrixindices(:,3) - alignmatrixindices(:,1);
                                   samplesoffby = median(tempvect);
                               end
                           catch
                             booler = 1; 
                           end

                        end

                        if (samplesoffby ~= 0)
                            % should only be possible for it to be off within a known range
                            if (abs(samplesoffby) < 100) % just in case something wierd happens dont create a bigger headache

                                % Shift the Trigger channel data
                                if (samplesoffby < 0)
                                    % cut off the back of the trigger data
                                    ceoevents = horzcat(zeros(1,abs(samplesoffby)), data(trigindx,1:size(data,2)+samplesoffby));
                                    data(trigindx,:) = ceoevents(1,:);
                                else
                                    % cut off the front of the trigger data
                                    ceoevents = horzcat(data(trigindx,1+samplesoffby:size(data,2)), zeros(1,abs(samplesoffby)));
                                    data(trigindx,:) = ceoevents(1,:);
                                end

                            end
                        end
                    end

                    for cC = 1:size(events,2)
                        if (events(1,cC) > 0) && (events(1,cC) <= size(data,2)) 
                            % add event to trigger channel if not already included
                            if (data(trigindx, events(1,cC)) ~= events(2,cC))
                                data(trigindx, events(1,cC)) = events(2,cC);
                            end
                        end
                    end
                end

                % Add events
                EEG.event = struct('type', [], 'latency', [], 'urevent', []);
                EEG.urevent = struct('type', [], 'latency', []);
                EEG.annotations = annotations;

                % Populate list based on values different from 0, triggers may last more than one sample
                templat = find(data(trigindx,:) ~= 0);
                templatrem = [];
                for cC = 2:numel(templat)
                    % If the sampling point is one off
                    if ((templat(cC)-1) == templat(cC-1))
                        if (data(trigindx,(templat(cC)-1)) == data(trigindx,(templat(cC))))
                            templatrem(end+1) = templat(cC);
                        end
                    end
                end
                templat = setdiff(templat,templatrem);
                if ~isempty(templat)
                    currentevent = 1;
                    for cC = 1:size(templat,2) 
                        % store sample
                        EEG.event(cC).latency = double(templat(cC));

                        if (data(trigindx,templat(cC)) == -99)
                            % boundary event
                            EEG.event(cC).type = 'boundary';
                            data(trigindx,templat(cC)) = 0; % remove boundary code
                        else
                            EEG.event(cC).type = data(trigindx,templat(cC));
                            EEG.event(cC).urevent = currentevent;

                            EEG.urevent(currentevent).type = data(trigindx,templat(cC));
                            EEG.urevent(currentevent).latency = double(templat(cC));
                            currentevent = currentevent + 1;
                        end
                    end
                end

                % Manage Data
                EEG.data = double(data);

                % Remove Trigger Channel
                trigindx = find(strcmpi({EEG.chanlocs.labels},'Trigger'));
                if ~isempty(trigindx)
                    if ~strcmpi(r.KeepTriggerChannel, 'True')
                        EEG.data(trigindx,:) = [];
                        EEG.chanlocs(trigindx) = [];
                    end
                end
                EEG.nbchan = size(EEG.data,1);

                % address resample bug
                try
                    if (size([EEG.event.type],2) == 0)
                        EEG.event = [];
                        EEG.urevent = [];
                    end
                catch
                    booler = 1;
                end

                if strcmpi(r.CurryLocations, 'False')
                    % Use default channel locations
                    try
                        tempEEG = EEG; % for dipfitdefs
                        dipfitdefs;
                        tmpp = which('eeglab.m');
                        tmpp = fullfile(fileparts(tmpp), 'functions', 'resources', 'Standard-10-5-Cap385_witheog.elp');
                        userdatatmp = { template_models(1).chanfile template_models(2).chanfile  tmpp };
                        try
                            [T, tempEEG] = evalc('pop_chanedit(tempEEG, ''lookup'', userdatatmp{1})');
                        catch
                            try
                                [T, tempEEG] = evalc('pop_chanedit(tempEEG, ''lookup'', userdatatmp{3})');
                            catch
                                booler = 1;
                            end
                        end
                        EEG.chanlocs = tempEEG.chanlocs;
                    catch
                        booler = 1;
                    end
                end

                % Place impedance values within the chanlocs structure
                try
                    if ~isempty(impedancematrix)
                        impedancematrix(impedancematrix == -1) = NaN; % screen for missing values
                        impedancelist = nanmedian(impedancematrix);
                        for cC = 1:size({EEG.chanlocs.labels},2)
                            chanindx = find(strcmpi(labels, EEG.chanlocs(cC).labels));
                            if (~isempty(chanindx))
                               EEG.chanlocs(cC).impedance = impedancematrix(1,chanindx)/1000; 
                               EEG.chanlocs(cC).median_impedance = impedancelist(1,chanindx)/1000;
                            end
                        end
                    end
                catch
                    booler = 1;
                end
                EEG.history = sprintf('%s\nEEG = loadcurry(''%s%s'', ''KeepTriggerChannel'', ''%s'', ''CurryLocations'', ''%s'');', EEG.history, filepath, [name, datafileextension], r.KeepTriggerChannel, r.CurryLocations); 
                [T, EEG] = evalc('eeg_checkset(EEG);');
                EEG.history = sprintf('%s\nEEG = eeg_checkset(EEG);', EEG.history);

            end
        end
    end   
end
