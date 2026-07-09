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
| Forcing generation | Not re-run on PathFinder | Validated on scratch (MPI) |
| `create_links.sh` | Pending | Pending |
| `create_uELM_*.sh` | Pending | Done (scripts committed) |
| `case.submit` | Pending | Pending |

---

## 10. MPI forcing generation (PathFinder, 2026-07-08)

Validated TESNorthERA5site forcing generation on PathFinder exposed both a **correctness bug** and **I/O performance** limits on the project filesystem. Fixes were committed to the repo and then propagated into the case-preparation generator.

### 10.1 Correctness and performance fix (`TES_AOI_forcingGEN_mpi.py`)

**Problem:** The previous 3D subsetting path used a boolean `AOI_mask` with a per-timestep loop. That could misalign time slices and grid columns in the output NetCDF files.

**Fix (commit `f25e820`):**

- Resolve AOI cells with integer indices: `AOI_idx = np.where(np.isin(flat_ids, aoi_pts))[0]`
- Subset 3D variables as `src[name][start:end, :, AOI_idx]` and assign chunks in one shot
- Subset 2D variables on the last axis: `src[name][..., AOI_idx]`
- Use `aoi_pts.size` / `AOI_idx.size` for output dimensions
- Configurable `chunk_size` (default **32**) passed as an optional 5th CLI argument
- MPI launch on PathFinder via `srun --mpi=pmi2`

Canonical script: [`TES_AOI_forcingGEN_mpi.py`](TES_AOI_forcingGEN_mpi.py) at repo root. A per-case copy is also kept under `TESNorthERA5site/scripts/` for reference.

### 10.2 TESNorthERA5site validated workflow (committed scripts)

Commit `f25e820` added the full PathFinder-ready TESNorthERA5site script set:

| Script | Role |
|--------|------|
| `TES_AOI_domainGEN.py`, `TES_AOI_surfdataGEN.py`, `TES_AOI_forcingGEN*.py` | AOI subsetting generators |
| `run_domain_surfdata.sh` | Domain + surfdata generation |
| `run_forcing.sbatch` | Slurm MPI forcing job (scratch output, repo-root MPI script) |
| `export_env.sh` | Case environment (`FORCING_OUT_DIR`, `FORCING_GEN_SCRIPT`, scheduler vars) |
| `create_uELM_*.sh` | PathFinder E3SM case creation (`--mach pathfinder`) |
| `create_links.sh`, `forcing_*_creation.py` | DATM forcing link setup |

Manual scratch helpers (not required for new cases after §10.3):

- [`TESNorthERA5site/scripts/run_forcinggen_scratch.sh`](TESNorthERA5site/scripts/run_forcinggen_scratch.sh) — early scratch test wrapper (copy-back was disabled during testing)

### 10.3 Generator update (`aoi_prepare_experiment.py`)

To make the validated workflow the **default for all future cases**, `aoi_prepare_experiment.py` was updated to generate:

1. **Scratch-first forcing I/O** — `FORCING_OUT_DIR` defaults to `/scratch/hpcl-cli185/${USER}/<expid>/forcing`
2. **Repo-root MPI script** — `FORCING_GEN_SCRIPT` defaults to `${REPO_ROOT}/TES_AOI_forcingGEN_mpi.py` so cases always pick up the latest fix without re-copying Python files
3. **`FORCING_CHUNK_SIZE`** — default 32 (override via optional config key `forcing.chunk_size`)
4. **`sync_forcing_to_project.sh`** — copies `TPHWL3Hrly`, `Precip3Hrly`, `Solar3Hrly` from scratch into `<case>/forcing/` on the project tree
5. **`run_forcing.sbatch`** — runs MPI on scratch, then calls `sync_forcing_to_project.sh` automatically (no `exec`, so sync always runs)

**Standard workflow for a new case:**

```
python aoi_prepare_experiment.py --config aoi_<case>_config.json
  → run_domain_surfdata.sh
  → sbatch run_forcing.sbatch        # MPI on scratch
       → sync_forcing_to_project.sh  # copy to <case>/forcing/
  → create_links.sh
  → create_uELM_*.sh
```

### 10.4 Regenerated vs committed TESNorthERA5site scripts

Re-running `aoi_prepare_experiment.py` on an **existing** case overwrites generated wrappers (`run_forcing.sbatch`, `export_env.sh`, `create_uELM_*.sh`, etc.). That is expected: the generator is the source of truth for new cases.

The committed TESNorthERA5site scripts (from `f25e820` plus `aca4394`) were hand-tuned **before** the §10.3 generator update. Differences after a test re-prepare included:

| Change | Committed TESNorthERA5site | After re-prepare |
|--------|---------------------------|------------------|
| Scratch → project sync | Not in `run_forcing.sbatch` | Adds `sync_forcing_to_project.sh` call |
| `FORCING_CHUNK_SIZE` | Not passed to MPI script | Passed as 5th argument (default 32) |
| `exec` in login-node path | Present (blocks post-run sync) | Removed |
| `create_uELM_transient2.sh` | No `JOB_QUEUE` line | Generator adds `./xmlchange --force JOB_QUEUE="batch_ccsi"` |

**Recommendation:** Keep the committed TESNorthERA5site scripts as the validated reference for that case until you intentionally re-prepare. For **new** cases, only run `aoi_prepare_experiment.py` once on a fresh experiment directory — the generated scripts will include §10.3 behavior automatically.

---

## 11. Immediate next actions

1. **Use `aoi_prepare_experiment.py` for new cases** — scratch forcing, repo-root MPI script, and project-tree sync are built in (§10.3).
2. **Re-run or validate TESNorthERA510PCT** on PathFinder if the full 10% case is needed.
3. **Push git changes** after confirming rebase outcome (§8).

---

## 12. Key references

- Baseline backup case: `TESNorthERA510PCT_baseline_bk/`
- PathFinder E3SM reference: `/projects/hpcl-cli185/proj-shared/wangd/kmELM/case_gene/PathFinder/TES_NORTHERA5/TES_NORTHERA5_ref.sh`
- Run commands: [`commands.txt`](commands.txt)
- Baseline config backup: `aoi_TESNorthERA510PCT_config.json_baseline`
