import csv
from collections import defaultdict
from statistics import median
from pathlib import Path
import matplotlib.pyplot as plt

# HPL block-size sweeps
# Aire: job 9234228, node028
# Calder: job 845308, calder-cpu021

FOLDER = Path(__file__).parent

DATASETS = {
    "Calder": FOLDER / "calder_nb_sweep_2026-11-06.csv",
    "Aire": FOLDER / "aire_nb_sweep_2026-11-07.csv",
}

results = {}

for cluster, filename in DATASETS.items():
    measurements = defaultdict(list)

    with filename.open(newline="") as f:
        for row in csv.DictReader(f):
            nb = int(row["NB"])
            performance = float(row["tflops"])
            measurements[nb].append(performance)

    results[cluster] = measurements

    print(f"\n{cluster}")
    for nb in sorted(measurements):
        values = measurements[nb]
        print(
            f"NB={nb:3d}  "
            f"Runs={len(values)}  "
            f"Median={median(values):.4f} TFLOP/s"
        )


# Research Computing colours and markers
COLORS = {
    "Aire": "#0d5b57",
    "Calder": "#d62828",
}

MARKERS = {
    "Aire": "o",
    "Calder": "s",
}

fig, ax = plt.subplots(figsize=(8, 4))

# Draw Calder first, then Aire
for cluster in ("Calder", "Aire"):

    measurements = results[cluster]
    block_sizes = sorted(measurements)
    medians = [median(measurements[nb]) for nb in block_sizes]

    color = COLORS[cluster]
    marker = MARKERS[cluster]

    # Faint connecting line
    ax.plot(
        block_sizes,
        medians,
        color=color,
        linewidth=1.6,
        alpha=0.35,
        zorder=1,
    )

    # All three measurements, using hollow markers
    offsets = [-6, 0, 6]

    for nb in block_sizes:
        for i, value in enumerate(measurements[nb]):
            ax.scatter(
                nb + offsets[i],
                value,
                s=90,
                marker=marker,
                facecolor="white",
                edgecolor=color,
                linewidth=1.2,
                alpha=0.95,
                zorder=2,
            )

    # Larger filled markers for medians
    ax.scatter(
        block_sizes,
        medians,
        s=170 if cluster == "Aire" else 150,
        marker=marker,
        color=color,
        edgecolors="white",
        linewidths=1.2,
        zorder=3,
        label=cluster,
    )

ax.set_xlabel("HPL block size")
ax.set_ylabel("Performance (TFLOP/s)")
ax.set_title("HPL performance by block size: Aire and Calder")

ax.set_xticks(block_sizes)
ax.set_ylim(4.0, 10.5)
#ax.set_yscale('log')
ax.grid(axis="y", alpha=0.22)
ax.legend(frameon=False)

fig.tight_layout()

fig.savefig(FOLDER / "hpl_nb_sweep.png", dpi=250)
fig.savefig(FOLDER / "hpl_nb_sweep.svg")

plt.close(fig)

print("Created HPL figures.")