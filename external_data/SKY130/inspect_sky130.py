
from pathlib import Path
import pandas as pd
import json

root = Path(
    r"C:\Internship Project\external_data\SKY130\raw\default"
)

files = list(root.glob("*.parquet"))

if not files:
    raise FileNotFoundError(
        f"No Parquet files found in {root}"
    )

for file in files:
    df = pd.read_parquet(file)

    print(f"\n===== {file.name} =====")
    print("Rows:", len(df))
    print("Columns:", df.columns.tolist())
    print("\nMissing values:")
    print(df.isna().sum())

    if "topology" in df.columns:
        print("\nTopologies:")
        print(df["topology"].value_counts().head(20))

    if "converged" in df.columns:
        print("\nConvergence status:")
        print(df["converged"].value_counts(dropna=False))

    if "metrics" in df.columns:
        print("\nExample metrics:")
        for value in df["metrics"].dropna().head(3):
            try:
                print(json.loads(value))
            except (TypeError, json.JSONDecodeError):
                print(value)
