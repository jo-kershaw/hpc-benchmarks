#!/bin/bash
#SBATCH --job-name=hpl_calder_timing_256_384
#SBATCH --nodes=1
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=02:30:00
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

[[ -x "$TIMED" ]] || {
    echo "ERROR: Missing timing executable"
    exit 1
}

echo "Node: $SLURM_JOB_NODELIST"
echo "Executable: $TIMED"
echo "Started: $(date)"

for test in 256_1 384_1 384_2 256_2; do

    NB=${test%%_*}
    REP=${test##*_}
    CASE="$SLURM_SUBMIT_DIR/NB$NB"

    [[ -s "$CASE/HPL.dat" ]] || {
        echo "ERROR: Missing HPL.dat for NB=$NB"
        exit 1
    }

    N=$(awk 'NR==6 {print $1}' "$CASE/HPL.dat")
    ACTUAL_NB=$(awk 'NR==8 {print $1}' "$CASE/HPL.dat")
    P=$(awk 'NR==11 {print $1}' "$CASE/HPL.dat")
    Q=$(awk 'NR==12 {print $1}' "$CASE/HPL.dat")

    if [[ "$N" != 270336 || "$ACTUAL_NB" != "$NB" ||
          "$P" != 8 || "$Q" != 16 ]]; then
        echo "ERROR: Invalid configuration for NB=$NB"
        exit 1
    fi

    echo "Starting NB=$NB repeat=$REP at $(date)"

    (
        cd "$CASE"
        srun -n "$SLURM_NTASKS" --cpu-bind=cores "$TIMED" \
            > "hpl_NB${NB}_rep${REP}.out" \
            2> "hpl_NB${NB}_rep${REP}.err"
    )

    OUTPUT="$CASE/hpl_NB${NB}_rep${REP}.out"

    if ! grep -q 'PASSED' "$OUTPUT"; then
        echo "ERROR: Numerical check failed for $test"
        exit 1
    fi

    grep -E '^WR|Max aggregated wall time|PASSED' "$OUTPUT"

    echo "Finished NB=$NB repeat=$REP at $(date)"
done

echo "All tests finished: $(date)"
