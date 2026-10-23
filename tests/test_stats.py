"""Checks that the statistics used in the report give the textbook answers."""

import math

import pytest

from analysis.stats import relative_lift, two_proportion_test, wilson_interval


def test_wilson_interval_contains_the_rate_and_narrows_with_more_data():
    lo_small, hi_small = wilson_interval(5, 100)
    lo_big, hi_big = wilson_interval(500, 10_000)
    assert lo_small < 0.05 < hi_small
    assert lo_big < 0.05 < hi_big
    assert (hi_big - lo_big) < (hi_small - lo_small)


def test_wilson_interval_known_value():
    # 10 successes out of 100 -> 95% Wilson interval 5.52% - 17.44%
    lo, hi = wilson_interval(10, 100)
    assert lo == pytest.approx(0.0552, abs=1e-4)
    assert hi == pytest.approx(0.1744, abs=1e-4)


def test_wilson_interval_without_trials_is_undefined():
    assert all(math.isnan(x) for x in wilson_interval(0, 0))


def test_two_proportion_test_detects_a_real_gap_and_ignores_noise():
    real = two_proportion_test(300, 5_000, 150, 5_000)
    noise = two_proportion_test(51, 1_000, 49, 1_000)
    assert real.significant and real.z > 0
    assert not noise.significant
    assert noise.p_value > 0.5


def test_two_proportion_test_needs_trials():
    with pytest.raises(ValueError):
        two_proportion_test(1, 0, 1, 10)


def test_relative_lift():
    assert relative_lift(0.06, 0.03) == pytest.approx(100)
    assert relative_lift(0.015, 0.03) == pytest.approx(-50)
    assert math.isnan(relative_lift(0.01, 0))
