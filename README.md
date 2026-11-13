# HPC Benchmarks

Scripts for running and analysing HPC benchmarks on the University of Leeds Aire and Calder clusters.

Comparing different aspects of system performance and investigating how results change with benchmark settings.

## Benchmarks

- **HPL (High Performance Linpack):** CPU and GPU floating-point performance, investigating matrix size, block size and scaling across nodes. GPU tests use NVIDIA HPL on Calder's H200 GPUs.
- **STREAM:** Memory bandwidth at different OpenMP thread counts.
- **OSU MPI Micro-Benchmarks:** MPI communication performance, including latency, bandwidth and collective operations.

## Repository contents

- `hpl/cpu/` — CPU HPL submission scripts and configurations.
- `hpl/gpu/` — GPU HPL submission scripts, configurations and results collection code.
- `hpl/` — Additional HPL analysis and plotting code.
- `stream/` — Slurm script and plotting code.
- `osu/` — MPI benchmark submission script.

## Data

Original benchmark measurements are not included in this repository.

The scripts were written for the Leeds HPC environment and may need modification to run on other systems.
