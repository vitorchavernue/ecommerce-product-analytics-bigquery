"""Generate a small synthetic dataset with the exact shape of the GA4 BigQuery export.

Why this exists
---------------
The real data (Google Merchandise Store, GA4 sample) lives in BigQuery. To test every model on a
laptop or in CI without a cloud account, this script creates a few thousand fake visitors whose
events follow the same structure as the real export: nested event parameters, a list of products
per event, device, country and traffic source. The numbers are invented; only the shape is real.

Usage
-----
    python scripts/generate_sample_data.py --out data/ga4_sample --users 4000 --seed 42
"""

from __future__ import annotations

import argparse
import random
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

# --------------------------------------------------------------------------------------------
# 1. Business assumptions used to invent the visitors
#    Period, devices, countries, marketing channels, product catalog and how likely a visitor
#    is to move from one step of the purchase journey to the next.
# --------------------------------------------------------------------------------------------
START = date(2020, 11, 1)
END = date(2021, 1, 31)
HOLIDAY_PEAK = (date(2020, 11, 27), date(2020, 12, 14))  # Black Friday to mid-December shopping

DEVICES = [("desktop", "Windows", "Chrome", 0.57), ("mobile", "Android", "Chrome", 0.22),
           ("mobile", "iOS", "Safari", 0.18), ("tablet", "iOS", "Safari", 0.03)]
COUNTRIES = [("United States", "Americas", 0.44), ("India", "Asia", 0.09), ("Canada", "Americas", 0.07),
             ("United Kingdom", "Europe", 0.04), ("Spain", "Europe", 0.03), ("France", "Europe", 0.03),
             ("Brazil", "Americas", 0.02), ("Japan", "Asia", 0.02), ("Germany", "Europe", 0.03),
             ("Taiwan", "Asia", 0.02), ("Other", "Europe", 0.21)]
# first-touch source / medium, as they appear in the export (including the obfuscated values)
CHANNELS = [("google", "organic", 0.34), ("(direct)", "(none)", 0.24), ("shop.googlemerchandisestore.com", "referral", 0.16),
            ("google", "cpc", 0.04), ("<Other>", "<Other>", 0.12), ("(data deleted)", "(data deleted)", 0.10)]
CATALOG = [
    ("GGOEGXXX0001", "Google Crewneck Sweatshirt", "Apparel", 48.0),
    ("GGOEGXXX0002", "Google Zip Hoodie", "Apparel", 55.0),
    ("GGOEGXXX0003", "Google Tee Black", "Apparel", 18.0),
    ("GGOEGXXX0004", "Google Cap", "Apparel", 22.0),
    ("GGOEGXXX0005", "Google Beanie", "Apparel", 16.0),
    ("GGOEGXXX0006", "Google Backpack", "Bags", 64.0),
    ("GGOEGXXX0007", "Google Tote Bag", "Bags", 14.0),
    ("GGOEGXXX0008", "Google Water Bottle", "Drinkware", 22.0),
    ("GGOEGXXX0009", "Google Mug", "Drinkware", 12.0),
    ("GGOEGXXX0010", "Google Tumbler", "Drinkware", 28.0),
    ("GGOEGXXX0011", "Google Notebook", "Office", 9.0),
    ("GGOEGXXX0012", "Google Pen Set", "Office", 6.0),
    ("GGOEGXXX0013", "Google Sticker Sheet", "Office", 3.0),
    ("GGOEGXXX0014", "Google Holiday Ornament", "Lifestyle", 10.0),
    ("GGOEGXXX0015", "Google Blanket", "Lifestyle", 45.0),
    ("GGOEGXXX0016", "Google Phone Case", "Electronics Accessories", 25.0),
]
# probability of reaching each step given the previous one (open funnel, per session)
FUNNEL = {"view_item": 0.42, "add_to_cart": 0.22, "begin_checkout": 0.55,
          "add_shipping_info": 0.82, "add_payment_info": 0.80, "purchase": 0.72}
DEVICE_FACTOR = {"desktop": 1.0, "mobile": 0.72, "tablet": 0.8}
CHANNEL_FACTOR = {"organic": 1.0, "(none)": 1.1, "referral": 0.85, "cpc": 1.35, "<Other>": 0.9, "(data deleted)": 0.95}


# --------------------------------------------------------------------------------------------
# 2. Small helpers to pick values following the weights above
# --------------------------------------------------------------------------------------------
def pick(rng: random.Random, options: list[tuple]) -> tuple:
    """Pick one option, using the last element of each tuple as its weight."""
    return rng.choices(options, weights=[o[-1] for o in options], k=1)[0]


