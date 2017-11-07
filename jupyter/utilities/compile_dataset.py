import numpy as np
import pandas as pd
import os, sys
import argparse
from datetime import datetime
startTime = datetime.now()

parser = argparse.ArgumentParser()
parser.add_argument("--directory", "-d", type=str, default="./")
parser.add_argument("--output", "-o", type=str, default="./")
parser.add_argument("--verbose", "-v", action="store_true")
args = parser.parse_args()

directory = args.directory
output = args.output
verbose = args.verbose

runs = []
for filename in os.listdir(directory):
    if filename.startswith('run'):
        run = int(filename.split('-')[-1].split('.')[0])
        runs.append(run)

if verbose:
    print(len(runs), "model runs.", " Last = " + str(sorted(runs)[-1]))

num_columns = 25
full_set = np.ndarray((len(runs)+1,num_columns),dtype=complex)

if len(runs) == sorted(runs)[-1]:
    for i, run in enumerate(sorted(runs)):
        filename = 'run-' + str(run) + '.txt'
        data = np.genfromtxt(directory + filename)
        full_set[i+1,:] = data[1] - 1j*data[2]
        if i == 0:
            full_set[i,:] = data[0]

        if verbose:
            progress = int(round(60.0 * run / len(runs)))

            percents = round(100.0 * run / len(runs), 1)
            bar = '=' * progress + '-' * (60 - progress)

            sys.stdout.write('Harmonic: %s - [%s] %s%s; run = %s\r' % (harmonic, bar, percents, '%', run))
            sys.stdout.flush()

    if verbose:
        print("\n")
    df = pd.DataFrame(full_set[1:], index=range(1,len(runs)+1), columns = np.real(full_set[0]))
    
    df_real, df_imag = df.applymap(np.real), df.applymap(np.imag)
    df_real.columns = [str(c) + '_real' for c in df_real.columns]
    df_imag.columns = [str(c) + '_imag' for c in df_imag.columns]

    full_df = pd.concat([df_real, df_imag], axis=1)
    full_df.to_csv(output + str(len(runs)) + '-Z.csv')
else:
    sys.exit('Error: Mismatch in files')

timedelta = datetime.now() - startTime
hours = int(timedelta.seconds / 3600)
minutes = int((timedelta.seconds - hours*3600)/60)
seconds = int(timedelta.seconds - hours*3600 - minutes*60)

print('\nCompleted in {} hours, {} minutes, and {} seconds'.format(hours, minutes, seconds))
