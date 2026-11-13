#!/bin/bash
set -euo pipefail

# Usage: bash tune-nb.sh Aire 192
#    or: bash tune-nb.sh Calder 256

system="${1:?Specify Aire or Calder}"
nb="${2:?Specify block size, e.g. 192 or 256}"

case "$system" in
    Aire)
        ROOT="${SCRATCH:?SCRATCH not set}/hpl-benchmark/Aire"
        JOBSCRIPT="hpl-aire.sh"
        RANKS=168
        ;;
    Calder)
        ROOT="/scratch-calder/users/$USER/hpl-benchmark/Calder"
        JOBSCRIPT="hpl-calder.sh"
        RANKS=128
        ;;
    *)
        echo "System must be Aire or Calder"
        exit 1
        ;;
esac

# Restrict this first experiment to our chosen sizes
#case "$nb" in
#    192|256) ;;
#    *)
#        echo "Use NB=192 or NB=256"
#        exit 1
#        ;;
#esac

case "$nb" in
    192|256|384) ;;
    *) exit 1 ;;
esac


SOURCE="$HOME/hpl-benchmark/hpl-2.3/bin/$system/HPL.dat"
BATCH="$HOME/hpl-benchmark/scripts/$JOBSCRIPT"

# Read the existing full-node settings
N=$(awk 'NR==6 {print $1}' "$SOURCE")
P=$(awk 'NR==11 {print $1}' "$SOURCE")
Q=$(awk 'NR==12 {print $1}' "$SOURCE")

# Check that we're using our established full-node setup
if [[ "$N" != 270336 || $((P*Q)) -ne $RANKS ]]; then
    echo "Unexpected N or MPI grid in $SOURCE"
    exit 1
fi

# Make a new experiment directory
RUN="$ROOT/$(date +%F_%H%M%S)_N${N}_NB${nb}_P${P}_Q${Q}_MPI${RANKS}"

mkdir -p "$RUN"

# Create an experiment-specific HPL.dat
# without modifying the master copy
awk -v nb="$nb" '
    NR==8 {$1=nb}
    {print}
' "$SOURCE" > "$RUN/HPL.dat"

# Keep a copy of the submission script
cp "$BATCH" "$RUN/"

echo "Experiment: $RUN"
echo "N=$N  NB=$nb  P=$P  Q=$Q"

# Verify the input file before submitting
if [[ ! -s "$RUN/HPL.dat" ]]; then
    echo "ERROR: HPL.dat is missing or empty!"
    exit 1
fi

actual_nb=$(awk 'NR==8 {print $1}' "$RUN/HPL.dat")

if [[ "$actual_nb" != "$nb" ]]; then
    echo "ERROR: Expected NB=$nb but found NB=$actual_nb"
    exit 1
fi

echo "Verified HPL.dat: N=$N, NB=$actual_nb"
ls -lh "$RUN/HPL.dat"


# Submit three sequential repetitions
cd "$RUN"
sbatch --array=1-3%1 "$JOBSCRIPT"
