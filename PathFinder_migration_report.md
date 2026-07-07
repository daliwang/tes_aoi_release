# PathFinder Migration Report

**Date:** 2026-07-07  
**Cluster:** OLCF PathFinder (`/projects/hpcl-cli185/`)  
**Repository:** `uELM_TES_experiment`  
**Reference E3SM case:** `kmELM/case_gene/PathFinder/TES_NORTHERA5/TES_NORTHERA5_ref.sh`

---

## 1. Summary

This work migrated the TES North ERA5 uELM experiment workflow from the old CADES Baseline cluster (`/gpfs/wolf2/cades/cli185/`) to PathFinder. Two experiment cases are configured:

| Case | Description | GridID file | Status |
|------|-------------|-------------|--------|
| `TESNorthERA510PCT` | 10% random subdomain (~25,954 cells) | `TESNorthERA510PCT_gridID.nc` | Scripts/config updated; workflow ready |
| `TESNorthERA5site` | 5-site test subdomain | `TESNorthERA5site_gridID.nc` | Scripts/config created; **blocked on Python env** |

Step-by-step run commands are in [`commands.txt`](commands.txt).

---

## 2. Path mapping (Baseline → PathFinder)

| Purpose | Baseline | PathFinder |
|---------|----------|------------|
| Project root | `/gpfs/wolf2/cades/cli185/proj-shared/wangd/` | `/projects/hpcl-cli185/proj-shared/wangd/` |
| E3SM input data | `.../world-shared/e3sm/inputdata` | `/projects/hpcl-cli185/world-shared/e3sm` |
| E3SM source | `.../kmELM/E3SM` | `/projects/hpcl-cli185/proj-shared/wangd/kmELM/E3SM` |
| TES case data | `.../kiloCraft/TES_cases_data/Daymet_ERA5_TESSFA_NORTH/` | same under `/projects/hpcl-cli185/...` |
| System profile | `/sw/baseline/nsp/init/profile` | `/software/baseline/nsp/init/profile` |
| Python env | `.../kiloCraft/python_test_env/activate_shared_env.sh` | same path (see §6) |
| CIME machine | `cades-baseline` | `pathfinder` |
| Slurm queue | `batch_ccsi` | `batch_ccsi` |

---

## 3. E3SM configuration changes

Applied consistently across case-creation scripts (`create_uELM_*.sh`), matching `TES_NORTHERA5_ref.sh`:

- `--mach pathfinder --compiler gnu --mpilib openmpi`
- `DIN_LOC_ROOT=/projects/hpcl-cli185/world-shared/e3sm`
- `E3SM_SRC_ROOT=/projects/hpcl-cli185/proj-shared/wangd/kmELM/E3SM`
- `CIME_OUTPUT_ROOT=/projects/hpcl-cli185/proj-shared/wangd/kmELM/e3sm_runs/`
- `./xmlchange --force JOB_QUEUE="batch_ccsi"` after `case.build`
- CO2 stream for transient cases:  
  `/projects/hpcl-cli185/proj-shared/zdr/e3sm_cases/20260225_Southeast_hires_single_I20TRCNPRDCTCBC/user_datm.streams.txt.co2tseries.20tr`

---

## 4. Case details

### 4.1 TESNorthERA510PCT (10% subdomain)

- **Config:** `aoi_TESNorthERA510PCT_config.json`
- **Experiment dir:** `TESNorthERA510PCT/`
- **Backup of old baseline run:** `TESNorthERA510PCT_baseline_bk/`
- **GridIDs:** 25,954 cells (10% of NORTHERA5 domain)

### 4.2 TESNorthERA5site (5-site test)

- **Config:** `aoi_TESNorthERA5site_config.json`
- **Experiment dir:** `TESNorthERA5site/`
- **GridIDs (seed=42):** `124869, 261376, 263190, 330575, 377032`

E3SM case directories (after `create_uELM_*.sh`):

