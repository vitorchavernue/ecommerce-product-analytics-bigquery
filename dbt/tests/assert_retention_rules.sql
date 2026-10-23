-- Retention must be between 0% and 100%, and exactly 100% in week 0 (the week of the first visit).
select *
from {{ ref('rpt_cohort_retention') }}
where retention_rate < 0 or retention_rate > 1
   or (week_number = 0 and abs(retention_rate - 1) > 0.000001)
