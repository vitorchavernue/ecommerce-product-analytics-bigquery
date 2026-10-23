-- The 95% interval must contain the measured conversion rate.
select *
from {{ ref('rpt_segment_conversion') }}
where conversion_rate < conversion_ci_low - 0.000001 or conversion_rate > conversion_ci_high + 0.000001
