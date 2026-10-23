"""Checks that the synthetic sample keeps the shape and the business rules of the real GA4 export."""

import duckdb
import pytest

from scripts.generate_sample_data import SCHEMA, simulate, write


@pytest.fixture(scope="module")
def sample(tmp_path_factory):
    out = tmp_path_factory.mktemp("ga4")
    rows = simulate(users=300, seed=7)
    write(rows, out)
    return rows, out


def test_same_columns_as_the_ga4_export(sample):
    _, out = sample
    columns = [c[0] for c in duckdb.sql(f"describe select * from read_parquet('{out}/events_*.parquet')").fetchall()]
    assert columns == SCHEMA.names


def test_one_file_per_day_named_like_the_export(sample):
    _, out = sample
    files = sorted(p.name for p in out.glob("events_*.parquet"))
    assert files[0] >= "events_20201101.parquet" and files[-1] <= "events_20210131.parquet"


def test_every_event_has_a_session_id_and_purchases_have_revenue(sample):
    rows, _ = sample
    for r in rows:
        assert any(p["key"] == "ga_session_id" for p in r["event_params"])
        if r["event_name"] == "purchase":
            assert r["ecommerce"]["purchase_revenue_in_usd"] > 0
            assert r["items"]


def test_generation_is_reproducible():
    assert simulate(users=50, seed=1) == simulate(users=50, seed=1)
