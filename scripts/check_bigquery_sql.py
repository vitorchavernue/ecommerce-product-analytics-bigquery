"""Check that the BigQuery version of every dbt model is valid SQL, without a Google account.

How it works: dbt compiles the models as BigQuery SQL (`--vars '{render_bigquery_sql: true}'`), and this
script parses every compiled file with a BigQuery SQL parser. A typo in the BigQuery-only syntax
(nested fields, table wildcards, date functions) fails the CI build before it reaches production.

Usage
-----
    cd dbt && dbt compile --profiles-dir . --target local --vars '{render_bigquery_sql: true}'
    python scripts/check_bigquery_sql.py dbt/target/compiled
"""

from __future__ import annotations

import sys
from pathlib import Path

import sqlglot


def main(folder: str) -> int:
    files = sorted(Path(folder).rglob("*.sql"))
    errors = 0
    # parse each compiled model / test with the BigQuery grammar; report every file that fails
    for f in files:
        try:
            sqlglot.parse(f.read_text(encoding="utf-8"), read="bigquery", error_level=sqlglot.ErrorLevel.RAISE)
        except sqlglot.errors.ParseError as exc:
            errors += 1
            print(f"FAIL {f}: {str(exc)[:300]}")
    print(f"{len(files)} compiled files checked, {errors} with BigQuery syntax errors")
    return 1 if errors or not files else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dbt/target/compiled"))
