#!/bin/bash
#SBATCH --job-name=hpl_calder_followup
#SBATCH --nodes=2
#SBATCH --ntasks=256
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=03:00:00
#SBATCH --output=hpl_%j.out
#SBATCH --error=hpl_%j.err

set -euo pipefail

EXPECTED_N="${1:?Matrix size N required}"
EXPECTED_NB="${2:?Block size NB required}"

module purge
export MODULEPATH=/uol/apps/calder/modules
module load calder/cpu
module load gcc/15.3.0
module load openmpi/5.0.10
module load openblas/0.3.33

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export OMP_DYNAMIC=FALSE

EXEC="$HOME/hpl-benchmark/hpl-2.3/bin/Calder/xhpl"

cd "$SLURM_SUBMIT_DIR"

# Verify the input configuration
N=$(awk 'NR==6 {print $1}' HPL.dat)
NB=$(awk 'NR==8 {print $1}' HPL.dat)
P=$(awk 'NR==11 {print $1}' HPL.dat)
Q=$(awk 'NR==12 {print $1}' HPL.dat)

if [[ "$N" != "$EXPECTED_N" ||
      "$NB" != "$EXPECTED_NB" ||
      "$P" != "16" ||
      "$Q" != "16" ]]; then
    echo "ERROR: HPL.dat configuration mismatch" >&2
    echo "N=$N NB=$NB P=$P Q=$Q" >&2
    exit 1
fi

test -x "$EXEC"

echo "===== HPL configuration ====="
echo "Job ID: $SLURM_JOB_ID"
echo "Nodes: $SLURM_JOB_NODELIST"
echo "N=$N NB=$NB P=$P Q=$Q"
echo "MPI processes: $SLURM_NTASKS"
echo "Executable: $EXEC"
echo "Start: $(date -Is)"
module list

# Record and verify process placement
srun -n "$SLURM_NTASKS" --cpu-bind=cores \
    hostname > rank_hosts.txt

sort rank_hosts.txt | uniq -c | tee rank_summary.txt

awk '
    { if ($1 != 128) bad=1; count++ }
    END { if (count != 2 || bad) exit 1 }
' rank_summary.txt

# Repeat within the same node allocation
for REP in 1 2; do

    echo "===== Repetition $REP ====="
    echo "Started: $(date -Is)"

    srun -n "$SLURM_NTASKS" --cpu-bind=cores \
        "$EXEC" \
        > "hpl_rep${REP}.out" \
        2> "hpl_rep${REP}.err"

    if ! grep -q 'PASSED' "hpl_rep${REP}.out"; then
        echo "ERROR: No HPL PASSED result in repetition $REP" >&2
        exit 1
    fi

    grep -E '^WR|PASSED|FAILED' "hpl_rep${REP}.out"

    echo "Finished: $(date -Is)"

done

echo "===== All repetitions completed ====="
