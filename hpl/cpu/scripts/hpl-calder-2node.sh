#!/bin/bash
#SBATCH --job-name=hpl_calder_2node
#SBATCH --nodes=2
#SBATCH --ntasks=256
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=03:00:00
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

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1

cd "$SLURM_SUBMIT_DIR" || exit 1

# Check that HPL.dat is present
if [[ ! -s HPL.dat ]]; then
    echo "ERROR: HPL.dat missing from $PWD" >&2
    exit 1
fi

N=$(awk 'NR==6 {print $1}' HPL.dat)
NB=$(awk 'NR==8 {print $1}' HPL.dat)
P=$(awk 'NR==11 {print $1}' HPL.dat)
Q=$(awk 'NR==12 {print $1}' HPL.dat)

if [[ "$N" != 270336 || "$NB" != 128 ||
      "$P" != 16 || "$Q" != 16 ]]; then
    echo "ERROR: Unexpected HPL configuration" >&2
    exit 1
fi

echo "Date: $(date)"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Working directory: $PWD"
echo "N=$N NB=$NB P=$P Q=$Q"
echo "MPI ranks: $SLURM_NTASKS"
echo "OpenBLAS threads: $OPENBLAS_NUM_THREADS"

module list

# Verify MPI processes are distributed across both nodes
HOSTFILE="rank_hosts_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt"

srun -n "$SLURM_NTASKS" --cpu-bind=cores \
    hostname > "$HOSTFILE"

echo "MPI rank distribution:"
sort "$HOSTFILE" | uniq -c

if [[ $(wc -l < "$HOSTFILE") -ne 256 ]] ||
   [[ $(sort -u "$HOSTFILE" | wc -l) -ne 2 ]] ||
   [[ $(sort "$HOSTFILE" | uniq -c |
       awk '$1 != 128 {bad=1} END {print bad+0}') -ne 0 ]]; then
    echo "ERROR: Incorrect MPI rank distribution" >&2
    exit 1
fi

# Run HPL across the two nodes
srun -n "$SLURM_NTASKS" --cpu-bind=cores \
    "$HOME/hpl-benchmark/hpl-2.3/bin/Calder/xhpl"
