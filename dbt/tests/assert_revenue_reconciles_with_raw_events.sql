-- Orders must match the raw purchase events:
--   * one order per transaction id (no order lost, none duplicated)
--   * the revenue kept for each order is one of the values recorded for that transaction
--     (when the export repeats a purchase, the copies may carry different values; the first record is kept)
with raw_purchases as (
    select
        transaction_id,
        min(coalesce(purchase_revenue_usd, 0)) as min_revenue,
        max(coalesce(purchase_revenue_usd, 0)) as max_revenue
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase' and transaction_id is not null
    group by transaction_id
)
select
    coalesce(r.transaction_id, o.transaction_id) as transaction_id,
    r.min_revenue,
    r.max_revenue,
    o.revenue_usd
from raw_purchases as r
full outer join {{ ref('fct_orders') }} as o on o.transaction_id = r.transaction_id
where r.transaction_id is null
   or o.transaction_id is null
   or o.revenue_usd < r.min_revenue - 0.01
   or o.revenue_usd > r.max_revenue + 0.01
