#!/bin/bash
#SBATCH --job-name=hpl_calder_timing
#SBATCH --nodes=1
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=02:00:00
#SBATCH --output=hpl_timing_%j.out
#SBATCH --error=hpl_timing_%j.err

set -euo pipefail

module purge
export MODULEPATH=/uol/apps/calder/modules
module load calder/cpu
module load gcc/15.3.0
module load openmpi/5.0.10
module load openblas/0.3.33

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1

TIMED="$HOME/hpl-benchmark/hpl-2.3-timing-fresh/bin/Calder/xhpl"

cd "$SLURM_SUBMIT_DIR"

if [[ ! -x "$TIMED" ]]; then
    echo "ERROR: Timing executable not found"
    exit 1
fi

echo "Node: $SLURM_JOB_NODELIST"
echo "Executable: $TIMED"
echo "Start: $(date)"

for NB in 128 256; do

    CASE="$SLURM_SUBMIT_DIR/NB$NB"

    if [[ ! -s "$CASE/HPL.dat" ]]; then
        echo "ERROR: Missing HPL.dat for NB=$NB"
        exit 1
    fi

    N=$(awk 'NR==6 {print $1}' "$CASE/HPL.dat")
    ACTUAL_NB=$(awk 'NR==8 {print $1}' "$CASE/HPL.dat")
    P=$(awk 'NR==11 {print $1}' "$CASE/HPL.dat")
    Q=$(awk 'NR==12 {print $1}' "$CASE/HPL.dat")

    if [[ "$N" != 270336 || "$ACTUAL_NB" != "$NB" ||
          "$P" != 8 || "$Q" != 16 ]]; then
        echo "ERROR: Invalid HPL.dat for NB=$NB"
        exit 1
    fi

    echo "=================================="
    echo "Starting NB=$NB at $(date)"
    echo "=================================="

    (
        cd "$CASE"
        srun --cpu-bind=cores "$TIMED" \
            > "hpl_NB${NB}.out" \
            2> "hpl_NB${NB}.err"
    )

    if ! grep -q 'PASSED' "$CASE/hpl_NB${NB}.out"; then
        echo "ERROR: NB=$NB did not pass numerical validation"
        exit 1
    fi

    echo "Finished NB=$NB at $(date)"
    grep -E '^WR|Max aggregated wall time|PASSED' \
        "$CASE/hpl_NB${NB}.out"

done

echo "All timing tests finished: $(date)"
