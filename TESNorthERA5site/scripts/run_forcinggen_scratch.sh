#!/bin/bash
set -euo pipefail

WORK_ROOT="/projects/hpcl-cli185/proj-shared/wangd"
PROJECT_ROOT="${WORK_ROOT}/uELM_TES_experiment"
SCRATCH_BASE="/scratch/hpcl-cli185/7xw/TESNorthERA5site"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRATCH_DIR="${SCRATCH_BASE}/run_${TIMESTAMP}"
SOURCE_DIR="${WORK_ROOT}/kiloCraft/TES_cases_data/Daymet_ERA5_TESSFA_NORTH/entire_domain/forcing"
AOI_DIR="${PROJECT_ROOT}/TESNorthERA5site/domain_surfdata"
AOI_FILE="TESNorthERA5site_domain.lnd.TES_NORTHERA5.4km.1d.c260707.nc"
OUTPUT_DIR="${PROJECT_ROOT}/TESNorthERA5site/forcing"
CHUNK_SIZE=32

mkdir -p "${SCRATCH_DIR}" \
         "${SCRATCH_DIR}/TPHWL3Hrly" \
         "${SCRATCH_DIR}/Precip3Hrly" \
         "${SCRATCH_DIR}/Solar3Hrly" \
         "${OUTPUT_DIR}/TPHWL3Hrly" \
         "${OUTPUT_DIR}/Precip3Hrly" \
         "${OUTPUT_DIR}/Solar3Hrly"

echo "Scratch run directory: ${SCRATCH_DIR}"

cd "${PROJECT_ROOT}"
srun --mpi=pmi2 -p hpcl-cli185 -q hpcl-cli185 -N 1 -c 1 -t 12:00:00 --mem=400G -n 4 \
    python3 -u TES_AOI_forcingGEN_mpi.py \
    "${SOURCE_DIR}" \
    "${SCRATCH_DIR}" \
    "${AOI_DIR}" \
    "${AOI_FILE}" \
    "${CHUNK_SIZE}"

# Mirror the source forcing folder structure into the project output tree.
# (Temporarily disabled for this run)
# for subdir in TPHWL3Hrly Precip3Hrly Solar3Hrly; do
#     mkdir -p "${OUTPUT_DIR}/${subdir}"
#     cp -a "${SCRATCH_DIR}/${subdir}/." "${OUTPUT_DIR}/${subdir}/"
# done

echo "Forcing generation completed; outputs in ${SCRATCH_DIR} (copy disabled)"
