{#-
  Products sold, one row per product inside each order.
  Uses the same "first record of each transaction" rule as the orders table, so duplicated purchase
  events do not double the units or the revenue of a product (identical copies recorded at the same
  moment are also collapsed by the DISTINCT below).
-#}
with purchase_items as (

    select
        i.*,
        dense_rank() over (partition by i.transaction_id order by i.event_ts, i.session_key) as record_order
    from {{ ref('stg_ga4__items') }} as i
    where i.event_name = 'purchase'
      and i.transaction_id is not null

)

select distinct
    transaction_id,
    user_pseudo_id,
    session_key,
    event_date        as order_date,
    item_id,
    item_name,
    item_category,
    price_usd,
    quantity,
    item_revenue_usd
from purchase_items
where record_order = 1