```
/projects/hpcl-cli185/proj-shared/wangd/kmELM/e3sm_cases/Daymet_ERA5_TESSFA_NORTH/
  uELM_TESNorthERA5site_I1850CNPRDCTCBC
  uELM_TESNorthERA5site_I1850CNPRDCTCBC_finalspin
  uELM_TESNorthERA5site_I20TRCNPRDCTCBC_transient1
  uELM_TESNorthERA5site_I20TRCNPRDCTCBC_transient2
```

---

## 5. Repository changes

### 5.1 New files

| File | Purpose |
|------|---------|
| `aoi_TESNorthERA5site_config.json` | PathFinder config for 5-site case |
| `TESNorthERA5site_gridID.nc` | 5-site gridcell ID file |
| `TESNorthERA5site/` | Generated experiment directory |
| `commands.txt` | End-to-end command list for both cases |
| `PathFinder_migration_report.md` | This report |

### 5.2 Updated files

| File | Changes |
|------|---------|
| `aoi_TESNorthERA510PCT_config.json` | PathFinder paths, `mach: pathfinder` |
| `TESNorthERA510PCT/scripts/*` | PathFinder paths, E3SM machine, bootstrap |
| `select_random_gridids.py` | Added `--count`; fixed auto-naming; updated default `--like` path |
| `aoi_prepare_experiment.py` | Python 3.9 compat; PathFinder defaults; `tes_data_group_id` fix in forcing script |

### 5.3 Removed duplicates

- `TESNorthERA55site/` (duplicate of 5-site case from bad auto-naming)
- `TESNorthERA55site_gridID.nc`
- `aoi_TESNorthERA55site_config.json`

### 5.4 Bug fixes

- `run_forcing.sbatch`: domain lookup uses `TES_NORTHERA5` (was incorrectly `TES_SE`)
- `select_random_gridids.py`: `--case-name TESNorthERA5 --count 5` no longer produces `TESNorthERA55site`

---

## 6. Python environment (blocking issue)

### Problem

`run_domain_surfdata.sh` fails with:

```
ModuleNotFoundError: No module named 'pyproj'
```

**Root cause:** The shared conda env at  
`/projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/conda_envs/testvenv`  
was copied from Baseline but is **broken on PathFinder**:

- `bin/python3` symlink missing
- `bin/python3.11` exists but is not executable (`-rw-rw----`, owned by `wangd`)
- `activate_shared_env.sh` prints success but `python3` falls through to miniforge **base** (Python 3.12, no `pyproj`)
- `pip install pyproj` installs to `~/.local` (Python 3.9), which the scripts do not use

`pyproj`, `netCDF4`, etc. **are present** inside `testvenv/lib/python3.11/site-packages` but cannot be reached.

### Resolution (in progress)

A working personal env was created:

```bash
module load miniforge3
source "$(conda info --base)/etc/profile.d/conda.sh"
conda create -y -n tes_aoi -c conda-forge python=3.11 pyproj netcdf4 numpy pandas scipy
conda activate tes_aoi
python -c "import pyproj, netCDF4, numpy, pandas, scipy; print('OK')"
```

**Status (2026-07-07):** `tes_aoi` at `/home/7xw/.conda/envs/tes_aoi` — import test **OK**.

### Recommended next steps for shared env

**Option A — Clone personal env into shared `testvenv`** (while `tes_aoi` is active):

```bash
conda activate tes_aoi
bash /projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/create_shared_env_from_existing.sh \
  /projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/conda_envs/testvenv
```

Requires write permission on `testvenv` (owned by `wangd`).

**Option B — Use personal env directly** (no shared `testvenv` rebuild):

```bash
source /projects/hpcl-cli185/proj-shared/wangd/kiloCraft/python_test_env/activate_shared_env.sh \
  $HOME/.conda/envs/tes_aoi
```

**Option C — Fix permissions** (owner `wangd`):

```bash
chmod +x .../testvenv/bin/python3.11
ln -sf python3.11 .../testvenv/bin/python3
ln -sf python3.11 .../testvenv/bin/python
```

