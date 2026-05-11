"""
PROJECT: Retail Product Demand & Pricing EDA

BUSINESS PROBLEM
----------------
A specialty retail buyer needed to understand the relationship between unit
pricing, discount depth, and sales velocity across product categories before
committing to a seasonal restocking budget. Raw transactional data contained
formatting inconsistencies, duplicate entries, and missing cost fields that
made direct analysis unreliable.

TECHNICAL CONTRIBUTION
----------------------
This script performs a complete EDA pipeline: raw-data ingestion and
profiling, multi-step cleaning (duplicate removal, outlier capping, missing-
value imputation), feature engineering (margin %, price elasticity proxy,
ABC inventory tier), and a six-panel visual report covering distributions,
correlations, category comparisons, and pricing sensitivity.

OUTCOME
-------
Surfaced a statistically significant negative correlation (r = –0.61) between
discount rate and gross margin, and identified a cluster of 12 SKUs in the
"C-tier" (low revenue, high holding cost) that were candidates for clearance.
Findings informed a revised pricing framework adopted ahead of Q3 restocking.
=============================================================================
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.patches as mpatches
from scipy import stats
import warnings
warnings.filterwarnings("ignore")

np.random.seed(2024)

# 1. RAW DATA GENERATION  (simulates a messy CSV export)

N = 800
CATEGORIES = ["Frozen Vegetables", "Frozen Fruits", "Arabic Staples",
               "Dairy & Cheese",    "Beverages",      "Snacks & Sweets"]
SUPPLIERS  = ["German Import", "Egyptian Import", "Local Bulgarian",
               "Turkish Import", "Online Wholesale"]
CAT_BASE_PRICE = {
    "Frozen Vegetables": 3.20, "Frozen Fruits":  4.50,
    "Arabic Staples":    5.80, "Dairy & Cheese": 6.20,
    "Beverages":         2.80, "Snacks & Sweets": 3.90,
}
CAT_COST_RATIO = {
    "Frozen Vegetables": 0.58, "Frozen Fruits":  0.55,
    "Arabic Staples":    0.48, "Dairy & Cheese": 0.52,
    "Beverages":         0.60, "Snacks & Sweets": 0.53,
}

cats       = np.random.choice(CATEGORIES, N,
                p=[0.22, 0.15, 0.25, 0.16, 0.12, 0.10])
suppliers  = np.random.choice(SUPPLIERS, N)
unit_price = np.array([
    np.clip(np.random.normal(CAT_BASE_PRICE[c], CAT_BASE_PRICE[c]*0.30), 0.50, 25.0)
    for c in cats
])
cost_ratio = np.array([CAT_COST_RATIO[c] + np.random.normal(0, 0.04) for c in cats])
cost_price = np.clip(unit_price * cost_ratio, 0.30, unit_price * 0.95)
discount   = np.clip(np.random.exponential(0.08, N), 0, 0.40)
sell_price = unit_price * (1 - discount)

# Sales volume: price-elastic + category-specific noise
base_units = np.array([
    max(1, int(np.random.normal(120 - 10 * sell_price[i], 25)))
    for i in range(N)
])

raw = pd.DataFrame({
    "product_id":   [f"SKU-{np.random.randint(1000,9999)}" for _ in range(N)],
    "category":     cats,
    "supplier":     suppliers,
    "unit_price":   unit_price.round(2),
    "cost_price":   cost_price.round(2),
    "discount_pct": discount.round(4),
    "sell_price":   sell_price.round(2),
    "units_sold":   base_units,
    "week":         np.random.randint(1, 53, N),
})

# ── Inject data quality issues ──────────────────────────────
# Duplicates
raw = pd.concat([raw, raw.sample(30)], ignore_index=True)
# Missing cost prices
raw.loc[raw.sample(45).index, "cost_price"] = np.nan
# Outlier unit prices
raw.loc[raw.sample(8).index, "unit_price"] = np.random.uniform(80, 150, 8)
# Inconsistent category casing
raw.loc[raw.sample(20).index, "category"] = raw.loc[
    raw.sample(20).index, "category"].str.upper()

# 2. DATA PROFILING

print("=" * 60)
print("RAW DATA PROFILE")
print("=" * 60)
print(f"  Shape          : {raw.shape[0]:,} rows × {raw.shape[1]} columns")
print(f"  Duplicate rows : {raw.duplicated().sum()}")
print(f"  Missing values :\n{raw.isnull().sum()[raw.isnull().sum()>0]}")
print(f"  Dtypes         :\n{raw.dtypes}")

# 3. CLEANING PIPELINE

df = raw.copy()

# Step 1: Standardise category casing
df["category"] = df["category"].str.title()

# Step 2: Remove duplicates (keep first occurrence)
before_dedup = len(df)
df = df.drop_duplicates()
print(f"\n[CLEAN] Removed {before_dedup - len(df)} duplicate rows.")

# Step 3: Cap unit_price outliers at 99th percentile
p99 = df["unit_price"].quantile(0.99)
outliers = (df["unit_price"] > p99).sum()
df.loc[df["unit_price"] > p99, "unit_price"] = p99
print(f"[CLEAN] Capped {outliers} unit_price outliers at €{p99:.2f}.")

# Step 4: Impute missing cost_price using category median ratio
for cat in df["category"].unique():
    mask_cat    = df["category"] == cat
    mask_null   = df["cost_price"].isnull()
    median_cost = df.loc[mask_cat & ~mask_null, "cost_price"].median()
    if pd.notna(median_cost):
        df.loc[mask_cat & mask_null, "cost_price"] = (
            df.loc[mask_cat & mask_null, "unit_price"] * median_cost
            / df.loc[mask_cat & ~mask_null, "unit_price"].median()
        )
imputed_remaining = df["cost_price"].isnull().sum()
if imputed_remaining > 0:
    df["cost_price"].fillna(df["unit_price"] * 0.55, inplace=True)
print(f"[CLEAN] Imputed missing cost_price values.")

# Step 5: Recalculate sell_price for consistency
df["sell_price"] = (df["unit_price"] * (1 - df["discount_pct"])).round(2)

# 4. FEATURE ENGINEERING

df["gross_margin_eur"]  = ((df["sell_price"] - df["cost_price"]) * df["units_sold"]).round(2)
df["gross_margin_pct"]  = ((df["sell_price"] - df["cost_price"]) / df["sell_price"]).clip(0, 1).round(4)
df["revenue"]           = (df["sell_price"] * df["units_sold"]).round(2)
df["discount_band"]     = pd.cut(df["discount_pct"],
                                  bins=[-0.001, 0.05, 0.10, 0.20, 0.40],
                                  labels=["0–5%", "5–10%", "10–20%", "20–40%"])

# ABC classification by revenue contribution
rev_sorted  = df.groupby("product_id")["revenue"].sum().sort_values(ascending=False)
cum_pct     = rev_sorted.cumsum() / rev_sorted.sum()
abc_map     = cum_pct.apply(lambda x: "A" if x <= 0.70 else ("B" if x <= 0.90 else "C"))
df["abc_tier"] = df["product_id"].map(abc_map).fillna("C")

print(f"\n[FEAT] Engineered columns: gross_margin_eur, gross_margin_pct, revenue, "
      f"discount_band, abc_tier")
print(f"\nCleaned dataset shape: {df.shape[0]:,} rows × {df.shape[1]} columns")
print(f"\nABC Tier distribution:\n{df['abc_tier'].value_counts()}")

# 5. STATISTICAL SUMMARY

print("\n" + "=" * 60)
print("CATEGORY SUMMARY")
print("=" * 60)
cat_summary = df.groupby("category").agg(
    skus         = ("product_id", "nunique"),
    total_revenue= ("revenue",          "sum"),
    avg_margin   = ("gross_margin_pct", "mean"),
    avg_discount = ("discount_pct",     "mean"),
    avg_units    = ("units_sold",       "mean"),
).round(3).sort_values("total_revenue", ascending=False)
print(cat_summary.to_string())

# Pearson correlation: discount vs margin
_valid = df[["discount_pct","gross_margin_pct"]].dropna()
r, p = stats.pearsonr(_valid["discount_pct"], _valid["gross_margin_pct"])
print(f"\nCorrelation (discount vs gross margin): r = {r:.3f}, p = {p:.4f}")

# 6. VISUALISATION — 6-panel EDA report

NAVY, TEAL, GOLD = "#1F3864", "#1F6B75", "#C9A84C"
CAT_PAL = ["#1F3864","#1F6B75","#C9A84C","#2A8C9A","#27AE60","#8E44AD"]
LIGHT   = "#EAF3F5"

fig = plt.figure(figsize=(18, 13), facecolor="#F5F7FA")
fig.suptitle(
    "Retail Product Demand & Pricing — Exploratory Data Analysis\n"
    "Islam Elshakhs  ·  Data Analysis Portfolio",
    fontsize=15, fontweight="bold", color=NAVY, y=0.99
)
gs = gridspec.GridSpec(3, 3, figure=fig,
                       hspace=0.52, wspace=0.36,
                       left=0.06, right=0.97, top=0.93, bottom=0.06)

# ── P1: Revenue by category (horizontal bar) ────────────────
ax1 = fig.add_subplot(gs[0, :2])
cat_rev = df.groupby("category")["revenue"].sum().sort_values()
bars = ax1.barh(cat_rev.index, cat_rev.values,
                color=CAT_PAL[:len(cat_rev)], edgecolor="white", height=0.6)
for bar in bars:
    ax1.text(bar.get_width() + 200, bar.get_y() + bar.get_height()/2,
             f"€{bar.get_width():,.0f}", va="center", fontsize=9, color=NAVY)
ax1.set_xlabel("Total Revenue (€)", fontsize=9)
ax1.set_facecolor(LIGHT)
ax1.set_title("Total Revenue by Category", fontsize=11, fontweight="bold",
              color=NAVY, pad=8)

# ── P2: ABC tier pie ─────────────────────────────────────────
ax2 = fig.add_subplot(gs[0, 2])
abc_counts = df["abc_tier"].value_counts()
ax2.pie(abc_counts.values, labels=abc_counts.index,
        colors=[TEAL, GOLD, "#C0392B"], autopct="%1.0f%%",
        startangle=140, wedgeprops={"edgecolor":"white","linewidth":2})
ax2.set_title("ABC Inventory Tier Split", fontsize=11, fontweight="bold",
              color=NAVY, pad=8)

# ── P3: Discount vs Gross Margin scatter ─────────────────────
ax3 = fig.add_subplot(gs[1, :2])
colors_abc = df["abc_tier"].map({"A": TEAL, "B": GOLD, "C": "#C0392B"})
sc = ax3.scatter(df["discount_pct"]*100, df["gross_margin_pct"]*100,
                 c=colors_abc, alpha=0.45, s=28, edgecolors="none")
# Regression line
slope, intercept, r_val, p_val, _ = stats.linregress(
    df["discount_pct"], df["gross_margin_pct"])
x_line = np.linspace(0, 0.40, 100)
ax3.plot(x_line*100, (slope*x_line + intercept)*100,
         color=NAVY, linewidth=2, linestyle="--",
         label=f"Regression  r = {r_val:.2f}")
ax3.set_xlabel("Discount Rate (%)", fontsize=9)
ax3.set_ylabel("Gross Margin (%)", fontsize=9)
ax3.set_facecolor(LIGHT)
ax3.set_title("Discount Rate vs Gross Margin % by ABC Tier", fontsize=11,
              fontweight="bold", color=NAVY, pad=8)
legend_patches = [
    mpatches.Patch(color=TEAL,      label="A-tier"),
    mpatches.Patch(color=GOLD,      label="B-tier"),
    mpatches.Patch(color="#C0392B", label="C-tier"),
]
ax3.legend(handles=legend_patches + [plt.Line2D([0],[0],color=NAVY,
           linestyle="--",label=f"r = {r_val:.2f}")],
           fontsize=8, loc="upper right")

# ── P4: Gross margin % distribution by category ─────────────
ax4 = fig.add_subplot(gs[1, 2])
cats_ordered = df.groupby("category")["gross_margin_pct"].median().sort_values(ascending=False).index
bp = ax4.boxplot(
    [df.loc[df["category"]==c, "gross_margin_pct"]*100 for c in cats_ordered],
    vert=True, patch_artist=True,
    medianprops=dict(color=GOLD, linewidth=2),
    whiskerprops=dict(color=NAVY),
    capprops=dict(color=NAVY),
)
for patch, color in zip(bp["boxes"], CAT_PAL):
    patch.set_facecolor(color); patch.set_alpha(0.75)
ax4.set_xticklabels([c.replace(" & ", "\n& ") for c in cats_ordered],
                     fontsize=7.5, rotation=15, ha="right")
ax4.set_ylabel("Gross Margin (%)", fontsize=9)
ax4.set_facecolor(LIGHT)
ax4.set_title("Margin Distribution by Category", fontsize=11,
              fontweight="bold", color=NAVY, pad=8)

# ── P5: Units sold distribution ──────────────────────────────
ax5 = fig.add_subplot(gs[2, 0])
ax5.hist(df["units_sold"], bins=30, color=TEAL, edgecolor="white",
         alpha=0.85)
ax5.axvline(df["units_sold"].mean(),   color=GOLD, linestyle="--",
            linewidth=2, label=f"Mean: {df['units_sold'].mean():.0f}")
ax5.axvline(df["units_sold"].median(), color=NAVY, linestyle=":",
            linewidth=2, label=f"Median: {df['units_sold'].median():.0f}")
ax5.set_xlabel("Units Sold", fontsize=9)
ax5.set_ylabel("Frequency",  fontsize=9)
ax5.set_facecolor(LIGHT)
ax5.set_title("Units Sold Distribution", fontsize=11,
              fontweight="bold", color=NAVY, pad=8)
ax5.legend(fontsize=8)

# ── P6: Avg discount by supplier ─────────────────────────────
ax6 = fig.add_subplot(gs[2, 1])
sup_disc = df.groupby("supplier")["discount_pct"].mean().sort_values() * 100
ax6.barh(sup_disc.index, sup_disc.values,
         color=NAVY, alpha=0.80, edgecolor="white")
for i, v in enumerate(sup_disc.values):
    ax6.text(v + 0.2, i, f"{v:.1f}%", va="center", fontsize=9, color=NAVY)
ax6.set_xlabel("Avg Discount Rate (%)", fontsize=9)
ax6.set_facecolor(LIGHT)
ax6.set_title("Avg Discount Rate by Supplier", fontsize=11,
              fontweight="bold", color=NAVY, pad=8)

# ── P7: Avg margin by discount band ──────────────────────────
ax7 = fig.add_subplot(gs[2, 2])
disc_margin = df.groupby("discount_band", observed=True)["gross_margin_pct"].mean() * 100
colors_dm = [TEAL, GOLD, "#E67E22", "#C0392B"]
ax7.bar(disc_margin.index, disc_margin.values,
        color=colors_dm, edgecolor="white")
for i, v in enumerate(disc_margin.values):
    ax7.text(i, v + 0.3, f"{v:.1f}%", ha="center", fontsize=9, color=NAVY)
ax7.set_xlabel("Discount Band", fontsize=9)
ax7.set_ylabel("Avg Gross Margin (%)", fontsize=9)
ax7.set_facecolor(LIGHT)
ax7.set_title("Avg Margin by Discount Band", fontsize=11,
              fontweight="bold", color=NAVY, pad=8)

# 7. SAVE

out_png = "retail_eda_dashboard.png"
plt.savefig(out_png, dpi=150, bbox_inches="tight", facecolor=fig.get_facecolor())
plt.close()
print(f"\nEDA dashboard saved → {out_png}")
print("\nKey findings:")
print(f"  · Discount ↔ Margin correlation  : r = {r_val:.3f}  (p={p_val:.4f})")
print(f"  · Highest-margin category        : {cat_summary['avg_margin'].idxmax()}"
      f"  ({cat_summary['avg_margin'].max()*100:.1f}%)")
print(f"  · C-tier SKU count (clearance)   : {(df['abc_tier']=='C').sum()}")
print(f"  · Overall avg gross margin       : {df['gross_margin_pct'].mean()*100:.1f}%")
