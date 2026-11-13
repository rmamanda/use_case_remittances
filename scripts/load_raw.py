#!/usr/bin/env python3
"""Load the three backend extracts into the raw schema.

dbt transforms; it does not ingest. In production this is a loader job writing raw
tables that dbt reads as sources. Here it is a script, so the warehouse ends up the
same shape either way and dbt never has to pretend a model is a source.
"""

from __future__ import annotations

import pathlib
import sys

import duckdb

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
DATABASE = ROOT / "data" / "warehouse.duckdb"
EXTRACTS = {
    "payments": "payments.csv",
    "receipts": "receipts.csv",
    "disbursements": "disbursements.csv",
}


def main() -> int:
    missing = [name for name in EXTRACTS.values() if not (RAW_DIR / name).exists()]
    if missing:
        print(f"Missing extracts in {RAW_DIR}: {', '.join(sorted(missing))}", file=sys.stderr)
        return 1

    DATABASE.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DATABASE))
    try:
        con.execute("create schema if not exists raw")
        for table, filename in EXTRACTS.items():
            path = (RAW_DIR / filename).as_posix()
            con.execute(
                f"""
                create or replace table raw.{table} as
                select
                    *,
                    '{filename}' as _source_file,
                    current_timestamp as _loaded_at
                from read_csv(
                    '{path}',
                    header = true,
                    all_varchar = true,
                    union_by_name = true
                )
                """
            )
            rows = con.execute(f"select count(*) from raw.{table}").fetchone()[0]
            print(f"raw.{table}: {rows:,} rows")
    finally:
        con.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
