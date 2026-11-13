
SOURCE="$HOME/hpl-benchmark/hpl-2.3/bin/Calder/HPL.dat"

N=$(awk 'NR==6 {print $1}' "$SOURCE")
NB=$(awk 'NR==8 {print $1}' "$SOURCE")
P=$(awk 'NR==11 {print $1}' "$SOURCE")
Q=$(awk 'NR==12 {print $1}' "$SOURCE")

RUN="/scratch-calder/users/$USER/hpl-benchmark/Calder/$(date +%F_%H%M%S)_N${N}_NB${NB}_P${P}_Q${Q}_MPI$((P*Q))"

mkdir -p "$RUN"
cp "$SOURCE" "$RUN/HPL.dat"
cp ~/hpl-benchmark/scripts/hpl-calder.sh "$RUN/"

cd "$RUN"
sbatch hpl-calder.sh
