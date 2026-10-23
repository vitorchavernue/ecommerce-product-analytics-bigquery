{#- Product catalog as seen in the events: one row per product name, with its latest id and category. -#}
with ranked as (

    select
        item_name,
        item_id,
        item_category,
        item_brand,
        row_number() over (partition by item_name order by case when item_id is null then 1 else 0 end, event_ts desc) as latest
    from {{ ref('stg_ga4__items') }}

)

select item_name, item_id, item_category, item_brand
from ranked
where latest = 1