def day_weight(d: date) -> float:
    """Relative traffic of a day: more visits in the holiday peak, fewer on weekends and after Christmas."""
    w = 1.0
    if HOLIDAY_PEAK[0] <= d <= HOLIDAY_PEAK[1]:
        w *= 1.6
    if d.weekday() >= 5:
        w *= 0.75
    if date(2020, 12, 24) <= d <= date(2021, 1, 3):
        w *= 0.6
    return w


def micros(ts: datetime) -> int:
    """Timestamps in the export are integers: microseconds since 1970 (UTC)."""
    return int(ts.timestamp() * 1_000_000)


def param(key: str, string_value=None, int_value=None, double_value=None) -> dict:
    """One event parameter, in the export's key / value structure."""
    return {"key": key, "value": {"string_value": string_value, "int_value": int_value,
                                  "float_value": None, "double_value": double_value}}


# --------------------------------------------------------------------------------------------
# 3. The table layout: same column names and nesting as the real GA4 export
# --------------------------------------------------------------------------------------------
VALUE = pa.struct([("string_value", pa.string()), ("int_value", pa.int64()),
                   ("float_value", pa.float64()), ("double_value", pa.float64())])
ITEM = pa.struct([("item_id", pa.string()), ("item_name", pa.string()), ("item_brand", pa.string()),
                  ("item_category", pa.string()), ("price_in_usd", pa.float64()), ("quantity", pa.int64()),
                  ("item_revenue_in_usd", pa.float64())])
SCHEMA = pa.schema([
    ("event_date", pa.string()),
    ("event_timestamp", pa.int64()),
    ("event_name", pa.string()),
    ("event_params", pa.list_(pa.struct([("key", pa.string()), ("value", VALUE)]))),
    ("user_pseudo_id", pa.string()),
    ("user_first_touch_timestamp", pa.int64()),
    ("device", pa.struct([("category", pa.string()), ("operating_system", pa.string()),
                          ("web_info", pa.struct([("browser", pa.string())]))])),
    ("geo", pa.struct([("continent", pa.string()), ("country", pa.string())])),
    ("traffic_source", pa.struct([("name", pa.string()), ("medium", pa.string()), ("source", pa.string())])),
    ("ecommerce", pa.struct([("transaction_id", pa.string()), ("purchase_revenue_in_usd", pa.float64()),
                             ("total_item_quantity", pa.int64()), ("unique_items", pa.int64())])),
    ("items", pa.list_(ITEM)),
    ("platform", pa.string()),
])


# --------------------------------------------------------------------------------------------
# 4. Simulate visitors: each one arrives on a day, may come back a few times, and in each visit
#    goes through the store (pages, product views, cart, checkout, purchase)
# --------------------------------------------------------------------------------------------
class Visit:
    """Writes the events of one visit, with the details shared by every event of that visit."""

    def __init__(self, rows: list[dict], rng: random.Random, user: dict, number: int, start: datetime, engaged: bool):
        self.rows, self.rng, self.user, self.number, self.engaged = rows, rng, user, number, engaged
        self.session_id = int(start.timestamp())
        self.clock = start

    def add(self, name: str, params: list[dict] | None = None, items=None, ecommerce=None, same_time=False) -> None:
        if not same_time:
            self.clock += timedelta(seconds=self.rng.randint(3, 90))
        u = self.user
        self.rows.append({
            "event_date": self.clock.strftime("%Y%m%d"),
            "event_timestamp": micros(self.clock),
            "event_name": name,
            "event_params": [param("ga_session_id", int_value=self.session_id),
                             param("ga_session_number", int_value=self.number),
                             param("session_engaged", string_value="1" if self.engaged else "0"),
                             param("page_location", string_value="https://shop.googlemerchandisestore.com/")]
            + (params or []),
            "user_pseudo_id": u["id"],
            "user_first_touch_timestamp": micros(u["first_touch"]),
            "device": {"category": u["device"], "operating_system": u["os"], "web_info": {"browser": u["browser"]}},
            "geo": {"continent": u["continent"], "country": u["country"]},
            "traffic_source": {"name": TRAFFIC_NAME.get(u["medium"], "<Other>"), "medium": u["medium"], "source": u["source"]},
            "ecommerce": ecommerce,
            "items": items or [],
            "platform": "WEB",
        })


TRAFFIC_NAME = {"organic": "(organic)", "(none)": "(direct)", "referral": "(referral)"}


