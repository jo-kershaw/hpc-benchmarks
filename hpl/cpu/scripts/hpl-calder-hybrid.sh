#!/bin/bash
#SBATCH --job-name=hpl_calder_hybrid
#SBATCH --nodes=1
#SBATCH --ntasks=64
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=2
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --array=1-3%1
#SBATCH --output=hpl_calder_%A_%a.out
#SBATCH --error=hpl_calder_%A_%a.err

set -euo pipefail

module purge
export MODULEPATH=/uol/apps/calder/modules
module load calder/cpu
module load gcc/15.3.0
module load openmpi/5.0.10
module load openblas/0.3.33

export OMP_NUM_THREADS=2
export OPENBLAS_NUM_THREADS=2

cd "$SLURM_SUBMIT_DIR" || exit 1

# Check the input before launching MPI
if [[ ! -s HPL.dat ]]; then
    echo "ERROR: HPL.dat missing from $PWD" >&2
    exit 1
fi

N=$(awk 'NR==6 {print $1}' HPL.dat)
NB=$(awk 'NR==8 {print $1}' HPL.dat)
P=$(awk 'NR==11 {print $1}' HPL.dat)
Q=$(awk 'NR==12 {print $1}' HPL.dat)

if [[ "$N" != 270336 || "$NB" != 128 ||
      "$P" != 8 || "$Q" != 8 ]]; then
    echo "ERROR: Unexpected HPL configuration" >&2
    exit 1
fi

echo "Date: $(date)"
echo "Allocated node: $SLURM_JOB_NODELIST"
echo "Working directory: $PWD"
echo "N=$N NB=$NB P=$P Q=$Q"
echo "MPI ranks: $SLURM_NTASKS"
echo "OpenBLAS threads: $OPENBLAS_NUM_THREADS"

module list

cp HPL.dat "HPL_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.dat"

srun --cpu-bind=cores \
    "$HOME/hpl-benchmark/hpl-2.3/bin/Calder/xhpl"
