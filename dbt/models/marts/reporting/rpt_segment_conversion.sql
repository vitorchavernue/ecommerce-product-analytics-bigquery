{#-
  Which segments convert better or worse than the rest of the store, and is the difference real?
  For each channel, device, visitor type and continent:
    - conversion rate (visits with a purchase / visits) and its 95% confidence interval;
    - the same rate for all other visits;
    - a two-proportion z test: |z| > 1.96 means the gap is statistically significant (5% level),
      not just noise from a small number of visits.
-#}
with sessions as (

    select * from {{ ref('fct_sessions') }}

),

segments as (

    {% set dims = ['channel', 'device_category', 'visitor_type', 'continent'] %}
    {% for dim in dims %}
    select
        '{{ dim }}' as dimension,
        coalesce(cast({{ dim }} as string), '(not set)') as segment,
        count(*) as sessions,
        sum(case when has_purchase then 1 else 0 end) as converted_sessions,
        sum(revenue_usd) as revenue_usd
    from sessions
    group by 1, 2
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

totals as (

    select
        count(*) as sessions,
        sum(case when has_purchase then 1 else 0 end) as converted_sessions,
        sum(revenue_usd) as revenue_usd
    from sessions

),

compared as (

    select
        s.dimension,
        s.segment,
        s.sessions,
        s.converted_sessions,
        s.revenue_usd,
        t.sessions - s.sessions                     as rest_sessions,
        t.converted_sessions - s.converted_sessions as rest_converted_sessions,
        t.converted_sessions * 1.0 / t.sessions     as store_conversion_rate
    from segments as s
    cross join totals as t

)

select
    dimension,
    segment,
    sessions,
    converted_sessions,
    revenue_usd,
    {{ safe_div('converted_sessions', 'sessions') }}                                   as conversion_rate,
    {{ wilson_bound('converted_sessions', 'sessions', 'lower') }}                      as conversion_ci_low,
    {{ wilson_bound('converted_sessions', 'sessions', 'upper') }}                      as conversion_ci_high,
    {{ safe_div('rest_converted_sessions', 'rest_sessions') }}                         as rest_conversion_rate,
    {{ safe_div('converted_sessions', 'sessions') }} / nullif(store_conversion_rate, 0) as index_vs_store,
    {{ safe_div('revenue_usd', 'sessions') }}                                          as revenue_per_session,
    {{ two_proportion_z('converted_sessions', 'sessions', 'rest_converted_sessions', 'rest_sessions') }} as z_score,
    abs(coalesce({{ two_proportion_z('converted_sessions', 'sessions', 'rest_converted_sessions', 'rest_sessions') }}, 0)) > 1.96
                                                                                       as is_significant
from compared
