{#-
  Users (one row per browser / device identifier).
  Brings together everything we know about a visitor: when they first found the store and through
  which channel, how many times they came back, and how much they bought.
-#}
with sessions as (

    select * from {{ ref('int_sessions') }}

),

first_touch as (

    select user_pseudo_id, min(user_first_touch_ts) as first_touch_ts
    from {{ ref('stg_ga4__events') }}
    group by user_pseudo_id

),

per_user as (

    select
        user_pseudo_id,
        min(session_start_ts)                                       as first_session_ts,
        max(session_start_ts)                                       as last_session_ts,
        {{ first_value_by('device_category', 'session_start_ts') }} as first_device_category,
        {{ first_value_by('country', 'session_start_ts') }}         as first_country,
        {{ first_value_by('channel', 'session_start_ts') }}         as first_session_channel,
        max(first_touch_source)                                     as acquisition_source,
        max(first_touch_medium)                                     as acquisition_medium,
        count(*)                                                    as sessions,
        sum(case when is_engaged then 1 else 0 end)                 as engaged_sessions,
        sum(orders)                                                 as orders,
        sum(revenue_usd)                                            as revenue_usd
    from sessions
    group by user_pseudo_id

)

select
    p.*,
    f.first_touch_ts,
    cast(coalesce(f.first_touch_ts, p.first_session_ts) as date)                            as first_seen_date,
    -- a "new user" is someone whose first ever visit happened inside the analysis window
    cast(coalesce(f.first_touch_ts, p.first_session_ts) as date)
        >= {{ parse_yyyymmdd("'" ~ var('start_date') ~ "'") }}                               as is_new_in_window,
    {{ channel_group('p.acquisition_source', 'p.acquisition_medium') }}                     as acquisition_channel
from per_user as p
left join first_touch as f on f.user_pseudo_id = p.user_pseudo_id
