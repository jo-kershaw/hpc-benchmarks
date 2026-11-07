import csv
import sys
from collections import defaultdict
from statistics import median

import matplotlib.pyplot as plt

RC_RED = "#d62828"
RC_GREEN = "#0d5b57"
RC_NAVY = "#0c2d48"

CLUSTER_COLOURS = {
    "Aire": RC_GREEN,
    "Calder": RC_RED,
}

CLUSTER_MARKERS = {
    "Aire": "o",      # Circle
    "Calder": "s",    # Square
}

# Usage:
# python plot_stream_scaling.py aire_results.csv calder_results.csv

results = defaultdict(list)

for filename in sys.argv[1:]:
    with open(filename, newline="") as f:
        for row in csv.DictReader(f):
            cluster = row["cluster"].capitalize()
            threads = int(row["threads"])
            bandwidth = float(row["triad_gbs"])

            results[(cluster, threads)].append(bandwidth)

if not results:
    raise SystemExit("Supply one or more results.csv files.")

summary = []

for (cluster, threads), values in sorted(results.items()):
    if len(values) != 3:
        print(f"Warning: {cluster}, {threads} threads: "
              f"only {len(values)} runs")

    summary.append({
        "cluster": cluster,
        "threads": threads,
        "median": median(values),
        "minimum": min(values),
        "maximum": max(values),
    })

fig, ax = plt.subplots(figsize=(9, 5.5))

for cluster in sorted({r["cluster"] for r in summary}):
    rows = sorted(
        (r for r in summary if r["cluster"] == cluster),
        key=lambda r: r["threads"],
    )

    x = [r["threads"] for r in rows]
    y = [r["median"] for r in rows]

    lower = [r["median"] - r["minimum"] for r in rows]
    upper = [r["maximum"] - r["median"] for r in rows]

    colour = CLUSTER_COLOURS.get(cluster, RC_NAVY)

    # Error bars only
    ax.errorbar(
        x, y,
        yerr=[lower, upper],
        fmt="none",
        ecolor=colour,
        elinewidth=1.4,
        capsize=4,
        alpha=0.35,
        zorder=1,
    )

    # Faint lines connecting the measurements
    ax.plot(
        x, y,
        color=colour,
        linewidth=1.2,
        alpha=0.3,
        zorder=1,
    )

    # Show the three individual measurements
    # Slight horizontal offsets prevent overlapping points
    for row in rows:
        threads = row["threads"]
        measurements = results[(cluster, threads)]

        for offset, bandwidth in zip(
            [0.90, 0.95, 1.05], measurements
        ):
            ax.scatter(
                threads * offset,
                bandwidth,
                s=50,
                marker=CLUSTER_MARKERS[cluster],
		facecolor="white",
                edgecolor=colour,
                alpha=0.95,
                zorder=2,
		linewidth=1.2
            )

    # Prominent markers, with different shapes for each cluster
    ax.scatter(
        x, y,
        s=150,
        marker=CLUSTER_MARKERS[cluster],
        color=colour,
        edgecolors="white",
        linewidths=1.2,
        label=cluster,
        zorder=3,
    )

ax.set_xscale("log", base=2)
ticks = sorted({r["threads"] for r in summary})
ax.set_xticks(ticks)
ax.set_xticklabels([str(t) for t in ticks])

ax.set_xlabel("Number of OpenMP threads")
ax.set_ylabel("STREAM Triad bandwidth (GB/s)")
ax.set_title("Memory bandwidth scaling on Aire and Calder")
ax.set_ylim(bottom=0)
ax.grid(axis="y", alpha=0.2)
ax.legend()

#fig.text(
   # 0.5, 0.02,
   # "Markers show the median of 3 runs; min–max error bars are often smaller than the markers.",
   # ha="center",
   # fontsize=9,
   # color=RC_NAVY,
#)

#fig.tight_layout(rect=(0, 0.06, 1, 1))
fig.tight_layout()
fig.savefig("stream_thread_scaling.png", dpi=250)
fig.savefig("stream_thread_scaling.svg")
plt.close(fig)

# Separate figure: variability between repetitions
fig2, ax2 = plt.subplots(figsize=(9, 3.5))

for cluster in sorted({r["cluster"] for r in summary}):
    rows = sorted(
        (r for r in summary if r["cluster"] == cluster),
        key=lambda r: r["threads"],
    )

    x = [r["threads"] for r in rows]

    spread = [
        100 * (r["maximum"] - r["minimum"]) / r["median"]
        for r in rows
    ]

    colour = CLUSTER_COLOURS[cluster]

    ax2.plot(
        x, spread,
        color=colour,
        alpha=0.3,
        linewidth=1.2,
    )

    ax2.scatter(
        x, spread,
        color=colour,
        marker=CLUSTER_MARKERS[cluster],
        s=65,
        label=cluster,
    )

ax2.set_xscale("log", base=2)
ax2.set_xticks(ticks)
ax2.set_xticklabels([str(t) for t in ticks])

ax2.set_xlabel("Number of OpenMP threads")
ax2.set_ylabel("Min–max spread / median (%)")
ax2.set_title("Variation across three STREAM repetitions")

ax2.set_ylim(bottom=0)
ax2.grid(axis="y", alpha=0.2)
ax2.legend()
ax2.set_ylim(0, 1)

fig2.tight_layout()
fig2.savefig("stream_variability.png", dpi=250)
fig2.savefig("stream_variability.svg")
plt.close(fig2)

with open("stream_thread_scaling_summary.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=list(summary[0]))
    writer.writeheader()
    writer.writerows(summary)

print("Created PNG, SVG and summary CSV.")
