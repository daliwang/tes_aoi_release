#!/bin/bash
#SBATCH -J TES_TESNorthERA510PCT_forcingGEN
#SBATCH -p hpcl-cli185
#SBATCH -q hpcl-cli185
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -c 1
#SBATCH -t 12:00:00
#SBATCH --mem=400G

source /software/baseline/nsp/init/profile || true
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
: "${PYTHON_ENV:=${SHARED_CONDA_PREFIX:-$HOME/.conda/envs/tes_aoi}}"
source /projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/activate_shared_env.sh "${PYTHON_ENV}"

# Source exported environment if present
if [ -f ./export_env.sh ]; then . ./export_env.sh; fi
export PYTHONUNBUFFERED=1

python3 -c "from mpi4py import MPI" 2>/dev/null || {
  echo "ERROR: mpi4py not found in ${PYTHON_ENV:-tes_aoi}; install with: conda install -c conda-forge mpi4py"
  exit 1
}
: "${EXP_ROOT:=$(cd "${SCRIPT_DIR}/.." && pwd)}"
echo "EXP_ROOT: ${EXP_ROOT}"

date_string=$(date +'%y%m%d-%H%M')
: "${EXPID:=TESNorthERA510PCT}"
: "${FORCING_DIR:=/projects/hpcl-cli185/proj-shared/wangd/kiloCraft/TES_cases_data/Daymet_ERA5_TESSFA_NORTH/entire_domain/forcing}"
: "${TES_DATA_GROUP_ID:=TES_NORTHERA5}"
OUT_DIR="${EXP_ROOT}/forcing"
mkdir -p "${OUT_DIR}"

# Locate the latest AOI domain to derive gridIDs
AOI_FILE_PATH="${EXP_ROOT}/domain_surfdata"
AOI_POINTS_FILE=$(ls -1 ${AOI_FILE_PATH}/*_domain.lnd.${TES_DATA_GROUP_ID}.4km.1d.c*.nc 2>/dev/null | sort | tail -n1 | xargs -r basename)
if [ -z "${AOI_POINTS_FILE}" ]; then echo 'ERROR: AOI domain file not found'; exit 2; fi

SRUN_QOS="${SCHED_QOS:-hpcl-cli185}"
SRUN_PARTITION="${SCHED_PARTITION:-hpcl-cli185}"
SRUN_NODES="${SCHED_NODES:-1}"
SRUN_TIME="${SCHED_TIME:-12:00:00}"
SRUN_MEM="${SCHED_MEM:-400G}"
SRUN_NTASKS="${SCHED_TASKS:-4}"
SRUN_CPUS_PER_TASK="${SCHED_CPUS_PER_TASK:-1}"

SRUN_CMD=(srun --mpi=pmi2 -p "${SRUN_PARTITION}" -q "${SRUN_QOS}" -N "${SRUN_NODES}" -c "${SRUN_CPUS_PER_TASK}" -t "${SRUN_TIME}" --mem="${SRUN_MEM}" -n "${SRUN_NTASKS}" python3 -u TES_AOI_forcingGEN_mpi.py "${FORCING_DIR}" "${OUT_DIR}" "${AOI_FILE_PATH}/" "${AOI_POINTS_FILE}")

# If not running inside a Slurm allocation, launch via srun on the login node
if [ -z "${SLURM_JOB_ID:-}" ]; then
  echo "${SRUN_CMD[*]}" | tee "${OUT_DIR}/${EXPID}_forcinggen.cmd.${date_string}"
  exec "${SRUN_CMD[@]}" 2>&1 | tee "${OUT_DIR}/${EXPID}_forcinggen.log.${date_string}"
fi

# Running under Slurm allocation
echo "${SRUN_CMD[*]}" | tee "${OUT_DIR}/${EXPID}_forcinggen.cmd.${date_string}"
"${SRUN_CMD[@]}" 2>&1 | tee "${OUT_DIR}/${EXPID}_forcinggen.log.${date_string}"
