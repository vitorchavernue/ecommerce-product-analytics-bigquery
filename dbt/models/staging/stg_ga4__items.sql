{#-
  Products inside each shopping event.
  A single event (e.g. a purchase) can contain several products; here each product becomes one row,
  so we can measure views, cart additions and sales per product and per category.
-#}
{{ config(cluster_by=['event_name', 'item_id']) }}

with source as (

    select * from {{ source('ga4', 'events') }}
    where {{ ga4_date_filter() }}
      and event_name in ('view_item', 'add_to_cart', 'begin_checkout', 'add_shipping_info', 'add_payment_info', 'purchase')

)

select
    {{ parse_yyyymmdd('event_date') }}                                          as event_date,
    {{ micros_to_timestamp('event_timestamp') }}                                as event_ts,
    event_name,
    user_pseudo_id,
    case when {{ event_param('ga_session_id', 'int') }} is not null
         then concat(user_pseudo_id, '-', cast({{ event_param('ga_session_id', 'int') }} as string)) end as session_key,
    nullif(ecommerce.transaction_id, '(not set)')                               as transaction_id,
    item.item_id                                                                as item_id,
    item.item_name                                                              as item_name,
    item.item_brand                                                             as item_brand,
    coalesce(nullif(item.item_category, ''), '(not set)')                       as item_category,
    item.price_in_usd                                                           as price_usd,
    coalesce(item.quantity, 1)                                                  as quantity,
    coalesce(item.item_revenue_in_usd, item.price_in_usd * coalesce(item.quantity, 1)) as item_revenue_usd
from source
{{ unnest_items('item') }}
where item.item_id is not null
