#!/bin/bash
#SBATCH --job-name=osu_mpi
#SBATCH --nodes=2
#SBATCH --ntasks=256
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=00:45:00
#SBATCH --output=osu_%j.out
#SBATCH --error=osu_%j.err

set -euo pipefail

# Select the correct software environment
case "${CLUSTER:-}" in
    calder)
        module purge
        export MODULEPATH=/uol/apps/calder/modules
        module load calder/cpu
        module load gcc/15.3.0
        module load openmpi/5.0.10
        ;;
    aire)
        module purge
        module load gcc/14.2.0
        module load openmpi/5.0.6/gcc-14.2.0
        ;;
    *)
        echo "ERROR: CLUSTER must be aire or calder" >&2
        exit 1
        ;;
esac

export OMP_NUM_THREADS=1

BIN="$HOME/mpi-benchmarks/install-$CLUSTER/libexec/osu-micro-benchmarks/mpi"

test -x "$BIN/pt2pt/osu_latency"
test -x "$BIN/pt2pt/osu_bw"
test -x "$BIN/collective/osu_allreduce"
test -x "$BIN/collective/osu_bcast"

echo "Cluster: $CLUSTER"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "Started: $(date -Is)"
module list
mpicc -show

# Run one process on each of the two nodes
pair() {
    if [[ "$CLUSTER" == "calder" ]]; then
        srun -n 2 --ntasks-per-node=1 --cpu-bind=cores "$@"
    else
        mpirun -np 2 --map-by ppr:1:node --bind-to core "$@"
    fi
}

# Run 128 processes on each node
allranks() {
    if [[ "$CLUSTER" == "calder" ]]; then
        srun -n 256 --ntasks-per-node=128 --cpu-bind=cores "$@"
    else
        mpirun -np 256 --map-by core --bind-to core "$@"
    fi
}

# Verify process placement
pair hostname > pair_hosts.txt
sort pair_hosts.txt | uniq -c

if [[ $(sort -u pair_hosts.txt | wc -l) -ne 2 ]]; then
    echo "ERROR: the two ranks are not on separate nodes" >&2
    exit 1
fi

allranks hostname > full_hosts.txt
sort full_hosts.txt | uniq -c > rank_summary.txt
cat rank_summary.txt

awk '{if ($1 != 128) bad=1; count++}
     END {if (count != 2 || bad) exit 1}' rank_summary.txt

# Three repetitions of four benchmarks
for REP in 1 2 3; do
    echo "===== Repetition $REP: $(date -Is) ====="

    pair "$BIN/pt2pt/osu_latency" \
        -m 1:1048576 -x 20 -i 1000 \
        > "latency_rep${REP}.txt"

    pair "$BIN/pt2pt/osu_bw" \
        -m 1:4194304 -x 20 -i 200 \
        > "bw_rep${REP}.txt"

    allranks "$BIN/collective/osu_allreduce" \
        -m 1:1048576 -x 20 -i 200 \
        > "allreduce_rep${REP}.txt"

    allranks "$BIN/collective/osu_bcast" \
        -m 1:1048576 -x 20 -i 200 \
        > "bcast_rep${REP}.txt"
done

echo "All benchmark runs completed"
echo "Finished: $(date -Is)"
