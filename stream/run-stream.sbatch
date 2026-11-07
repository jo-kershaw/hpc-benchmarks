#!/bin/bash
#SBATCH --job-name=stream_threads
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=01:00:00
#SBATCH --output=slurm_%j.out
#SBATCH --error=slurm_%j.err

set -euo pipefail
export LC_ALL=C

# CLUSTER is supplied by sbatch when we submit.
case "$CLUSTER" in
    calder)
        module purge
        export MODULEPATH=/uol/apps/calder/modules
        module load calder/cpu
        module load gcc/15.3.0
        CORES=128
        ;;
    aire)
        module purge
        module load gcc/14.2.0
        CORES=168
        ;;
    *)
        echo "Unknown cluster: $CLUSTER" >&2
        exit 1
        ;;
esac

# Confirm that the full node was allocated.
if [[ "${SLURM_CPUS_PER_TASK:-}" != "$CORES" ]]; then
    echo "Expected $CORES allocated cores" >&2
    exit 1
fi

EXE="$HOME/stream-thread-scaling/bin/stream-$CLUSTER"
ROOT="$PWD"


test -x "$EXE"

# Consistent OpenMP placement for every run.
export OMP_PLACES=cores
export OMP_PROC_BIND=spread
export OMP_DYNAMIC=FALSE

# Record enough information to reproduce the experiment.
{
    echo "Cluster: $CLUSTER"
    echo "Job: $SLURM_JOB_ID"
    echo "Node: $SLURM_JOB_NODELIST"
    echo "Started: $(date -Is)"
    echo "Cores: $CORES"
    echo "OMP_PLACES=$OMP_PLACES"
    echo "OMP_PROC_BIND=$OMP_PROC_BIND"
    echo "Memory policy: default, parallel first-touch"
    echo "Array size: 500000000"
    echo "NTIMES: 20"
    gcc --version | head -1
    sha256sum "$EXE"
    lscpu | grep -E 'Socket|NUMA node'
} > metadata.txt

# Choose the full set of thread counts.
if [[ "$CLUSTER" == "aire" ]]; then
    FIRST="1 2 4 8 16 32 64 96 128 168"
    SECOND="168 128 96 64 32 16 8 4 2 1"
    THIRD="64 2 168 4 128 1 96 8 32 16"
    EXPECTED=30
else
    FIRST="1 2 4 8 16 32 64 96 128"
    SECOND="128 96 64 32 16 8 4 2 1"
    THIRD="64 2 128 4 96 1 32 8 16"
    EXPECTED=27
fi

echo "cluster,threads,repeat,copy_gbs,triad_gbs" > results.csv

# Three rounds with varied thread-count order.
for REP in 1 2 3; do
    case "$REP" in
        1) ORDER="$FIRST" ;;
        2) ORDER="$SECOND" ;;
        3) ORDER="$THIRD" ;;
    esac

    for THREADS in $ORDER; do
        export OMP_NUM_THREADS="$THREADS"

        OUT="stream_t${THREADS}_r${REP}.out"
        ERR="stream_t${THREADS}_r${REP}.err"

        echo "Threads=$THREADS Rep=$REP Started=$(date -Is)"

        # One OpenMP process, with all node cores available.
        # OpenMP itself controls thread placement.
        srun -N 1 -n 1 -c "$CORES" --cpu-bind=none \
            "$EXE" > "$OUT" 2> "$ERR"

        # Check that STREAM completed successfully.
        if ! grep -q "Solution Validates" "$OUT"; then
            echo "STREAM validation failed: $OUT" >&2
            exit 1
        fi

        ACTUAL=$(awk '/Number of Threads counted =/ {
            print $NF
        }' "$OUT")

        if [[ "$ACTUAL" != "$THREADS" ]]; then
            echo "Unexpected OpenMP thread count: $ACTUAL" >&2
            exit 1
        fi

        # STREAM reports MB/s. Convert to decimal GB/s.
        awk -v cl="$CLUSTER" -v t="$THREADS" -v r="$REP" '
            /^Copy:/  {copy=$2}
            /^Triad:/ {triad=$2}
            END {
                if (copy=="" || triad=="") exit 1
                printf "%s,%d,%d,%.4f,%.4f\n",
                    cl,t,r,copy/1000,triad/1000
            }
        ' "$OUT" >> "$ROOT/results.csv"

    done
done

# Check that we collected every measurement.
if [[ $(wc -l < results.csv) -ne $((EXPECTED+1)) ]]; then
    echo "Missing results" >&2
    exit 1
fi

echo "All $EXPECTED STREAM tests completed successfully"
echo "Finished: $(date -Is)"
