{#-
  Fact table of orders, with the context of the visit in which each purchase happened
  (channel, device, country) and whether it was the customer's first order.
-#}
with orders as (

    select * from {{ ref('int_orders') }}

)

select
    o.transaction_id,
    o.user_pseudo_id,
    o.session_key,
    o.order_date,
    o.order_ts,
    o.revenue_usd,
    o.items_quantity,
    s.channel,
    s.device_category,
    s.country,
    s.continent,
    row_number() over (partition by o.user_pseudo_id order by o.order_ts, o.transaction_id)   as customer_order_number,
    row_number() over (partition by o.user_pseudo_id order by o.order_ts, o.transaction_id) = 1 as is_first_order
from orders as o
left join {{ ref('int_sessions') }} as s on s.session_key = o.session_key
