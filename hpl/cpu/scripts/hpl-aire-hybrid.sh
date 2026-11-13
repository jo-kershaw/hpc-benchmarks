#!/bin/bash
#SBATCH --job-name=hpl_aire_hybrid
#SBATCH --partition=nodes
#SBATCH --nodes=1
#SBATCH --ntasks=84
#SBATCH --ntasks-per-node=84
#SBATCH --cpus-per-task=2
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --array=1-3%1
#SBATCH --output=hpl_aire_%A_%a.out
#SBATCH --error=hpl_aire_%A_%a.err

module purge
module load gcc/14.2.0
module load openmpi/5.0.6/gcc-14.2.0
module load openblas/0.3.28/gcc-14.2.0

export OPENBLAS_NUM_THREADS=2
export OMP_NUM_THREADS=2

cd "$SLURM_SUBMIT_DIR" || exit 1

if [[ ! -s HPL.dat ]]; then
    echo "ERROR: HPL.dat missing from $PWD" >&2
    exit 1
fi

N=$(awk 'NR==6 {print $1}' HPL.dat)
NB=$(awk 'NR==8 {print $1}' HPL.dat)
P=$(awk 'NR==11 {print $1}' HPL.dat)
Q=$(awk 'NR==12 {print $1}' HPL.dat)

if [[ "$N" != 270336 || "$NB" != 128 ||
      "$P" != 7 || "$Q" != 12 ]]; then
    echo "ERROR: Unexpected HPL configuration" >&2
    exit 1
fi

echo "Date: $(date)"
echo "Node: $SLURM_JOB_NODELIST"
echo "Working directory: $PWD"
echo "N=$N NB=$NB P=$P Q=$Q"
echo "MPI ranks: $SLURM_NTASKS"
echo "OpenBLAS threads: $OPENBLAS_NUM_THREADS"
module list

mpirun -np "$SLURM_NTASKS" \
    --map-by slot:PE=2 --bind-to core \
    "$HOME/hpl-benchmark/hpl-2.3/bin/Aire/xhpl"
