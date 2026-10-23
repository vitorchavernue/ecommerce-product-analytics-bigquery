{#-
  Daily KPIs by channel, device and country (Looker Studio: scorecards and time series).
  Only additive numbers are stored (visits, orders, revenue...). Rates such as conversion are
  calculated in the dashboard as SUM(orders) / SUM(sessions), so they stay correct for any filter.
-#}
select
    session_date                                                    as date,
    channel,
    device_category,
    visitor_type,
    country,
    continent,
    count(*)                                                        as sessions,
    sum(case when is_engaged then 1 else 0 end)                     as engaged_sessions,
    sum(case when visitor_type = 'New' then 1 else 0 end)           as new_user_sessions,
    sum(page_views)                                                 as page_views,
    sum(engagement_seconds)                                         as engagement_seconds,
    sum(case when has_view_item then 1 else 0 end)                  as product_view_sessions,
    sum(case when has_add_to_cart then 1 else 0 end)                as add_to_cart_sessions,
    sum(case when has_purchase then 1 else 0 end)                   as purchase_sessions,
    sum(orders)                                                     as orders,
    sum(revenue_usd)                                                as revenue_usd
from {{ ref('fct_sessions') }}
group by 1, 2, 3, 4, 5, 6
