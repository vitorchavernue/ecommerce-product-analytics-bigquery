{#-
  Fact table of visits, ready for analysis.
  Adds the "closed" purchase funnel: a visit only counts in a step if it also went through all
  the previous steps. This is the view used by the funnel chart, where each bar is never larger
  than the one before it, so drop-offs between steps can be read directly.
-#}
select
    session_key,
    user_pseudo_id,
    session_date,
    session_start_ts,
    session_number,
    case when session_number = 1 or is_first_visit then 'New' else 'Returning' end   as visitor_type,
    channel,
    source,
    medium,
    landing_page,
    device_category,
    operating_system,
    browser,
    country,
    continent,
    is_engaged,
    engagement_seconds,
    page_views,

    -- open funnel (did the step happen at all)
    has_view_item,
    has_add_to_cart,
    has_begin_checkout,
    has_add_shipping_info,
    has_add_payment_info,
    has_purchase,

    -- closed funnel (step reached only after all the previous ones)
    has_view_item                                                     as funnel_1_view_item,
    has_view_item and has_add_to_cart                                 as funnel_2_add_to_cart,
    has_view_item and has_add_to_cart and has_begin_checkout          as funnel_3_begin_checkout,
    has_view_item and has_add_to_cart and has_begin_checkout
        and has_add_shipping_info                                     as funnel_4_shipping_info,
    has_view_item and has_add_to_cart and has_begin_checkout
        and has_add_shipping_info and has_add_payment_info            as funnel_5_payment_info,
    has_view_item and has_add_to_cart and has_begin_checkout
        and has_add_shipping_info and has_add_payment_info
        and has_purchase                                              as funnel_6_purchase,

    orders,
    revenue_usd
from {{ ref('int_sessions') }}
