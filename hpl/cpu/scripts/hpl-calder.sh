#!/bin/bash
#SBATCH --job-name=hpl_calder
#SBATCH --nodes=1
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --array=1-3%1
#SBATCH --output=hpl_calder_%A_%a.out
#SBATCH --error=hpl_calder_%A_%a.err

# Load libraries used to build HPL
module purge
export MODULEPATH=/uol/apps/calder/modules
module load calder/cpu
module load gcc/15.3.0
module load openmpi/5.0.10
module load openblas/0.3.33

# One thread per MPI process
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

# Working directory
cd "$SLURM_SUBMIT_DIR" || exit 1
echo "Working directory: $PWD"
echo "Using HPL.dat: $PWD/HPL.dat"
echo "N: $(awk 'NR==6 {print $1}' HPL.dat)"
echo "NB: $(awk 'NR==8 {print $1}' HPL.dat)"


# Record information about the run
echo "HPL baseline test: Calder"
date
hostname
module list

# reproducibility!
cp HPL.dat "HPL_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.dat"

echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job: $SLURM_JOB_ID"
echo "Allocated nodes: $SLURM_JOB_NODELIST"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "MPI processes: $SLURM_NTASKS"

lscpu | grep -E 'Model name|Socket|Core.s. per socket|Thread.s. per core'
module list

# Run HPL
#srun ./xhpl
# Calder
srun --cpu-bind=cores \
    "$HOME/hpl-benchmark/hpl-2.3/bin/Calder/xhpl"
