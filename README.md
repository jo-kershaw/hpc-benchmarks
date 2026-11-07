# HPC Benchmarks

Scripts for running and analysing HPC benchmarks on the University of Leeds Aire and Calder clusters.

Comparing different aspects of system performance and investigating how results change with benchmark settings.

## Benchmarks

- **HPL (High Performance Linpack):** Floating-point performance, including the effect of block size.
- **STREAM:** Memory bandwidth at different OpenMP thread counts.
- **OSU MPI Micro-Benchmarks:** MPI communication performance, including latency, bandwidth and collective operations.

## Repository contents

- `hpl/` — Slurm scripts, HPL configuration files and plotting code.
- `stream/` — Slurm script and plotting code.
- `osu/` — MPI benchmark submission script.

## Data

Original benchmark measurements are not included in this repository.

The scripts were written for the Leeds HPC environment and may need modification to run on other systems.

Small synthetic datasets may be added to demonstrate the plotting scripts.