---

## 7. Verified paths (PathFinder)

All config paths were verified present on PathFinder:

- `TESNorthERA5site_gridID.nc`
- `TESNorthERA510PCT_gridID.nc`
- NORTHERA5 base domain, surfdata, forcing directories
- `kmELM/E3SM` source tree
- `/projects/hpcl-cli185/world-shared/e3sm`
- CO2 stream file under `proj-shared/zdr/e3sm_cases/`
- `/software/baseline/nsp/init/profile`

---

## 8. Git notes

During this work, `dev` was rebased locally. After rebase:

- `git push origin dev` may be rejected (non-fast-forward) because commit SHAs changed
- `git pull` may report "Already up to date" if `dev` tracks `origin/main` instead of `origin/dev`
- Fix tracking: `git branch --set-upstream-to=origin/dev dev`
- After rebase, push with: `git push --force-with-lease origin dev` (only if remote history should be replaced)

---

## 9. Workflow status

| Step | TESNorthERA510PCT | TESNorthERA5site |
|------|-------------------|------------------|
| GridID file | Done | Done |
| `aoi_prepare_experiment.py` | Done (manual script updates) | Done |
| Domain/surfdata generation | Not re-run on PathFinder | Done |
| Forcing generation | Not re-run on PathFinder | In progress / validated on scratch |
| `create_links.sh` | Pending | Pending |
| `create_uELM_*.sh` | Pending | Pending |
| `case.submit` | Pending | Pending |

---

## 10. Forcing-generation adjustments on PathFinder

To reduce the impact of the slow NFS-backed project filesystem, the TESNorthERA5site forcing workflow was adapted to use the faster scratch filesystem at `/scratch/hpcl-cli185/7xw/TESNorthERA5site`.

### 10.1 Script changes

- Updated [TES_AOI_forcingGEN_mpi.py](TES_AOI_forcingGEN_mpi.py) to make the 3D subsetting chunk size configurable and default it to 32.
- Added a wrapper script at [TESNorthERA5site/scripts/run_forcinggen_scratch.sh](TESNorthERA5site/scripts/run_forcinggen_scratch.sh) that:
  - runs the forcing generator from the scratch area,
  - creates the three expected forcing subfolders (`TPHWL3Hrly`, `Precip3Hrly`, `Solar3Hrly`),
  - copies generated files back into the project output tree after completion.
- Added a Slurm batch launcher at [TESNorthERA5site/scripts/run_forcinggen_scratch.batch.sh](TESNorthERA5site/scripts/run_forcinggen_scratch.batch.sh) for submission through `sbatch`.

### 10.2 Operational notes

- The scratch-based workflow was necessary because writes to the project filesystem were much slower and were causing the forcing generation to appear stalled or incomplete.
- The larger chunk size reduced the number of small subsetting loops and improved throughput, although the overall run remains slower than ideal because the workflow still does many NetCDF read/write operations.
- The current implementation is functional, but further performance gains may require additional optimization in the Python subsetting loop or a larger Slurm allocation.

---

## 11. Immediate next actions

1. **Fix Python environment** (§6) — required before any AOI generation script will run.
2. **Run TESNorthERA5site workflow** — follow [`commands.txt`](commands.txt) § TESNorthERA5site, steps 3–7.
3. **Re-run or validate TESNorthERA510PCT** on PathFinder if full 10% case is needed.
4. **Push git changes** after confirming rebase outcome (§8).

---

## 11. Key references

- Baseline backup case: `TESNorthERA510PCT_baseline_bk/`
- PathFinder E3SM reference: `/projects/hpcl-cli185/proj-shared/wangd/kmELM/case_gene/PathFinder/TES_NORTHERA5/TES_NORTHERA5_ref.sh`
- Run commands: [`commands.txt`](commands.txt)
- Baseline config backup: `aoi_TESNorthERA510PCT_config.json_baseline`
