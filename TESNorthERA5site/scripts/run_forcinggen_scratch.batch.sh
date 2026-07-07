#!/bin/bash
#SBATCH -J TESNorthERA5site_forcing
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -c 1
#SBATCH -t 12:00:00
#SBATCH --mem=400G
#SBATCH -p hpcl-cli185
#SBATCH -q hpcl-cli185

set -euo pipefail

cd /projects/hpcl-cli185/proj-shared/wangd/uELM_TES_experiment
bash TESNorthERA5site/scripts/run_forcinggen_scratch.sh
