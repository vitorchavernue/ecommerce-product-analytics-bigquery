"""Statistics used in the findings report, written so a business reader can follow each step.

- wilson_interval: range in which the true conversion rate most likely lies (95%)
- two_proportion_test: are two conversion rates really different, or is the gap just chance?
- relative_lift: how much better (or worse) one rate is than another, in percent
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from scipy.stats import norm


# --------------------------------------------------------------------------------------------
# 1. Confidence interval of a rate
#    With few visits, a rate can look high just by luck. The interval shows that uncertainty:
#    the fewer the visits, the wider the range.
# --------------------------------------------------------------------------------------------
def wilson_interval(successes: int, trials: int, confidence: float = 0.95) -> tuple[float, float]:
    if trials <= 0:
        return (math.nan, math.nan)
    z = norm.ppf(1 - (1 - confidence) / 2)
    p = successes / trials
    centre = (p + z * z / (2 * trials)) / (1 + z * z / trials)
    half = z * math.sqrt(p * (1 - p) / trials + z * z / (4 * trials * trials)) / (1 + z * z / trials)
    return (centre - half, centre + half)


# --------------------------------------------------------------------------------------------
# 2. Comparing two rates (e.g. desktop vs mobile, holiday weeks vs normal weeks)
#    The p-value is the chance of seeing a gap this large if both groups actually converted the same.
#    Below 5% we call the difference statistically significant.
# --------------------------------------------------------------------------------------------
@dataclass(frozen=True)
class ProportionTest:
    rate_a: float
    rate_b: float
    z: float
    p_value: float

    @property
    def significant(self) -> bool:
        return self.p_value < 0.05


def two_proportion_test(successes_a: int, trials_a: int, successes_b: int, trials_b: int) -> ProportionTest:
    if min(trials_a, trials_b) <= 0:
        raise ValueError("both groups need at least one trial")
    rate_a, rate_b = successes_a / trials_a, successes_b / trials_b
    pooled = (successes_a + successes_b) / (trials_a + trials_b)
    se = math.sqrt(pooled * (1 - pooled) * (1 / trials_a + 1 / trials_b))
    z = (rate_a - rate_b) / se if se > 0 else 0.0
    return ProportionTest(rate_a, rate_b, z, 2 * (1 - norm.cdf(abs(z))))


# --------------------------------------------------------------------------------------------
# 3. Relative difference between two rates, in percent ("mobile converts 60% less than desktop")
# --------------------------------------------------------------------------------------------
def relative_lift(rate_a: float, rate_b: float) -> float:
    return math.nan if rate_b == 0 else (rate_a / rate_b - 1) * 100
