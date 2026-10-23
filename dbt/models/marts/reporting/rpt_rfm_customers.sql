{#-
  RFM segmentation of customers (people who bought at least once).
    Recency   - days since the last order (fewer days = better)
    Frequency - number of orders
    Monetary  - total spent (USD)
  Recency and monetary get a score from 1 to 5 (quintiles), frequency uses fixed order counts, and the combination of scores places the
  customer in a segment with a clear action: keep Champions happy, win back customers At Risk, etc.
-#}
with customers as (

    select
        user_pseudo_id,
        max(order_date)                     as last_order_date,
        min(order_date)                     as first_order_date,
        count(*)                            as frequency,
        sum(revenue_usd)                    as monetary_usd
    from {{ ref('fct_orders') }}
    group by user_pseudo_id

),

scored as (

    select
        c.*,
        {{ days_between('c.last_order_date', date_literal(var('rfm_reference_date'))) }} as recency_days,
        6 - ntile(5) over (order by {{ days_between('c.last_order_date', date_literal(var('rfm_reference_date'))) }}, c.user_pseudo_id) as r_score,
        -- most online customers buy once, so frequency uses fixed thresholds instead of quintiles
        case when c.frequency >= 4 then 5 when c.frequency = 3 then 4 when c.frequency = 2 then 3 else 1 end as f_score,
        ntile(5) over (order by c.monetary_usd, c.user_pseudo_id)                             as m_score
    from customers as c

)

select
    s.*,
    concat(cast(r_score as string), cast(f_score as string), cast(m_score as string)) as rfm_code,
    case
        when r_score >= 4 and f_score >= 4 and m_score >= 4 then 'Champions'
        when r_score >= 3 and f_score >= 4                  then 'Loyal customers'
        when r_score >= 4 and f_score <= 2 and m_score >= 4 then 'Big first purchase'
        when r_score >= 4 and f_score <= 2                  then 'New customers'
        when r_score >= 3 and f_score >= 2                  then 'Potential loyalists'
        when r_score <= 2 and (f_score >= 4 or m_score >= 4) then 'At risk - high value'
        when r_score <= 2 and f_score >= 2                  then 'At risk'
        else 'Hibernating'
    end as rfm_segment,
    d.acquisition_channel,
    d.first_device_category,
    d.first_country
from scored as s
left join {{ ref('dim_users') }} as d on d.user_pseudo_id = s.user_pseudo_id
