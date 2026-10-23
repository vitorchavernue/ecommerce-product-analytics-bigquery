-- Closed funnel: a step can never have more visits than the step before it.
with steps as (
    select date, channel, device_category, visitor_type, step_order, sessions,
           lag(sessions) over (partition by date, channel, device_category, visitor_type order by step_order) as previous_step
    from {{ ref('rpt_funnel') }}
)
select * from steps where previous_step is not null and sessions > previous_step
