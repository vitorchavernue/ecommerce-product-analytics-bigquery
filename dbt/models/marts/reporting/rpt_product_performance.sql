{#-
  Product performance: how often each product is viewed, added to the cart and bought.
  The two conversion rates show where each product loses customers:
    cart rate     = visits that added the product / visits that viewed it
    purchase rate = orders with the product / visits that added it
  A product with many views but a low cart rate may have a price, photo or description problem.
-#}
with items as (

    select * from {{ ref('stg_ga4__items') }}

),

funnel as (

    select
        item_name,
        count(distinct case when event_name = 'view_item' then session_key end)    as view_sessions,
        count(distinct case when event_name = 'add_to_cart' then session_key end)  as cart_sessions
    from items
    group by item_name

),

sales as (

    select
        item_name,
        count(distinct transaction_id)      as orders,
        sum(quantity)                       as units_sold,
        sum(item_revenue_usd)               as revenue_usd
    from {{ ref('fct_order_items') }}
    group by item_name

)

select
    d.item_name,
    d.item_id,
    d.item_category,
    coalesce(f.view_sessions, 0)                                    as view_sessions,
    coalesce(f.cart_sessions, 0)                                    as cart_sessions,
    coalesce(s.orders, 0)                                           as orders,
    coalesce(s.units_sold, 0)                                       as units_sold,
    coalesce(s.revenue_usd, 0)                                      as revenue_usd,
    {{ safe_div('f.cart_sessions', 'f.view_sessions') }}            as cart_rate,
    {{ safe_div('s.orders', 'f.cart_sessions') }}                   as purchase_rate,
    {{ safe_div('s.revenue_usd', 'f.view_sessions') }}              as revenue_per_view_session
from {{ ref('dim_items') }} as d
left join funnel as f on f.item_name = d.item_name
left join sales as s on s.item_name = d.item_name
