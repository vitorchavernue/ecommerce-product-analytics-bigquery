{#-
  Visits (sessions).
  GA4 does not store visits as rows: a visit is the set of events that share the same user and
  session id. Here those events are grouped into one row per visit, with when it started, where it came
  from, how engaged it was, which steps of the purchase journey it reached and how much it sold.
-#}
with events as (

    select * from {{ ref('stg_ga4__events') }}
    where session_key is not null

),

orders as (

    select session_key, count(*) as orders, sum(revenue_usd) as revenue_usd
    from {{ ref('int_orders') }}
    group by session_key

),

sessions as (

    select
        session_key,
        max(user_pseudo_id)                                                     as user_pseudo_id,
        min(event_ts)                                                           as session_start_ts,
        min(event_date)                                                         as session_date,
        max(ga_session_number)                                                  as session_number,

        -- where the visit came from: the source of the visit if recorded, otherwise the first touch
        {{ first_value_by('session_source', 'event_ts') }}                      as session_source,
        {{ first_value_by('session_medium', 'event_ts') }}                      as session_medium,
        max(first_touch_source)                                                 as first_touch_source,
        max(first_touch_medium)                                                 as first_touch_medium,
        {{ first_value_by('page_location', 'event_ts') }}                       as landing_page,

        -- device and location
        max(device_category)                                                    as device_category,
        max(operating_system)                                                   as operating_system,
        max(browser)                                                            as browser,
        max(country)                                                            as country,
        max(continent)                                                          as continent,

        -- engagement
        max(case when is_engaged_event then 1 else 0 end) = 1                   as is_engaged,
        sum(coalesce(engagement_time_msec, 0)) / 1000.0                         as engagement_seconds,
        sum(case when event_name = 'page_view' then 1 else 0 end)               as page_views,
        max(case when event_name = 'first_visit' then 1 else 0 end) = 1         as is_first_visit,

        -- purchase journey: did the visit reach each step? (open funnel: each step on its own)
        max(case when event_name = 'view_item' then 1 else 0 end) = 1           as has_view_item,
        max(case when event_name = 'add_to_cart' then 1 else 0 end) = 1         as has_add_to_cart,
        max(case when event_name = 'begin_checkout' then 1 else 0 end) = 1      as has_begin_checkout,
        max(case when event_name = 'add_shipping_info' then 1 else 0 end) = 1   as has_add_shipping_info,
        max(case when event_name = 'add_payment_info' then 1 else 0 end) = 1    as has_add_payment_info,
        max(case when event_name = 'purchase' then 1 else 0 end) = 1            as has_purchase

    from events
    group by session_key

)

select
    s.*,
    coalesce(s.session_source, s.first_touch_source)                            as source,
    coalesce(s.session_medium, s.first_touch_medium)                            as medium,
    {{ channel_group('coalesce(s.session_source, s.first_touch_source)',
                     'coalesce(s.session_medium, s.first_touch_medium)') }}     as channel,
    coalesce(o.orders, 0)                                                        as orders,
    coalesce(o.revenue_usd, 0)                                                   as revenue_usd
from sessions as s
left join orders as o on o.session_key = s.session_key
