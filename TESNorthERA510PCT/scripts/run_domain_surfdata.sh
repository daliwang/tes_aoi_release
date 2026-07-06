#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

source /software/baseline/nsp/init/profile
source /projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/activate_shared_env.sh

# Source exported environment if present
if [ -f ./export_env.sh ]; then . ./export_env.sh; fi

date_string=$(date +'%y%m%d-%H%M')
: "${EXPID:=TESNorthERA510PCT}"
: "${EXP_ROOT:=$(cd "${SCRIPT_DIR}/.." && pwd)}"
: "${AOI_POINTS_DIR:=/projects/hpcl-cli185/proj-shared/wangd/uELM_TES_experiment}"
: "${AOI_POINTS_FILE:=TESNorthERA510PCT_gridID.nc}"
: "${TES_DATA_GROUP_ID:=TES_NORTHERA5}"
: "${BASE_DOMAIN_FILE:=/projects/hpcl-cli185/proj-shared/wangd/kiloCraft/TES_cases_data/Daymet_ERA5_TESSFA_NORTH/entire_domain/domain_surfdata/NORTHERA5_domain.lnd.TES_NORTHERA5.4km.1d.c251009.nc}"
: "${SURFDATA_DIR:=/projects/hpcl-cli185/proj-shared/wangd/kiloCraft/TES_cases_data/Daymet_ERA5_TESSFA_NORTH/entire_domain/domain_surfdata}"
: "${SURFDATA_FILE:=surfdata.TESSFA_DOMAIN1.4km.1d.NALCMS.c260218_yw.nc}"
DOM_SURF_DIR="${EXP_ROOT}/domain_surfdata"
mkdir -p "${DOM_SURF_DIR}"

# Ensure domain source file is available with expected local name
if [ ! -e domain.lnd."${TES_DATA_GROUP_ID}".4km.1d.nc ]; then
  ln -sf "${BASE_DOMAIN_FILE}" domain.lnd."${TES_DATA_GROUP_ID}".4km.1d.nc
fi

echo "[1/2] Generating AOI domain..."
python3 TES_AOI_domainGEN.py "${AOI_POINTS_DIR}" "${DOM_SURF_DIR}" "${AOI_POINTS_FILE}" 2>&1 | tee "${DOM_SURF_DIR}/${EXPID}_domaingen.log.${date_string}"

echo "Resolving latest AOI domain file..."
AOI_PREFIX="$(echo "${AOI_POINTS_FILE}" | awk -F'_' '{print $1}')"
AOI_DOMAIN=$(ls -1 ${DOM_SURF_DIR}/${AOI_PREFIX}_domain.lnd."${TES_DATA_GROUP_ID}".4km.1d.c*.nc 2>/dev/null | sort | tail -n1)
if [ -z "${AOI_DOMAIN}" ]; then echo 'ERROR: AOI domain file not found'; exit 2; fi

echo "[2/2] Generating AOI surfdata..."
python3 TES_AOI_surfdataGEN.py "${SURFDATA_DIR}" "${SURFDATA_FILE}" "${DOM_SURF_DIR}" "${DOM_SURF_DIR}/" "$(basename "${AOI_DOMAIN}")" 2>&1 | tee "${DOM_SURF_DIR}/${EXPID}_surfdargen.log.${date_string}"

echo 'Domain and surfdata generation complete.'
