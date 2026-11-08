from pathlib import Path
import csv
import sys
from statistics import median

import matplotlib.pyplot as plt

# Usage:
# python osu/plot_osu.py ~/hpc-benchmark-data/osu

DATA = Path(sys.argv[1]).expanduser()
OUTDIR = Path(__file__).resolve().parent

COLORS = {
    "Aire": "#0d5b57",
    "Calder": "#d62828",
}

MARKERS = {
    "Aire": "o",
    "Calder": "s",
}


def load_runs(cluster, test):
    """
    Read the three OSU repetition files for one cluster and one test.

    Returns a dictionary:
        size_in_bytes -> [rep1, rep2, rep3]
    """
    runs = []

    for rep in (1, 2, 3):
        filename = DATA / cluster / f"{test}_rep{rep}.txt"
        values = {}

        with filename.open() as f:
            for line in f:
                if not line.strip() or line.startswith("#"):
                    continue

                parts = line.split()
                if len(parts) != 2:
                    continue

                size, result = parts
                values[int(size)] = float(result)

        runs.append(values)

    sizes = sorted(runs[0])

    if any(sorted(run) != sizes for run in runs[1:]):
        raise ValueError(f"Message sizes differ: {cluster} {test}")

    return {
        size: [run[size] for run in runs]
        for size in sizes
    }


def summarise(cluster, test):
    """
    Convert the repetition data into median/min/max rows.
    """
    raw = load_runs(cluster.lower(), test)
    rows = []

    for size in sorted(raw):
        values = raw[size]

        if test == "bw":
            # OSU bandwidth output is in MB/s.
            # Convert to GB/s for a cleaner y-axis.
            values = [v / 1000.0 for v in values]
            units = "GB/s"
        else:
            units = "us"

        rows.append({
            "cluster": cluster,
            "test": test,
            "size_bytes": size,
            "median": median(values),
            "minimum": min(values),
            "maximum": max(values),
            "units": units,
        })

    return rows


def human_size_labels(values):
    """
    Simple labels for selected message sizes.
    """
    labels = []
    for v in values:
        if v >= 1024 * 1024:
            if v % (1024 * 1024) == 0:
                labels.append(f"{v // (1024 * 1024)}M")
            else:
                labels.append(str(v))
        elif v >= 1024:
            if v % 1024 == 0:
                labels.append(f"{v // 1024}K")
            else:
                labels.append(str(v))
        else:
            labels.append(str(v))
    return labels


def plot_panel(ax, rows, ylabel, title):
    """
    Plot one panel (latency or bandwidth).
    """
    for cluster in ("Aire", "Calder"):
        cluster_rows = [r for r in rows if r["cluster"] == cluster]

        x = [r["size_bytes"] for r in cluster_rows]
        y = [r["median"] for r in cluster_rows]
        lower = [r["median"] - r["minimum"] for r in cluster_rows]
        upper = [r["maximum"] - r["median"] for r in cluster_rows]

        color = COLORS[cluster]
        marker = MARKERS[cluster]

        # Aire is drawn above Calder
        layer = 10 if cluster == "Aire" else 5

        # Read all three original measurements
        raw = load_runs(cluster.lower(), cluster_rows[0]["test"])

        # Small horizontal offsets so individual runs are visible
        offsets = (0.88, 1.0, 1.12)

        for size in x:
            for offset, value in zip(offsets, raw[size]):

                if cluster_rows[0]["test"] == "bw":
                    value /= 1000.0

                ax.scatter(
                    size * offset,
                    value,
                    marker=marker,
                    s=32,
                    facecolors="none",
                    edgecolors=color,
                    linewidths=1.0,
                    alpha=0.65,
                    zorder=layer + 1,
                )

        # Faint connecting line
        ax.plot(
            x, y,
            color=color,
            linewidth=1.5,
            alpha=0.35,
        )

        # Error bars
        #ax.errorbar(
            #x, y,
            #yerr=[lower, upper],
            #fmt="none",
            #ecolor=color,
            #elinewidth=1.0,
            #capsize=3,
            #alpha=0.9,
        #)

        # Prominent median markers
        ax.scatter(
            x, y,
            color=color,
            marker=marker,
            s=65 if cluster == "Aire" else 50,
            label=cluster,
            zorder=layer + 2,
        )

    ax.set_xscale("log", base=2)
    ax.set_yscale('log')
    ax.set_xlabel("Message size (bytes)")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.grid(axis="y", alpha=0.25)

    # A small, readable set of x ticks
    all_sizes = sorted({r["size_bytes"] for r in rows})
    tick_candidates = [1, 16, 256, 4096, 65536, 1048576, 4194304]
    ticks = [t for t in tick_candidates if t in all_sizes]

    ax.set_xticks(ticks)
    ax.set_xticklabels(human_size_labels(ticks))


# Build summary data
latency_rows = []
bandwidth_rows = []

for cluster in ("Aire", "Calder"):
    latency_rows.extend(summarise(cluster, "latency"))
    bandwidth_rows.extend(summarise(cluster, "bw"))

# Write summary CSV
summary_file = OUTDIR / "osu_summary.csv"
with summary_file.open("w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "cluster", "test", "size_bytes",
            "median", "minimum", "maximum", "units"
        ],
    )
    writer.writeheader()
    writer.writerows(latency_rows + bandwidth_rows)

# Make the figure
#fig, axes = plt.subplots(1, 2, figsize=(11, 4.8))
fig, axes = plt.subplots(1, 2, figsize=(11, 3.8))


plot_panel(
    axes[0],
    latency_rows,
    ylabel="Latency (µs)",
    title="A. MPI latency",
)

plot_panel(
    axes[1],
    bandwidth_rows,
    ylabel="Bandwidth (GB/s)",
    title="B. MPI bandwidth",
)

axes[1].legend(frameon=False)

fig.tight_layout()

png_file = OUTDIR / "osu_mpi_two_panel.png"
svg_file = OUTDIR / "osu_mpi_two_panel.svg"

fig.savefig(png_file, dpi=300)
fig.savefig(svg_file)
plt.close(fig)

print(f"Created: {png_file}")
print(f"Created: {svg_file}")
print(f"Created: {summary_file}")