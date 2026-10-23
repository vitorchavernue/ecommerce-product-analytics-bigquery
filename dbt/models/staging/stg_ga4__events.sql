{#-
  Events, flattened.
  The raw export keeps the details of each event inside nested lists. Here every useful detail
  becomes its own column (visit id, page, source of the visit, revenue...), with readable names and
  proper types. Every other model reads this table, so the large public dataset is scanned only once.
-#}
{{ config(cluster_by=['event_date', 'event_name']) }}

with source as (

    select * from {{ source('ga4', 'events') }}
    where {{ ga4_date_filter() }}

),

flattened as (

    select
        {{ parse_yyyymmdd('event_date') }}                          as event_date,
        {{ micros_to_timestamp('event_timestamp') }}                as event_ts,
        event_name,
        user_pseudo_id,
        {{ micros_to_timestamp('user_first_touch_timestamp') }}     as user_first_touch_ts,

        -- visit (session) identifiers
        {{ event_param('ga_session_id', 'int') }}                   as ga_session_id,
        {{ event_param('ga_session_number', 'int') }}               as ga_session_number,
        {{ event_param('session_engaged', 'string') }}              as session_engaged_flag,
        {{ event_param('engagement_time_msec', 'int') }}            as engagement_time_msec,

        -- page and source of the visit (when the event carries them)
        {{ event_param('page_location', 'string') }}                as page_location,
        {{ event_param('source', 'string') }}                       as session_source,
        {{ event_param('medium', 'string') }}                       as session_medium,

        -- how the user first found the store (first touch)
        traffic_source.source                                       as first_touch_source,
        traffic_source.medium                                       as first_touch_medium,

        -- device and location
        device.category                                             as device_category,
        device.operating_system                                     as operating_system,
        device.web_info.browser                                     as browser,
        geo.country                                                 as country,
        geo.continent                                               as continent,

        -- purchase details (only filled on purchase events)
        nullif(ecommerce.transaction_id, '(not set)')               as transaction_id,
        ecommerce.purchase_revenue_in_usd                           as purchase_revenue_usd,
        ecommerce.total_item_quantity                               as total_item_quantity

    from source

)

select
    *,
    case when ga_session_id is not null
         then concat(user_pseudo_id, '-', cast(ga_session_id as string)) end   as session_key,
    coalesce(session_engaged_flag = '1', false)                                as is_engaged_event
from flattened
