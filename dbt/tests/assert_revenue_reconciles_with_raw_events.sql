-- Revenue in the orders table must equal the revenue of the raw purchase events,
-- counting each transaction once (tolerance: 1 cent).
with raw_purchases as (
    select transaction_id, max(purchase_revenue_usd) as revenue_usd
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase' and transaction_id is not null
    group by transaction_id
),
totals as (
    select
        (select coalesce(sum(revenue_usd), 0) from raw_purchases)              as raw_revenue,
        (select coalesce(sum(revenue_usd), 0) from {{ ref('fct_orders') }})   as model_revenue,
        (select count(*) from raw_purchases)                                   as raw_orders,
        (select count(*) from {{ ref('fct_orders') }})                         as model_orders
)
select * from totals
where abs(raw_revenue - model_revenue) > 0.01 or raw_orders <> model_orders
