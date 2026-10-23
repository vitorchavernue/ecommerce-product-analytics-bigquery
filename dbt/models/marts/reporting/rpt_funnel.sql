{#-
  Purchase funnel in "long" format: one row per day, channel, device and step.
  Looker Studio can draw it as a funnel or bar chart and filter it by any dimension.
-#}
with sessions as (

    select * from {{ ref('fct_sessions') }}

),

steps as (

    {% set funnel = [
        (1, 'Product view', 'funnel_1_view_item'),
        (2, 'Add to cart', 'funnel_2_add_to_cart'),
        (3, 'Begin checkout', 'funnel_3_begin_checkout'),
        (4, 'Shipping info', 'funnel_4_shipping_info'),
        (5, 'Payment info', 'funnel_5_payment_info'),
        (6, 'Purchase', 'funnel_6_purchase'),
    ] %}
    {% for order, label, column in funnel %}
    select
        session_date as date, channel, device_category, visitor_type,
        {{ order }} as step_order,
        '{{ order }}. {{ label }}' as step_name,
        sum(case when {{ column }} then 1 else 0 end) as sessions
    from sessions
    group by 1, 2, 3, 4
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    s.*,
    t.total_sessions
from steps as s
join (
    select session_date as date, channel, device_category, visitor_type, count(*) as total_sessions
    from sessions group by 1, 2, 3, 4
) as t
  on t.date = s.date and t.channel = s.channel and t.device_category = s.device_category
 and t.visitor_type = s.visitor_type
