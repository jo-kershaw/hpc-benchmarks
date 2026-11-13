#!/bin/bash
#SBATCH --job-name=hpl-h200-2gpu
#SBATCH --partition=calder-gpu-hopper
#SBATCH --gres=gpu:nvidia_h200:2
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=4
#SBATCH --mem=256G
#SBATCH --time=00:30:00
#SBATCH --output=slurm-%j.out

set -euo pipefail

module load calder/hopper cuda/13.3.0 openmpi/5.0.10

NVIDIA_HPL="/scratch-calder/users/$USER/hpl-benchmark/Calder/GPU/software/nvidia_hpc_benchmarks_openmpi-linux-x86_64-26.02.04-archive"

echo "Job: $SLURM_JOB_ID"
echo "Node: $SLURM_JOB_NODELIST"
nvidia-smi -L

srun --mpi=pmix --cpu-bind=none \
    "$NVIDIA_HPL/cuda13/hpl.sh" \
    --dat "$PWD/HPL.dat" \
    --no-multinode
