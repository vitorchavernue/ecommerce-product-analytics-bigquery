{#-
  Orders (one row per purchase).
  The export sometimes records the same purchase more than once. Counting every purchase event would
  inflate sales, so each transaction id is kept only once (its first record).
  Purchases without a transaction id cannot be told apart and are left out (reported in data quality).
-#}
with purchases as (

    select
        transaction_id,
        user_pseudo_id,
        session_key,
        event_date,
        event_ts,
        purchase_revenue_usd,
        total_item_quantity,
        row_number() over (partition by transaction_id order by event_ts, session_key) as record_order
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'
      and transaction_id is not null

)

select
    transaction_id,
    user_pseudo_id,
    session_key,
    event_date      as order_date,
    event_ts        as order_ts,
    coalesce(purchase_revenue_usd, 0)  as revenue_usd,
    coalesce(total_item_quantity, 0)   as items_quantity
from purchases
where record_order = 1
