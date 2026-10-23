{#- Summary of the RFM segments: how many customers, how much revenue, and their typical behaviour. -#}
with customers as (

    select * from {{ ref('rpt_rfm_customers') }}

)

select
    rfm_segment,
    count(*)                                                    as customers,
    sum(monetary_usd)                                           as revenue_usd,
    sum(monetary_usd) / sum(sum(monetary_usd)) over ()          as revenue_share,
    count(*) * 1.0 / sum(count(*)) over ()                      as customer_share,
    avg(recency_days)                                           as avg_recency_days,
    avg(frequency)                                              as avg_orders,
    avg(monetary_usd)                                           as avg_revenue_usd
from customers
group by rfm_segment
