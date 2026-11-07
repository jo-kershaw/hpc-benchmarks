import csv
from collections import defaultdict
from statistics import median
from pathlib import Path
import matplotlib.pyplot as plt

# HPL block-size sweep: Calder, job 845308, node calder-cpu021
DATA = Path(__file__).with_name("calder_nb_sweep_2026-11-06.csv")

results = defaultdict(list)

# Read the measurements
with DATA.open(newline="") as f:
    for row in csv.DictReader(f):
        nb = int(row["NB"])
        performance = float(row["tflops"])

        results[nb].append(performance)

# Display the results
for nb in sorted(results):
    values = results[nb]

    print(
        f"NB={nb:3d}  "
        f"Runs={len(values)}  "
        f"Median={median(values):.4f} TFLOP/s"
    )

# Research Computing colours
RC_GREEN = "#0d5b57"
RC_NAVY = "#0c2d48"

import matplotlib.pyplot as plt
from statistics import median

# Calder colour from the STREAM plot
CALDER = "#d62828"

# Prepare data
block_sizes = sorted(results)
medians = [median(results[nb]) for nb in block_sizes]

# Work out y-axis limits with some padding
all_values = [v for values in results.values() for v in values]
ymin = min(all_values)
ymax = max(all_values)
ypad = 0.12 * (ymax - ymin)

fig, ax = plt.subplots(figsize=(8, 5))

# Faint line joining the medians
ax.plot(
    block_sizes,
    medians,
    color=CALDER,
    linewidth=1.6,
    alpha=0.35,
    zorder=1,
)

# Plot all three measurements at each NB
# Small horizontal offsets so overlapping points can be seen
offsets = [-6, 0, 6]

for nb in block_sizes:
    values = results[nb]
    for i, val in enumerate(values):
        ax.scatter(
            nb + offsets[i],
            val,
            s=90,
            marker="s",
            facecolor="white",
            edgecolor=CALDER,
            linewidth=1.2,
            alpha=0.95,
            zorder=2,
        )

# Plot the median as a larger filled marker
ax.scatter(
    block_sizes,
    medians,
    s=150,
    marker="s",
    color=CALDER,
    edgecolors="white",
    linewidths=1.2,
    zorder=3,
    label="Median",
)

ax.set_xlabel("HPL block size (NB)")
ax.set_ylabel("Performance (TFLOP/s)")
ax.set_title("Calder HPL performance by block size")

ax.set_xticks(block_sizes)
#ax.set_ylim(ymin - 0.15 * ypad, ymax + ypad)
#ax.set_ylim(ymin - 5.0 * ypad, ymax + ypad)
ax.set_ylim(6.0, 10.5)
ax.grid(axis="y", alpha=0.22)

# Optional legend
ax.legend(frameon=False)

fig.tight_layout()

fig.savefig(DATA.with_name("hpl_nb_sweep.png"), dpi=250)
fig.savefig(DATA.with_name("hpl_nb_sweep.svg"))

plt.close(fig)

print("Created HPL figures.")
