import argparse
import os

from datasets import load_dataset

from open_thoughts import decontaminate, deduplicate
from open_thoughts.math.filter import filter_problems
from open_thoughts.math.reason import reason

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", default=False)
    args = parser.parse_args()

    ds = load_dataset("AI-MO/NuminaMath-CoT", split="train")
    ds = ds.filter(lambda x: x["source"] in ["amc_aime", "olympiads", "aops_forum", "math"])
    ds = ds.filter(filter_problems)
    ds = ds.rename_column("source", "source_subset")
    ds = ds.rename_column("problem", "question")
    ds = ds.add_column("domain", ["math"] * len(ds))
    ds = ds.add_column("source", ["numina_math"] * len(ds))

    if args.dry_run:
        ds = ds.take(3)

    ds = deduplicate(ds)
    ds = decontaminate(ds)
    ds = reason(ds)

    if args.dry_run:
        print("======== MATH DATASET ========")
        print(ds)
        print(ds[0])
        print("================")

    ds.push_to_hub(f"{os.environ.get('HF_ORG')}/open-thoughts-math{'-dry-run' if args.dry_run else ''}", private=os.environ.get("HF_PRIVATE"))
