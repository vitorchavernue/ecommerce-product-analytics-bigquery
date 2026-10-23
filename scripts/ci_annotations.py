"""Show the result of a dbt run directly on the GitHub Actions page (as annotations).

- results: every model or test that failed becomes an error annotation with dbt's message,
  plus one notice with the totals, so a failure can be understood without opening the logs
- report:  the findings report is shown as a notice, so the main numbers of each production
  run can be read on the run page

Usage
-----
    python scripts/ci_annotations.py results dbt/target/run_results.json
    python scripts/ci_annotations.py report docs/findings.md
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path


def escape(text: str) -> str:
    """GitHub workflow commands need %, carriage returns and new lines encoded."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def results(path: Path) -> None:
    # 1. read dbt's run summary; if dbt stopped before writing it, say so
    if not path.exists():
        print(f"::error title=dbt::{path} not found - dbt stopped before running any model (see the step log)")
        return
    run = json.loads(path.read_text(encoding="utf-8"))
    # 2. one error annotation per failed model or test, with dbt's own explanation
    for r in run["results"]:
        if r["status"] in ("error", "fail", "runtime error"):
            print(f"::error title=dbt {r['status']}: {r['unique_id']}::{escape((r.get('message') or '')[:4000])}")
    # 3. totals by status (success, pass, error, fail, skipped...)
    totals = Counter(r["status"] for r in run["results"])
    print(f"::notice title=dbt totals::{escape(', '.join(f'{k}={v}' for k, v in sorted(totals.items())))}")


def report(path: Path, chunk_size: int = 3500) -> None:
    # GitHub shows about 4,000 characters per annotation: split the report at section breaks
    chunks, current = [], ""
    for block in path.read_text(encoding="utf-8").split("\n## "):
        block = block if not chunks and not current else "## " + block
        if current and len(current) + len(block) > chunk_size:
            chunks.append(current)
            current = ""
        current += ("\n" if current else "") + block
    chunks.append(current)
    for i, chunk in enumerate(chunks[:9], start=1):
        print(f"::notice title=findings report ({i}/{len(chunks)})::{escape(chunk)}")


if __name__ == "__main__":
    mode, file = sys.argv[1], Path(sys.argv[2])
    {"results": results, "report": report}[mode](file)
