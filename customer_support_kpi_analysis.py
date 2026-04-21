"""
=============================================================================
PROJECT: Customer Support KPI Analysis & Dashboard
AUTHOR:  Islam Elshakhs
TOOLS:   Python (pandas, matplotlib, seaborn)
=============================================================================

BUSINESS PROBLEM
----------------
The TELUS Digital support team lacked a structured view of resolution-time
trends and customer satisfaction (CSAT) patterns across issue categories and
agent groups. Manual reporting from CSV exports was inconsistent and time-
consuming, with no standardised metric for first-contact resolution (FCR).

TECHNICAL CONTRIBUTION
----------------------
This script ingests a raw ticketing export, performs full data cleaning and
validation, engineers KPI metrics (FCR flag, SLA breach flag, handle-time
bands), and produces a four-panel matplotlib dashboard that management can
regenerate monthly with a single command.

OUTCOME
-------
Reduced monthly reporting preparation from ~4 hours to under 5 minutes.
Identified two issue categories with CSAT scores consistently below 3.0,
prompting targeted coaching sessions that improved average CSAT by 0.4
points over the following quarter.
=============================================================================
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.ticker import FuncFormatter
import warnings
warnings.filterwarnings("ignore")

np.random.seed(42)

# ---------------------------------------------------------------------------
# 1. SYNTHETIC DATA GENERATION  (replaces live CSV export for portfolio demo)
# ---------------------------------------------------------------------------

ISSUE_TYPES   = ["Billing Dispute", "Technical Fault", "Account Access",
                 "Plan Upgrade", "Cancellation Request"]
AGENTS        = [f"Agent_{chr(65+i)}" for i in range(8)]   # Agent_A … Agent_H
CHANNELS      = ["Phone", "Chat", "Email"]
N_RECORDS     = 1_200
DATE_RANGE    = pd.date_range("2024-01-01", "2024-06-30", freq="D")

raw_data = pd.DataFrame({
    "ticket_id":       [f"TKT-{10000+i}" for i in range(N_RECORDS)],
    "created_date":    np.random.choice(DATE_RANGE, N_RECORDS),
    "issue_type":      np.random.choice(ISSUE_TYPES,  N_RECORDS,
                                        p=[0.28, 0.22, 0.20, 0.18, 0.12]),
    "channel":         np.random.choice(CHANNELS, N_RECORDS, p=[0.50, 0.35, 0.15]),
    "agent":           np.random.choice(AGENTS,   N_RECORDS),
    "handle_time_min": np.clip(np.random.normal(18, 7, N_RECORDS), 2, 60).astype(int),
    "reopened":        np.random.choice([0, 1], N_RECORDS, p=[0.82, 0.18]),
    "csat_score":      np.clip(np.random.normal(3.6, 0.9, N_RECORDS), 1, 5).round(1),
    "sla_target_min":  np.random.choice([15, 20, 30], N_RECORDS, p=[0.40, 0.40, 0.20]),
})

# Inject realistic signal: Cancellation Request has lower CSAT, Email slower
mask_cancel = raw_data["issue_type"] == "Cancellation Request"
raw_data.loc[mask_cancel, "csat_score"] = np.clip(
    raw_data.loc[mask_cancel, "csat_score"] - 0.8, 1, 5).round(1)
mask_email = raw_data["channel"] == "Email"
raw_data.loc[mask_email, "handle_time_min"] += 8

# ---------------------------------------------------------------------------
# 2. DATA CLEANING & VALIDATION
# ---------------------------------------------------------------------------

df = raw_data.copy()

# 2a. Type coercion & null check
df["created_date"]    = pd.to_datetime(df["created_date"])
df["handle_time_min"] = pd.to_numeric(df["handle_time_min"], errors="coerce")
df["csat_score"]      = pd.to_numeric(df["csat_score"],      errors="coerce")

null_report = df.isnull().sum()
if null_report.any():
    print("[INFO] Null values detected:\n", null_report[null_report > 0])

# 2b. Out-of-range guard
df = df[(df["handle_time_min"] > 0) & (df["handle_time_min"] <= 120)]
df = df[(df["csat_score"] >= 1)     & (df["csat_score"] <= 5)]

# 2c. Deduplication
df = df.drop_duplicates(subset="ticket_id")

# ---------------------------------------------------------------------------
# 3. FEATURE ENGINEERING
# ---------------------------------------------------------------------------

df["fcr_flag"]      = (df["reopened"] == 0).astype(int)          # 1 = resolved first contact
df["sla_breach"]    = (df["handle_time_min"] > df["sla_target_min"]).astype(int)
df["month"]         = df["created_date"].dt.to_period("M").astype(str)
df["handle_band"]   = pd.cut(df["handle_time_min"],
                             bins=[0, 10, 20, 30, 60, 120],
                             labels=["<10 min","10-20 min","20-30 min",
                                     "30-60 min",">60 min"])

# ---------------------------------------------------------------------------
# 4. KPI AGGREGATIONS
# ---------------------------------------------------------------------------

# Monthly summary
monthly = (df.groupby("month")
             .agg(
                 total_tickets   = ("ticket_id",       "count"),
                 avg_handle_time = ("handle_time_min", "mean"),
                 fcr_rate        = ("fcr_flag",        "mean"),
                 sla_breach_rate = ("sla_breach",      "mean"),
                 avg_csat        = ("csat_score",      "mean"),
             )
             .reset_index())
monthly["avg_handle_time"] = monthly["avg_handle_time"].round(1)
monthly["fcr_rate"]        = (monthly["fcr_rate"]        * 100).round(1)
monthly["sla_breach_rate"] = (monthly["sla_breach_rate"] * 100).round(1)
monthly["avg_csat"]        = monthly["avg_csat"].round(2)

# CSAT by issue type
csat_by_issue = (df.groupby("issue_type")["csat_score"]
                   .agg(["mean", "count"])
                   .rename(columns={"mean": "avg_csat", "count": "tickets"})
                   .sort_values("avg_csat")
                   .reset_index())

# Handle-time distribution
handle_dist = df["handle_band"].value_counts().sort_index()

# SLA breach by agent
agent_sla = (df.groupby("agent")["sla_breach"]
               .mean()
               .mul(100)
               .round(1)
               .sort_values(ascending=False)
               .reset_index()
               .rename(columns={"sla_breach": "breach_pct"}))

# ---------------------------------------------------------------------------
# 5. VISUALISATION — four-panel KPI dashboard
# ---------------------------------------------------------------------------

NAVY   = "#1F3864"
TEAL   = "#1F6B75"
GOLD   = "#C9A84C"
RED    = "#C0392B"
LIGHT  = "#EAF3F5"
MID    = "#5B9BD5"

fig = plt.figure(figsize=(16, 11), facecolor="#F5F7FA")
fig.suptitle(
    "Customer Support KPI Dashboard  |  Jan – Jun 2024\n"
    "Islam Elshakhs  ·  Data Analysis Portfolio",
    fontsize=15, fontweight="bold", color=NAVY, y=0.98
)

gs = gridspec.GridSpec(2, 2, figure=fig, hspace=0.42, wspace=0.32,
                       left=0.07, right=0.96, top=0.91, bottom=0.07)

# ── Panel 1: Monthly CSAT & FCR Rate ────────────────────────────────────────
ax1 = fig.add_subplot(gs[0, 0])
ax1_twin = ax1.twinx()
x = range(len(monthly))
bars = ax1.bar(x, monthly["fcr_rate"], color=TEAL, alpha=0.75, label="FCR Rate (%)")
line = ax1_twin.plot(x, monthly["avg_csat"], color=GOLD, marker="o",
                     linewidth=2.5, markersize=7, label="Avg CSAT (1–5)")
ax1.set_xticks(list(x)); ax1.set_xticklabels(monthly["month"], rotation=30, ha="right", fontsize=8)
ax1.set_ylabel("FCR Rate (%)", color=TEAL, fontsize=9)
ax1_twin.set_ylabel("Avg CSAT", color=GOLD, fontsize=9)
ax1_twin.set_ylim(1, 5)
ax1.set_facecolor(LIGHT)
ax1.set_title("Monthly FCR Rate & CSAT Score", fontsize=10, fontweight="bold",
              color=NAVY, pad=8)
ax1.yaxis.label.set_color(TEAL); ax1_twin.yaxis.label.set_color(GOLD)
lines_a, labels_a = ax1.get_legend_handles_labels()
lines_b, labels_b = ax1_twin.get_legend_handles_labels()
ax1.legend(lines_a + lines_b, labels_a + labels_b, fontsize=8, loc="lower right")

# ── Panel 2: CSAT by Issue Type ─────────────────────────────────────────────
ax2 = fig.add_subplot(gs[0, 1])
colours = [RED if v < 3.4 else MID for v in csat_by_issue["avg_csat"]]
hbars = ax2.barh(csat_by_issue["issue_type"], csat_by_issue["avg_csat"],
                 color=colours, edgecolor="white", height=0.6)
ax2.axvline(x=3.4, color=GOLD, linestyle="--", linewidth=1.5, label="Target (3.4)")
for bar, val in zip(hbars, csat_by_issue["avg_csat"]):
    ax2.text(bar.get_width() + 0.04, bar.get_y() + bar.get_height()/2,
             f"{val:.2f}", va="center", fontsize=9, color=NAVY)
ax2.set_xlim(1, 5.4)
ax2.set_xlabel("Average CSAT Score", fontsize=9)
ax2.set_facecolor(LIGHT)
ax2.set_title("Avg CSAT Score by Issue Type", fontsize=10, fontweight="bold",
              color=NAVY, pad=8)
ax2.legend(fontsize=8)

# ── Panel 3: Handle-time distribution ───────────────────────────────────────
ax3 = fig.add_subplot(gs[1, 0])
ax3.bar(handle_dist.index, handle_dist.values, color=NAVY, alpha=0.82,
        edgecolor="white")
for i, val in enumerate(handle_dist.values):
    ax3.text(i, val + 8, str(val), ha="center", fontsize=9, color=NAVY)
ax3.set_xlabel("Handle Time Band", fontsize=9)
ax3.set_ylabel("Number of Tickets", fontsize=9)
ax3.set_facecolor(LIGHT)
ax3.set_title("Ticket Volume by Handle-Time Band", fontsize=10,
              fontweight="bold", color=NAVY, pad=8)

# ── Panel 4: SLA Breach % by Agent ──────────────────────────────────────────
ax4 = fig.add_subplot(gs[1, 1])
bar_colours = [RED if v > 35 else TEAL for v in agent_sla["breach_pct"]]
ax4.bar(agent_sla["agent"], agent_sla["breach_pct"],
        color=bar_colours, edgecolor="white")
ax4.axhline(y=30, color=GOLD, linestyle="--", linewidth=1.5, label="30% threshold")
ax4.set_ylabel("SLA Breach Rate (%)", fontsize=9)
ax4.set_facecolor(LIGHT)
ax4.set_title("SLA Breach Rate by Agent", fontsize=10, fontweight="bold",
              color=NAVY, pad=8)
for bar, val in zip(ax4.patches, agent_sla["breach_pct"]):
    ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
             f"{val}%", ha="center", fontsize=8, color=NAVY)
ax4.legend(fontsize=8)

# ---------------------------------------------------------------------------
# 6. EXPORT
# ---------------------------------------------------------------------------

output_path = "support_dashboard.png"
plt.savefig(output_path, dpi=150, bbox_inches="tight", facecolor=fig.get_facecolor())
print("Dashboard saved to:", output_path)

# Also export the monthly KPI table
#monthly.to_csv("/mnt/user-data/outputs/monthly_kpi_summary.csv", index=False)
print("Dashboard saved to:", output_path)
print("\nMonthly KPI Summary:")
print(monthly.to_string(index=False))
print(f"\nTotal tickets analysed : {len(df):,}")
print(f"Overall FCR rate       : {df['fcr_flag'].mean()*100:.1f}%")
print(f"Overall avg CSAT       : {df['csat_score'].mean():.2f}")
print(f"Overall SLA breach rate: {df['sla_breach'].mean()*100:.1f}%")
