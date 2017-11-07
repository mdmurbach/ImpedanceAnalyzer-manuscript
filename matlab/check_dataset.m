clear all; clc; close all

% Setup
import com.comsol.model.*
import com.comsol.model.util.*
ModelUtil.showProgress(true);
COMSOL_MODEL_FILE = '../comsol/P2DImpedance.mph';
DATASET_FILE = '../supplementary-files/dataset/full_dataset.csv';

% Set the frequencies for COMSOL to simulate
FREQUENCIES = '10^range(5,-(1/3),-3)';

RUN_LIST = readtable(DATASET_FILE, 'ReadVariableNames', false, 'HeaderLines', 1);

n_parameters = 31;
n_frequencies = 25;
    
fid = fopen(DATASET_FILE, 'r');
header = textscan(fid, repmat('%[^,],', [1,n_parameters]), 1);
fclose(fid);

names = cell(n_parameters,1);
units = cell(size(names));

for i=1:n_parameters
    string = cell2mat(header{i});
    split = strsplit(string,'[');
    names{i} = cell2mat(split(1));
    if length(split) > 1
        string2 = cell2mat(split(2));
        split2 = strsplit(string2,']');
        units{i} = cell2mat(split2(1));
    end
end

num_runs = 50;
random_runs = randi([1 height(RUN_LIST)], 1, num_runs);

for run = random_runs
    disp(run)
    
    parameter_values = table2array(RUN_LIST(run,1:n_parameters));
    raw_impedance = table2array(RUN_LIST(run,n_parameters+1:n_parameters+n_frequencies));
    
    impedance_values = zeros(1,length(raw_impedance));
    for i=1:length(raw_impedance)
        impedance_values(i) = str2num(cell2mat(raw_impedance(i)));
    end
    
    model = mphload(COMSOL_MODEL_FILE);
    model.hist.disable;
    
    % Load parameter values for run
    for k = 2:size(parameter_values,2)
        variable = names(k);
        value = [num2str(parameter_values(k)) '[' cell2mat(units(k)) ']'];
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
    
    calced_impedance = harmonics(2,:)- harmonics(3,:)*1j;
    
    difference = calced_impedance - impedance_values;
    
    if all(abs(difference) < 1e-6)
        disp(['Run:' num2str(run) ' - PASSED']);
        output_file = ['./PASSED - ' num2str(run) '.csv'];
    else
        disp(['Run:' num2str(run) ' - FAILED']);
        output_file = ['./FAILED - ' num2str(run) '.csv'];
    end

    [fileID2, msg] = fopen(output_file, 'a');
    if fileID2 == -1
        fclose('all');     
    else
        formatSpec = ['%e' repmat(',%e', 1, length(impedance_values)-1)];
        fprintf(fileID2, formatSpec, real(impedance_values));
        formatSpec = ['%e' repmat(',%e', 1, length(impedance_values)-1) '\n'];
        fprintf(fileID2, formatSpec, imag(impedance_values));
        formatSpec = ['%e' repmat(',%e', 1, length(calced_impedance)-1)];
        fprintf(fileID2, formatSpec, real(calced_impedance));
        formatSpec = ['%e' repmat(',%e', 1, length(calced_impedance)-1) '\n'];
        fprintf(fileID2, formatSpec, imag(calced_impedance));
        formatSpec = ['%e' repmat(',%e', 1, length(difference)-1)];
        fprintf(fileID2, formatSpec, real(difference));
        formatSpec = ['%e' repmat(',%e', 1, length(difference)-1) '\n'];
        fprintf(fileID2, formatSpec, imag(difference));
        fclose('all'); 
    end 
end