#!/bin/bash
set -e

KILOCRAFT_ROOT="/projects/hpcl-cli185/proj-shared/wangd/kiloCraft/"
KMELM_ROOT="/projects/hpcl-cli185/proj-shared/wangd/kmELM/"
KMELM_CASE_ROOT="${KMELM_ROOT}/e3sm_cases/"
KMELM_RUN_ROOT="${KMELM_ROOT}/e3sm_runs/"
E3SM_SRC_ROOT="${KMELM_ROOT}/E3SM/"
E3SM_DIN="/projects/hpcl-cli185/world-shared/e3sm"

TES_DATA_ROOT="$KILOCRAFT_ROOT/TES_cases_data/"
TES_DOMAIN_FORCING_GROUP_ID="Daymet_ERA5_TESSFA_NORTH"
TES_DATA_GROUP_ID="TES_NORTHERA5"

EXPID="TESNorthERA5site"
CASE_COMPSET="I20TRCNPRDCTCBC"

# Transient case directory (Phase 2: 2000 start, 25 years)
CASEDIR="$KMELM_CASE_ROOT/${TES_DOMAIN_FORCING_GROUP_ID}/uELM_${EXPID}_${CASE_COMPSET}_transient2"
CASE_DATA="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# CO2 stream file for transient (20TR); copy into case dir (installed as user_datm.streams.txt.co2tseries.20tr)
CO2_STREAM_SRC="/projects/hpcl-cli185/proj-shared/zdr/e3sm_cases/20260225_Southeast_hires_single_I20TRCNPRDCTCBC/user_datm.streams.txt.co2tseries.20tr"

DOMAIN_FILE=$(ls -1 ${CASE_DATA}/domain_surfdata/${EXPID}_domain.lnd.${TES_DATA_GROUP_ID}.4km.1d.c*.nc 2>/dev/null | sort | tail -n1 | xargs -r basename)
if [ -z "${DOMAIN_FILE}" ]; then echo 'ERROR: Domain file not found'; exit 2; fi
SURFDATA_FILE=$(ls -1 ${CASE_DATA}/domain_surfdata/${EXPID}_surfdata.${TES_DATA_GROUP_ID}.4km.1d.NLCD.c*.nc 2>/dev/null | sort | tail -n1 | xargs -r basename)
if [ -z "${SURFDATA_FILE}" ]; then echo 'ERROR: Surfdata file not found'; exit 2; fi

rm -rf "${CASEDIR}"

${E3SM_SRC_ROOT}/cime/scripts/create_newcase --case "${CASEDIR}" --mach pathfinder --compiler gnu --mpilib openmpi --compset "${CASE_COMPSET}" --res ELM_USRDAT  --handle-preexisting-dirs r --srcroot "${E3SM_SRC_ROOT}"

cd "${CASEDIR}"

./xmlchange PIO_TYPENAME="pnetcdf"
./xmlchange PIO_NETCDF_FORMAT="64bit_data"
./xmlchange DIN_LOC_ROOT="${E3SM_DIN}"
./xmlchange DIN_LOC_ROOT_CLMFORC="${CASE_DATA}"
./xmlchange CIME_OUTPUT_ROOT="$KMELM_RUN_ROOT"

# Data mode and domain bindings
./xmlchange DATM_MODE="uELM_TES"
./xmlchange ATM_DOMAIN_PATH="${CASE_DATA}/domain_surfdata/"
./xmlchange ATM_DOMAIN_FILE="${DOMAIN_FILE}"
./xmlchange LND_DOMAIN_PATH="${CASE_DATA}/domain_surfdata/"
./xmlchange LND_DOMAIN_FILE="${DOMAIN_FILE}"

# Scientific configuration for transient Phase 2 (2000 start, 25 years)
./xmlchange STOP_N="25"
./xmlchange REST_N="25"
./xmlchange STOP_OPTION="nyears"
./xmlchange ATM_NCPL="24"
./xmlchange DATM_CLMNCEP_YR_START="2000"
./xmlchange DATM_CLMNCEP_YR_END="2024"
./xmlchange DATM_CLMNCEP_YR_ALIGN="1990"
./xmlchange CONTINUE_RUN="FALSE"
./xmlchange ELM_ACCELERATED_SPINUP="off"
./xmlchange ELM_BLDNML_OPTS="-bgc bgc -nutrient cnp -nutrient_comp_pathway rd  -soil_decomp ctc -methane"
./xmlchange RUN_TYPE="hybrid"
./xmlchange RUN_STARTDATE="2000-01-01"

# Copy CO2 stream file for transient into case directory (destination uses standard name user_datm...)
if [ -f "${CO2_STREAM_SRC}" ]; then
  cp "${CO2_STREAM_SRC}" "${CASEDIR}/user_datm.streams.txt.co2tseries.20tr"
else
  ALT_CO2_SRC="/projects/hpcl-cli185/proj-shared/zdr/e3sm_cases/20260225_Southeast_hires_single_I20TRCNPRDCTCBC/uuser_datm.streams.txt.co2tseries.20tr"
  if [ -f "${ALT_CO2_SRC}" ]; then
    cp "${ALT_CO2_SRC}" "${CASEDIR}/user_datm.streams.txt.co2tseries.20tr"
  else
    echo "WARNING: CO2 stream file not found at ${CO2_STREAM_SRC} or ${ALT_CO2_SRC}; copy manually if needed."
  fi
fi

cat >> user_nl_elm <<EOF
!finidat = '/projects/hpcl-cli185/scratch/zdr/e3sm_run/20260225_Southeast_hires_single_I1850CNPRDCTCBC/run/20260225_Southeast_hires_single_I1850CNPRDCTCBC.elm.r.0401-01-01-00000.nc'
finidat = '${KMELM_RUN_ROOT}/uELM_${EXPID}_${CASE_COMPSET}_transient1/run/uELM_${EXPID}_${CASE_COMPSET}_transient1.elm.r.2000-01-01-00000.nc'
fsurdat = '${CASE_DATA}/domain_surfdata/${SURFDATA_FILE}'
do_budgets = .false.
flanduse_timeseries = ''
check_finidat_fsurdat_consistency = .false.
check_finidat_year_consistency = .false.

spinup_state = 0
suplphos = 'NONE'
hist_nhtfrq=0
hist_mfilt=1
EOF

# Computational resources
./xmlchange NTASKS="1"
./xmlchange NTASKS_PER_INST="1"
./xmlchange MAX_MPITASKS_PER_NODE="1"
./xmlchange JOB_WALLCLOCK_TIME="2:00:00"

./case.setup --reset
./case.setup

./case.build --clean-all
./case.build

./xmlchange --force JOB_QUEUE="batch_ccsi"

