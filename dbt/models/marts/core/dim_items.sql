{#-
  Product catalog as seen in the events: one row per product name.
  A product can appear under different category paths in the export (e.g. "Home/Apparel/Men's / Unisex"
  and "Men's / Unisex"); the category used most often for that product is kept, plus its latest id.
-#}
with categories as (

    select
        item_name,
        item_category,
        row_number() over (partition by item_name order by count(*) desc, item_category) as category_rank
    from {{ ref('stg_ga4__items') }}
    group by item_name, item_category

),

latest as (

    select
        item_name,
        item_id,
        item_brand,
        row_number() over (partition by item_name order by case when item_id is null then 1 else 0 end, event_ts desc) as latest_rank
    from {{ ref('stg_ga4__items') }}

)

select l.item_name, l.item_id, c.item_category, l.item_brand
from latest as l
join categories as c on c.item_name = l.item_name and c.category_rank = 1
where l.latest_rank = 1