def simulate(users: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    days = [START + timedelta(days=i) for i in range((END - START).days + 1)]
    weights = [day_weight(d) for d in days]
    rows: list[dict] = []
    order_no = 0

    for _ in range(users):
        device, os_name, browser, _w = pick(rng, DEVICES)
        country, continent, _w = pick(rng, COUNTRIES)
        source, medium, _w = pick(rng, CHANNELS)
        first_day = rng.choices(days, weights=weights, k=1)[0]
        user = {"id": f"{rng.randint(10**8, 10**9 - 1)}.{rng.randint(10**9, 2 * 10**9)}",
                "device": device, "os": os_name, "browser": browser, "country": country, "continent": continent,
                "source": source, "medium": medium,
                "first_touch": datetime.combine(first_day, datetime.min.time(), tzinfo=UTC)
                + timedelta(seconds=rng.randint(0, 86_399))}

        # how many visits this person makes (most people come only once)
        n_sessions = 1 + min(int(rng.expovariate(1.6)), 8)
        session_start = user["first_touch"]
        for s in range(n_sessions):
            if s > 0:
                session_start += timedelta(days=rng.expovariate(1 / 9), seconds=rng.randint(0, 40_000))
                if session_start.date() > END:
                    break
            in_peak = HOLIDAY_PEAK[0] <= session_start.date() <= HOLIDAY_PEAK[1]
            factor = DEVICE_FACTOR[device] * CHANNEL_FACTOR[medium] * (1.25 if in_peak else 1.0) * (1.3 if s > 0 else 1.0)
            visit = Visit(rows, rng, user, s + 1, session_start, engaged=rng.random() < (0.72 if device == "desktop" else 0.6))

            # arrival: first visit (new visitors only), session start and the pages seen
            if s == 0:
                visit.add("first_visit", same_time=True)
            visit.add("session_start", same_time=True)
            for _p in range(1 + int(rng.expovariate(0.45))):
                visit.add("page_view", [param("engagement_time_msec", int_value=rng.randint(500, 60_000))])
            if visit.engaged:
                visit.add("user_engagement", [param("engagement_time_msec", int_value=rng.randint(10_000, 400_000))])
                if rng.random() < 0.5:
                    visit.add("scroll", [param("percent_scrolled", int_value=90)])

            # purchase journey: each step only happens with a probability, given the previous one
            basket = [rng.choice(CATALOG) for _b in range(1 + int(rng.expovariate(1.2)))]
            for step, p in FUNNEL.items():
                if rng.random() >= min(0.97, p * factor):
                    break
                items = [{"item_id": i[0], "item_name": i[1], "item_brand": "Google", "item_category": i[2],
                          "price_in_usd": i[3], "quantity": 1 + int(rng.expovariate(1.8)), "item_revenue_in_usd": None}
                         for i in basket]
                ecommerce = None
                if step == "purchase":
                    order_no += 1
                    for it in items:
                        it["item_revenue_in_usd"] = round(it["price_in_usd"] * it["quantity"], 2)
                    ecommerce = {"transaction_id": f"T{order_no:06d}",
                                 "purchase_revenue_in_usd": round(sum(i["item_revenue_in_usd"] for i in items), 2),
                                 "total_item_quantity": sum(i["quantity"] for i in items), "unique_items": len(items)}
                visit.add(step, items=items, ecommerce=ecommerce)
                # the real export sometimes records the same purchase twice: keep that problem in the sample
                if step == "purchase" and rng.random() < 0.02:
                    visit.add(step, items=items, ecommerce=ecommerce)
    return rows


# --------------------------------------------------------------------------------------------
# 5. Save one Parquet file per day, named like the daily tables of the export (events_YYYYMMDD)
# --------------------------------------------------------------------------------------------
def write(rows: list[dict], out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("events_*.parquet"):
        old.unlink()
    by_day: dict[str, list[dict]] = {}
    last_day = END.strftime("%Y%m%d")
    for r in rows:
        if r["event_date"] > last_day:  # visits that cross midnight on the last day are cut, like the real sample
            continue
        by_day.setdefault(r["event_date"], []).append(r)
    for day, day_rows in sorted(by_day.items()):
        day_rows.sort(key=lambda r: r["event_timestamp"])
        pq.write_table(pa.Table.from_pylist(day_rows, schema=SCHEMA), out / f"events_{day}.parquet")
    return len(by_day)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default="data/ga4_sample", type=Path)
    parser.add_argument("--users", default=4000, type=int)
    parser.add_argument("--seed", default=42, type=int)
    args = parser.parse_args()
    rows = simulate(args.users, args.seed)
    days = write(rows, args.out)
    purchases = sum(1 for r in rows if r["event_name"] == "purchase")
    print(f"{len(rows):,} events · {days} daily files · {purchases:,} purchase events -> {args.out}")


if __name__ == "__main__":
    main()
