{#- Product catalog as seen in the events: latest name and category of each product id. -#}
with ranked as (

    select
        item_id,
        item_name,
        item_category,
        item_brand,
        row_number() over (partition by item_id order by event_ts desc) as latest
    from {{ ref('stg_ga4__items') }}

)

select item_id, item_name, item_category, item_brand
from ranked
where latest = 1
