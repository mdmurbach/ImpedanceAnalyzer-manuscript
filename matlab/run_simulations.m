clear all; clc; close all

EMAIL = false;
%%% Send Email Setup
%%% This will email you if there is an error as well as the files when they
%%% are completed.
%%%
%%% 1. Add email + password to start email file
%%% 2. Uncomment the below lines
% start_email();
% EMAIL = true;
% EMAIL_ADDRESS = '...@....com';

START = 1;
STOP = 38800;

output_folder = ['impedance_' num2str(START) '-' num2str(STOP)];
mkdir('../supplementary-files/dataset/raw_data', output_folder);

import com.comsol.model.*
import com.comsol.model.util.*
ModelUtil.showProgress(true);

COMSOL_MODEL_FILE = '../comsol/P2DImpedance.mph';
PARAMETER_FILE = '../supplementary-files/dataset/model_runs.txt';
SOBOL_LIST = readtable(PARAMETER_FILE, 'ReadVariableNames', false, 'HeaderLines', 1);

n_parameters = size(SOBOL_LIST,2);

fid = fopen(PARAMETER_FILE, 'r');
header = textscan(fid, [repmat('%[^,],', [1, n_parameters])], 1);
fclose(fid);

names = cell(n_parameters,1);
units = cell(size(names));

for i=2:n_parameters
    string = cell2mat(header{i});
    split = strsplit(string,'[');
    names{i} = cell2mat(split(1));
    string2 = cell2mat(split(2));
    split2 = strsplit(string2,']');
    units{i} = split2(1);
end

FREQUENCIES = '10^range(5,-(1/3),-3)';

times = [];
for j = START:STOP
    tic
    disp(['Run:' num2str(j)]);

    model = mphload(COMSOL_MODEL_FILE);
    model.hist.disable;

    % Load parameter values for run
    parameter_values = table2array(SOBOL_LIST(j,:));
    for k = 2:size(parameter_values,2)
        variable = names(k);
        value = [num2str(parameter_values(k)) '[' cell2mat(units{k}) ']'];
        model.param.set(variable, value);
    end

    % Update location of probe
    L = parameter_values(2)+ parameter_values(3) ...
                    + parameter_values(4);
    disp(['Length = ' num2str(L)])
    model.probe('pdom1').setIndex('coords1', num2str(L),0,0);

    % Set frequency
    model.study('std1').feature('param').set('plistarr', FREQUENCIES);
    model.study('std1').feature('param').set('pname', 'f');

    % Run the simulation
    model.study('std1').run;
        
    % Extract the harmonics
    try
        str = mphtable(model,'tbl5');
        tbl_data = str.data;
        f = tbl_data(:,1);
    catch
        warning('tbl_data does not exist for these parameters');
        tbl_data = NaN(1,7);
    end
    harmonics = tbl_data(:,:)';
    
    % Save the harmonics to file
    OUTPUT_FILE_NAME = ['../supplementary-files/dataset/raw_data/' output_folder '/run-' num2str(j) '.txt'];

    [fileID2, msg] = fopen(OUTPUT_FILE_NAME, 'a');
    if fileID2 == -1
        if EMAIL
            sendmail(EMAIL_ADDRESS, ['COMSOL FAILURE'],...
                ['fopen failed. harmonics data from run ' num2str(j) ' failed to save.']);
        end
        fclose('all');
    else
        for line = 1:size(harmonics,1)
            formatSpec = ['%e' repmat(' %e', 1, size(harmonics,2)-1) '\n'];
            fprintf(fileID2, formatSpec, harmonics(line, :));
        end
        fclose('all'); 

        times = [times toc];

        if(mod(j,25)==0)
            disp([num2str(j) ' runs completed. Last 25 runs took an average of ' num2str(mean(times)) ' seconds.']);
            times = [];
        end
    end
end

if EMAIL
    sendmail(EMAIL_ADDRESS, ['COMSOL Finished - Runs: ' num2str(START) '-' num2str(STOP)],...
           [num2str(STOP - START) ' runs completed.']);
end