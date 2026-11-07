#!/bin/bash
#SBATCH --job-name=hpl_A_NB_sweep
#SBATCH --nodes=1
#SBATCH --ntasks=168
#SBATCH --ntasks-per-node=168
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=24:00:00
#SBATCH --output=slurm_%j.out
#SBATCH --error=slurm_%j.err

set -euo pipefail

# Aire software environment
module purge
module load gcc/14.2.0
module load openmpi/5.0.5/gcc-14.2.0
module load openblas/0.3.28/gcc-14.2.0

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export OMP_DYNAMIC=FALSE

# Same executable as one-node binary-swap experiment
EXEC="$HOME/hpl-benchmark/hpl-2.3/bin/Aire/xhpl"
ROOT="$SLURM_SUBMIT_DIR"

cd "$ROOT"
test -x "$EXEC"

echo "Node: $SLURM_JOB_NODELIST"
echo "Executable: $EXEC"
sha256sum "$EXEC"
echo "Started: $(date -Is)"

# Verify that all 168 MPI ranks are on this node
srun -n 168 --cpu-bind=cores \
    hostname < /dev/null > rank_hosts.txt

sort rank_hosts.txt | uniq -c | tee rank_summary.txt

awk '
    {if ($1 != 168) bad=1; count++}
    END {if (count != 1 || bad) exit 1}
' rank_summary.txt

# Verify HPL configurations before running
for NB in 128 192 256 384 512; do
    SETTINGS=$(awk '
        NR==6  {n=$1}
        NR==8  {nb=$1}
        NR==11 {p=$1}
        NR==12 {q=$1}
        NR==23 {bcast=$1}
        NR==26 {swap=$1}
        END {print n,nb,p,q,bcast,swap}
    ' "$ROOT/NB$NB/HPL.dat")

    if [[ "$SETTINGS" != "270336 $NB 12 14 1 0" ]]; then
        echo "Incorrect HPL settings for NB=$NB: $SETTINGS" >&2
        exit 1
    fi
done

# Create a CSV file for plotting
echo "NB,rep,seconds,gflops,tflops" > "$ROOT/results.csv"

# Three rounds; vary the order to reduce order effects
for REP in 1 2 3; do

    case "$REP" in
        1) BLOCKS="128 192 256 384 512" ;;
        2) BLOCKS="512 384 256 192 128" ;;
        3) BLOCKS="256 128 512 192 384" ;;
    esac

    for NB in $BLOCKS; do

        cd "$ROOT/NB$NB"

        OUT="hpl_rep${REP}.out"
        ERR="hpl_rep${REP}.err"

        echo
        echo "===== NB=$NB, repetition $REP ====="
        echo "Started: $(date -Is)"

        srun -n 168 --cpu-bind=cores "$EXEC" \
            < /dev/null > "$OUT" 2> "$ERR"

        # Stop if the calculation did not pass
        if ! grep -q '^WR' "$OUT" ||
           ! grep -q 'PASSED' "$OUT" ||
           grep -q 'FAILED' "$OUT"; then
            echo "HPL FAILED for NB=$NB, repetition $REP" >&2
            exit 1
        fi

        grep -E '^WR|PASSED' "$OUT"

        # Extract elapsed time and TFLOP/s
        awk -v nb="$NB" -v rep="$REP" '
            /^WR/ {
                printf "%d,%d,%s,%s,%.4f\n",
                    nb, rep, $(NF-1), $NF, $NF/1000
            }
        ' "$OUT" >> "$ROOT/results.csv"

        echo "Finished: $(date -Is)"

    done
done

cd "$ROOT"

# There should be a header plus 15 measurements
if [[ $(wc -l < results.csv) -ne 16 ]]; then
    echo "ERROR: Missing measurements" >&2
    exit 1
fi

echo
echo "All 15 HPL runs completed successfully"
echo "Finished: $(date -Is)"
cat results.csv
