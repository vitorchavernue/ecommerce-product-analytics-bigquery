{#- Users with acquisition channel, first device and country, and lifetime totals in the window. -#}
select
    user_pseudo_id,
    first_seen_date,
    is_new_in_window,
    acquisition_channel,
    acquisition_source,
    acquisition_medium,
    first_session_channel,
    first_device_category,
    first_country,
    first_session_ts,
    last_session_ts,
    sessions,
    engaged_sessions,
    orders,
    revenue_usd,
    orders > 0 as is_customer
from {{ ref('int_users') }}
